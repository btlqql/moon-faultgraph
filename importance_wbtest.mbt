///|
test "signed consensus term is independent of the switching event" {
  let graph = compile(
    [Event(0), Event(1), Event(2), Not(0), And(3, 1), And(0, 2), Or(4, 5)],
    3,
  )
  let terms = graph.prime_implicants()
  assert_eq(terms.length(), 3)
  assert_true(terms.contains([-1, 2]))
  assert_true(terms.contains([1, 3]))
  assert_true(terms.contains([2, 3]))
  let factors = graph.event_importance([0.2, 0.1, 0.03])
  assert_true((factors[0].birnbaum + 0.07).abs() < 1.0e-12)
  assert_true(factors[0].raw is Finite(_))
}

///|
test "degenerate importance has explicit status and no false finite values" {
  let graph = compile([Event(0)], 1)
  let absent = graph.event_importance([0.0])[0]
  assert_true(absent.raw is Undefined)
  assert_true(absent.rrw is Undefined)
  assert_true(absent.fussell_vesely_dif is Undefined)
  let active = graph.event_importance([0.2])[0]
  assert_true(active.rrw is Unbounded)
  assert_true(active.raw is Finite(5.0))
}
