import gleam/dict
import gleamlog/types.{
  type Clause, type KnowledgeBase, type PredicateIndicator, type Term, Atom,
  Clause, Compound, Fact, KnowledgeBase,
}

/// Create an empty knowledge base
pub fn new() -> KnowledgeBase {
  KnowledgeBase(clauses: dict.new())
}

/// Add a clause to the knowledge base (appended at the end)
pub fn add_clause(
  kb: KnowledgeBase,
  indicator: PredicateIndicator,
  clause: Clause,
) -> KnowledgeBase {
  let existing = case dict.get(kb.clauses, indicator) {
    Ok(clauses) -> clauses
    Error(_) -> []
  }
  let updated =
    dict.insert(kb.clauses, indicator, list_append(existing, clause))
  KnowledgeBase(clauses: updated)
}

/// Retrieve all clauses for a given predicate indicator
pub fn get_clauses(
  kb: KnowledgeBase,
  indicator: PredicateIndicator,
) -> List(Clause) {
  case dict.get(kb.clauses, indicator) {
    Ok(clauses) -> clauses
    Error(_) -> []
  }
}

pub fn assertz(kb: KnowledgeBase, clause: Clause) -> Result(KnowledgeBase, Nil) {
  case clause_indicator(clause) {
    Ok(indicator) -> Ok(add_clause(kb, indicator, clause))
    Error(_) -> Error(Nil)
  }
}

pub fn asserta(kb: KnowledgeBase, clause: Clause) -> Result(KnowledgeBase, Nil) {
  case clause_indicator(clause) {
    Ok(indicator) -> {
      let existing = get_clauses(kb, indicator)
      let updated = dict.insert(kb.clauses, indicator, [clause, ..existing])
      Ok(KnowledgeBase(clauses: updated))
    }
    Error(_) -> Error(Nil)
  }
}

pub fn lookup(kb: KnowledgeBase, indicator: PredicateIndicator) -> List(Clause) {
  get_clauses(kb, indicator)
}

pub fn retract(
  kb: KnowledgeBase,
  head: Term,
) -> Result(#(Clause, KnowledgeBase), Nil) {
  case term_indicator(head) {
    Ok(indicator) -> {
      let clauses = get_clauses(kb, indicator)
      case remove_first_matching(clauses, head, []) {
        Ok(#(removed, remaining)) -> {
          let updated = dict.insert(kb.clauses, indicator, remaining)
          Ok(#(removed, KnowledgeBase(clauses: updated)))
        }
        Error(_) -> Error(Nil)
      }
    }
    Error(_) -> Error(Nil)
  }
}

fn remove_first_matching(
  clauses: List(Clause),
  head: Term,
  acc: List(Clause),
) -> Result(#(Clause, List(Clause)), Nil) {
  case clauses {
    [] -> Error(Nil)
    [clause, ..rest] ->
      case clause_head(clause) == head {
        True -> Ok(#(clause, list_concat(list_reverse(acc), rest)))
        False -> remove_first_matching(rest, head, [clause, ..acc])
      }
  }
}

fn clause_head(clause: Clause) -> Term {
  case clause {
    Fact(head) -> head
    Clause(head, _) -> head
  }
}

fn clause_indicator(clause: Clause) -> Result(PredicateIndicator, Nil) {
  term_indicator(clause_head(clause))
}

fn term_indicator(term: Term) -> Result(PredicateIndicator, Nil) {
  case term {
    Atom(name) -> Ok(types.PredicateIndicator(name, 0))
    Compound(name, args) ->
      Ok(types.PredicateIndicator(name, list_length(args)))
    _ -> Error(Nil)
  }
}

fn list_length(list: List(a)) -> Int {
  case list {
    [] -> 0
    [_, ..rest] -> 1 + list_length(rest)
  }
}

fn list_reverse(list: List(a)) -> List(a) {
  list_reverse_loop(list, [])
}

fn list_reverse_loop(list: List(a), acc: List(a)) -> List(a) {
  case list {
    [] -> acc
    [first, ..rest] -> list_reverse_loop(rest, [first, ..acc])
  }
}

fn list_concat(left: List(a), right: List(a)) -> List(a) {
  case left {
    [] -> right
    [first, ..rest] -> [first, ..list_concat(rest, right)]
  }
}

fn list_append(lst: List(a), item: a) -> List(a) {
  case lst {
    [] -> [item]
    [first, ..rest] -> [first, ..list_append(rest, item)]
  }
}
