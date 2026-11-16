///|
let scoped_trees : String =
  #|<opsa-mef>
  #|  <define-fault-tree name="Plant">
  #|    <define-gate name="Top" role="private">
  #|      <or><gate name="TrainA.Check"/><event name="Plant.TrainB.Check" type="gate"/></or>
  #|    </define-gate>
  #|    <define-component name="TrainA" role="private">
  #|      <define-gate name="Check"><event name="Failure"/></define-gate>
  #|      <define-basic-event name="Failure"><float value="0.1"/></define-basic-event>
  #|    </define-component>
  #|    <define-component name="TrainB" role="private">
  #|      <define-gate name="Check"><basic-event name="Unit.Failure"/></define-gate>
  #|      <define-component name="Unit">
  #|        <define-basic-event name="Failure"><float value="0.2"/></define-basic-event>
  #|        <define-basic-event name="Alarm" role="public"><float value="0.03"/></define-basic-event>
  #|      </define-component>
  #|    </define-component>
  #|  </define-fault-tree>
  #|  <define-fault-tree name="Aux">
  #|    <define-gate name="Backup">
  #|      <and><gate name="Plant.Top"/><basic-event name="Alarm"/><basic-event name="Failure"/></and>
  #|    </define-gate>
  #|  </define-fault-tree>
  #|  <model-data>
  #|    <define-basic-event name="Failure"><float value="0.6"/></define-basic-event>
  #|  </model-data>
  #|</opsa-mef>

///|
test "MEF qualified event identities remain distinct across import and export" {
  let original = parse_static(scoped_trees, top="Plant.Top")
  assert_eq(original.top, "Plant.Top")
  assert_true(
    (original.graph.probability(original.probabilities) - 0.28).abs() < 1.0e-12,
  )
  let changed = original.probabilities.copy()
  guard original.basic_event_index("Plant.TrainA.Failure") is Some(index) else {
    fail("missing private event")
  }
  changed[index] = 0.25
  assert_eq(
    original.basic_event_index("Plant.TrainB.Unit.Alarm"),
    original.basic_event_index("Alarm"),
  )
  let xml = original.to_xml(probabilities=changed)
  assert_true(xml.contains("<define-component name=\"Unit\">"))
  assert_true(xml.contains("<gate name=\"TrainA.Check\""))
  let updated = parse_static(xml, top="Plant.Top")
  assert_eq(updated.events, original.events)
  assert_eq(updated.probabilities, changed)
  assert_true(
    (updated.graph.probability(updated.probabilities) - 0.4).abs() < 1.0e-12,
  )
  let backup = parse_static(xml, top="Aux.Backup")
  assert_eq(backup.top, "Backup")
  assert_true(
    (backup.graph.probability(backup.probabilities) - 0.0072).abs() < 1.0e-12,
  )
}

///|
test "MEF validates private paths, duplicate names, cycles and top selection" {
  let invalid : Array[(String, String?)] = [
    (scoped_trees, None),
    (scoped_trees, Some("Top")),
    (scoped_trees, Some("Plant..Top")),
    (
      scoped_trees.replace_all(old="Unit.Failure", new="Missing.Failure"),
      Some("Plant.Top"),
    ),
    (
      scoped_trees.replace_all(old="Unit.Failure", new="Plant.TrainA.Check"),
      Some("Plant.Top"),
    ),
    (
      scoped_trees.replace_all(
        old="name=\"TrainA.Check\"",
        new="name=\"Aux.Backup\"",
      ),
      Some("Plant.Top"),
    ),
    (
      scoped_trees.replace_all(
        old="name=\"Alarm\" role=\"public\"",
        new="name=\"Failure\" role=\"public\"",
      ),
      Some("Plant.Top"),
    ),
  ]
  for (source, top) in invalid {
    try parse_static(source, top?) catch {
      InvalidModel(_) => ()
      err => raise err
    } noraise {
      _ => fail("expected invalid scoped MEF input")
    }
  }
}

///|
test "MEF export escapes labels and root metadata without changing scoped names" {
  let source = scoped_trees
    .replace_all(
      old="<opsa-mef>",
      new="<opsa-mef name=\"A &amp; &quot;B&quot;&#10;C\">",
    )
    .replace_all(
      old="<define-component name=\"Unit\">",
      new="<define-component name=\"Unit\"><label>Valve &amp; &lt;relay&gt; &gt;</label>",
    )
    .replace_all(old="Plant.TrainB.Check", new="Plant&#46;TrainB&#46;Check")
  let model = parse_static(source, top="Plant.Top")
  let xml = model.to_xml()
  assert_true(xml.contains("A &amp; &quot;B&quot;"))
  assert_true(xml.contains("Valve &amp; &lt;relay&gt; &gt;"))
  assert_true(xml.contains("Plant.TrainB.Check"))
  let round_trip = parse_static(xml, top="Plant.Top")
  assert_eq(round_trip.events, model.events)
  assert_eq(round_trip.to_xml(), xml)
}

///|
test "MEF resource limits apply across scopes and deeply nested components" {
  let source = StringBuilder()
  source.write_string("<opsa-mef>")
  for tree in 0..<2 {
    source.write_string("<define-fault-tree name=\"Tree\{tree}\">")
    source.write_string(
      "<define-gate name=\"Top\{tree}\"><basic-event name=\"E0\"/></define-gate>",
    )
    for event in 0..<(64 + tree) {
      source.write_string(
        "<define-basic-event name=\"E\{event}\" role=\"private\"><float value=\"0.1\"/></define-basic-event>",
      )
    }
    source.write_string("</define-fault-tree>")
  }
  source.write_string("</opsa-mef>")
  try parse_static(source.to_string(), top="Top0") catch {
    InvalidModel(message) =>
      assert_eq(message, "static model exceeds 128 basic events")
    err => raise err
  } noraise {
    _ => fail("expected the document-wide basic event limit")
  }

  let nested = StringBuilder()
  nested.write_string("<opsa-mef><define-fault-tree name=\"Tree\">")
  for _ in 0..<100 {
    nested.write_string("<define-component name=\"Nested\">")
  }
  for _ in 0..<100 {
    nested.write_string("</define-component>")
  }
  nested.write_string("</define-fault-tree></opsa-mef>")
  try parse_static(nested.to_string()) catch {
    InvalidModel(message) => assert_eq(message, "MEF element or depth limit")
    err => raise err
  } noraise {
    _ => fail("expected the MEF depth limit")
  }

  let wide = StringBuilder()
  wide.write_string("<opsa-mef><define-fault-tree name=\"Tree\">")
  for component in 0..<1025 {
    wide.write_string("<define-component name=\"Unit\{component}\"/>")
  }
  wide.write_string("</define-fault-tree></opsa-mef>")
  try parse_static(wide.to_string()) catch {
    InvalidModel(message) =>
      assert_eq(message, "static model exceeds 1024 components")
    err => raise err
  } noraise {
    _ => fail("expected the MEF component limit")
  }
}
