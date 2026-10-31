///|
pub(all) suberror GraphError {
  InvalidGraph
  InvalidProbability
  ResourceLimit
}

// Gate operands refer to earlier gate indices; Event indexes identify the
// SAME random variable wherever reused. Different events must be independent.

///|
pub(all) enum Gate {
  Event(Int32)
  And(Int32, Int32)
  Or(Int32, Int32)
  Not(Int32)
  Vote(Int32, Array[Int32])
}

///|
struct Node {
  variable : Int32
  low : Int32
  high : Int32
}

///|
pub struct FaultGraph {
  nodes : Array[Node]
  root : Int32
  variables : Int32
}

///|
priv struct Builder {
  nodes : Array[Node]
  unique : Map[(Int32, Int32, Int32), Int32]
  cache : Map[(Bool, Int32, Int32), Int32]
  limit : Int32
}

///|
fn mk(
  b : Builder,
  variable : Int32,
  low : Int32,
  high : Int32,
) -> Int32 raise GraphError {
  if low == high {
    return low
  }
  let key = (variable, low, high)
  if b.unique.get(key) is Some(id) {
    return id
  }
  if b.nodes.length() >= b.limit {
    raise ResourceLimit
  }
  let id = b.nodes.length()
  b.nodes.push({ variable, low, high, })
  b.unique[key] = id
  id
}

///|
fn apply(
  b : Builder,
  and_op : Bool,
  a : Int32,
  c : Int32,
) -> Int32 raise GraphError {
  let (a, c) = if a <= c { (a, c) } else { (c, a) }
  if a == c {
    return a
  }
  if and_op {
    if a == 0 {
      return 0
    }
    if a == 1 {
      return c
    }
  } else {
    if a == 0 {
      return c
    }
    if a == 1 {
      return 1
    }
  }
  let key = (and_op, a, c)
  if b.cache.get(key) is Some(id) {
    return id
  }
  if b.cache.length() >= b.limit * 8 {
    raise ResourceLimit
  }
  let na = b.nodes[a]
  let nc = b.nodes[c]
  let v = if na.variable < nc.variable { na.variable } else { nc.variable }
  let (al, ah) = if na.variable == v { (na.low, na.high) } else { (a, a) }
  let (cl, ch) = if nc.variable == v { (nc.low, nc.high) } else { (c, c) }
  let low = apply(b, and_op, al, cl)
  let high = apply(b, and_op, ah, ch)
  let id = mk(b, v, low, high)
  b.cache[key] = id
  id
}

///|
fn negate(
  b : Builder,
  id : Int32,
  memo : Map[Int32, Int32],
) -> Int32 raise GraphError {
  if id <= 1 {
    return 1 - id
  }
  if memo.get(id) is Some(x) {
    return x
  }
  let n = b.nodes[id]
  let low = negate(b, n.low, memo)
  let high = negate(b, n.high, memo)
  let result = mk(b, n.variable, low, high)
  memo[id] = result
  result
}

///|
pub fn compile(
  gates : Array[Gate],
  variables : Int32,
  node_limit~ : Int32 = 100000,
) -> FaultGraph raise GraphError {
  if variables < 1 ||
    variables > 128 ||
    gates.is_empty() ||
    gates.length() > 4096 {
    raise InvalidGraph
  }
  if node_limit < 2 || node_limit > 1000000 {
    raise ResourceLimit
  }
  let b : Builder = {
    nodes: [
      { variable: 129, low: 0, high: 0, },
      { variable: 129, low: 1, high: 1, },
    ],
    unique: Map([]),
    cache: Map([]),
    limit: node_limit,
  }
  let roots : Array[Int32] = []
  for i in 0..<gates.length() {
    let id = match gates[i] {
      Event(v) => {
        if v < 0 || v >= variables {
          raise InvalidGraph
        }
        mk(b, v, 0, 1)
      }
      And(a, c) | Or(a, c) => {
        if a < 0 || c < 0 || a >= i || c >= i {
          raise InvalidGraph
        }
        apply(b, gates[i] is And(_, _), roots[a], roots[c])
      }
      Not(a) => {
        if a < 0 || a >= i {
          raise InvalidGraph
        }
        negate(b, roots[a], Map([]))
      }
      Vote(k, inputs) => {
        if inputs.length() > 128 || k < 0 || k > inputs.length() {
          raise InvalidGraph
        }
        let dp = Array::make(k + 1, 0)
        dp[0] = 1
        for a in inputs {
          if a < 0 || a >= i {
            raise InvalidGraph
          }
          for j = k; j >= 1; j = j - 1 {
            dp[j] = apply(b, false, dp[j], apply(b, true, roots[a], dp[j - 1]))
          }
        }
        dp[k]
      }
    }
    roots.push(id)
  }
  { nodes: b.nodes, root: roots[roots.length() - 1], variables, }
}

///|
pub fn FaultGraph::node_count(self : FaultGraph) -> Int32 {
  self.nodes.length()
}

///|
pub fn FaultGraph::probability(
  self : FaultGraph,
  probabilities : Array[Double],
) -> Double raise GraphError {
  if probabilities.length() != self.variables {
    raise InvalidProbability
  }
  for p in probabilities {
    if !(p >= 0.0 && p <= 1.0) {
      raise InvalidProbability
    }
  }
  let values = Array::make(self.nodes.length(), 0.0)
  values[1] = 1.0
  // Unique nodes are appended after their children: topological evaluation.
  for i in 2..<self.nodes.length() {
    let n = self.nodes[i]
    let p = probabilities[n.variable]
    values[i] = (1.0 - p) * values[n.low] + p * values[n.high]
  }
  values[self.root]
}

// Signed Birnbaum importance; noncoherent NOT models can be negative.

///|
pub fn FaultGraph::importance(
  self : FaultGraph,
  probabilities : Array[Double],
) -> Array[Double] raise GraphError {
  ignore(self.probability(probabilities))
  let out : Array[Double] = []
  for v in 0..<self.variables {
    let p = probabilities.copy()
    p[v] = 0.0
    let low = self.probability(p)
    p[v] = 1.0
    out.push(self.probability(p) - low)
  }
  out
}
