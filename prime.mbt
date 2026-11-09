///|
priv struct PrimeSearch {
  builder : Builder
  memo : Map[Int32, Array[Array[Int32]]]
  limit : Int32
  mut work : Int64
  mut stored : Int32
}

///|
fn add_prime(
  search : PrimeSearch,
  terms : Array[Array[Int32]],
  term : Array[Int32],
) -> Unit raise GraphError {
  // Bound subset comparisons as well as the number of stored candidates.
  search.work += 1L + terms.length().to_int64() * (term.length() + 1).to_int64()
  if search.work > 1000000L {
    raise ResourceLimit
  }
  insert_minimal(terms, term, search.limit)
}

///|
fn primes(
  search : PrimeSearch,
  id : Int32,
) -> Array[Array[Int32]] raise GraphError {
  if id == 0 {
    return []
  }
  if id == 1 {
    return [[]]
  }
  if search.memo.get(id) is Some(terms) {
    return terms
  }
  let node = search.builder.nodes[id]
  // Terms independent of this variable must imply both cofactors.
  let intersection = apply(search.builder, true, node.low, node.high)
  let result = primes(search, intersection).copy()
  for
    (child, literal) in [
      (node.low, -(node.variable + 1)),
      (node.high, node.variable + 1),
    ] {
    for suffix in primes(search, child) {
      let term = [literal]
      for value in suffix {
        term.push(value)
      }
      add_prime(search, result, term)
    }
  }
  search.stored += result.length()
  if search.stored > 16000 {
    raise ResourceLimit
  }
  search.memo[id] = result
  result
}

///|
/// Signed one-based literals: -1 means event 0 is false, +1 means it is true.
/// A constant true function returns one empty term. Resource limits raise an error.
pub fn FaultGraph::prime_implicants(
  self : FaultGraph,
  limit~ : Int32 = 256,
) -> Array[Array[Int32]] raise GraphError {
  if limit < 1 || limit > 1024 || self.nodes.length() > 10000 {
    raise ResourceLimit
  }
  let unique = Map([])
  for i in 2..<self.nodes.length() {
    let node = self.nodes[i]
    unique[(node.variable, node.low, node.high)] = i
  }
  primes(
    {
      builder: {
        nodes: self.nodes.copy(),
        unique,
        cache: Map([]),
        limit: 20000,
      },
      memo: Map([]),
      limit,
      work: 0L,
      stored: 0,
    },
    self.root,
  )
}
