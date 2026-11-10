///|
pub struct StaticModel {
  graph : @core.FaultGraph
  events : Array[String]
  probabilities : Array[Double]
  top : String
  priv document : String
}

///|
priv struct Resolver {
  definitions : Map[String, Element]
  indices : Map[String, Int32]
  active : Map[String, Bool]
  referenced : Map[String, Bool]
  gates : Array[@core.Gate]
  events : Array[String]
  probabilities : Array[Double]
}

///|
fn Resolver::push(self : Resolver, gate : @core.Gate) -> Int32 raise MefError {
  if self.gates.length() >= 4095 {
    raise InvalidModel("compiled gate limit")
  }
  self.gates.push(gate)
  self.gates.length() - 1
}

///|
fn scalar(node : Element) -> Double raise {
  node.allow(["value"])
  node.leaf()
  let text = node.required("value")
  // MEF float values use the XML Schema decimal spelling, not JSON's.
  if text.contains("_") {
    raise InvalidModel("invalid numeric literal " + text)
  }
  @string.parse_double(text.trim()) catch {
    _ => raise InvalidModel("invalid numeric literal " + text)
  }
}

///|
fn boolean(node : Element) -> Bool raise MefError {
  node.allow(["value"])
  node.leaf()
  match node.required("value") {
    "true" => true
    "false" => false
    _ => raise InvalidModel("expected true or false")
  }
}

///|
fn Resolver::constant(self : Resolver, value : Bool) -> Int32 raise MefError {
  let yes = self.push(@core.Vote(0, []))
  if value {
    yes
  } else {
    self.push(@core.Not(yes))
  }
}

///|
fn Resolver::resolve(
  self : Resolver,
  name : String,
  depth : Int32,
) -> Int32 raise {
  if depth > 128 {
    raise InvalidModel("reference depth limit")
  }
  if self.indices.get(name) is Some(index) {
    return index
  }
  if self.active.get(name) is Some(true) {
    raise InvalidModel("gate cycle at " + name)
  }
  guard self.definitions.get(name) is Some(node) else {
    raise InvalidModel("unknown event " + name)
  }
  self.active[name] = true
  let body = node.body()
  let index = match node.tag {
    "define-basic-event" => {
      if body.length() != 1 ||
        body[0].tag != "float" ||
        self.events.length() >= 128 {
        raise InvalidModel("expected one fixed float probability for " + name)
      }
      let p = scalar(body[0])
      if !(p >= 0.0 && p <= 1.0) {
        raise InvalidModel("probability outside [0,1] for " + name)
      }
      let index = self.push(@core.Event(self.events.length()))
      self.events.push(name)
      self.probabilities.push(p)
      index
    }
    "define-house-event" =>
      if body.is_empty() {
        self.constant(false)
      } else {
        if body.length() != 1 || body[0].tag != "constant" {
          raise InvalidModel("expected Boolean house event " + name)
        }
        self.constant(boolean(body[0]))
      }
    _ => {
      if body.length() != 1 {
        raise InvalidModel("expected one formula for " + name)
      }
      self.formula(body[0], depth + 1)
    }
  }
  self.active[name] = false
  self.indices[name] = index
  index
}

///|
fn Resolver::formula(
  self : Resolver,
  node : Element,
  depth : Int32,
) -> Int32 raise {
  if depth > 128 {
    raise InvalidModel("formula depth limit")
  }
  match node.tag {
    "gate" | "basic-event" | "house-event" | "event" => {
      node.allow(if node.tag == "event" { ["name", "type"] } else { ["name"] })
      node.leaf()
      let name = node.name()
      guard self.definitions.get(name) is Some(definition) else {
        raise InvalidModel("unknown event " + name)
      }
      let kind = if node.tag == "event" {
        node.attr("type")
      } else {
        Some(node.tag)
      }
      if kind is Some(kind) && "define-" + kind != definition.tag {
        raise InvalidModel("reference type mismatch for " + name)
      }
      if definition.tag == "define-gate" {
        self.referenced[name] = true
      }
      self.resolve(name, depth + 1)
    }
    "constant" => self.constant(boolean(node))
    "not" => {
      node.allow([])
      if node.children.length() != 1 {
        raise InvalidModel("not requires one operand")
      }
      self.push(@core.Not(self.formula(node.children[0], depth + 1)))
    }
    "and" | "or" | "atleast" => {
      node.allow(if node.tag == "atleast" { ["min"] } else { [] })
      if node.children.is_empty() || node.children.length() > 128 {
        raise InvalidModel("invalid operand count for " + node.tag)
      }
      let inputs : Array[Int32] = []
      for child in node.children {
        inputs.push(self.formula(child, depth + 1))
      }
      if node.tag == "atleast" {
        let count = node.required("min")
        if count.contains("_") {
          raise InvalidModel("invalid atleast threshold")
        }
        let k = @string.parse_int(count.trim(), base=10) catch {
          _ => raise InvalidModel("invalid atleast threshold")
        }
        if k < 1 || k > inputs.length() {
          raise InvalidModel("invalid atleast threshold")
        }
        self.push(@core.Vote(k, inputs))
      } else {
        let mut root = inputs[0]
        for i in 1..<inputs.length() {
          root = self.push(
            if node.tag == "and" {
              @core.And(root, inputs[i])
            } else {
              @core.Or(root, inputs[i])
            },
          )
        }
        root
      }
    }
    _ => raise InvalidModel("unsupported MEF formula " + node.tag)
  }
}

