import gleam/io
import gleam/list
import gleamlog
import gleamlog/cli/repl
import gleamlog/cli/runner

pub fn main() -> Nil {
  case args() {
    [] -> repl.start(gleamlog.new())
    [file_path] -> runner.run_file(file_path)
    ["-e", query] -> run_query(query)
    _ -> print_help()
  }
}

fn run_query(query: String) -> Nil {
  let solutions = gleamlog.query(gleamlog.new(), query)
  io.println("solutions: " <> int_to_string(list.length(solutions)))
}

fn print_help() -> Nil {
  io.println("gleamlog")
  io.println("gleamlog <file.pl>")
  io.println("gleamlog -e \"?- goal.\"")
}

@external(erlang, "init", "get_plain_arguments")
fn args() -> List(String)

@external(erlang, "erlang", "integer_to_binary")
fn int_to_string(value: Int) -> String
