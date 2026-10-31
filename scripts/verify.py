"""Standalone independent oracles; only Python stdlib, MoonBit and Node required."""
from pathlib import Path
import itertools,json,math,os,random,subprocess,wave
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
    p=subprocess.run(['node',str(ROOT/'_build/js/debug/build/cmd/main/main.js'),str(path)],cwd=ROOT,capture_output=True,text=True,encoding='utf-8')
    result=json.loads(p.stdout)
    assert result['ok']==ok and (p.returncode==0)==ok,(p.stdout,p.stderr)
    return result

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
    req=dict(probabilities=p,gates=gates)
    if coherent:req.update(diagnose=True,range={'lower':[q*.5 for q in p],'upper':[q+.1 for q in p]},mitigations=True)
    result=request(req)
    assert abs(result['probability']-probability(gates,p))<1e-12
    for v in range(n):
        lo=p.copy();hi=p.copy();lo[v]=0;hi[v]=1
        assert abs(result['importance'][v]-(probability(gates,hi)-probability(gates,lo)))<1e-12
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
report={'status':'passed','seed':20261031,'boolean_truth_table_models':64,'coherent_range_cut_repair_models':40}

(WORK/'result.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
