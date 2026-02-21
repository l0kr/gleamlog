import gleam/list
import gleamlog/substitution
import gleamlog/types.{
  type Substitution, type Term, type UnificationError, Atom, Compound, Cons,
  Float, Integer, OccursCheckFailure, PrologNil, UnificationFailure, Var,
}

/// Unify two terms, returning the updated substitution or an error
pub fn unify(
  t1: Term,
  t2: Term,
  sub: Substitution,
) -> Result(Substitution, UnificationError) {
  let t1 = walk(t1, sub)
  let t2 = walk(t2, sub)
  case t1, t2 {
    // Two identical variables — already unified
    Var(_, id1), Var(_, id2) if id1 == id2 -> Ok(sub)
    // Bind variable to term (with occurs check)
    Var(_, id), term | term, Var(_, id) -> extend_check(sub, id, term)
    // Atoms unify if names match
    Atom(a), Atom(b) if a == b -> Ok(sub)
    // Integers unify if values match
    Integer(a), Integer(b) if a == b -> Ok(sub)
    // Floats unify if values match
    Float(a), Float(b) if a == b -> Ok(sub)
    // Empty lists unify
    PrologNil, PrologNil -> Ok(sub)
    // Cons cells — unify head and tail
    Cons(h1, t1_tail), Cons(h2, t2_tail) -> {
      case unify(h1, h2, sub) {
        Ok(sub2) -> unify(t1_tail, t2_tail, sub2)
        Error(e) -> Error(e)
      }
    }
    // Compound terms — unify if same functor/arity, then unify args
    Compound(f1, args1), Compound(f2, args2) ->
      case f1 == f2 && list.length(args1) == list.length(args2) {
        True -> unify_args(args1, args2, sub)
        False -> Error(UnificationFailure(t1, t2))
      }
    // Everything else fails
    _, _ -> Error(UnificationFailure(t1, t2))
  }
}

/// Walk/dereference a term through a substitution to its current binding
pub fn walk(term: Term, sub: Substitution) -> Term {
  case term {
    Var(_, id) ->
      case substitution.lookup(sub, id) {
        Ok(bound_term) -> walk(bound_term, sub)
        Error(_) -> term
      }
    _ -> term
  }
}

/// Deep walk — fully resolve a term including inside compound terms
pub fn walk_deep(term: Term, sub: Substitution) -> Term {
  case walk(term, sub) {
    Var(_, _) as v -> v
    Atom(_) as a -> a
    Integer(_) as i -> i
    Float(_) as f -> f
    PrologNil -> PrologNil
    Cons(head, tail) -> Cons(walk_deep(head, sub), walk_deep(tail, sub))
    Compound(functor, args) ->
      Compound(functor, list.map(args, fn(arg) { walk_deep(arg, sub) }))
  }
}

/// Extend substitution with occurs check
fn extend_check(
  sub: Substitution,
  var_id: Int,
  term: Term,
) -> Result(Substitution, UnificationError) {
  case occurs_in(var_id, term, sub) {
    True -> Error(OccursCheckFailure(var_id, term))
    False -> Ok(substitution.bind(sub, var_id, term))
  }
}

/// Check if a variable occurs in a term (following bindings through sub)
fn occurs_in(var_id: Int, term: Term, sub: Substitution) -> Bool {
  case walk(term, sub) {
    Var(_, id) -> id == var_id
    Compound(_, args) -> list.any(args, fn(arg) { occurs_in(var_id, arg, sub) })
    Cons(head, tail) ->
      occurs_in(var_id, head, sub) || occurs_in(var_id, tail, sub)
    _ -> False
  }
}

/// Unify two argument lists pairwise
fn unify_args(
  args1: List(Term),
  args2: List(Term),
  sub: Substitution,
) -> Result(Substitution, UnificationError) {
  case args1, args2 {
    [], [] -> Ok(sub)
    [a1, ..rest1], [a2, ..rest2] ->
      case unify(a1, a2, sub) {
        Ok(sub2) -> unify_args(rest1, rest2, sub2)
        Error(e) -> Error(e)
      }
    _, _ ->
      Error(UnificationFailure(Atom("arity_mismatch"), Atom("arity_mismatch")))
  }
}
