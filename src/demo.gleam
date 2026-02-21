import gleam/dict
import gleam/io
import gleam/list
import gleam/string
import gleamlog
import gleamlog/builtins/io as prolog_io
import gleamlog/types

pub fn main() -> Nil {
  let program =
    "parent(tom, bob).
parent(tom, liz).
parent(bob, ann).
grandparent(X, Z) :- parent(X, Y), parent(Y, Z).
member(X, [X|_]).
member(X, [_|T]) :- member(X, T)."

  let engine =
    gleamlog.new()
    |> gleamlog.consult_string(program)

  run_query(engine, "?- parent(tom, X).")
  run_query(engine, "?- grandparent(tom, X).")
  run_query(engine, "?- member(X, [a, b, c]).")
  run_query(engine, "?- X is 1 + 2 * 3.")
}

fn run_query(engine: types.Engine, query: String) -> Nil {
  io.println("query: " <> query)
  let solutions = gleamlog.query(engine, query)
  case solutions {
    [] -> io.println("false.")
    _ -> list.each(solutions, print_solution)
  }
  io.println("")
}

fn print_solution(solution: types.Solution) -> Nil {
  let types.Solution(bindings: bindings) = solution
  let entries = dict.to_list(bindings)
  case entries {
    [] -> io.println("true.")
    _ ->
      entries
      |> list.map(fn(entry) {
        let #(name, value) = entry
        name <> " = " <> prolog_io.render(value)
      })
      |> string.join(", ")
      |> io.println
  }
}
