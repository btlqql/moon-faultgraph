///|
test "noncoherent model cannot claim monotone interval endpoints" {
  let graph = compile([Event(0), Not(0)], 1)
  assert_true(
    try {
      ignore(graph.probability_range([0.1], [0.2]))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(graph.mitigations([0.1]))
      false
    } catch {
      _ => true
    },
  )
  assert_true((graph.conditioned_probability([0.1], [0]) - 1.0).abs() < 1.0e-12)
}

///|
test "zero and certain events preserve interval and repair meaning" {
  let graph = compile([Event(0), Event(1), Or(0, 1)], 2)
  let range = graph.probability_range([0.0, 1.0], [1.0, 1.0])
  assert_eq(range.lower, 1.0)
  assert_eq(range.upper, 1.0)
  let p = [0.2, 0.3]
  ignore(graph.mitigations(p))
  assert_eq(p[0], 0.2)
  assert_true(
    try {
      ignore(graph.probability_range([0.2], [0.3]))
      false
    } catch {
      _ => true
    },
  )
}
