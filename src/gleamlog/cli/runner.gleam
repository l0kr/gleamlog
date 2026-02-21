import gleam/io
import gleamlog
import gleamlog/cli/repl

pub fn run_file(path: String) -> Nil {
  case read_file(path) {
    Ok(source) -> {
      let engine = gleamlog.new() |> gleamlog.consult_string(source)
      repl.start(engine)
    }
    Error(_) -> io.println("could not read file")
  }
}

@external(erlang, "file", "read_file")
fn read_file(path: String) -> Result(String, Nil)
