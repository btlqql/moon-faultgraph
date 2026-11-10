"""Standalone independent oracles; only Python stdlib, MoonBit and Node required."""
from pathlib import Path
import itertools,json,math,os,random,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'_build/oracle';WORK.mkdir(parents=True,exist_ok=True)
R=random.Random(20261031)
MOON=os.environ.get('MOON_BIN','moon')
def invoke(args):
    p=subprocess.run(args,cwd=ROOT,capture_output=True,text=True,encoding='utf-8')
    assert p.returncode==0,(args,p.stdout,p.stderr)
    return p.stdout
invoke([MOON,'build','--target','js','--deny-warn'])
def request(data,ok=True):
    path=WORK/'request.json';path.write_text(json.dumps(data),encoding='utf-8')
    return request_from(path,ok)
def request_from(path,ok=True):
    p=subprocess.run(['node',str(ROOT/'_build/js/debug/build/cmd/main/main.js'),str(path)],cwd=ROOT,capture_output=True,text=True,encoding='utf-8')
    result=json.loads(p.stdout)
    assert result['ok']==ok and (p.returncode==0)==ok,(p.stdout,p.stderr)
    return result

def exhaustive_primes(gates, n):
    assignments = list(itertools.product((False, True), repeat=n))
    failures = [bits for bits in assignments if not truth(gates, bits)]
    def implies(term):
        return not any(all(bits[i] == state for i, state in term) for bits in failures)
    output = set()
    for mask in itertools.product((None, False, True), repeat=n):
        term = tuple((i, state) for i, state in enumerate(mask) if state is not None)
        if implies(term) and all(not implies(term[:i] + term[i+1:]) for i in range(len(term))):
            output.add(tuple(i+1 if state else -(i+1) for i, state in term))
    return output

def truth(gates,bits):
    values=[]
    for g in gates:
        op=g[0]
        values.append(bits[g[1]] if op=='event' else not values[g[1]] if op=='not' else
                      values[g[1]] and values[g[2]] if op=='and' else values[g[1]] or values[g[2]] if op=='or' else
                      sum(values[i] for i in g[2])>=g[1])
    return values[-1]
def probability(gates,p):
    return sum(math.prod(q if bit else 1-q for bit,q in zip(bits,p)) for bits in itertools.product([False,True],repeat=len(p)) if truth(gates,bits))
for case in range(64):
    n=R.randrange(1,7);gates=[['event',i] for i in range(n)]
    coherent=case<40
    for _ in range(12):
        op=R.choice(['and','or','vote'] if coherent else ['and','or','not','vote'])
        a,b=R.randrange(len(gates)),R.randrange(len(gates))
        gates.append([op,a] if op=='not' else [op,R.randrange(4),[a,b,a]] if op=='vote' else [op,a,b])
    p=[R.uniform(.1,.8) for _ in range(n)]
    req=dict(probabilities=p,gates=gates,prime_implicants=True)
    if coherent:req.update(diagnose=True,range={'lower':[q*.5 for q in p],'upper':[q+.1 for q in p]},mitigations=True)
    result=request(req)
    q = probability(gates,p)
    assert abs(result['probability']-q)<1e-12
    assert {tuple(term) for term in result['prime_implicants']} == exhaustive_primes(gates,n)
    for v in range(n):
        lo=p.copy();hi=p.copy();lo[v]=0;hi[v]=1
        q1, q0 = probability(gates,hi), probability(gates,lo)
        assert abs(result['importance'][v]-(q1-q0))<1e-12
        row = result['importance_factors'][v]
        for name, numerator, denominator in [('fussell_vesely_dif',p[v]*q1,q),('raw',q1,q),('rrw',q,q0)]:
            measure = row[name]
            if q == 0:
                assert measure == {'state':'undefined','value':None}
            elif denominator == 0:
                assert measure == {'state':'unbounded','value':None}
            else:
                assert measure['state']=='finite' and math.isclose(measure['value'],numerator/denominator,abs_tol=1e-12)
    if coherent:
        sets=[]
        for bits in itertools.product([False,True],repeat=n):
            ids=[i for i,b in enumerate(bits) if b]
            if truth(gates,bits) and all(not truth(gates,tuple(b and i!=v for i,b in enumerate(bits))) for v in ids):sets.append(tuple(ids))
        assert sorted(tuple(s) for s in result['diagnosis']['minimal_cut_sets'])==sorted(sets)
        assert abs(result['range']['lower']-probability(gates,[q*.5 for q in p]))<1e-12
        assert abs(result['range']['upper']-probability(gates,[q+.1 for q in p]))<1e-12
        for row in result['mitigations']:
            q=p.copy();q[row['event']]=0
            assert abs(row['remaining_probability']-probability(gates,q))<1e-12
