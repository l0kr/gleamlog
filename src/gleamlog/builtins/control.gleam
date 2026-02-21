import gleamlog/types.{type Term, Atom, Compound}

pub fn is_true(term: Term) -> Bool {
  term == Atom("true")
}

pub fn is_fail(term: Term) -> Bool {
  term == Atom("fail")
}

pub fn is_cut(term: Term) -> Bool {
  term == Atom("!")
}

pub fn as_conjunction(term: Term) -> Result(#(Term, Term), Nil) {
  case term {
    Compound(",", [left, right]) -> Ok(#(left, right))
    _ -> Error(Nil)
  }
}

pub fn as_disjunction(term: Term) -> Result(#(Term, Term), Nil) {
  case term {
    Compound(";", [left, right]) -> Ok(#(left, right))
    _ -> Error(Nil)
  }
}

pub fn as_if_then(term: Term) -> Result(#(Term, Term), Nil) {
  case term {
    Compound("->", [cond, then_]) -> Ok(#(cond, then_))
    _ -> Error(Nil)
  }
}

pub fn as_negation(term: Term) -> Result(Term, Nil) {
  case term {
    Compound("\\+", [goal]) -> Ok(goal)
    _ -> Error(Nil)
  }
}

pub fn as_call(term: Term) -> Result(Term, Nil) {
  case term {
    Compound("call", [goal]) -> Ok(goal)
    _ -> Error(Nil)
  }
}

pub fn as_once(term: Term) -> Result(Term, Nil) {
  case term {
    Compound("once", [goal]) -> Ok(goal)
    _ -> Error(Nil)
  }
}
