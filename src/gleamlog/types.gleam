import gleam/dict.{type Dict}

/// A Prolog term
pub type Term {
  /// A logic variable, e.g., X, _Foo, _
  Var(name: String, id: Int)
  /// An atom, e.g., foo, 'hello world'
  Atom(name: String)
  /// An integer
  Integer(value: Int)
  /// A floating-point number
  Float(value: Float)
  /// A compound term / structure, e.g., f(a, X)
  Compound(functor: String, args: List(Term))
  /// The empty list []
  PrologNil
  /// List cons cell [H|T]
  Cons(head: Term, tail: Term)
}

/// A predicate indicator: name/arity
pub type PredicateIndicator {
  PredicateIndicator(name: String, arity: Int)
}

/// A Prolog clause: Head :- Body1, Body2, ...
pub type Clause {
  /// A rule with head and body goals
  Clause(head: Term, body: List(Term))
  /// A fact is a clause with an empty body
  Fact(head: Term)
}

/// A substitution maps variable IDs to terms
pub type Substitution =
  Dict(Int, Term)

/// A choice point for backtracking
pub type ChoicePoint {
  ChoicePoint(
    goal_stack: List(Term),
    substitution: Substitution,
    clauses: List(Clause),
    trail: List(Int),
    cut_barrier: Bool,
  )
}

/// A single query solution with named variable bindings
pub type Solution {
  Solution(bindings: Dict(String, Term))
}

/// Query result — either succeeds with solutions or fails
pub type QueryResult {
  Success(solutions: List(Solution))
  Failure
  Error(message: String)
}

/// The knowledge base stores clauses indexed by predicate indicator
pub type KnowledgeBase {
  KnowledgeBase(clauses: Dict(PredicateIndicator, List(Clause)))
}

/// Engine state
pub type Engine {
  Engine(knowledge_base: KnowledgeBase, var_counter: Int, flags: PrologFlags)
}

/// Prolog system flags
pub type PrologFlags {
  PrologFlags(max_depth: Int, occurs_check: Bool, double_quotes: DoubleQuotes)
}

/// How double-quoted strings are interpreted
pub type DoubleQuotes {
  DQAtom
  DQChars
  DQCodes
}

/// Errors that can occur during unification
pub type UnificationError {
  OccursCheckFailure(var_id: Int, term: Term)
  UnificationFailure(t1: Term, t2: Term)
}
