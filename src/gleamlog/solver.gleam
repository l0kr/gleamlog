import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}
import gleamlog/builtins/arithmetic
import gleamlog/builtins/comparison
import gleamlog/knowledge_base
import gleamlog/types.{
  type Clause, type Engine, type PredicateIndicator, type Solution,
  type Substitution, type Term, Atom, Clause, Compound, Fact, PredicateIndicator,
  Solution, Var,
}
import gleamlog/unify

pub fn solve(engine: Engine, goals: List(Term)) -> List(Solution) {
  let query_vars = collect_query_vars(goals)
  let start_counter = max_var_id(goals) + 1
  let start_counter = int_max(start_counter, engine.var_counter)
  let subs =
    resolve(
      goals,
      engine.knowledge_base,
      dict.new(),
      start_counter,
      0,
      engine.flags.max_depth,
    )
  list.map(subs, fn(sub) { solution_from_sub(query_vars, sub) })
}

fn resolve(
  goals: List(Term),
  kb: types.KnowledgeBase,
  sub: Substitution,
  counter: Int,
  depth: Int,
  max_depth: Int,
) -> List(Substitution) {
  case depth > max_depth {
    True -> []
    False ->
      case goals {
        [] -> [sub]
        [goal, ..rest] ->
          case unify.walk(goal, sub) {
            g ->
              case handle_builtin(g, rest, kb, sub, counter, depth, max_depth) {
                Some(results) -> results
                None ->
                  case term_indicator(g) {
                    Ok(indicator) -> {
                      let clauses = knowledge_base.get_clauses(kb, indicator)
                      resolve_clauses(
                        clauses,
                        g,
                        rest,
                        kb,
                        sub,
                        counter,
                        depth,
                        max_depth,
                        [],
                      )
                    }
                    Error(_) -> []
                  }
              }
          }
      }
  }
}

fn handle_builtin(
  goal: Term,
  rest: List(Term),
  kb: types.KnowledgeBase,
  sub: Substitution,
  counter: Int,
  depth: Int,
  max_depth: Int,
) -> Option(List(Substitution)) {
  case goal {
    Atom("true") | Atom("!") ->
      Some(resolve(rest, kb, sub, counter, depth + 1, max_depth))
    Atom("fail") -> Some([])
    Compound(",", [left, right]) ->
      Some(resolve(
        [left, right, ..rest],
        kb,
        sub,
        counter,
        depth + 1,
        max_depth,
      ))
    Compound(";", [left, right]) -> {
      let left_results =
        resolve([left, ..rest], kb, sub, counter, depth + 1, max_depth)
      let right_results =
        resolve([right, ..rest], kb, sub, counter, depth + 1, max_depth)
      Some(list.append(left_results, right_results))
    }
    Compound("->", [cond, then_]) ->
      case resolve([cond], kb, sub, counter, depth + 1, max_depth) {
        [] -> Some([])
        [first, ..] ->
          Some(resolve(
            [then_, ..rest],
            kb,
            first,
            counter,
            depth + 1,
            max_depth,
          ))
      }
    Compound("\\+", [neg_goal]) ->
      case resolve([neg_goal], kb, sub, counter, depth + 1, max_depth) {
        [] -> Some(resolve(rest, kb, sub, counter, depth + 1, max_depth))
        _ -> Some([])
      }
    Compound("call", [call_goal]) ->
      Some(resolve([call_goal, ..rest], kb, sub, counter, depth + 1, max_depth))
    Compound("once", [call_goal]) ->
      case resolve([call_goal], kb, sub, counter, depth + 1, max_depth) {
        [] -> Some([])
        [first, ..] ->
          Some(resolve(rest, kb, first, counter, depth + 1, max_depth))
      }
    Compound("=", [left, right]) ->
      case unify.unify(left, right, sub) {
        Ok(sub1) -> Some(resolve(rest, kb, sub1, counter, depth + 1, max_depth))
        Error(_) -> Some([])
      }
    Compound("\\=", [left, right]) ->
      case unify.unify(left, right, sub) {
        Ok(_) -> Some([])
        Error(_) -> Some(resolve(rest, kb, sub, counter, depth + 1, max_depth))
      }
    Compound("==", [left, right]) ->
      case unify.walk_deep(left, sub) == unify.walk_deep(right, sub) {
        True -> Some(resolve(rest, kb, sub, counter, depth + 1, max_depth))
        False -> Some([])
      }
    Compound("\\==", [left, right]) ->
      case unify.walk_deep(left, sub) == unify.walk_deep(right, sub) {
        True -> Some([])
        False -> Some(resolve(rest, kb, sub, counter, depth + 1, max_depth))
      }
    Compound("var", [value]) ->
      Some(guard_bool(
        comparison.is_var(value, sub),
        rest,
        kb,
        sub,
        counter,
        depth,
        max_depth,
      ))
    Compound("nonvar", [value]) ->
      Some(guard_bool(
        comparison.is_nonvar(value, sub),
        rest,
        kb,
        sub,
        counter,
        depth,
        max_depth,
      ))
    Compound("atom", [value]) ->
      Some(guard_bool(
        comparison.is_atom(value, sub),
        rest,
        kb,
        sub,
        counter,
        depth,
        max_depth,
      ))
    Compound("integer", [value]) ->
      Some(guard_bool(
        comparison.is_integer(value, sub),
        rest,
        kb,
        sub,
        counter,
        depth,
        max_depth,
      ))
    Compound("float", [value]) ->
      Some(guard_bool(
        comparison.is_float(value, sub),
        rest,
        kb,
        sub,
        counter,
        depth,
        max_depth,
      ))
    Compound("number", [value]) ->
      Some(guard_bool(
        comparison.is_number(value, sub),
        rest,
        kb,
        sub,
        counter,
        depth,
        max_depth,
      ))
    Compound("compound", [value]) ->
      Some(guard_bool(
        comparison.is_compound(value, sub),
        rest,
        kb,
        sub,
        counter,
        depth,
        max_depth,
      ))
    Compound("atomic", [value]) ->
      Some(guard_bool(
        comparison.is_atomic(value, sub),
        rest,
        kb,
        sub,
        counter,
        depth,
        max_depth,
      ))
    Compound("is_list", [value]) ->
      Some(guard_bool(
        comparison.is_list(value, sub),
        rest,
        kb,
        sub,
        counter,
        depth,
        max_depth,
      ))
    Compound("is", [left, expr]) ->
      case arithmetic.eval(expr, sub) {
        Ok(number) ->
          case unify.unify(left, number, sub) {
            Ok(sub1) ->
              Some(resolve(rest, kb, sub1, counter, depth + 1, max_depth))
            Error(_) -> Some([])
          }
        Error(_) -> Some([])
      }
    Compound(op, [left, right]) ->
      case is_arithmetic_compare(op) {
        True ->
          case arithmetic.eval_to_float(left), arithmetic.eval_to_float(right) {
            Ok(a), Ok(b) ->
              Some(guard_bool(
                apply_arithmetic_compare(op, a, b),
                rest,
                kb,
                sub,
                counter,
                depth,
                max_depth,
              ))
            _, _ -> Some([])
          }
        False -> None
      }
    _ -> None
  }
}