request({'probabilities':[.1],'gates':[['event',0],['not',0]],'range':{'lower':[.1],'upper':[.2]}},False)
def model(name):
    return str(ROOT/'examples'/name)

shared = request({'mef':model('shared-power.xml'),'prime_implicants':True})
independent = request({'mef':model('independent-power.xml'),'prime_implicants':True})
switch = request({'mef':model('mode-switch.xml'),'prime_implicants':True})
assert math.isclose(shared['probability'], .154, abs_tol=1e-12)
assert math.isclose(independent['probability'], .1036, abs_tol=1e-12)
assert math.isclose(switch['probability'], .086, abs_tol=1e-12)
assert {frozenset((x['event'],x['occurs']) for x in term) for term in switch['prime_implicants']} == {
    frozenset([('AlternateMode',False),('PrimaryDown',True)]),
    frozenset([('AlternateMode',True),('AlternateDown',True)]),
    frozenset([('PrimaryDown',True),('AlternateDown',True)]),
}
design = request_from(ROOT/'examples/power-design-review.json')
assert design['top'] == 'ServiceDown' and design['maximum_probability'] == 0.09
assert design['baseline']['probability'] == shared['probability']
assert design['baseline']['meets_target'] is False
upgrade, split = design['variants']
assert [upgrade['name'], split['name']] == ['Upgrade the shared feed', 'Independent feeds']
assert upgrade['meets_target'] is True and split['meets_target'] is False
for result, expected in [(upgrade, .0788), (split, .1036)]:
    assert math.isclose(result['probability'], expected, abs_tol=1e-12)
    assert math.isclose(result['risk_reduction'], .154 - expected, abs_tol=1e-12)
    assert math.isclose(result['relative_risk_reduction'], (.154 - expected) / .154, abs_tol=1e-12)
    assert result['prime_implicants'] and result['importance_factors']
priority = design['baseline']['prevention_effects']
assert priority == sorted(priority, key=lambda row: (-row['risk_reduction'], row['event']))
assert priority[0]['event'] == 'PowerLoss' and priority[0]['effect'] == 'reduces_risk'
assert math.isclose(priority[0]['probability_if_prevented'], .06, abs_tol=1e-12)
assert math.isclose(priority[0]['risk_reduction'], .094, abs_tol=1e-12)

def review_request(baseline, variants, **options):
    return dict(design_review=dict(outcome='Service loss', probability_basis='Equal illustrative mission',
                                   baseline=baseline, variants=variants, **options))

nonmonotone = review_request(
    dict(name='Mode switch', mef=model('mode-switch.xml')),
    [dict(name='Fixed primary', probability_overrides=dict(AlternateMode=0))],
)
nonmonotone_report = request(nonmonotone)
mode = next(row for row in nonmonotone_report['baseline']['prevention_effects']
            if row['event'] == 'AlternateMode')
assert mode['effect'] == 'increases_risk'
assert math.isclose(mode['risk_reduction'], -.014, abs_tol=1e-12)
assert math.isclose(mode['probability_if_prevented'], .1, abs_tol=1e-12)
assert nonmonotone_report['variants'][0]['risk_reduction'] < 0
assert nonmonotone_report['variants'][0]['meets_target'] is None

zero = dict(name='Ideal feed and path', mef=model('shared-power.xml'),
            probability_overrides=dict(PowerLoss=0, PathAUnavailable=0))
