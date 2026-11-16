///|
pub struct StaticModel {
  graph : @core.FaultGraph
  events : Array[String]
  probabilities : Array[Double]
  top : String
  priv document : String
  priv event_paths : Array[String]
}

///|
priv struct Resolver {
  scopes : ScopeIndex
  indices : Map[String, Int32]
  active : Map[String, Bool]
  referenced : Map[String, Bool]
  gates : Array[@core.Gate]
  events : Array[String]
  event_paths : Array[String]
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
  guard self.scopes.definitions.get(name) is Some(definition) else {
    raise InvalidModel("unknown event " + name)
  }
  let node = definition.node
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
      self.events.push(definition.id)
      self.event_paths.push(name)
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
      self.formula(body[0], definition, depth + 1)
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
  context : Definition,
  depth : Int32,
) -> Int32 raise {
  if depth > 128 {
    raise InvalidModel("formula depth limit")
  }
  match node.tag {
    "gate" | "basic-event" | "house-event" | "event" => {
      node.allow(if node.tag == "event" { ["name", "type"] } else { ["name"] })
      node.leaf()
      let name = node.reference()
      let kind = if node.tag == "event" {
        node.attr("type")
      } else {
        Some(node.tag)
      }
      let kind = kind.map(fn(kind) { "define-" + kind })
      guard self.scopes.lookup(context.scope, name, kind) is Some(path) else {
        raise InvalidModel("unresolved event " + name + " in " + context.scope)
      }
      let target = self.scopes.definitions[path]
      if target.node.tag == "define-gate" && target.tree == context.tree {
        self.referenced[path] = true
      }
      self.resolve(path, depth + 1)
    }
    "constant" => self.constant(boolean(node))
    "not" => {
      node.allow([])
      if node.children.length() != 1 {
        raise InvalidModel("not requires one operand")
      }
      self.push(@core.Not(self.formula(node.children[0], context, depth + 1)))
    }
    "and" | "or" | "atleast" | "xor" | "nand" | "nor" => {
      node.allow(if node.tag == "atleast" { ["min"] } else { [] })
      let operand_count = node.children.length()
      let negate = node.tag == "nand" || node.tag == "nor"
      if operand_count == 0 ||
        operand_count > 128 ||
        (negate && operand_count < 2) ||
        (node.tag == "xor" && operand_count != 2) {
        raise InvalidModel("invalid operand count for " + node.tag)
      }
      let inputs : Array[Int32] = []
      for child in node.children {
        inputs.push(self.formula(child, context, depth + 1))
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
      } else if node.tag == "xor" {
        let any = self.push(@core.Or(inputs[0], inputs[1]))
        let both = self.push(@core.And(inputs[0], inputs[1]))
        let not_both = self.push(@core.Not(both))
        self.push(@core.And(any, not_both))
      } else {
        let mut root = inputs[0]
        for i in 1..<inputs.length() {
          root = self.push(
            if node.tag == "and" || node.tag == "nand" {
              @core.And(root, inputs[i])
            } else {
              @core.Or(root, inputs[i])
            },
          )
        }
        if negate {
          self.push(@core.Not(root))
        } else {
          root
        }
      }
    }
    _ => raise InvalidModel("unsupported MEF formula " + node.tag)
  }
}

///|
/// Parse scoped static fault trees plus optional model-data.
/// A top is selected by public name or full path. If omitted, exactly one
/// top gate must exist across the document's trees.
pub fn parse_static(source : String, top? : String) -> StaticModel raise {
  let document = read_tree(source)
  document.allow(["name"])
  let scopes = index_scopes(document)
  let resolver : Resolver = {
    scopes,
    indices: Map([]),
    active: Map([]),
    referenced: Map([]),
    gates: [],
    events: [],
    event_paths: [],
    probabilities: [],
  }
  for name, _ in scopes.definitions {
    ignore(resolver.resolve(name, 0))
  }
  let selected = match top {
    Some(name) => {
      guard scopes.lookup("", name, Some("define-gate")) is Some(path) else {
        raise InvalidModel("unknown top gate " + name)
      }
      path
    }
    None => {
      let candidates : Array[String] = []
      for name, definition in scopes.definitions {
        if definition.node.tag == "define-gate" &&
          resolver.referenced.get(name) is None {
          candidates.push(name)
        }
      }
      if candidates.length() != 1 {
        raise InvalidModel("select a top gate explicitly")
      }
      candidates[0]
    }
  }
  if resolver.events.is_empty() {
    raise InvalidModel("at least one basic event is required")
  }
  resolver.gates.push(@core.Vote(1, [resolver.indices[selected]]))
  {
    graph: @core.compile(resolver.gates, resolver.events.length()),
    events: resolver.events,
    probabilities: resolver.probabilities,
    top: scopes.definitions[selected].id,
    document: source,
    event_paths: resolver.event_paths,
  }
}

///|
/// Resolve a public basic-event name or a fully qualified declaration path.
pub fn StaticModel::basic_event_index(
  self : StaticModel,
  name : String,
) -> Int32? {
  for index, id in self.events {
    if id == name || self.event_paths[index] == name {
      return Some(index)
    }
  }
  None
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
    values[self.event_paths[i]] = p[i]
  }
  let writer = @xml.Writer::new()
  write_tree(read_tree(self.document), writer, values, "")
  writer.to_string()
}