fn guard_bool(
  ok: Bool,
  rest: List(Term),
  kb: types.KnowledgeBase,
  sub: Substitution,
  counter: Int,
  depth: Int,
  max_depth: Int,
) -> List(Substitution) {
  case ok {
    True -> resolve(rest, kb, sub, counter, depth + 1, max_depth)
    False -> []
  }
}

fn is_arithmetic_compare(op: String) -> Bool {
  list.contains(["<", ">", "=<", ">=", "=:=", "=\\="], op)
}

fn apply_arithmetic_compare(op: String, left: Float, right: Float) -> Bool {
  case op {
    "<" -> left <. right
    ">" -> left >. right
    "=<" -> left <=. right
    ">=" -> left >=. right
    "=:=" -> left == right
    "=\\=" -> left != right
    _ -> False
  }
}

fn resolve_clauses(
  clauses: List(Clause),
  goal: Term,
  rest_goals: List(Term),
  kb: types.KnowledgeBase,
  sub: Substitution,
  counter: Int,
  depth: Int,
  max_depth: Int,
  acc: List(Substitution),
) -> List(Substitution) {
  case clauses {
    [] -> acc
    [clause, ..more] -> {
      let #(renamed, counter1) = rename_clause(clause, counter)
      let #(head, body) = clause_parts(renamed)
      let branch_results = case unify.unify(goal, head, sub) {
        Ok(sub1) -> {
          let new_goals = list.append(body, rest_goals)
          resolve(new_goals, kb, sub1, counter1, depth + 1, max_depth)
        }
        Error(_) -> []
      }
      let acc1 = list.append(acc, branch_results)
      resolve_clauses(
        more,
        goal,
        rest_goals,
        kb,
        sub,
        counter1,
        depth,
        max_depth,
        acc1,
      )
    }
  }
}

fn clause_parts(clause: Clause) -> #(Term, List(Term)) {
  case clause {
    Fact(head) -> #(head, [])
    Clause(head, body) -> #(head, body)
  }
}

