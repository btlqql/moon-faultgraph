///|
priv struct Definition {
  node : Element
  scope : String
  tree : String
  id : String
}

///|
priv struct ScopeIndex {
  definitions : Map[String, Definition]
  public_names : Map[String, String]
  components : Map[String, Bool]
}

///|
fn Element::is_private(self : Element, inherited : Bool) -> Bool raise MefError {
  match self.attr("role") {
    Some("private") => true
    Some("public") => false
    None => inherited
    Some(value) => raise InvalidModel("unsupported MEF role " + value)
  }
}

///|
fn ScopeIndex::register(
  self : ScopeIndex,
  container : Element,
  scope : String,
  tree : String,
  inherited_private : Bool,
) -> Unit raise MefError {
  for definition in container.body() {
    let name = definition.name()
    let path = qualified_name(scope, name)
    let is_private = definition.is_private(inherited_private)
    if tree.is_empty() && is_private {
      raise InvalidModel("private definition at model scope " + name)
    }
    match definition.tag {
      "define-component" if !tree.is_empty() => {
        definition.allow(["name", "role"])
        if self.components.get(path) is Some(_) {
          raise InvalidModel("duplicate component " + path)
        }
        self.components[path] = true
        self.register(definition, path, tree, is_private)
      }
      "define-basic-event" | "define-house-event" =>
        self.add_definition(definition, name, path, scope, tree, is_private)
      "define-gate" if !tree.is_empty() =>
        self.add_definition(definition, name, path, scope, tree, is_private)
      _ => raise InvalidModel("unsupported definition " + definition.tag)
    }
  }
}

///|
fn ScopeIndex::add_definition(
  self : ScopeIndex,
  node : Element,
  name : String,
  path : String,
  scope : String,
  tree : String,
  is_private : Bool,
) -> Unit raise MefError {
  node.allow(["name", "role"])
  if self.definitions.get(path) is Some(_) {
    raise InvalidModel("duplicate name " + path)
  }
  if self.definitions.length() >= 1024 {
    raise InvalidModel("static model exceeds 1024 definitions")
  }
  if !is_private {
    if self.public_names.get(name) is Some(_) {
      raise InvalidModel("duplicate public name " + name)
    }
    self.public_names[name] = path
  }
  self.definitions[path] = {
    node,
    scope,
    tree,
    id: if is_private {
      path
    } else {
      name
    },
  }
}

///|
fn index_scopes(document : Element) -> ScopeIndex raise MefError {
  let index : ScopeIndex = {
    definitions: Map([]),
    public_names: Map([]),
    components: Map([]),
  }
  let trees : Map[String, Bool] = Map([])
  let mut data_seen = false
  for container in document.body() {
    match container.tag {
      "define-fault-tree" => {
        container.allow(["name"])
        let name = container.name()
        if trees.get(name) is Some(_) {
          raise InvalidModel("duplicate fault tree " + name)
        }
        trees[name] = true
        index.register(container, name, name, false)
      }
      "model-data" if !data_seen => {
        container.allow([])
        data_seen = true
        index.register(container, "", "", false)
      }
      _ =>
        raise InvalidModel(
          "unsupported or duplicate container " + container.tag,
        )
    }
  }
  if trees.is_empty() {
    raise InvalidModel("expected at least one static fault tree")
  }
  index
}

///|
fn ScopeIndex::of_kind(
  self : ScopeIndex,
  path : String,
  kind : String?,
) -> Bool {
  match self.definitions.get(path) {
    None => false
    Some(definition) => kind is None || kind == Some(definition.node.tag)
  }
}

///|
fn ScopeIndex::lookup(
  self : ScopeIndex,
  scope : String,
  name : String,
  kind : String?,
) -> String? {
  if !scope.is_empty() {
    let relative_path = qualified_name(scope, name)
    if self.of_kind(relative_path, kind) {
      return Some(relative_path)
    }
  }
  let path = if name.contains(".") {
    name
  } else {
    guard self.public_names.get(name) is Some(path) else { return None }
    path
  }
  if self.of_kind(path, kind) {
    Some(path)
  } else {
    None
  }
}
