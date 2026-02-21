import gleam/dict
import gleam/list
import gleamlog/knowledge_base
import gleamlog/parser/parser
import gleamlog/solver
import gleamlog/types.{
  type Clause, type Engine, type PredicateIndicator, type Solution, type Term, DQAtom, Engine, PredicateIndicator,
  PrologFlags,
}

/// Create a new Prolog engine with default settings
pub fn new() -> Engine {
  Engine(
    knowledge_base: knowledge_base.new(),
    var_counter: 0,
    flags: PrologFlags(
      max_depth: 100_000,
      occurs_check: False,
      double_quotes: DQAtom,
    ),
  )
}

/// Consult a Prolog source string, adding clauses to the engine
pub fn consult_string(engine: Engine, source: String) -> Engine {
  case parser.parse_program(source) {
    Ok(clauses) ->
      list.fold(clauses, engine, fn(engine, clause) {
        case clause_indicator(clause) {
          Ok(indicator) -> {
            let kb = knowledge_base.add_clause(engine.knowledge_base, indicator, clause)
            Engine(..engine, knowledge_base: kb)
          }
          Error(_) -> engine
        }
      })
    Error(_) -> engine
  }
}

/// Query the engine with a goal string, returning all solutions
pub fn query(engine: Engine, goal: String) -> List(Solution) {
  case parser.parse_query(goal) {
    Ok(goals) -> solver.solve(engine, goals)
    Error(_) -> []
  }
}

fn clause_indicator(clause: Clause) -> Result(PredicateIndicator, Nil) {
  case clause {
    types.Fact(head) -> term_indicator(head)
    types.Clause(head, _) -> term_indicator(head)
  }
}

fn term_indicator(term: Term) -> Result(PredicateIndicator, Nil) {
  case term {
    types.Atom(name) -> Ok(PredicateIndicator(name, 0))
    types.Compound(name, args) -> Ok(PredicateIndicator(name, list.length(args)))
    _ -> Error(Nil)
  }
}

/// Get the current variable counter (useful for generating fresh variables)
pub fn fresh_var(engine: Engine, name: String) -> #(types.Term, Engine) {
  let id = engine.var_counter
  let var = types.Var(name, id)
  let engine = Engine(..engine, var_counter: id + 1)
  #(var, engine)
}

/// Get the current variable counter value
pub fn var_counter(engine: Engine) -> Int {
  engine.var_counter
}

/// Create an empty solution (no bindings)
pub fn empty_solution() -> Solution {
  types.Solution(bindings: dict.new())
}
