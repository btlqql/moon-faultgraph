// Antichain insertion. Removing supersets prevents double-counting explanations;
// the returned cut sets must not be summed as independent probabilities.

///|
fn insert_minimal(
  sets : Array[Array[Int32]],
  candidate : Array[Int32],
  limit : Int32,
) -> Unit raise GraphError {
  for existing in sets {
    if existing.all(fn(v) { candidate.contains(v) }) {
      return
    }
  }
  let mut i = 0
  while i < sets.length() {
    if candidate.all(fn(v) { sets[i].contains(v) }) {
      ignore(sets.remove(i))
    } else {
      i += 1
    }
  }
  if sets.length() >= limit {
    raise ResourceLimit
  }
  sets.push(candidate)
}

///|
fn cuts(
  graph : FaultGraph,
  id : Int32,
  memo : Map[Int32, Array[Array[Int32]]],
  limit : Int32,
) -> Array[Array[Int32]] raise GraphError {
  if id == 0 {
    return []
  }
  if id == 1 {
    return [[]]
  }
  if memo.get(id) is Some(s) {
    return s
  }
  let node = graph.nodes[id]
  let result : Array[Array[Int32]] = []
  for s in cuts(graph, node.low, memo, limit) {
    insert_minimal(result, s, limit)
  }
  for s in cuts(graph, node.high, memo, limit) {
    let candidate = [node.variable]
    for v in s {
      candidate.push(v)
    }
    insert_minimal(result, candidate, limit)
  }
  memo[id] = result
  result
}

// Complete minimal positive cut sets for syntactically coherent models only.
// Exceeding a budget raises ResourceLimit; never returns an unlabeled prefix.

///|
pub fn FaultGraph::minimal_cut_sets(
  self : FaultGraph,
  limit~ : Int32 = 256,
) -> Array[Array[Int32]] raise GraphError {
  if !self.coherent {
    raise InvalidGraph
  }
  if limit < 1 || limit > 1024 || self.nodes.length() > 10000 {
    raise ResourceLimit
  }
  cuts(self, self.root, Map([]), limit)
}

// Independent basic variables conditioned on fixed observations. A contradictory
// zero-probability observation is rejected instead of silently inventing a posterior.

///|
pub fn FaultGraph::conditioned_probability(
  self : FaultGraph,
  p : Array[Double],
  observations : Array[Int32],
) -> Double raise GraphError {
  ignore(self.probability(p))
  if observations.length() != self.variables {
    raise InvalidGraph
  }
  let posterior = p.copy()
  for v in 0..<self.variables {
    match observations[v] {
      -1 => ()
      0 => {
        if p[v] == 1.0 {
          raise InvalidProbability
        }
        posterior[v] = 0.0
      }
      1 => {
        if p[v] == 0.0 {
          raise InvalidProbability
        }
        posterior[v] = 1.0
      }
      _ => raise InvalidGraph
    }
  }
  self.probability(posterior)
}
