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