fn term_indicator(term: Term) -> Result(PredicateIndicator, Nil) {
  case term {
    Atom(name) -> Ok(PredicateIndicator(name, 0))
    Compound(name, args) -> Ok(PredicateIndicator(name, list.length(args)))
    _ -> Error(Nil)
  }
}

fn rename_clause(clause: Clause, counter: Int) -> #(Clause, Int) {
  let vars = dict.new()
  case clause {
    Fact(head) -> {
      let #(head1, _, counter1) = rename_term(head, vars, counter)
      #(Fact(head1), counter1)
    }
    Clause(head, body) -> {
      let #(head1, vars1, counter1) = rename_term(head, vars, counter)
      let #(body1, _, counter2) = rename_terms(body, vars1, counter1, [])
      #(Clause(head1, body1), counter2)
    }
  }
}

fn rename_terms(
  terms: List(Term),
  vars: dict.Dict(Int, Int),
  counter: Int,
  acc: List(Term),
) -> #(List(Term), dict.Dict(Int, Int), Int) {
  case terms {
    [] -> #(list.reverse(acc), vars, counter)
    [term, ..rest] -> {
      let #(term1, vars1, counter1) = rename_term(term, vars, counter)
      rename_terms(rest, vars1, counter1, [term1, ..acc])
    }
  }
}

fn rename_term(
  term: Term,
  vars: dict.Dict(Int, Int),
  counter: Int,
) -> #(Term, dict.Dict(Int, Int), Int) {
  case term {
    Var(name, old_id) ->
      case dict.get(vars, old_id) {
        Ok(new_id) -> #(Var(name, new_id), vars, counter)
        Error(_) -> {
          let vars1 = dict.insert(vars, old_id, counter)
          #(Var(name, counter), vars1, counter + 1)
        }
      }
    Atom(_) | types.Integer(_) | types.Float(_) | types.PrologNil -> #(
      term,
      vars,
      counter,
    )
    types.Cons(head, tail) -> {
      let #(head1, vars1, counter1) = rename_term(head, vars, counter)
      let #(tail1, vars2, counter2) = rename_term(tail, vars1, counter1)
      #(types.Cons(head1, tail1), vars2, counter2)
    }
    Compound(functor, args) -> {
      let #(args1, vars1, counter1) = rename_terms(args, vars, counter, [])
      #(Compound(functor, args1), vars1, counter1)
    }
  }
}

fn collect_query_vars(goals: List(Term)) -> dict.Dict(String, Int) {
  collect_from_terms(goals, dict.new())
}

fn collect_from_terms(
  terms: List(Term),
  acc: dict.Dict(String, Int),
) -> dict.Dict(String, Int) {
  case terms {
    [] -> acc
    [term, ..rest] -> collect_from_terms(rest, collect_from_term(term, acc))
  }
}

fn collect_from_term(
  term: Term,
  acc: dict.Dict(String, Int),
) -> dict.Dict(String, Int) {
  case term {
    Var(name, id) ->
      case name == "_" {
        True -> acc
        False -> dict.insert(acc, name, id)
      }
    Atom(_) | types.Integer(_) | types.Float(_) | types.PrologNil -> acc
    types.Cons(head, tail) ->
      collect_from_term(tail, collect_from_term(head, acc))
    Compound(_, args) -> collect_from_terms(args, acc)
  }
}

fn max_var_id(terms: List(Term)) -> Int {
  max_var_id_terms(terms, -1)
}

fn max_var_id_terms(terms: List(Term), current: Int) -> Int {
  case terms {
    [] -> current
    [term, ..rest] -> max_var_id_terms(rest, max_var_id_term(term, current))
  }
}

fn max_var_id_term(term: Term, current: Int) -> Int {
  case term {
    Var(_, id) -> int_max(current, id)
    Atom(_) | types.Integer(_) | types.Float(_) | types.PrologNil -> current
    types.Cons(head, tail) ->
      max_var_id_term(tail, max_var_id_term(head, current))
    Compound(_, args) -> max_var_id_terms(args, current)
  }
}

fn solution_from_sub(
  vars: dict.Dict(String, Int),
  sub: Substitution,
) -> Solution {
  let pairs = dict.to_list(vars)
  let bindings =
    list.fold(pairs, dict.new(), fn(bindings, pair) {
      let #(name, id) = pair
      let value = unify.walk_deep(Var(name, id), sub)
      dict.insert(bindings, name, value)
    })
  Solution(bindings: bindings)
}

fn int_max(a: Int, b: Int) -> Int {
  case a >= b {
    True -> a
    False -> b
  }
}
