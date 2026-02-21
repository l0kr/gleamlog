import gleam/dict
import gleamlog
import gleamlog/types.{
  Atom, Clause, Compound, Cons, Fact, Float, Integer, PredicateIndicator,
  PrologNil, Solution, Var,
}

pub fn term_construction_test() {
  // Variables
  let x = Var("X", 0)
  assert x.name == "X"
  assert x.id == 0

  // Atoms
  let a = Atom("hello")
  assert a.name == "hello"

  // Integers
  let n = Integer(42)
  assert n.value == 42

  // Floats
  let f = Float(3.14)
  assert f.value == 3.14

  // Compound terms: f(a, X)
  let t = Compound("f", [Atom("a"), Var("X", 0)])
  assert t.functor == "f"
  assert t.args == [Atom("a"), Var("X", 0)]

  // Lists: [1, 2, 3] = Cons(1, Cons(2, Cons(3, PrologNil)))
  let lst = Cons(Integer(1), Cons(Integer(2), Cons(Integer(3), PrologNil)))
  assert lst.head == Integer(1)
}

pub fn clause_construction_test() {
  // Fact: parent(tom, bob).
  let fact = Fact(Compound("parent", [Atom("tom"), Atom("bob")]))
  assert fact.head == Compound("parent", [Atom("tom"), Atom("bob")])

  // Rule: grandparent(X, Z) :- parent(X, Y), parent(Y, Z).
  let rule =
    Clause(head: Compound("grandparent", [Var("X", 0), Var("Z", 2)]), body: [
      Compound("parent", [Var("X", 0), Var("Y", 1)]),
      Compound("parent", [Var("Y", 1), Var("Z", 2)]),
    ])
  assert rule.head == Compound("grandparent", [Var("X", 0), Var("Z", 2)])
  assert rule.body
    == [
      Compound("parent", [Var("X", 0), Var("Y", 1)]),
      Compound("parent", [Var("Y", 1), Var("Z", 2)]),
    ]
}

pub fn predicate_indicator_test() {
  let pi = PredicateIndicator("parent", 2)
  assert pi.name == "parent"
  assert pi.arity == 2
}

pub fn solution_test() {
  let bindings = dict.from_list([#("X", Atom("tom")), #("Y", Atom("bob"))])
  let sol = Solution(bindings)
  assert dict.get(sol.bindings, "X") == Ok(Atom("tom"))
  assert dict.get(sol.bindings, "Y") == Ok(Atom("bob"))
  assert dict.get(sol.bindings, "Z") == Error(Nil)
}

pub fn engine_creation_test() {
  let engine = gleamlog.new()
  assert engine.var_counter == 0
  assert engine.flags.occurs_check == False
  assert engine.flags.max_depth == 100_000
}

pub fn fresh_var_test() {
  let engine = gleamlog.new()
  let #(v1, engine) = gleamlog.fresh_var(engine, "X")
  let #(v2, engine) = gleamlog.fresh_var(engine, "Y")
  assert v1 == Var("X", 0)
  assert v2 == Var("Y", 1)
  assert engine.var_counter == 2
}
