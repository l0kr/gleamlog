import gleamlog/types.{type Term, Atom, Compound, Cons, Float, Integer, PrologNil, Var}
import gleamlog/unify

pub fn is_var(term: Term, sub: types.Substitution) -> Bool {
  case unify.walk(term, sub) {
    Var(_, _) -> True
    _ -> False
  }
}

pub fn is_nonvar(term: Term, sub: types.Substitution) -> Bool {
  !is_var(term, sub)
}

pub fn is_atom(term: Term, sub: types.Substitution) -> Bool {
  case unify.walk_deep(term, sub) {
    Atom(_) -> True
    _ -> False
  }
}

pub fn is_integer(term: Term, sub: types.Substitution) -> Bool {
  case unify.walk_deep(term, sub) {
    Integer(_) -> True
    _ -> False
  }
}

pub fn is_float(term: Term, sub: types.Substitution) -> Bool {
  case unify.walk_deep(term, sub) {
    Float(_) -> True
    _ -> False
  }
}

pub fn is_number(term: Term, sub: types.Substitution) -> Bool {
  case unify.walk_deep(term, sub) {
    Integer(_) | Float(_) -> True
    _ -> False
  }
}

pub fn is_compound(term: Term, sub: types.Substitution) -> Bool {
  case unify.walk_deep(term, sub) {
    Compound(_, _) | Cons(_, _) -> True
    _ -> False
  }
}

pub fn is_atomic(term: Term, sub: types.Substitution) -> Bool {
  case unify.walk_deep(term, sub) {
    Atom(_) | Integer(_) | Float(_) | PrologNil -> True
    _ -> False
  }
}

pub fn is_list(term: Term, sub: types.Substitution) -> Bool {
  is_list_term(unify.walk_deep(term, sub))
}

fn is_list_term(term: Term) -> Bool {
  case term {
    PrologNil -> True
    Cons(_, tail) -> is_list_term(tail)
    _ -> False
  }
}
