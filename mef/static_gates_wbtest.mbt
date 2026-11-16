///|
let gate_fixture : String =
  #|<opsa-mef>
  #|  <define-fault-tree name="Logic">
  #|    <define-gate name="Top">
  #|      <xor><basic-event name="A"/><basic-event name="B"/></xor>
  #|    </define-gate>
  #|  </define-fault-tree>
  #|  <model-data>
  #|    <define-basic-event name="A"><float value="0.1"/></define-basic-event>
  #|    <define-basic-event name="B"><float value="0.2"/></define-basic-event>
  #|  </model-data>
  #|</opsa-mef>

///|
test "MEF XOR NAND and NOR evaluate and survive export as their original tags" {
  for (tag, expected) in [("xor", 0.26), ("nand", 0.98), ("nor", 0.72)] {
    let source = gate_fixture.replace_all(old="xor", new=tag)
    let original = parse_static(source)
    let xml = original.to_xml()
    assert_true(xml.contains("<" + tag + ">"))
    let exported = parse_static(xml)
    assert_eq(
      exported.graph.prime_implicants(),
      original.graph.prime_implicants(),
    )
    assert_true(
      (exported.graph.probability(exported.probabilities) - expected).abs() <
      1.0e-12,
    )
  }
}

///|
test "MEF XOR retains shared event identity inside a nested formula" {
  let source = gate_fixture.replace_all(
    old="<basic-event name=\"B\"/></xor>",
    new="<or><basic-event name=\"A\"/><basic-event name=\"B\"/></or></xor>",
  )
  let model = parse_static(source)
  assert_true(
    (model.graph.probability(model.probabilities) - 0.18).abs() < 1.0e-12,
  )
  assert_eq(model.graph.prime_implicants().length(), 1)
}

///|
test "MEF validates operand counts for XOR NAND and NOR" {
  for tag in ["xor", "nand", "nor"] {
    let source = gate_fixture
      .replace_all(old="xor", new=tag)
      .replace_all(old="<basic-event name=\"B\"/>", new="")
    try parse_static(source) catch {
      InvalidModel(_) => ()
      err => raise err
    } noraise {
      _ => fail("expected invalid operand count for " + tag)
    }
  }
  let source = gate_fixture.replace_all(
    old="</xor>",
    new="<constant value=\"false\"/></xor>",
  )
  try parse_static(source) catch {
    InvalidModel(_) => ()
    err => raise err
  } noraise {
    _ => fail("expected binary XOR")
  }
}
