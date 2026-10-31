///|
test "shared-event probability intervals and individual mitigations" {
  let graph = compile(
    [Event(0), Event(1), Event(2), And(0, 1), And(0, 2), Or(3, 4)],
    3,
  )
  let range = graph.probability_range([0.1, 0.2, 0.3], [0.2, 0.3, 0.4])
  assert_true((range.lower - 0.044).abs() < 1.0e-12)
  assert_true((range.upper - 0.116).abs() < 1.0e-12)
  let repairs = graph.mitigations([0.1, 0.2, 0.3])
  assert_eq(repairs[0].remaining_probability, 0.0)
  assert_true((repairs[1].reduction - 0.014).abs() < 1.0e-12)
  assert_true(
    try {
      ignore(graph.probability_range([0.2, 0.2, 0.3], [0.1, 0.3, 0.4]))
      false
    } catch {
      _ => true
    },
  )
}
