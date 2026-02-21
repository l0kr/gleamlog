import gleam/dict
import gleam/list
import gleamlog
import gleamlog/types.{Atom, Integer, Solution}

pub fn unify_builtin_test() {
  let solutions = gleamlog.new() |> gleamlog.query("?- X = a.")
  assert list.length(solutions) == 1
  let assert [Solution(bindings: bindings)] = solutions
  assert dict.get(bindings, "X") == Ok(Atom("a"))
}

pub fn not_unifiable_builtin_test() {
  let solutions = gleamlog.new() |> gleamlog.query("?- a \\= b.")
  assert list.length(solutions) == 1
}

pub fn type_test_builtin_test() {
  let solutions = gleamlog.new() |> gleamlog.query("?- atom(a), integer(1), number(1), is_list([1,2]).")
  assert list.length(solutions) == 1
}

pub fn arithmetic_is_test() {
  let solutions = gleamlog.new() |> gleamlog.query("?- X is 1 + 2 * 3.")
  let assert [Solution(bindings: bindings)] = solutions
  assert dict.get(bindings, "X") == Ok(Integer(7))
}

pub fn arithmetic_compare_test() {
  let solutions = gleamlog.new() |> gleamlog.query("?- 7 > 3, 3 =< 3, 2 =\\= 3.")
  assert list.length(solutions) == 1
}

pub fn disjunction_and_negation_test() {
  let solutions = gleamlog.new() |> gleamlog.query("?- (X = a ; X = b), \\+ (X = c).")
  let xs =
    list.map(solutions, fn(solution) {
      let Solution(bindings: bindings) = solution
      case dict.get(bindings, "X") {
        Ok(Atom(name)) -> name
        _ -> ""
      }
    })
  assert xs == ["a", "b"]
}
