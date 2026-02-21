import gleam/dict
import gleam/io
import gleam/list
import gleam/string
import gleamlog
import gleamlog/builtins/io as prolog_io
import gleamlog/types

pub fn start(engine: types.Engine) -> Nil {
  loop(engine)
}

fn loop(engine: types.Engine) -> Nil {
  case read_line("?- ") {
    Error(_) -> Nil
    Ok(input) -> {
      let input = string.trim(input)
      case input {
        "" -> loop(engine)
        "halt." | "halt" -> Nil
        _ ->
          case string.starts_with(input, "consult(") {
            True ->
              case consult_path(input) {
                Ok(path) -> {
                  let engine = load_file(engine, path)
                  loop(engine)
                }
                Error(_) -> {
                  io.println("invalid consult command")
                  loop(engine)
                }
              }
            False -> {
              let solutions = gleamlog.query(engine, input)
              print_solutions(solutions)
              loop(engine)
            }
          }
      }
    }
  }
}

fn print_solutions(solutions: List(types.Solution)) -> Nil {
  case solutions {
    [] -> io.println("false.")
    _ -> {
      list.each(solutions, fn(solution) { print_solution(solution) })
      io.println("true.")
    }
  }
}

fn print_solution(solution: types.Solution) -> Nil {
  let types.Solution(bindings: bindings) = solution
  let pairs = dict.to_list(bindings)
  case pairs {
    [] -> io.println("true")
    _ ->
      pairs
      |> list.map(fn(pair) {
        let #(name, value) = pair
        name <> " = " <> prolog_io.render(value)
      })
      |> string.join(", ")
      |> io.println
  }
}

fn consult_path(input: String) -> Result(String, Nil) {
  let input = string.trim(input)
  let input = case string.ends_with(input, ".") {
    True -> string.drop_end(input, 1)
    False -> input
  }
  let input = string.drop_start(input, 8)
  let input = string.drop_end(input, 1)
  let path = string.trim(input)
  case string.starts_with(path, "'") && string.ends_with(path, "'") {
    True -> Ok(path |> string.drop_start(1) |> string.drop_end(1))
    False -> Ok(path)
  }
}

fn load_file(engine: types.Engine, path: String) -> types.Engine {
  case read_file(path) {
    Ok(source) -> gleamlog.consult_string(engine, source)
    Error(_) -> {
      io.println("could not read file")
      engine
    }
  }
}

@external(erlang, "io", "get_line")
fn read_line(prompt: String) -> Result(String, Nil)

@external(erlang, "file", "read_file")
fn read_file(path: String) -> Result(String, Nil)
