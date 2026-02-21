import gleamlog/substitution
import gleamlog/types.{
  Atom, Compound, Cons, Float, Integer, OccursCheckFailure, PrologNil, Var,
}
import gleamlog/unify

// --- walk tests ---

pub fn walk_unbound_var_test() {
  let sub = substitution.new()
  assert unify.walk(Var("X", 0), sub) == Var("X", 0)
}

pub fn walk_bound_var_test() {
  let sub = substitution.new() |> substitution.bind(0, Atom("hello"))
  assert unify.walk(Var("X", 0), sub) == Atom("hello")
}

pub fn walk_chain_test() {
  // X -> Y -> a
  let sub =
    substitution.new()
    |> substitution.bind(0, Var("Y", 1))
    |> substitution.bind(1, Atom("a"))
  assert unify.walk(Var("X", 0), sub) == Atom("a")
}

pub fn walk_non_var_test() {
  let sub = substitution.new()
  assert unify.walk(Atom("hello"), sub) == Atom("hello")
  assert unify.walk(Integer(42), sub) == Integer(42)
}

// --- walk_deep tests ---

pub fn walk_deep_compound_test() {
  // X = a, resolve f(X, b)
  let sub = substitution.new() |> substitution.bind(0, Atom("a"))
  let term = Compound("f", [Var("X", 0), Atom("b")])
  assert unify.walk_deep(term, sub) == Compound("f", [Atom("a"), Atom("b")])
}

pub fn walk_deep_nested_test() {
  // X = a, Y = f(X)
  let sub =
    substitution.new()
    |> substitution.bind(0, Atom("a"))
    |> substitution.bind(1, Compound("f", [Var("X", 0)]))
  assert unify.walk_deep(Var("Y", 1), sub) == Compound("f", [Atom("a")])
}

pub fn walk_deep_list_test() {
  // H = 1, resolve [H|T]
  let sub = substitution.new() |> substitution.bind(0, Integer(1))
  let term = Cons(Var("H", 0), Var("T", 1))
  assert unify.walk_deep(term, sub) == Cons(Integer(1), Var("T", 1))
}

// --- unify tests ---

// unify(X, a) → {X → a}
pub fn unify_var_atom_test() {
  let sub = substitution.new()
  let result = unify.unify(Var("X", 0), Atom("a"), sub)
  assert result == Ok(substitution.bind(sub, 0, Atom("a")))
}

// unify(a, X) → {X → a} (symmetric)
pub fn unify_atom_var_test() {
  let sub = substitution.new()
  let result = unify.unify(Atom("a"), Var("X", 0), sub)
  assert result == Ok(substitution.bind(sub, 0, Atom("a")))
}

// unify(a, a) → success (no new bindings)
pub fn unify_identical_atoms_test() {
  let sub = substitution.new()
  assert unify.unify(Atom("a"), Atom("a"), sub) == Ok(sub)
}

// unify(a, b) → failure
pub fn unify_different_atoms_test() {
  let sub = substitution.new()
  let result = unify.unify(Atom("a"), Atom("b"), sub)
  assert result
    == Error(types.UnificationFailure(Atom("a"), Atom("b")))
}

// unify(42, 42) → success
pub fn unify_identical_integers_test() {
  let sub = substitution.new()
  assert unify.unify(Integer(42), Integer(42), sub) == Ok(sub)
}

// unify(42, 99) → failure
pub fn unify_different_integers_test() {
  let sub = substitution.new()
  let result = unify.unify(Integer(42), Integer(99), sub)
  assert result
    == Error(types.UnificationFailure(Integer(42), Integer(99)))
}

// unify(3.14, 3.14) → success
pub fn unify_identical_floats_test() {
  let sub = substitution.new()
  assert unify.unify(Float(3.14), Float(3.14), sub) == Ok(sub)
}

// unify(X, X) → success (same variable)
pub fn unify_same_var_test() {
  let sub = substitution.new()
  assert unify.unify(Var("X", 0), Var("X", 0), sub) == Ok(sub)
}

// unify(X, Y) → {X → Y} or {Y → X}
pub fn unify_two_vars_test() {
  let sub = substitution.new()
  let result = unify.unify(Var("X", 0), Var("Y", 1), sub)
  assert result == Ok(substitution.bind(sub, 0, Var("Y", 1)))
}

// unify(f(X, b), f(a, Y)) → {X → a, Y → b}
pub fn unify_compound_test() {
  let sub = substitution.new()
  let t1 = Compound("f", [Var("X", 0), Atom("b")])
  let t2 = Compound("f", [Atom("a"), Var("Y", 1)])
  let result = unify.unify(t1, t2, sub)
  let expected =
    substitution.new()
    |> substitution.bind(0, Atom("a"))
    |> substitution.bind(1, Atom("b"))
  assert result == Ok(expected)
}

// unify(f(X, X), f(a, a)) → {X → a}
pub fn unify_repeated_var_same_test() {
  let sub = substitution.new()
  let t1 = Compound("f", [Var("X", 0), Var("X", 0)])
  let t2 = Compound("f", [Atom("a"), Atom("a")])
  let result = unify.unify(t1, t2, sub)
  let expected = substitution.bind(sub, 0, Atom("a"))
  assert result == Ok(expected)
}

