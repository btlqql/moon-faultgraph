///|
pub(all) suberror MefError {
  InvalidModel(String)
}

///|
priv struct Element {
  tag : String
  attrs : Array[(String, String)]
  children : Array[Element]
  text : StringBuilder
}

///|
fn element(e : @xml.XmlElement) -> Element {
  {
    tag: e.name,
    attrs: e.attributes.map(fn(a) { (a.name, a.value) }),
    children: [],
    text: StringBuilder(),
  }
}

///|
fn read_tree(source : String) -> Element raise {
  if source.length() > 2000000 {
    raise InvalidModel("MEF input exceeds 2 million code units")
  }
  // Permit the conventional bare doctype. Reject DTD subsets and external identifiers
  // before the XML reader can process declarations.
  let input = source.replace_all(old="<!DOCTYPE opsa-mef>", new="")
  if input.contains("<!DOCTYPE") {
    raise InvalidModel("only a bare opsa-mef doctype is supported")
  }
  let reader = @xml.Reader::from_string(input)
  let root : Element = {
    tag: "",
    attrs: [],
    children: [],
    text: StringBuilder(),
  }
  let stack = [root]
  let mut count = 0
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(e) | Empty(e) => {
        count += 1
        if count > 12000 || stack.length() > 96 {
          raise InvalidModel("MEF element or depth limit")
        }
        let child = element(e)
        stack[stack.length() - 1].children.push(child)
        if event.kind is Start(_) {
          stack.push(child)
        }
      }
      End(_) => ignore(stack.pop())
      Text(value) | CData(value) => {
        let current = stack[stack.length() - 1]
        if current.tag == "label" {
          current.text.write_string(value)
        } else if !value.trim().is_empty() {
          raise InvalidModel("unexpected text in " + current.tag)
        }
      }
      Comment(_) | Decl(..) => ()
      Eof => break
      _ => raise InvalidModel("unsupported XML declaration")
    }
  }
  if root.children.length() != 1 || root.children[0].tag != "opsa-mef" {
    raise InvalidModel("expected one opsa-mef root")
  }
  root.children[0]
}

///|
fn Element::attr(self : Element, key : String) -> String? {
  for (name, value) in self.attrs {
    if name == key {
      return Some(value)
    }
  }
  None
}

///|
fn Element::required(self : Element, key : String) -> String raise MefError {
  guard self.attr(key) is Some(value) else {
    raise InvalidModel(self.tag + " requires " + key)
  }
  value
}

///|
fn Element::allow(self : Element, keys : Array[String]) -> Unit raise MefError {
  for (key, _) in self.attrs {
    if !keys.contains(key) {
      raise InvalidModel("unsupported attribute " + self.tag + "/" + key)
    }
  }
}

///|
fn Element::name(self : Element) -> String raise MefError {
  let value = self.required("name")
  let chars = value.to_array()
  if chars.is_empty() ||
    chars.length() > 128 ||
    !ascii_letter(chars[0]) ||
    !chars.all(fn(c) {
      ascii_letter(c) || (c >= '0' && c <= '9') || c == '_' || c == '-'
    }) {
    raise InvalidModel("unsupported MEF name " + value)
  }
  value
}

///|
fn ascii_letter(c : Char) -> Bool {
  (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')
}

///|
fn Element::body(self : Element) -> Array[Element] raise MefError {
  let body : Array[Element] = []
  let mut seen_label = false
  for child in self.children {
    if child.tag == "label" {
      child.allow([])
      if seen_label || !child.children.is_empty() {
        raise InvalidModel("invalid label in " + self.tag)
      }
      seen_label = true
    } else {
      body.push(child)
    }
  }
  body
}

///|
fn Element::leaf(self : Element) -> Unit raise MefError {
  if !self.children.is_empty() {
    raise InvalidModel("expected leaf " + self.tag)
  }
}

///|
fn write_tree(
  node : Element,
  writer : @xml.Writer,
  values : Map[String, Double],
) -> Unit raise {
  if node.tag == "define-basic-event" {
    let name = node.required("name")
    guard values.get(name) is Some(value) else {
      raise InvalidModel("unknown event " + name)
    }
    writer.start_element(node.tag, node.attrs)
    for label in node.children {
      if label.tag == "label" {
        write_tree(label, writer, values)
      }
    }
    writer.empty_element("float", [("value", Json(value).stringify())])
    writer.end_element(node.tag)
  } else if node.children.is_empty() && node.text.to_string().is_empty() {
    writer.empty_element(node.tag, node.attrs)
  } else {
    writer.start_element(node.tag, node.attrs)
    let label = node.text.to_string()
    if !label.is_empty() {
      writer.text(label)
    }
    for child in node.children {
      write_tree(child, writer, values)
    }
    writer.end_element(node.tag)
  }
}
