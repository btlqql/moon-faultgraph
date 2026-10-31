///|
test "shared dependency minimal cuts and observations" {
  let g = compile(
    [Event(0), Event(1), Event(2), And(0, 1), And(0, 2), Or(3, 4)],
    3,
  )
  let sets = g.minimal_cut_sets()
  assert_eq(sets.length(), 2)
  for s in sets {
    assert_true(s.contains(0))
    assert_eq(s.length(), 2)
  }
  assert_true(
    (g.conditioned_probability([0.1, 0.2, 0.3], [1, -1, -1]) - 0.44).abs() <
    1.0e-12,
  )
  assert_eq(g.conditioned_probability([0.1, 0.2, 0.3], [0, -1, -1]), 0.0)
  assert_true(
    try {
      ignore(g.minimal_cut_sets(limit=1))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "noncoherent cuts and impossible evidence rejected" {
  let g = compile([Event(0), Not(0)], 1)
  assert_true(
    try {
      ignore(g.minimal_cut_sets())
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(g.conditioned_probability([0.0], [1]))
      false
    } catch {
      _ => true
    },
  )
}
