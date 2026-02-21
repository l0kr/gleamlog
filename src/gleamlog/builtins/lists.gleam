import gleam/list
import gleamlog/types.{type Term}

pub fn findall(values: List(Term)) -> Term {
  from_list(values)
}

pub fn bagof(values: List(Term)) -> Result(Term, Nil) {
  case values {
    [] -> Error(Nil)
    _ -> Ok(from_list(values))
  }
}

pub fn setof(values: List(Term)) -> Result(Term, Nil) {
  case values {
    [] -> Error(Nil)
    _ -> Ok(from_list(list.unique(values)))
  }
}

fn from_list(values: List(Term)) -> Term {
  case values {
    [] -> types.PrologNil
    [first, ..rest] -> types.Cons(first, from_list(rest))
  }
}
