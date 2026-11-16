"""Compare the MoonBit CLI and SCRAM 0.16.2 on static MEF models."""
import argparse
import json
import math
import os
from pathlib import Path
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "_build"
BUILD.mkdir(exist_ok=True)
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--scram", required=True)
parser.add_argument("--reference-model", type=Path, required=True)
args = parser.parse_args()
version = subprocess.run([args.scram, "--version"], capture_output=True, text=True, check=True, timeout=60)
assert version.stdout.split()[:2] == ["SCRAM", "0.16.2"], version.stdout
subprocess.run([os.environ.get("MOON_BIN", "moon"), "build", "--target", "js", "--deny-warn"], cwd=ROOT, check=True)
cli = ROOT / "_build/js/debug/build/cmd/main/main.js"

def moon_report(request, path, *, error=None):
    path.write_text(json.dumps(request), encoding="utf-8")
    result = subprocess.run(["node", str(cli), str(path)], cwd=ROOT,
                            capture_output=True, text=True, encoding="utf-8")
    report = json.loads(result.stdout)
    if error is None:
        assert result.returncode == 0 and report["ok"], report
    else:
        assert result.returncode != 0 and not report["ok"] and error in report["error"], report
    return report

def scram_report(model, path):
    subprocess.run([args.scram, "--bdd", "--prime-implicants", "--probability=true", "--importance=true",
                    "--output-path", str(path), str(model)], check=True, timeout=60)
    return ET.parse(path).getroot()

def compare(report, reference):
    top = report["top"]
    products, = [node for node in reference.findall("./results/sum-of-products") if node.get("name") == top]
    importance, = [node for node in reference.findall("./results/importance") if node.get("name") == top]
    reference_probability = float(products.attrib["probability"])
    assert math.isclose(reference_probability, report["probability"], rel_tol=1e-6), (top, reference_probability, report["probability"])

    def literal(element):
        if element.tag == "not":
            return (element[0].attrib["name"], False)
        assert element.tag == "basic-event", element.tag
        return (element.attrib["name"], True)
    observed = {frozenset(literal(item) for item in term) for term in products.findall("product")}
    expected = {frozenset((item["event"], item["occurs"]) for item in term) for term in report["prime_implicants"]}
    assert observed == expected, (top, observed, expected)
    event_metrics = {row["event"]: row for row in report["importance_factors"]}
    comparisons = 0
    for item in importance.findall("basic-event"):
        for own, other in [("fussell_vesely_dif", "DIF"), ("raw", "RAW"), ("rrw", "RRW")]:
            metric = event_metrics[item.attrib["name"]][own]
            # SCRAM 0.16.2 leaves ratios with a zero denominator at a default value.
            if metric["state"] == "finite":
                assert math.isclose(float(item.attrib[other]), metric["value"], rel_tol=5e-6, abs_tol=1e-10), (top, own, item.attrib, metric)
                comparisons += 1
    assert comparisons > 0
    return comparisons


def xml_structure(node):
    attributes = dict(node.attrib)
    if node.tag == "float":
        attributes["value"] = float(attributes["value"])
    return node.tag, attributes, (node.text or "").strip(), [xml_structure(child) for child in node]


def verify_scoped(temporary):
    source = ROOT / "examples/scoped-power.xml"
    output = temporary / "scoped-export.xml"
    request_path = temporary / "request.json"
    request = {"mef": str(source), "prime_implicants": True}
    moon_report(request, request_path, error="select a top gate explicitly")
    moon_report({**request, "top": "PlantA.Top", "probability_overrides": {"Power": 0.25}},
                request_path, error="unknown basic event Power")
    updated = moon_report({**request, "top": "PlantA.Top", "probability_overrides": {"PlantA.Power": 0.25},
                           "export": str(output)}, request_path)

    # Compare the whole tree after changing just the one qualified declaration.
    expected = ET.parse(source).getroot()
    probability, = expected.findall("./define-fault-tree[@name='PlantA']/define-basic-event[@name='Power']/float")
    probability.set("value", "0.25")
    assert xml_structure(ET.parse(output).getroot()) == xml_structure(expected), output

    scram_source = scram_report(source, temporary / "scoped-original-scram.xml")
    scram_export = scram_report(output, temporary / "scoped-export-scram.xml")
    scoped_records = []
    # A = XOR(a, not(pump and grid)); B = not(b or a or pump).
    for top, baseline, overridden in [("PlantA.Top", 0.804, 0.69), ("PlantB.Top", 0.378, 0.315)]:
        original = moon_report({**request, "top": top}, request_path)
        reimported = moon_report({**request, "mef": str(output), "top": top}, request_path)
        assert original["top"] == reimported["top"] == top, (original["top"], reimported["top"])
        assert math.isclose(original["probability"], baseline, rel_tol=1e-12), (top, original["probability"])
        assert math.isclose(reimported["probability"], overridden, rel_tol=1e-12), (top, reimported["probability"])
        assert original["prime_implicants"] == reimported["prime_implicants"], top
        if top == "PlantA.Top":
            assert updated["probability"] == reimported["probability"]
            assert updated["importance_factors"] == reimported["importance_factors"]
        metrics = compare(original, scram_source) + compare(reimported, scram_export)
        scoped_records.append({"model": source.name, "top": top, "baseline": original["probability"],
                               "export_probability": reimported["probability"],
                               "terms": len(original["prime_implicants"]), "finite_importance_checks": metrics})
    return scoped_records


records = []
with tempfile.TemporaryDirectory(dir=BUILD) as folder:
    temporary = Path(folder)
    paths = [ROOT / "examples/shared-power.xml", ROOT / "examples/independent-power.xml",
             ROOT / "examples/mode-switch.xml", args.reference_model.resolve()]
    for i, path in enumerate(paths):
        original = moon_report({"mef":str(path), "prime_implicants":True}, temporary/"request.json")
        metrics = compare(original, scram_report(path, temporary/f"original-{i}.xml"))
        out = temporary/f"export-{i}.xml"
        request = {"mef":str(path), "prime_implicants":True,"export":str(out)}
        if i == 0:
            request["probability_overrides"] = {"PowerLoss":0.02}
        exported = moon_report(request, temporary/"request.json")
        metrics += compare(exported, scram_report(out, temporary/f"round-trip-{i}.xml"))
        records.append({"model":path.name,"baseline":original["probability"],
                        "export_probability":exported["probability"],
                        "terms":len(original["prime_implicants"]),"finite_importance_checks":metrics})
    records.extend(verify_scoped(temporary))
result = {"status":"passed","scram":"0.16.2","cases":records}
(BUILD/"scram-comparison.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
print(json.dumps(result,indent=2))
