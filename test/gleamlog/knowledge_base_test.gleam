import gleamlog/knowledge_base
import gleamlog/types.{Atom, Compound, Fact, PredicateIndicator}

pub fn empty_kb_test() {
  let kb = knowledge_base.new()
  let pi = PredicateIndicator("parent", 2)
  assert knowledge_base.get_clauses(kb, pi) == []
}

pub fn add_and_get_clauses_test() {
  let kb = knowledge_base.new()
  let pi = PredicateIndicator("parent", 2)

  let fact1 = Fact(Compound("parent", [Atom("tom"), Atom("bob")]))
  let fact2 = Fact(Compound("parent", [Atom("tom"), Atom("liz")]))

  let kb = knowledge_base.add_clause(kb, pi, fact1)
  let kb = knowledge_base.add_clause(kb, pi, fact2)

  let clauses = knowledge_base.get_clauses(kb, pi)
  assert clauses == [fact1, fact2]
}

pub fn separate_predicates_test() {
  let kb = knowledge_base.new()

  let parent_pi = PredicateIndicator("parent", 2)
  let child_pi = PredicateIndicator("child", 2)

  let parent_fact = Fact(Compound("parent", [Atom("tom"), Atom("bob")]))
  let child_fact = Fact(Compound("child", [Atom("bob"), Atom("tom")]))

  let kb = knowledge_base.add_clause(kb, parent_pi, parent_fact)
  let kb = knowledge_base.add_clause(kb, child_pi, child_fact)

  assert knowledge_base.get_clauses(kb, parent_pi) == [parent_fact]
  assert knowledge_base.get_clauses(kb, child_pi) == [child_fact]
}
