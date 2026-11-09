///|
extern "js" fn read_input(path : String) -> String =
  #| p => {const f=process.getBuiltinModule('fs'); const s=f.statSync(p); if(s.size>16000000)throw Error('input exceeds 16 MB');return f.readFileSync(p,'utf8');}

///|
extern "js" fn status(code : Int32) -> Unit =
  #| n => {process.exitCode=n;}

///|
fn field(j : Json, name : String) -> Json raise {
  guard j is Object(o) else { fail("expected object") }
  guard o.get(name) is Some(v) else { fail("missing field " + name) }
  v
}

///|
fn arr(j : Json) -> Array[Json] raise {
  guard j is Array(a) else { fail("expected array") }
  a
}

///|
fn num(j : Json) -> Double raise {
  guard j is Number(n, ..) else { fail("expected number") }
  if n != n || n - n != 0.0 {
    fail("nonfinite number")
  }
  n
}

///|
fn integer(j : Json) -> Int32 raise {
  let n = num(j)
  if n < -1000000.0 || n > 1000000.0 || n.to_int().to_double() != n {
    fail("expected bounded integer")
  }
  n.to_int()
}

///|
fn main {
  try {
    let args = @env.args()
    if args.length() < 3 {
      fail("usage: moon run cmd/main --target js -- request.json")
    }
    let path = args[args.length() - 1]
    let request = @json.parse(read_input(path))
    let result = if request is Object(fields) &&
      fields.get("mef") is Some(String(model)) {
      run_mef(request, path, model)
    } else {
      execute(request)
    }
    println(result.stringify())
  } catch {
    error => {
      println(
        Json::object({ "ok": Json(false), "error": Json(error.to_string()) }).stringify(),
      )
      status(1)
    }
  }
}

///|
fn execute(j : Json) -> Json raise {
  let probabilities = arr(field(j, "probabilities")).map(fn(x) raise { num(x) })
  let gates : Array[@core.Gate] = []
  for row in arr(field(j, "gates")) {
    let a = arr(row)
    if a.is_empty() {
      fail("empty gate")
    }
    guard a[0] is String(op) else { fail("expected gate operator") }
    let gate = match op {
      "event" => {
        if a.length() != 2 {
          fail("event arity")
        }
        @core.Event(integer(a[1]))
      }
      "not" => {
        if a.length() != 2 {
          fail("not arity")
        }
        @core.Not(integer(a[1]))
      }
      "and" | "or" => {
        if a.length() != 3 {
          fail("binary arity")
        }
        let x = integer(a[1])
        let y = integer(a[2])
        if op == "and" {
          @core.And(x, y)
        } else {
          @core.Or(x, y)
        }
      }
      "vote" => {
        if a.length() != 3 {
          fail("vote arity")
        }
        @core.Vote(integer(a[1]), arr(a[2]).map(fn(x) raise { integer(x) }))
      }
      _ => fail("unknown operator")
    }
    gates.push(gate)
  }
  let graph = @core.compile(gates, probabilities.length())
  let factors = graph.event_importance(probabilities)
  let names = Array::makei(probabilities.length(), fn(i) { i.to_string() })
  let prime_implicants = if j is Object(fields) &&
    fields.get("prime_implicants") is Some(True) {
    Json(graph.prime_implicants())
  } else {
    Json::null()
  }
  let diagnosis = if j is Object(fields) && fields.get("diagnose") is Some(True) {
    let cutsets = graph.minimal_cut_sets()
    let conditional = match fields.get("observations") {
      None => Json::null()
      Some(values) =>
        Json(
          graph.conditioned_probability(
            probabilities,
            arr(values).map(fn(x) raise { integer(x) }),
          ),
        )
    }
    Json::object({
      "minimal_cut_sets": Json(cutsets),
      "conditional_probability": conditional,
    })
  } else {
    Json::null()
  }
  let range = if j is Object(fields) && fields.get("range") is Some(r) {
    let bound = graph.probability_range(
      arr(field(r, "lower")).map(fn(x) raise { num(x) }),
      arr(field(r, "upper")).map(fn(x) raise { num(x) }),
    )
    Json::object({ "lower": Json(bound.lower), "upper": Json(bound.upper) })
  } else {
    Json::null()
  }
  let mitigation = if j is Object(fields) &&
    fields.get("mitigations") is Some(True) {
    Json(
      graph
      .mitigations(probabilities)
      .map(fn(m) {
        Json::object({
          "event": Json(m.event),
          "reduction": Json(m.reduction),
          "remaining_probability": Json(m.remaining_probability),
        })
      }),
    )
  } else {
    Json::null()
  }
  Json::object({
    "ok": Json(true),
    "probability": Json(graph.probability(probabilities)),
    "importance": Json(factors.map(fn(factor) { factor.birnbaum })),
    "importance_factors": importance_report(factors, names),
    "prime_implicants": prime_implicants,
    "allocated_nodes": Json(graph.node_count()),
    "diagnosis": diagnosis,
    "range": range,
    "mitigations": mitigation,
  })
}
