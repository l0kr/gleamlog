import gleam/int
import gleam/io
import gleam/list
import gleam/string
import gleamlog/types.{
  type Term, Atom, Compound, Cons, Float, Integer, PrologNil, Var,
}

pub fn write(term: Term) -> Nil {
  io.print(render(term))
}

pub fn writeln(term: Term) -> Nil {
  io.println(render(term))
}

pub fn nl() -> Nil {
  io.println("")
}

pub fn render(term: Term) -> String {
  case term {
    Var(name, id) ->
      case name == "_" {
        True -> "_" <> int.to_string(id)
        False -> name
      }
    Atom(name) -> name
    Integer(value) -> int.to_string(value)
    Float(value) -> float_to_string(value)
    PrologNil -> "[]"
    Cons(_, _) as list_term -> render_list(list_term)
    Compound(functor, args) ->
      functor <> "(" <> string.join(list.map(args, render), ", ") <> ")"
  }
}

fn render_list(term: Term) -> String {
  let #(items, tail) = list_parts(term, [])
  let base = "[" <> string.join(items, ", ")
  case tail {
    PrologNil -> base <> "]"
    _ -> base <> " | " <> render(tail) <> "]"
  }
}

fn list_parts(term: Term, acc: List(String)) -> #(List(String), Term) {
  case term {
    Cons(head, tail) -> list_parts(tail, [render(head), ..acc])
    _ -> #(list.reverse(acc), term)
  }
}

@external(erlang, "erlang", "float_to_binary")
fn float_to_string(value: Float) -> String
