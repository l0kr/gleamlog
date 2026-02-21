import gleam/float
import gleam/int
import gleam/list
import gleam/string

pub type Token {
  AtomToken(String)
  VarToken(String)
  IntToken(Int)
  FloatToken(Float)
  StringToken(String)
  LParen
  RParen
  LBracket
  RBracket
  Dot
  Comma
  Pipe
  OperatorToken(String)
  Eof
}

pub type PositionedToken {
  PositionedToken(token: Token, line: Int, col: Int)
}

pub fn tokenize(source: String) -> Result(List(PositionedToken), String) {
  lex(string.to_graphemes(source), 1, 1, [])
}

fn lex(
  chars: List(String),
  line: Int,
  col: Int,
  acc: List(PositionedToken),
) -> Result(List(PositionedToken), String) {
  case chars {
    [] -> Ok(list.reverse([PositionedToken(Eof, line, col), ..acc]))
    [char, ..rest] -> {
      case is_whitespace(char) {
        True -> {
          let #(next_line, next_col) = advance(line, col, char)
          lex(rest, next_line, next_col, acc)
        }
        False ->
          case char {
            "%" -> {
              let #(line1, col1) = advance(line, col, "%")
              let #(rest1, line2, col2) =
                consume_line_comment(rest, line1, col1)
              lex(rest1, line2, col2, acc)
            }
            "/" ->
              case rest {
                ["*", ..comment_rest] -> {
                  let #(line1, col1) = advance(line, col, "/")
                  let #(line2, col2) = advance(line1, col1, "*")
                  case consume_block_comment(comment_rest, line2, col2) {
                    Ok(#(rest1, line3, col3)) -> lex(rest1, line3, col3, acc)
                    Error(message) -> Error(message)
                  }
                }
                _ -> lex_operator(chars, line, col, acc)
              }
            "(" ->
              lex(rest, line, col + 1, [
                PositionedToken(LParen, line, col),
                ..acc
              ])
            ")" ->
              lex(rest, line, col + 1, [
                PositionedToken(RParen, line, col),
                ..acc
              ])
            "[" ->
              lex(rest, line, col + 1, [
                PositionedToken(LBracket, line, col),
                ..acc
              ])
            "]" ->
              lex(rest, line, col + 1, [
                PositionedToken(RBracket, line, col),
                ..acc
              ])
            "," ->
              lex(rest, line, col + 1, [
                PositionedToken(Comma, line, col),
                ..acc
              ])
            "|" ->
              lex(rest, line, col + 1, [PositionedToken(Pipe, line, col), ..acc])
            "." ->
              lex(rest, line, col + 1, [PositionedToken(Dot, line, col), ..acc])
            "'" ->
              case read_quoted(rest, "'", [], 0) {
                Ok(#(value, rest1, consumed)) ->
                  lex(rest1, line, col + consumed + 1, [
                    PositionedToken(AtomToken(value), line, col),
                    ..acc
                  ])
                Error(message) -> Error(message)
              }
            "\"" ->
              case read_quoted(rest, "\"", [], 0) {
                Ok(#(value, rest1, consumed)) ->
                  lex(rest1, line, col + consumed + 1, [
                    PositionedToken(StringToken(value), line, col),
                    ..acc
                  ])
                Error(message) -> Error(message)
              }
            _ ->
              case is_digit(char) {
                True -> lex_number(char, rest, line, col, acc)
                False ->
                  case is_var_start(char) {
                    True -> lex_var(char, rest, line, col, acc)
                    False ->
                      case is_atom_start(char) {
                        True -> lex_atom(char, rest, line, col, acc)
                        False ->
                          case is_operator_char(char) {
                            True -> lex_operator(chars, line, col, acc)
                            False ->
                              Error(
                                "Unexpected character "
                                <> char
                                <> " at "
                                <> int.to_string(line)
                                <> ":"
                                <> int.to_string(col),
                              )
                          }
                      }
                  }
              }
          }
      }
    }
  }
}

fn lex_number(
  first: String,
  rest: List(String),
  line: Int,
  col: Int,
  acc: List(PositionedToken),
) -> Result(List(PositionedToken), String) {
  let #(digits, rest1, consumed_digits) = read_while(rest, is_digit, [first], 1)
  case rest1 {
    [".", next, ..rest2] ->
      case is_digit(next) {
        True -> {
          let #(frac, rest3, consumed_frac) =
            read_while(rest2, is_digit, [next], 1)
          let text = digits <> "." <> frac
          case float.parse(text) {
            Ok(value) ->
              lex(rest3, line, col + consumed_digits + consumed_frac + 1, [
                PositionedToken(FloatToken(value), line, col),
                ..acc
              ])
            Error(_) ->
              Error(
                "Invalid float "
                <> text
                <> " at "
                <> int.to_string(line)
                <> ":"
                <> int.to_string(col),
              )
          }
        }
        False ->
          case int.parse(digits) {
            Ok(value) ->
              lex(rest1, line, col + consumed_digits, [
                PositionedToken(IntToken(value), line, col),
                ..acc
              ])
            Error(_) ->
              Error(
                "Invalid integer "
                <> digits
                <> " at "
                <> int.to_string(line)
                <> ":"
                <> int.to_string(col),
              )
          }
      }
    _ ->
      case int.parse(digits) {
        Ok(value) ->
          lex(rest1, line, col + consumed_digits, [
            PositionedToken(IntToken(value), line, col),
            ..acc
          ])
        Error(_) ->
          Error(
            "Invalid integer "
            <> digits
            <> " at "
            <> int.to_string(line)
            <> ":"
            <> int.to_string(col),
          )
      }
  }
}

fn lex_atom(
  first: String,
  rest: List(String),
  line: Int,
  col: Int,
  acc: List(PositionedToken),
) -> Result(List(PositionedToken), String) {
  let #(name, rest1, consumed) = read_while(rest, is_ident_continue, [first], 1)
  case is_word_operator(name) {
    True ->
      lex(rest1, line, col + consumed, [
        PositionedToken(OperatorToken(name), line, col),
        ..acc
      ])
    False ->
      lex(rest1, line, col + consumed, [
        PositionedToken(AtomToken(name), line, col),
        ..acc
      ])
  }
}

fn lex_var(
  first: String,
  rest: List(String),
  line: Int,
  col: Int,
  acc: List(PositionedToken),
) -> Result(List(PositionedToken), String) {
  let #(name, rest1, consumed) = read_while(rest, is_ident_continue, [first], 1)
  lex(rest1, line, col + consumed, [
    PositionedToken(VarToken(name), line, col),
    ..acc
  ])
}

fn lex_operator(
  chars: List(String),
  line: Int,
  col: Int,
  acc: List(PositionedToken),
) -> Result(List(PositionedToken), String) {
  let #(op, rest, consumed) = read_while(chars, is_operator_char, [], 0)
  case op {
    "" ->
      Error(
        "Unexpected character at "
        <> int.to_string(line)
        <> ":"
        <> int.to_string(col),
      )
    _ ->
      lex(rest, line, col + consumed, [
        PositionedToken(OperatorToken(op), line, col),
        ..acc
      ])
  }
}

fn read_while(
  chars: List(String),
  predicate: fn(String) -> Bool,
  acc: List(String),
  consumed: Int,
) -> #(String, List(String), Int) {
  case chars {
    [char, ..rest] ->
      case predicate(char) {
        True -> read_while(rest, predicate, [char, ..acc], consumed + 1)
        False -> #(string.concat(list.reverse(acc)), chars, consumed)
      }
    _ -> #(string.concat(list.reverse(acc)), chars, consumed)
  }
}

fn read_quoted(
  chars: List(String),
  quote: String,
  acc: List(String),
  consumed: Int,
) -> Result(#(String, List(String), Int), String) {
  case chars {
    [] -> Error("Unterminated quoted string")
    [char, ..rest] ->
      case char == quote {
        True -> Ok(#(string.concat(list.reverse(acc)), rest, consumed + 1))
        False ->
          case char {
            "\\" ->
              case rest {
                [escaped, ..rest2] ->
                  read_quoted(rest2, quote, [escaped, ..acc], consumed + 2)
                [] -> Error("Unterminated escape sequence in quoted string")
              }
            "\n" -> Error("Newline inside quoted string")
            _ -> read_quoted(rest, quote, [char, ..acc], consumed + 1)
          }
      }
  }
}

fn consume_line_comment(
  chars: List(String),
  line: Int,
  col: Int,
) -> #(List(String), Int, Int) {
  case chars {
    [] -> #(chars, line, col)
    ["\n", ..rest] -> {
      let #(line1, col1) = advance(line, col, "\n")
      #(rest, line1, col1)
    }
    [char, ..rest] -> {
      let #(line1, col1) = advance(line, col, char)
      consume_line_comment(rest, line1, col1)
    }
  }
}

fn consume_block_comment(
  chars: List(String),
  line: Int,
  col: Int,
) -> Result(#(List(String), Int, Int), String) {
  case chars {
    [] -> Error("Unterminated block comment")
    ["*", "/", ..rest] -> {
      let #(line1, col1) = advance(line, col, "*")
      let #(line2, col2) = advance(line1, col1, "/")
      Ok(#(rest, line2, col2))
    }
    [char, ..rest] -> {
      let #(line1, col1) = advance(line, col, char)
      consume_block_comment(rest, line1, col1)
    }
  }
}

fn advance(line: Int, col: Int, char: String) -> #(Int, Int) {
  case char {
    "\n" -> #(line + 1, 1)
    _ -> #(line, col + 1)
  }
}

fn is_whitespace(char: String) -> Bool {
  list.contains([" ", "\t", "\n", "\r"], char)
}

fn is_digit(char: String) -> Bool {
  list.contains(["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"], char)
}

fn is_lower(char: String) -> Bool {
  list.contains(
    [
      "a",
      "b",
      "c",
      "d",
      "e",
      "f",
      "g",
      "h",
      "i",
      "j",
      "k",
      "l",
      "m",
      "n",
      "o",
      "p",
      "q",
      "r",
      "s",
      "t",
      "u",
      "v",
      "w",
      "x",
      "y",
      "z",
    ],
    char,
  )
}

fn is_upper(char: String) -> Bool {
  list.contains(
    [
      "A",
      "B",
      "C",
      "D",
      "E",
      "F",
      "G",
      "H",
      "I",
      "J",
      "K",
      "L",
      "M",
      "N",
      "O",
      "P",
      "Q",
      "R",
      "S",
      "T",
      "U",
      "V",
      "W",
      "X",
      "Y",
      "Z",
    ],
    char,
  )
}

fn is_atom_start(char: String) -> Bool {
  is_lower(char)
}

fn is_var_start(char: String) -> Bool {
  is_upper(char) || char == "_"
}

fn is_ident_continue(char: String) -> Bool {
  is_lower(char) || is_upper(char) || is_digit(char) || char == "_"
}

fn is_operator_char(char: String) -> Bool {
  list.contains(
    [
      ":",
      "-",
      ">",
      ";",
      "=",
      "\\",
      "+",
      "*",
      "/",
      "<",
      "@",
      "?",
      "!",
    ],
    char,
  )
}

fn is_word_operator(word: String) -> Bool {
  list.contains(["is", "rem", "mod"], word)
}
