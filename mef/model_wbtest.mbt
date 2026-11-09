///|
test "MEF vote and house event survive probability override and export" {
  let source =
    #|<?xml version="1.0"?>
    #|<!DOCTYPE opsa-mef>
    #|<opsa-mef>
    #|  <define-fault-tree name="VoteTree">
    #|    <define-gate name="Loss">
    #|      <atleast min="2"><basic-event name="A"/><basic-event name="B"/><house-event name="On"/></atleast>
    #|    </define-gate>
    #|  </define-fault-tree>
    #|  <model-data>
    #|    <define-basic-event name="A"><label>Supply &amp; converter</label><float value="0.1"/></define-basic-event>
    #|    <define-basic-event name="B"><float value="0.2"/></define-basic-event>
    #|    <define-house-event name="On"><constant value="true"/></define-house-event>
    #|  </model-data>
    #|</opsa-mef>
  let model = parse_static(source)
  assert_eq(model.top, "Loss")
  assert_true(
    (model.graph.probability(model.probabilities) - 0.28).abs() < 1.0e-12,
  )
  let updated = model.to_xml(probabilities=[0.3, 0.4])
  assert_true(updated.contains("Supply &amp; converter"))
  let roundtrip = parse_static(updated)
  assert_eq(roundtrip.events, model.events)
  assert_eq(roundtrip.graph.prime_implicants(), model.graph.prime_implicants())
  assert_true(
    (roundtrip.graph.probability(roundtrip.probabilities) - 0.58).abs() <
    1.0e-12,
  )
}