// unify(f(X, X), f(a, b)) → Error (X can't be both a and b)
pub fn unify_repeated_var_conflict_test() {
  let sub = substitution.new()
  let t1 = Compound("f", [Var("X", 0), Var("X", 0)])
  let t2 = Compound("f", [Atom("a"), Atom("b")])
  let result = unify.unify(t1, t2, sub)
  assert result
    == Error(types.UnificationFailure(Atom("a"), Atom("b")))
}

// unify(X, f(X)) with occurs check → Error
pub fn unify_occurs_check_test() {
  let sub = substitution.new()
  let t1 = Var("X", 0)
  let t2 = Compound("f", [Var("X", 0)])
  let result = unify.unify(t1, t2, sub)
  assert result == Error(OccursCheckFailure(0, t2))
}

// unify(f(a), g(a)) → failure (different functors)
pub fn unify_different_functors_test() {
  let sub = substitution.new()
  let t1 = Compound("f", [Atom("a")])
  let t2 = Compound("g", [Atom("a")])
  let result = unify.unify(t1, t2, sub)
  assert result == Error(types.UnificationFailure(t1, t2))
}

// unify(f(a), f(a, b)) → failure (different arity)
pub fn unify_different_arity_test() {
  let sub = substitution.new()
  let t1 = Compound("f", [Atom("a")])
  let t2 = Compound("f", [Atom("a"), Atom("b")])
  let result = unify.unify(t1, t2, sub)
  assert result == Error(types.UnificationFailure(t1, t2))
}

// unify([], []) → success
pub fn unify_empty_lists_test() {
  let sub = substitution.new()
  assert unify.unify(PrologNil, PrologNil, sub) == Ok(sub)
}

// unify([H|T], [1, 2, 3]) → {H → 1, T → [2, 3]}
pub fn unify_list_cons_test() {
  let sub = substitution.new()
  let t1 = Cons(Var("H", 0), Var("T", 1))
  let t2 =
    Cons(Integer(1), Cons(Integer(2), Cons(Integer(3), PrologNil)))
  let result = unify.unify(t1, t2, sub)
  let expected =
    substitution.new()
    |> substitution.bind(0, Integer(1))
    |> substitution.bind(1, Cons(Integer(2), Cons(Integer(3), PrologNil)))
  assert result == Ok(expected)
}

// unify([1, 2], [1, 2]) → success
pub fn unify_identical_lists_test() {
  let sub = substitution.new()
  let lst = Cons(Integer(1), Cons(Integer(2), PrologNil))
  assert unify.unify(lst, lst, sub) == Ok(sub)
}

// unify([1, 2], [1, 3]) → failure
pub fn unify_different_lists_test() {
  let sub = substitution.new()
  let t1 = Cons(Integer(1), Cons(Integer(2), PrologNil))
  let t2 = Cons(Integer(1), Cons(Integer(3), PrologNil))
  let result = unify.unify(t1, t2, sub)
  assert result
    == Error(types.UnificationFailure(Integer(2), Integer(3)))
}

// Nested compound: unify(f(g(X)), f(g(a))) → {X → a}
pub fn unify_nested_compound_test() {
  let sub = substitution.new()
  let t1 = Compound("f", [Compound("g", [Var("X", 0)])])
  let t2 = Compound("f", [Compound("g", [Atom("a")])])
  let result = unify.unify(t1, t2, sub)
  assert result == Ok(substitution.bind(sub, 0, Atom("a")))
}

// Transitive: X = Y, Y = a  →  walk X = a
pub fn unify_transitive_test() {
  let sub = substitution.new()
  let assert Ok(sub) = unify.unify(Var("X", 0), Var("Y", 1), sub)
  let assert Ok(sub) = unify.unify(Var("Y", 1), Atom("a"), sub)
  assert unify.walk_deep(Var("X", 0), sub) == Atom("a")
  assert unify.walk_deep(Var("Y", 1), sub) == Atom("a")
}

// unify(atom, 42) → failure (type mismatch)
pub fn unify_type_mismatch_test() {
  let sub = substitution.new()
  let result = unify.unify(Atom("a"), Integer(42), sub)
  assert result
    == Error(types.UnificationFailure(Atom("a"), Integer(42)))
}

// Deep occurs check: unify(X, f(g(X))) → Error
pub fn unify_deep_occurs_check_test() {
  let sub = substitution.new()
  let t2 = Compound("f", [Compound("g", [Var("X", 0)])])
  let result = unify.unify(Var("X", 0), t2, sub)
  assert result == Error(OccursCheckFailure(0, t2))
}

// Symmetry property: unify(t1, t2) and unify(t2, t1) should both succeed or both fail
pub fn unify_symmetry_test() {
  let sub = substitution.new()
  let t1 = Compound("f", [Var("X", 0), Atom("b")])
  let t2 = Compound("f", [Atom("a"), Var("Y", 1)])

  let r1 = unify.unify(t1, t2, sub)
  let r2 = unify.unify(t2, t1, sub)

  // Both should succeed
  let assert Ok(s1) = r1
  let assert Ok(s2) = r2

  // Applying both substitutions should yield the same ground term
  assert unify.walk_deep(t1, s1) == unify.walk_deep(t2, s1)
  assert unify.walk_deep(t1, s2) == unify.walk_deep(t2, s2)
}
