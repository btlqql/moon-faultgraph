///|
test "shared event is not independent copies" {
  // (A AND B) OR (A AND C) = A AND (B OR C)
  let graph = compile(
    [Event(0), Event(1), Event(2), And(0, 1), And(0, 2), Or(3, 4)],
    3,
  )
  let p = graph.probability([0.1, 0.2, 0.3])
  assert_true((p - 0.044).abs() < 1.0e-12)
  // Treating the two branches as independent incorrectly gives .0494.
  let importance = graph.importance([0.1, 0.2, 0.3])
  assert_true((importance[0] - 0.44).abs() < 1.0e-12)
  assert_true((importance[1] - 0.07).abs() < 1.0e-12)
}

///|
test "complement, voting, repeated votes and canonical reductions" {
  let impossible = compile([Event(0), Not(0), And(0, 1)], 1)
  assert_eq(impossible.probability([0.4]), 0.0)
  let vote = compile([Event(0), Event(1), Event(2), Vote(2, [0, 1, 2])], 3)
  assert_eq(vote.probability([0.5, 0.5, 0.5]), 0.5)
  let repeated = compile([Event(0), Vote(2, [0, 0])], 1)
  assert_eq(repeated.probability([0.4]), 0.4)
  let negative = compile([Event(0), Not(0)], 1).importance([0.4])
  assert_eq(negative[0], -1.0)
}

///|
test "cycle forward reference invalid probability and resource cap reject" {
  assert_true(
    try {
      ignore(compile([And(0, 0)], 1))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(compile([Event(0)], 1, node_limit=2))
      false
    } catch {
      _ => true
    },
  )
  let g = compile([Event(0)], 1)
  assert_true(
    try {
      ignore(g.probability([1.1]))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(g.probability([]))
      false
    } catch {
      _ => true
    },
  )
}
