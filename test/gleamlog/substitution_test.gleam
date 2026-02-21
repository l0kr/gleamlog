import gleamlog/substitution
import gleamlog/types.{Atom, Compound, Integer, Var}

pub fn new_substitution_test() {
  let sub = substitution.new()
  assert substitution.lookup(sub, 0) == Error(Nil)
}

pub fn bind_and_lookup_test() {
  let sub = substitution.new()
  let sub = substitution.bind(sub, 0, Atom("hello"))
  assert substitution.lookup(sub, 0) == Ok(Atom("hello"))
  assert substitution.lookup(sub, 1) == Error(Nil)
}

pub fn multiple_bindings_test() {
  let sub = substitution.new()
  let sub = substitution.bind(sub, 0, Atom("a"))
  let sub = substitution.bind(sub, 1, Integer(42))
  let sub = substitution.bind(sub, 2, Compound("f", [Var("X", 0)]))

  assert substitution.lookup(sub, 0) == Ok(Atom("a"))
  assert substitution.lookup(sub, 1) == Ok(Integer(42))
  assert substitution.lookup(sub, 2) == Ok(Compound("f", [Var("X", 0)]))
}

pub fn overwrite_binding_test() {
  let sub = substitution.new()
  let sub = substitution.bind(sub, 0, Atom("first"))
  let sub = substitution.bind(sub, 0, Atom("second"))
  assert substitution.lookup(sub, 0) == Ok(Atom("second"))
}
