///|
extern "js" fn resolve_from(document : String, name : String) -> String =
  #| (document, name) => {
  #|   const path = process.getBuiltinModule('path');
  #|   return path.resolve(path.dirname(document), name);
  #| }

///|
extern "js" fn write_xml(path : String, xml : String) -> Bool =
  #| (path, xml) => {
  #|   try {
  #|     process.getBuiltinModule('fs').writeFileSync(path, xml + '\n', { flag: 'wx' });
  #|     return true;
  #|   } catch { return false; }
  #| }

///|
fn ratio(value : @core.RiskRatio) -> Json {
  match value {
    Finite(number) =>
      Json::object({ "state": Json("finite"), "value": Json(number) })
    Undefined =>
      Json::object({ "state": Json("undefined"), "value": Json::null() })
    Unbounded =>
      Json::object({ "state": Json("unbounded"), "value": Json::null() })
  }
}

///|
fn importance_report(
  factors : Array[@core.EventImportance],
  names : Array[String],
) -> Json {
  Json(
    factors.map(fn(factor) {
      Json::object({
        "event": Json(names[factor.event]),
        "forced_failed": Json(factor.forced_failed),
        "forced_working": Json(factor.forced_working),
        "birnbaum": Json(factor.birnbaum),
        "fussell_vesely_dif": ratio(factor.fussell_vesely_dif),
        "raw": ratio(factor.raw),
        "rrw": ratio(factor.rrw),
      })
    }),
  )
}

///|
fn named_primes(graph : @core.FaultGraph, names : Array[String]) -> Json raise {
  Json(
    graph
    .prime_implicants()
    .map(fn(term) {
      Json(
        term.map(fn(literal) {
          Json::object({
            "event": Json(names[literal.abs() - 1]),
            "occurs": Json(literal > 0),
          })
        }),
      )
    }),
  )
}

///|
fn run_mef(
  request : Json,
  request_path : String,
  model_path : String,
) -> Json raise {
  guard request is Object(fields) else { fail("expected object") }
  let top = match fields.get("top") {
    Some(String(name)) => Some(name)
    None => None
    _ => fail("top must be a gate name")
  }
  let model = @mef.parse_static(
    read_input(resolve_from(request_path, model_path)),
    top?,
  )
  let p = model.probabilities.copy()
  match fields.get("probability_overrides") {
    Some(Object(overrides)) =>
      for name, value in overrides {
        let mut event = -1
        for i in 0..<model.events.length() {
          if model.events[i] == name {
            event = i
          }
        }
        if event == -1 {
          fail("unknown basic event " + name)
        }
        p[event] = num(value)
      }
    None => ()
    _ => fail("probability_overrides must be an object")
  }
  let baseline = model.graph.probability(model.probabilities)
  let probability = model.graph.probability(p)
  let factors = importance_report(model.graph.event_importance(p), model.events)
  let primes = if fields.get("prime_implicants") is Some(True) {
    named_primes(model.graph, model.events)
  } else {
    Json::null()
  }
  let exported = match fields.get("export") {
    Some(String(path)) => {
      if !write_xml(
          resolve_from(request_path, path),
          model.to_xml(probabilities=p),
        ) {
        fail("export already exists or cannot be written")
      }
      Json(path)
    }
    None => Json::null()
    _ => fail("export must be a file path")
  }
  Json::object({
    "ok": Json(true),
    "top": Json(model.top),
    "baseline_probability": Json(baseline),
    "probability": Json(probability),
    "risk_reduction": Json(baseline - probability),
    "importance_factors": factors,
    "prime_implicants": primes,
    "export": exported,
  })
}
