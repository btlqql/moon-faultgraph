///|
pub(all) struct ProbabilityRange {
  lower : Double
  upper : Double
}

///|
pub(all) struct Mitigation {
  event : Int32
  reduction : Double
  remaining_probability : Double
}

// Monotone endpoints under independent basic-event probability intervals.
// No confidence level or correlated joint-distribution interpretation.

///|
pub fn FaultGraph::probability_range(
  self : FaultGraph,
  lower : Array[Double],
  upper : Array[Double],
) -> ProbabilityRange raise GraphError {
  if !self.coherent {
    raise InvalidGraph
  }
  let low = self.probability(lower)
  let high = self.probability(upper)
  for i in 0..<lower.length() {
    if lower[i] > upper[i] {
      raise InvalidProbability
    }
  }
  { lower: low, upper: high, }
}

// Each row independently makes one event impossible; rows must not be summed
// to claim the effect of several repairs in a graph with shared dependencies.

///|
pub fn FaultGraph::mitigations(
  self : FaultGraph,
  probabilities : Array[Double],
) -> Array[Mitigation] raise GraphError {
  if !self.coherent {
    raise InvalidGraph
  }
  let baseline = self.probability(probabilities)
  let out : Array[Mitigation] = []
  for i in 0..<self.variables {
    let p = probabilities.copy()
    p[i] = 0.0
    let remaining = self.probability(p)
    out.push({
      event: i,
      reduction: baseline - remaining,
      remaining_probability: remaining,
    })
  }
  out
}
