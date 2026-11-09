///|
pub(all) enum RiskRatio {
  Finite(Double)
  Undefined
  Unbounded
}

///|
pub(all) struct EventImportance {
  event : Int32
  forced_failed : Double
  forced_working : Double
  birnbaum : Double
  fussell_vesely_dif : RiskRatio
  raw : RiskRatio
  rrw : RiskRatio
}

///|
fn risk_ratio(numerator : Double, denominator : Double) -> RiskRatio {
  if denominator == 0.0 {
    if numerator == 0.0 {
      Undefined
    } else {
      Unbounded
    }
  } else {
    let ratio = numerator / denominator
    if ratio - ratio != 0.0 {
      Unbounded
    } else {
      Finite(ratio)
    }
  }
}

///|
/// FV uses SCRAM's diagnosis importance convention P(event AND top)/P(top).
/// The two forced probabilities are interventions, including at input p=0 or p=1.
pub fn FaultGraph::event_importance(
  self : FaultGraph,
  probabilities : Array[Double],
) -> Array[EventImportance] raise GraphError {
  let baseline = self.probability(probabilities)
  let scenario = probabilities.copy()
  let result : Array[EventImportance] = []
  for event in 0..<self.variables {
    let p = scenario[event]
    scenario[event] = 0.0
    let forced_working = self.probability(scenario)
    scenario[event] = 1.0
    let forced_failed = self.probability(scenario)
    scenario[event] = p
    result.push({
      event,
      forced_failed,
      forced_working,
      birnbaum: forced_failed - forced_working,
      fussell_vesely_dif: risk_ratio(p * forced_failed, baseline),
      raw: if baseline == 0.0 {
        Undefined
      } else {
        risk_ratio(forced_failed, baseline)
      },
      rrw: if baseline == 0.0 {
        Undefined
      } else {
        risk_ratio(baseline, forced_working)
      },
    })
  }
  result
}
