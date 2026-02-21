import gleamlog/parser/parser
import gleamlog/types.{Atom, Clause, Compound, Cons, Fact, Integer, PrologNil, Var}

pub fn parse_fact_atom_test() {
  let source = "foo."
  assert parser.parse_program(source) == Ok([Fact(Atom("foo"))])
}

pub fn parse_fact_compound_test() {
  let source = "parent(tom, bob)."
  assert parser.parse_program(source)
    == Ok([Fact(Compound("parent", [Atom("tom"), Atom("bob")]))])
}

pub fn parse_rule_test() {
  let source = "grandparent(X, Z) :- parent(X, Y), parent(Y, Z)."
  let expected =
    Clause(
      Compound("grandparent", [Var("X", 0), Var("Z", 1)]),
      [
        Compound("parent", [Var("X", 0), Var("Y", 2)]),
        Compound("parent", [Var("Y", 2), Var("Z", 1)]),
      ],
    )
  assert parser.parse_program(source) == Ok([expected])
}

pub fn parse_query_list_test() {
  let source = "?- member(X, [1, 2, 3])."
  let expected =
    [
      Compound(
        "member",
        [
          Var("X", 0),
          Cons(Integer(1), Cons(Integer(2), Cons(Integer(3), PrologNil))),
        ],
      ),
    ]
  assert parser.parse_query(source) == Ok(expected)
}

pub fn parse_operator_precedence_test() {
  let source = "X is 1 + 2 * 3"
  let expected =
    Compound(
      "is",
      [
        Var("X", 0),
        Compound("+", [Integer(1), Compound("*", [Integer(2), Integer(3)])]),
      ],
    )
  assert parser.parse_term(source) == Ok(expected)
}
