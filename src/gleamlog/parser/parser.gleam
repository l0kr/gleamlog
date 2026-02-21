import gleam/dict
import gleam/list
import gleam/string
import gleamlog/parser/tokenizer
import gleamlog/types.{
  type Clause, type Term, Atom, Clause, Compound, Cons, Fact, Float, Integer,
  PrologNil, Var,
}

type PositionedToken =
  tokenizer.PositionedToken

pub type ParseError {
  ParseError(message: String, line: Int, col: Int)
}

type ParseContext {
  ParseContext(vars: dict.Dict(String, Int), next_id: Int)
}

pub fn parse_program(source: String) -> Result(List(Clause), ParseError) {
  case tokenizer.tokenize(source) {
    Ok(tokens) -> parse_clauses(tokens, [])
    Error(message) -> Error(ParseError(message, 1, 1))
  }
}

pub fn parse_term(source: String) -> Result(Term, ParseError) {
  case tokenizer.tokenize(source) {
    Ok(tokens) -> {
      let ctx = ParseContext(dict.new(), 0)
      case parse_term_with_comma(tokens, ctx) {
        Ok(#(term, rest, _)) -> expect_eof(rest, term)
        Error(error) -> Error(error)
      }
    }
    Error(message) -> Error(ParseError(message, 1, 1))
  }
}

pub fn parse_query(source: String) -> Result(List(Term), ParseError) {
  let trimmed = string.trim(source)
  let source = case string.starts_with(trimmed, "?-") {
    True -> string.trim(string.drop_start(trimmed, 2))
    False -> trimmed
  }
  let source = case string.ends_with(source, ".") {
    True -> string.drop_end(source, 1)
    False -> source
  }
  case parse_term(source) {
    Ok(term) -> Ok(flatten_conjunction(term))
    Error(error) -> Error(error)
  }
}

fn parse_clauses(
  tokens: List(PositionedToken),
  acc: List(Clause),
) -> Result(List(Clause), ParseError) {
  case tokens {
    [tokenizer.PositionedToken(tokenizer.Eof, _, _)] -> Ok(list.reverse(acc))
    _ ->
      case parse_clause(tokens) {
        Ok(#(clause, rest)) -> parse_clauses(rest, [clause, ..acc])
        Error(error) -> Error(error)
      }
  }
}

fn parse_clause(
  tokens: List(PositionedToken),
) -> Result(#(Clause, List(PositionedToken)), ParseError) {
  let ctx = ParseContext(dict.new(), 0)
  case parse_term_no_comma(tokens, ctx) {
    Ok(#(head, rest, ctx1)) ->
      case rest {
        [tokenizer.PositionedToken(tokenizer.Dot, _, _), ..rest1] ->
          Ok(#(Fact(head), rest1))
        [
          tokenizer.PositionedToken(tokenizer.OperatorToken(":-"), _, _),
          ..rest1
        ] ->
          case parse_term_with_comma(rest1, ctx1) {
            Ok(#(body, rest2, _)) ->
              case rest2 {
                [tokenizer.PositionedToken(tokenizer.Dot, _, _), ..rest3] ->
                  Ok(#(Clause(head, flatten_conjunction(body)), rest3))
                _ -> Error(error_here("Expected '.' after clause body", rest2))
              }
            Error(error) -> Error(error)
          }
        _ -> Error(error_here("Expected '.' or ':-' after clause head", rest))
      }
    Error(error) -> Error(error)
  }
}

fn expect_eof(
  tokens: List(PositionedToken),
  term: Term,
) -> Result(Term, ParseError) {
  case tokens {
    [tokenizer.PositionedToken(tokenizer.Eof, _, _)] -> Ok(term)
    _ -> Error(error_here("Unexpected tokens after term", tokens))
  }
}

fn parse_term_with_comma(
  tokens: List(PositionedToken),
  ctx: ParseContext,
) -> Result(#(Term, List(PositionedToken), ParseContext), ParseError) {
  parse_semicolon(tokens, ctx)
}

fn parse_term_no_comma(
  tokens: List(PositionedToken),
  ctx: ParseContext,
) -> Result(#(Term, List(PositionedToken), ParseContext), ParseError) {
  parse_comparison(tokens, ctx)
}

fn parse_semicolon(
  tokens: List(PositionedToken),
  ctx: ParseContext,
) -> Result(#(Term, List(PositionedToken), ParseContext), ParseError) {
  case parse_arrow(tokens, ctx) {
    Ok(#(left, rest, ctx1)) ->
      case rest {
        [tokenizer.PositionedToken(tokenizer.OperatorToken(";"), _, _), ..rest1] ->
          case parse_semicolon(rest1, ctx1) {
            Ok(#(right, rest2, ctx2)) ->
              Ok(#(Compound(";", [left, right]), rest2, ctx2))
            Error(error) -> Error(error)
          }
        _ -> Ok(#(left, rest, ctx1))
      }
    Error(error) -> Error(error)
  }
}

fn parse_arrow(
  tokens: List(PositionedToken),
  ctx: ParseContext,
) -> Result(#(Term, List(PositionedToken), ParseContext), ParseError) {
  case parse_comma(tokens, ctx) {
    Ok(#(left, rest, ctx1)) ->
      case rest {
        [
          tokenizer.PositionedToken(tokenizer.OperatorToken("->"), _, _),
          ..rest1
        ] ->
          case parse_arrow(rest1, ctx1) {
            Ok(#(right, rest2, ctx2)) ->
              Ok(#(Compound("->", [left, right]), rest2, ctx2))
            Error(error) -> Error(error)
          }
        _ -> Ok(#(left, rest, ctx1))
      }
    Error(error) -> Error(error)
  }
}

fn parse_comma(
  tokens: List(PositionedToken),
  ctx: ParseContext,
) -> Result(#(Term, List(PositionedToken), ParseContext), ParseError) {
  case parse_comparison(tokens, ctx) {
    Ok(#(left, rest, ctx1)) ->
      case rest {
        [tokenizer.PositionedToken(tokenizer.Comma, _, _), ..rest1] ->
          case parse_comma(rest1, ctx1) {
            Ok(#(right, rest2, ctx2)) ->
              Ok(#(Compound(",", [left, right]), rest2, ctx2))
            Error(error) -> Error(error)
          }
        [tokenizer.PositionedToken(tokenizer.OperatorToken(","), _, _), ..rest1] ->
          case parse_comma(rest1, ctx1) {
            Ok(#(right, rest2, ctx2)) ->
              Ok(#(Compound(",", [left, right]), rest2, ctx2))
            Error(error) -> Error(error)
          }
        _ -> Ok(#(left, rest, ctx1))
      }
    Error(error) -> Error(error)
  }
}

fn parse_comparison(
  tokens: List(PositionedToken),
  ctx: ParseContext,
) -> Result(#(Term, List(PositionedToken), ParseContext), ParseError) {
  case parse_add(tokens, ctx) {
    Ok(#(left, rest, ctx1)) ->
      case rest {
        [tokenizer.PositionedToken(tokenizer.OperatorToken(op), _, _), ..rest1] ->
          case is_comparison_op(op) {
            True ->
              case parse_add(rest1, ctx1) {
                Ok(#(right, rest2, ctx2)) ->
                  Ok(#(Compound(op, [left, right]), rest2, ctx2))
                Error(error) -> Error(error)
              }
            False -> Ok(#(left, rest, ctx1))
          }
        _ -> Ok(#(left, rest, ctx1))
      }
    Error(error) -> Error(error)
  }
}

fn parse_add(
  tokens: List(PositionedToken),
  ctx: ParseContext,
) -> Result(#(Term, List(PositionedToken), ParseContext), ParseError) {
  case parse_mul(tokens, ctx) {
    Ok(#(left, rest, ctx1)) -> parse_add_tail(left, rest, ctx1)
    Error(error) -> Error(error)
  }
}

fn parse_add_tail(
  left: Term,
  tokens: List(PositionedToken),
  ctx: ParseContext,
) -> Result(#(Term, List(PositionedToken), ParseContext), ParseError) {
  case tokens {
    [tokenizer.PositionedToken(tokenizer.OperatorToken(op), _, _), ..rest] ->
      case is_add_op(op) {
        True ->
          case parse_mul(rest, ctx) {
            Ok(#(right, rest1, ctx1)) ->
              parse_add_tail(Compound(op, [left, right]), rest1, ctx1)
            Error(error) -> Error(error)
          }
        False -> Ok(#(left, tokens, ctx))
      }
    _ -> Ok(#(left, tokens, ctx))
  }
}

fn parse_mul(
  tokens: List(PositionedToken),
  ctx: ParseContext,
) -> Result(#(Term, List(PositionedToken), ParseContext), ParseError) {
  case parse_pow(tokens, ctx) {
    Ok(#(left, rest, ctx1)) -> parse_mul_tail(left, rest, ctx1)
    Error(error) -> Error(error)
  }
}

fn parse_mul_tail(
  left: Term,
  tokens: List(PositionedToken),
  ctx: ParseContext,
) -> Result(#(Term, List(PositionedToken), ParseContext), ParseError) {
  case tokens {
    [tokenizer.PositionedToken(tokenizer.OperatorToken(op), _, _), ..rest] ->
      case is_mul_op(op) {
        True ->
          case parse_pow(rest, ctx) {
            Ok(#(right, rest1, ctx1)) ->
              parse_mul_tail(Compound(op, [left, right]), rest1, ctx1)
            Error(error) -> Error(error)
          }
        False -> Ok(#(left, tokens, ctx))
      }
    _ -> Ok(#(left, tokens, ctx))
  }
}

fn parse_pow(
  tokens: List(PositionedToken),
  ctx: ParseContext,
) -> Result(#(Term, List(PositionedToken), ParseContext), ParseError) {
  case parse_prefix(tokens, ctx) {
    Ok(#(left, rest, ctx1)) ->
      case rest {
        [
          tokenizer.PositionedToken(tokenizer.OperatorToken("**"), _, _),
          ..rest1
        ] ->
          case parse_prefix(rest1, ctx1) {
            Ok(#(right, rest2, ctx2)) ->
              Ok(#(Compound("**", [left, right]), rest2, ctx2))
            Error(error) -> Error(error)
          }
        _ -> Ok(#(left, rest, ctx1))
      }
    Error(error) -> Error(error)
  }
}

fn parse_prefix(
  tokens: List(PositionedToken),
  ctx: ParseContext,
) -> Result(#(Term, List(PositionedToken), ParseContext), ParseError) {
  case tokens {
    [tokenizer.PositionedToken(tokenizer.OperatorToken("\\+"), _, _), ..rest] ->
      case parse_prefix(rest, ctx) {
        Ok(#(term, rest1, ctx1)) -> Ok(#(Compound("\\+", [term]), rest1, ctx1))
        Error(error) -> Error(error)
      }
    [tokenizer.PositionedToken(tokenizer.OperatorToken("-"), _, _), ..rest] ->
      case parse_prefix(rest, ctx) {
        Ok(#(term, rest1, ctx1)) -> Ok(#(Compound("-", [term]), rest1, ctx1))
        Error(error) -> Error(error)
      }
    [tokenizer.PositionedToken(tokenizer.OperatorToken("\\"), _, _), ..rest] ->
      case parse_prefix(rest, ctx) {
        Ok(#(term, rest1, ctx1)) -> Ok(#(Compound("\\", [term]), rest1, ctx1))
        Error(error) -> Error(error)
      }
    _ -> parse_primary(tokens, ctx)
  }
}

fn parse_primary(
  tokens: List(PositionedToken),
  ctx: ParseContext,
) -> Result(#(Term, List(PositionedToken), ParseContext), ParseError) {
  case tokens {
    [tokenizer.PositionedToken(tokenizer.VarToken(name), _, _), ..rest] -> {
      let #(var, ctx1) = var_for(name, ctx)
      Ok(#(var, rest, ctx1))
    }
    [tokenizer.PositionedToken(tokenizer.AtomToken(name), _, _), ..rest] ->
      case rest {
        [tokenizer.PositionedToken(tokenizer.LParen, _, _), ..rest1] ->
          case parse_args(rest1, ctx) {
            Ok(#(args, rest2, ctx1)) ->
              case rest2 {
                [tokenizer.PositionedToken(tokenizer.RParen, _, _), ..rest3] ->
                  Ok(#(Compound(name, args), rest3, ctx1))
                _ -> Error(error_here("Expected ')' after arguments", rest2))
              }
            Error(error) -> Error(error)
          }
        _ -> Ok(#(Atom(name), rest, ctx))
      }
    [tokenizer.PositionedToken(tokenizer.IntToken(value), _, _), ..rest] ->
      Ok(#(Integer(value), rest, ctx))
    [tokenizer.PositionedToken(tokenizer.FloatToken(value), _, _), ..rest] ->
      Ok(#(Float(value), rest, ctx))
    [tokenizer.PositionedToken(tokenizer.StringToken(value), _, _), ..rest] ->
      Ok(#(Atom(value), rest, ctx))
    [tokenizer.PositionedToken(tokenizer.OperatorToken("!"), _, _), ..rest] ->
      Ok(#(Atom("!"), rest, ctx))
    [tokenizer.PositionedToken(tokenizer.LParen, _, _), ..rest] ->
      case parse_term_with_comma(rest, ctx) {
        Ok(#(term, rest1, ctx1)) ->
          case rest1 {
            [tokenizer.PositionedToken(tokenizer.RParen, _, _), ..rest2] ->
              Ok(#(term, rest2, ctx1))
            _ ->
              Error(error_here("Expected ')' after parenthesized term", rest1))
          }
        Error(error) -> Error(error)
      }
    [tokenizer.PositionedToken(tokenizer.LBracket, _, _), ..rest] ->
      parse_list(rest, ctx)
    _ -> Error(error_here("Unexpected token", tokens))
  }
}

fn parse_args(
  tokens: List(PositionedToken),
  ctx: ParseContext,
) -> Result(#(List(Term), List(PositionedToken), ParseContext), ParseError) {
  case tokens {
    [tokenizer.PositionedToken(tokenizer.RParen, _, _), ..] ->
      Ok(#([], tokens, ctx))
    _ ->
      case parse_term_no_comma(tokens, ctx) {
        Ok(#(arg, rest, ctx1)) -> parse_args_tail([arg], rest, ctx1)
        Error(error) -> Error(error)
      }
  }
}

fn parse_args_tail(
  acc: List(Term),
  tokens: List(PositionedToken),
  ctx: ParseContext,
) -> Result(#(List(Term), List(PositionedToken), ParseContext), ParseError) {
  case tokens {
    [tokenizer.PositionedToken(tokenizer.Comma, _, _), ..rest] ->
      case parse_term_no_comma(rest, ctx) {
        Ok(#(arg, rest1, ctx1)) -> parse_args_tail([arg, ..acc], rest1, ctx1)
        Error(error) -> Error(error)
      }
    _ -> Ok(#(list.reverse(acc), tokens, ctx))
  }
}

fn parse_list(
  tokens: List(PositionedToken),
  ctx: ParseContext,
) -> Result(#(Term, List(PositionedToken), ParseContext), ParseError) {
  case tokens {
    [tokenizer.PositionedToken(tokenizer.RBracket, _, _), ..rest] ->
      Ok(#(PrologNil, rest, ctx))
    _ ->
      case parse_term_no_comma(tokens, ctx) {
        Ok(#(head, rest, ctx1)) -> parse_list_tail([head], rest, ctx1)
        Error(error) -> Error(error)
      }
  }
}

fn parse_list_tail(
  acc: List(Term),
  tokens: List(PositionedToken),
  ctx: ParseContext,
) -> Result(#(Term, List(PositionedToken), ParseContext), ParseError) {
  case tokens {
    [tokenizer.PositionedToken(tokenizer.Comma, _, _), ..rest] ->
      case parse_term_no_comma(rest, ctx) {
        Ok(#(term, rest1, ctx1)) -> parse_list_tail([term, ..acc], rest1, ctx1)
        Error(error) -> Error(error)
      }
    [tokenizer.PositionedToken(tokenizer.Pipe, _, _), ..rest] ->
      case parse_term_no_comma(rest, ctx) {
        Ok(#(tail, rest1, ctx1)) ->
          case rest1 {
            [tokenizer.PositionedToken(tokenizer.RBracket, _, _), ..rest2] ->
              Ok(#(build_list(list.reverse(acc), tail), rest2, ctx1))
            _ -> Error(error_here("Expected ']' after list tail", rest1))
          }
        Error(error) -> Error(error)
      }
    [tokenizer.PositionedToken(tokenizer.RBracket, _, _), ..rest] ->
      Ok(#(build_list(list.reverse(acc), PrologNil), rest, ctx))
    _ -> Error(error_here("Expected ',', '|' or ']'", tokens))
  }
}

fn build_list(items: List(Term), tail: Term) -> Term {
  case items {
    [] -> tail
    [first, ..rest] -> Cons(first, build_list(rest, tail))
  }
}

fn flatten_conjunction(term: Term) -> List(Term) {
  case term {
    Compound(",", [left, right]) ->
      list.append(flatten_conjunction(left), flatten_conjunction(right))
    _ -> [term]
  }
}

fn var_for(name: String, ctx: ParseContext) -> #(Term, ParseContext) {
  case ctx, name {
    ParseContext(vars, next_id), "_" -> #(
      Var(name, next_id),
      ParseContext(vars, next_id + 1),
    )
    ParseContext(vars, next_id), _ ->
      case dict.get(vars, name) {
        Ok(id) -> #(Var(name, id), ctx)
        Error(_) -> {
          let vars1 = dict.insert(vars, name, next_id)
          #(Var(name, next_id), ParseContext(vars1, next_id + 1))
        }
      }
  }
}

fn is_comparison_op(op: String) -> Bool {
  list.contains(
    [
      "=",
      "\\=",
      "==",
      "\\==",
      "is",
      "=:=",
      "=\\=",
      "<",
      ">",
      "=<",
      ">=",
      "@<",
      "@>",
      "@=<",
      "@>=",
    ],
    op,
  )
}

fn is_add_op(op: String) -> Bool {
  list.contains(["+", "-", "/\\", "\\/"], op)
}

fn is_mul_op(op: String) -> Bool {
  list.contains(["*", "/", "//", "rem", "mod"], op)
}

fn error_here(message: String, tokens: List(PositionedToken)) -> ParseError {
  case tokens {
    [tokenizer.PositionedToken(_, line, col), ..] ->
      ParseError(message, line, col)
    [] -> ParseError(message, 0, 0)
  }
}
