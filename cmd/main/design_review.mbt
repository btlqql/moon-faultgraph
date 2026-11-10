///|
priv struct ReviewScenario {
  name : String
  model_path : String
  model : @mef.StaticModel
  probabilities : Array[Double]
  probability : Double
}

///|
fn review_fields(
  value : Json,
  allowed : Array[String],
  context : String,
) -> Map[String, Json] raise {
  guard value is Object(fields) else { fail(context + " must be an object") }
  for key, _ in fields {
    if !allowed.contains(key) {
      fail("unsupported " + context + " field " + key)
    }
  }
  fields
}

///|
fn review_text(value : Json, context : String, limit : Int32) -> String raise {
  guard value is String(text) else { fail(context + " must be a string") }
  let text = text.trim().to_owned()
  if text.is_empty() || text.length() > limit {
    fail(context + " must be nonempty and within its length limit")
  }
  text
}

///|
fn prevention_effects(
  scenario : ReviewScenario,
  factors : Array[@core.EventImportance],
) -> Json {
  let effects = factors.map(fn(factor) {
    let p = scenario.probabilities[factor.event]
    // Q - Q0 = p * (Q1 - Q0) for the independent-event model.
    (factor, p * factor.birnbaum)
  })
  effects.sort_by(fn(a, b) {
    let (factor_a, effect_a) = a
    let (factor_b, effect_b) = b
    if effect_a == effect_b {
      scenario.model.events[factor_a.event].lexical_compare(
        scenario.model.events[factor_b.event],
      )
    } else {
      compare(effect_b, effect_a)
    }
  })
  Json(
    effects.map(fn(entry) {
      let (factor, reduction) = entry
      let direction = if reduction > 0.0 {
        "reduces_risk"
      } else if reduction < 0.0 {
        "increases_risk"
      } else {
        "unchanged"
      }
      Json::object({
        "event": Json(scenario.model.events[factor.event]),
        "probability": Json(scenario.probabilities[factor.event]),
        "probability_if_prevented": Json(factor.forced_working),
        "risk_reduction": Json(reduction),
        "effect": Json(direction),
      })
    }),
  )
}

///|
fn scenario_report(
  scenario : ReviewScenario,
  reference : Double,
  target : Double?,
  include_primes : Bool,
) -> Json raise {
  let risk_reduction = reference - scenario.probability
  let relative = if reference > 0.0 {
    let fraction = risk_reduction / reference
    if fraction - fraction == 0.0 {
      Json(fraction)
    } else {
      Json::null()
    }
  } else {
    Json::null()
  }
  let factors = scenario.model.graph.event_importance(scenario.probabilities)
  Json::object({
    "name": Json(scenario.name),
    "mef": Json(scenario.model_path),
    "probability": Json(scenario.probability),
    "risk_reduction": Json(risk_reduction),
    "relative_risk_reduction": relative,
    "meets_target": match target {
      Some(maximum) => Json(scenario.probability <= maximum)
      None => Json::null()
    },
    "importance_factors": importance_report(factors, scenario.model.events),
    "prevention_effects": prevention_effects(scenario, factors),
    "prime_implicants": if include_primes {
      named_primes(scenario.model.graph, scenario.model.events)
    } else {
      Json::null()
    },
  })
}

///|
fn run_design_review(review : Json, request_path : String) -> Json raise {
  let fields = review_fields(
    review,
    [
      "outcome", "probability_basis", "baseline", "variants", "maximum_probability",
      "prime_implicants",
    ],
    "design_review",
  )
  let outcome = review_text(field(review, "outcome"), "outcome", 512)
  let probability_basis = review_text(
    field(review, "probability_basis"),
    "probability_basis",
    512,
  )
  let target = match fields.get("maximum_probability") {
    Some(value) => {
      let maximum = num(value)
      if maximum < 0.0 || maximum > 1.0 {
        fail("maximum_probability must be within [0,1]")
      }
      Some(maximum)
    }
    None => None
  }
  let include_primes = match fields.get("prime_implicants") {
    Some(True) => true
    Some(False) | None => false
    _ => fail("prime_implicants must be a boolean")
  }
  let variants = arr(field(review, "variants"))
  if variants.is_empty() || variants.length() > 8 {
    fail("design_review requires 1 to 8 variants")
  }

  let input = field(review, "baseline")
  let baseline_fields = review_fields(
    input,
    ["name", "mef", "top", "probability_overrides"],
    "baseline",
  )
  let baseline_name = review_text(field(input, "name"), "baseline name", 128)
  let baseline_path = review_text(field(input, "mef"), "baseline mef", 4096)
  let top = requested_top(baseline_fields)
  let baseline_model = @mef.parse_static(
    read_input(resolve_from(request_path, baseline_path)),
    top?,
  )
  let baseline_probabilities = with_overrides(
    baseline_model.events,
    baseline_model.probabilities,
    baseline_fields.get("probability_overrides"),
  )
  let baseline : ReviewScenario = {
    name: baseline_name,
    model_path: baseline_path,
    model: baseline_model,
    probabilities: baseline_probabilities,
    probability: baseline_model.graph.probability(baseline_probabilities),
  }
  let scenarios : Array[ReviewScenario] = []
  let names : Map[String, Bool] = Map([(baseline_name, true)])
  for variant in variants {
    let variant_fields = review_fields(
      variant,
      ["name", "mef", "probability_overrides"],
      "variant",
    )
    let name = review_text(field(variant, "name"), "variant name", 128)
    if names.get(name) is Some(_) {
      fail("duplicate scenario name " + name)
    }
    names[name] = true
    let overrides = variant_fields.get("probability_overrides")
    let (model_path, model, initial) = match variant_fields.get("mef") {
      Some(value) => {
        let model_path = review_text(value, "variant mef", 4096)
        let model = @mef.parse_static(
          read_input(resolve_from(request_path, model_path)),
          top=baseline.model.top,
        )
        (model_path, model, model.probabilities)
      }
      None => {
        guard overrides is Some(Object(changes)) && !changes.is_empty() else {
          fail("variant without mef requires probability_overrides")
        }
        (baseline.model_path, baseline.model, baseline.probabilities)
      }
    }
    let probabilities = with_overrides(model.events, initial, overrides)
    scenarios.push({
      name,
      model_path,
      model,
      probabilities,
      probability: model.graph.probability(probabilities),
    })
  }
  scenarios.sort_by(fn(a, b) {
    if a.probability == b.probability {
      a.name.lexical_compare(b.name)
    } else {
      compare(a.probability, b.probability)
    }
  })
  let reports : Array[Json] = []
  for scenario in scenarios {
    reports.push(
      scenario_report(scenario, baseline.probability, target, include_primes),
    )
  }
  Json::object({
    "ok": Json(true),
    "outcome": Json(outcome),
    "probability_basis": Json(probability_basis),
    "top": Json(baseline.model.top),
    "maximum_probability": match target {
      Some(maximum) => Json(maximum)
      None => Json::null()
    },
    "baseline": scenario_report(
      baseline,
      baseline.probability,
      target,
      include_primes,
    ),
    "variants": Json(reports),
  })
}
