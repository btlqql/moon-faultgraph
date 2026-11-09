"""Compare the MoonBit CLI and an independently built SCRAM 0.16.2."""
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
subprocess.run([os.environ.get("MOON_BIN", "moon"), "build", "--target", "js", "--deny-warn"], cwd=ROOT, check=True)
cli = ROOT / "_build/js/debug/build/cmd/main/main.js"

def moon_report(request, path):
    path.write_text(json.dumps(request), encoding="utf-8")
    result = subprocess.run(["node", str(cli), str(path)], cwd=ROOT, check=True,
                            capture_output=True, text=True, encoding="utf-8")
    return json.loads(result.stdout)

def scram_report(model, path):
    subprocess.run([args.scram, "--bdd", "--prime-implicants", "--probability=true", "--importance=true",
                    "--output-path", str(path), str(model)], check=True, timeout=60)
    return ET.parse(path).getroot()

def compare(report, reference):
    products = reference.find(".//results/sum-of-products")
    assert products is not None
    assert math.isclose(float(products.attrib["probability"]), report["probability"], rel_tol=1e-6)
    def literal(element):
        if element.tag == "not":
            return (element[0].attrib["name"], False)
        assert element.tag == "basic-event", element.tag
        return (element.attrib["name"], True)
    observed = {frozenset(literal(item) for item in term) for term in products.findall("product")}
    expected = {frozenset((item["event"],item["occurs"]) for item in term) for term in report["prime_implicants"]}
    assert observed == expected, (observed, expected)
    event_metrics = {row["event"]:row for row in report["importance_factors"]}
    comparisons = 0
    for item in reference.findall(".//results/importance/basic-event"):
        for own, other in [("fussell_vesely_dif","DIF"),("raw","RAW"),("rrw","RRW")]:
            metric = event_metrics[item.attrib["name"]][own]
            # SCRAM 0.16.2 leaves ratios with a zero denominator at a default value.
            if metric["state"] == "finite":
                assert math.isclose(float(item.attrib[other]), metric["value"], rel_tol=5e-6, abs_tol=1e-10), (own,item.attrib,metric)
                comparisons += 1
    assert comparisons > 0
    return comparisons

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
result = {"status":"passed","scram":"0.16.2","cases":records}
(BUILD/"scram-comparison.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
print(json.dumps(result,indent=2))
