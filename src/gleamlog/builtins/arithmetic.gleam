import gleam/int
import gleamlog/types.{type Term, Compound, Float, Integer}
import gleamlog/unify

pub fn eval(term: Term, sub: types.Substitution) -> Result(Term, Nil) {
  eval_term(unify.walk_deep(term, sub))
}

fn eval_term(term: Term) -> Result(Term, Nil) {
  case term {
    Integer(_) | Float(_) -> Ok(term)
    Compound("+", [left, right]) ->
      eval_binary(left, right, fn(a, b) { a +. b }, fn(a, b) { Integer(a + b) })
    Compound("-", [left, right]) ->
      eval_binary(left, right, fn(a, b) { a -. b }, fn(a, b) { Integer(a - b) })
    Compound("*", [left, right]) ->
      eval_binary(left, right, fn(a, b) { a *. b }, fn(a, b) { Integer(a * b) })
    Compound("/", [left, right]) -> eval_binary_float(left, right, fn(a, b) { a /. b })
    Compound("//", [left, right]) ->
      case eval_to_float(left), eval_to_float(right) {
        Ok(a), Ok(b) ->
          case b == 0.0 {
            True -> Error(Nil)
            False -> Ok(Integer(float_to_int(float_floor(a /. b))))
          }
        _, _ -> Error(Nil)
      }
    Compound("mod", [left, right]) | Compound("rem", [left, right]) ->
      case eval_to_int(left), eval_to_int(right) {
        Ok(a), Ok(b) ->
          case b == 0 {
            True -> Error(Nil)
            False -> Ok(Integer(a % b))
          }
        _, _ -> Error(Nil)
      }
    Compound("-", [value]) ->
      case eval_term(value) {
        Ok(Integer(i)) -> Ok(Integer(-1 * i))
        Ok(Float(f)) -> Ok(Float(-1.0 *. f))
        _ -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

fn eval_binary(
  left: Term,
  right: Term,
  op: fn(Float, Float) -> Float,
  int_op: fn(Int, Int) -> Term,
) -> Result(Term, Nil) {
  case eval_term(left), eval_term(right) {
    Ok(Integer(a)), Ok(Integer(b)) -> Ok(int_op(a, b))
    _, _ ->
      case eval_to_float(left), eval_to_float(right) {
        Ok(a), Ok(b) -> number_from_float(op(a, b))
        _, _ -> Error(Nil)
      }
  }
}

fn eval_binary_float(
  left: Term,
  right: Term,
  op: fn(Float, Float) -> Float,
) -> Result(Term, Nil) {
  case eval_to_float(left), eval_to_float(right) {
    Ok(a), Ok(b) -> number_from_float(op(a, b))
    _, _ -> Error(Nil)
  }
}

pub fn eval_to_float(term: Term) -> Result(Float, Nil) {
  case eval_term(term) {
    Ok(Integer(value)) -> Ok(int.to_float(value))
    Ok(Float(value)) -> Ok(value)
    _ -> Error(Nil)
  }
}

pub fn eval_to_int(term: Term) -> Result(Int, Nil) {
  case eval_term(term) {
    Ok(Integer(value)) -> Ok(value)
    Ok(Float(value)) -> Ok(float_to_int(value))
    _ -> Error(Nil)
  }
}

fn number_from_float(value: Float) -> Result(Term, Nil) {
  let floor = float_floor(value)
  case value == floor {
    True -> Ok(Integer(float_to_int(floor)))
    False -> Ok(Float(value))
  }
}

@external(erlang, "erlang", "trunc")
fn float_to_int(value: Float) -> Int

@external(erlang, "erlang", "floor")
fn float_floor(value: Float) -> Float
