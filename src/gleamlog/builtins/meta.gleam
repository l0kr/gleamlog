import gleam/list
import gleamlog/types.{type Term, Atom, Compound, Integer}

pub fn call(goal: Term) -> Term {
  goal
}

pub fn functor(term: Term) -> #(Term, Int) {
  case term {
    Atom(name) -> #(Atom(name), 0)
    Compound(name, args) -> #(Atom(name), list.length(args))
    types.Cons(_, _) -> #(Atom("."), 2)
    types.PrologNil -> #(Atom("[]"), 0)
    types.Var(_, _) as var -> #(var, 0)
    Integer(_) as i -> #(i, 0)
    types.Float(_) as f -> #(f, 0)
  }
}

pub fn arg(term: Term, index: Int) -> Result(Term, Nil) {
  case term {
    Compound(_, args) ->
      case index >= 1 && index <= list.length(args) {
        True -> nth(args, index - 1)
        False -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

pub fn univ(term: Term) -> Term {
  case term {
    Atom(_) | Integer(_) | types.Float(_) | types.Var(_, _) | types.PrologNil -> {
      types.Cons(term, types.PrologNil)
    }
    Compound(name, args) -> list_to_prolog([Atom(name), ..args])
    types.Cons(head, tail) -> list_to_prolog([Atom("."), head, tail])
  }
}

pub fn copy_term(term: Term) -> Term {
  term
}

fn list_to_prolog(items: List(Term)) -> Term {
  case items {
    [] -> types.PrologNil
    [first, ..rest] -> types.Cons(first, list_to_prolog(rest))
  }
}

fn nth(items: List(a), index: Int) -> Result(a, Nil) {
  case items, index {
    [first, ..], 0 -> Ok(first)
    [_, ..rest], i if i > 0 -> nth(rest, i - 1)
    _, _ -> Error(Nil)
  }
}