restored_feed = dict(name='Restored feed fault', probability_overrides=dict(PowerLoss=.1))
tie = dict(name='Another restored feed fault', probability_overrides=dict(PowerLoss=.1))
isolated_path = dict(name='Path fault only', probability_overrides=dict(PathAUnavailable=.2))
zero_report = request(review_request(zero, [restored_feed, tie, isolated_path]))
assert zero_report['baseline']['probability'] == 0
assert [row['name'] for row in zero_report['variants']] == [
    'Path fault only', 'Another restored feed fault', 'Restored feed fault',
]
assert math.isclose(zero_report['variants'][0]['probability'], .06, abs_tol=1e-12)
assert [row['probability'] for row in zero_report['variants'][1:]] == [.1, .1]
assert all(row['relative_risk_reduction'] is None for row in zero_report['variants'])
boundary = dict(name='At the decimal target', mef=model('shared-power.xml'),
                probability_overrides=dict(PowerLoss=0, PathAUnavailable=.1, PathBUnavailable=.2))
below = dict(name='Below the target', probability_overrides=dict(PathAUnavailable=.09))
boundary_report = request(review_request(boundary, [below], maximum_probability=.02))
assert boundary_report['baseline']['probability'] == .1 * .2
assert boundary_report['baseline']['meets_target'] is False
assert boundary_report['variants'][0]['meets_target'] is True
for variants in [
    [dict(name=zero['name'], mef=model('shared-power.xml'))],
    [dict(name='No change specified')],
    [dict(name='Bad event', probability_overrides={'Unknown': .2})],
    [dict(name='Bad probability', probability_overrides={'PowerLoss': 1.2})],
    [dict(name='Conflicting top', top='other', mef=model('shared-power.xml'))],
]:
    request(review_request(zero, variants), False)
request(dict(review_request(zero, [restored_feed]), mef=model('shared-power.xml')), False)
request(review_request(zero, [restored_feed], maximum_probability=-.1), False)
request(review_request(zero, [restored_feed], prime_implicants='true'), False)

with tempfile.TemporaryDirectory(dir=WORK) as folder:
    exported = Path(folder)/'remediated.xml'
    change = dict(mef=model('shared-power.xml'), probability_overrides={'PowerLoss':.02},
                  export=str(exported), prime_implicants=True)
    revised = request(change)
    assert math.isclose(revised['probability'], .0788, abs_tol=1e-12)
    content = exported.read_bytes()
    request(change,False)
    assert exported.read_bytes()==content
    after = request(dict(mef=str(exported),prime_implicants=True))
    assert after['probability']==revised['probability']
    assert after['prime_implicants']==revised['prime_implicants']
    text = (ROOT/'examples/mode-switch.xml').read_text(encoding='utf-8')
    invalid = Path(folder)/'invalid.xml'
    for source in [
        text.replace('<!DOCTYPE opsa-mef>', '<!DOCTYPE opsa-mef SYSTEM "https://invalid.example/dtd">'),
        text.replace('<basic-event name="PrimaryDown"/>','<gate name="ServiceDown"/>'),
        text.replace('<float value="0.03"/>','<float value="1.2"/>'),
        text.replace('<basic-event name="AlternateDown"/>','<gate name="AlternateDown"/>'),
    ]:
        invalid.write_text(source,encoding='utf-8')
        request({'mef':str(invalid)},False)
    invalid.write_text(text.replace('ServiceDown', 'DifferentTop'), encoding='utf-8')
    mismatch = request(review_request(zero, [dict(name='Different gate', mef=str(invalid))]), False)
    assert 'unknown top gate ServiceDown' in mismatch['error'], mismatch
    absent = Path(folder)/'absent.xml'
    missing = request(review_request(zero, [dict(name='Missing file', mef=str(absent))]), False)
    assert 'cannot read input' in missing['error']
report={'status':'passed','seed':20261031,'boolean_truth_table_models':64,
        'signed_prime_and_importance_oracles':64,'coherent_range_cut_repair_models':40,
        'shared_power':shared['probability'],'independent_feeds':independent['probability'],
        'upgraded_shared_power':revised['probability'],'mode_switch':switch['probability'],
        'mef_round_trip_and_invalid_inputs':True,
        'design_review_ranking_and_target':True,'design_review_signed_prevention':True,
        'design_review_zero_baseline_and_isolated_variants':True,
        'design_review_computed_probability_target_boundary':True}

(WORK/'result.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
