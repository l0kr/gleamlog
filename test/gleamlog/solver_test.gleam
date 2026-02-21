import gleam/dict
import gleam/list
import gleamlog
import gleamlog/types.{Atom, Solution}

pub fn query_simple_fact_test() {
  let engine =
    gleamlog.new()
    |> gleamlog.consult_string("parent(tom, bob).")
  let solutions = gleamlog.query(engine, "?- parent(tom, X).")
  assert list.length(solutions) == 1
  let assert [Solution(bindings: bindings)] = solutions
  assert dict.get(bindings, "X") == Ok(Atom("bob"))
}

pub fn query_rule_test() {
  let engine =
    gleamlog.new()
    |> gleamlog.consult_string(
      "parent(tom, bob). parent(bob, ann). grandparent(X, Z) :- parent(X, Y), parent(Y, Z).",
    )
  let solutions = gleamlog.query(engine, "?- grandparent(tom, X).")
  assert list.length(solutions) == 1
  let assert [Solution(bindings: bindings)] = solutions
  assert dict.get(bindings, "X") == Ok(Atom("ann"))
}

pub fn query_backtracking_test() {
  let engine =
    gleamlog.new()
    |> gleamlog.consult_string(
      "parent(tom, bob). parent(tom, liz). parent(tom, pat).",
    )
  let solutions = gleamlog.query(engine, "?- parent(tom, X).")
  let xs =
    list.map(solutions, fn(solution) {
      case solution {
        Solution(bindings: bindings) ->
          case dict.get(bindings, "X") {
            Ok(Atom(name)) -> name
            _ -> ""
          }
      }
    })
  assert xs == ["bob", "liz", "pat"]
}

pub fn query_recursive_test() {
  let engine =
    gleamlog.new()
    |> gleamlog.consult_string(
      "parent(tom, bob). parent(bob, ann). parent(ann, sue). ancestor(X, Y) :- parent(X, Y). ancestor(X, Z) :- parent(X, Y), ancestor(Y, Z).",
    )
  let solutions = gleamlog.query(engine, "?- ancestor(tom, X).")
  let xs =
    list.map(solutions, fn(solution) {
      case solution {
        Solution(bindings: bindings) ->
          case dict.get(bindings, "X") {
            Ok(Atom(name)) -> name
            _ -> ""
          }
      }
    })
  assert xs == ["bob", "ann", "sue"]
}
