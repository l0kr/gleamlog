import gleam/dict
import gleamlog/types.{type Substitution, type Term}

/// Create an empty substitution
pub fn new() -> Substitution {
  dict.new()
}

/// Bind a variable to a term
pub fn bind(sub: Substitution, var_id: Int, term: Term) -> Substitution {
  dict.insert(sub, var_id, term)
}

/// Look up a variable's binding
pub fn lookup(sub: Substitution, var_id: Int) -> Result(Term, Nil) {
  dict.get(sub, var_id)
}