///|
/// Parse one flat static tree plus optional model-data. Names are globally unique.
/// If top is omitted, the model must have exactly one unreferenced named gate.
pub fn parse_static(source : String, top? : String) -> StaticModel raise {
  let document = read_tree(source)
  document.allow(["name"])
  let definitions : Map[String, Element] = Map([])
  let mut tree_seen = false
  let mut data_seen = false
  for container in document.body() {
    match container.tag {
      "define-fault-tree" if !tree_seen => {
        container.allow(["name"])
        ignore(container.name())
        tree_seen = true
      }
      "model-data" if !data_seen => {
        container.allow([])
        data_seen = true
      }
      _ =>
        raise InvalidModel(
          "unsupported or duplicate container " + container.tag,
        )
    }
    for definition in container.body() {
      if definition.tag != "define-basic-event" &&
        definition.tag != "define-house-event" &&
        !(definition.tag == "define-gate" &&
        container.tag == "define-fault-tree") {
        raise InvalidModel("unsupported definition " + definition.tag)
      }
      definition.allow(["name", "role"])
      if definition.attr("role") is Some(role) && role != "public" {
        raise InvalidModel("only public definitions are supported")
      }
      let name = definition.name()
      if definitions.get(name) is Some(_) {
        raise InvalidModel("duplicate name " + name)
      }
      definitions[name] = definition
    }
  }
  if !tree_seen || definitions.length() > 1024 {
    raise InvalidModel("expected one bounded static tree")
  }
  let resolver : Resolver = {
    definitions,
    indices: Map([]),
    active: Map([]),
    referenced: Map([]),
    gates: [],
    events: [],
    probabilities: [],
  }
  for name, _ in definitions {
    ignore(resolver.resolve(name, 0))
  }
  let candidates : Array[String] = []
  for name, definition in definitions {
    if definition.tag == "define-gate" && resolver.referenced.get(name) is None {
      candidates.push(name)
    }
  }
  let selected = match top {
    Some(name) => name
    None => {
      if candidates.length() != 1 {
        raise InvalidModel("select a top gate explicitly")
      }
      candidates[0]
    }
  }
  guard definitions.get(selected) is Some(definition) &&
    definition.tag == "define-gate" else {
    raise InvalidModel("unknown top gate " + selected)
  }
  if resolver.events.is_empty() {
    raise InvalidModel("at least one basic event is required")
  }
  resolver.gates.push(@core.Vote(1, [resolver.indices[selected]]))
  {
    graph: @core.compile(resolver.gates, resolver.events.length()),
    events: resolver.events,
    probabilities: resolver.probabilities,
    top: selected,
    document: source,
  }
}

///|
/// Canonically export the accepted structure, optionally with new probabilities.
pub fn StaticModel::to_xml(
  self : StaticModel,
  probabilities? : Array[Double],
) -> String raise {
  let p = match probabilities {
    Some(values) => values
    None => self.probabilities
  }
  ignore(self.graph.probability(p))
  let values = Map([])
  for i in 0..<self.events.length() {
    values[self.events[i]] = p[i]
  }
  let writer = @xml.Writer::new()
  write_tree(read_tree(self.document), writer, values)
  writer.to_string()
}
