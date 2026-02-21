# gleamlog

[![Package Version](https://img.shields.io/hexpm/v/gleamlog)](https://hex.pm/packages/gleamlog)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gleamlog/)

GleamLog is a Prolog interpreter written in Gleam for the BEAM runtime.
It supports Prolog terms, unification with occurs check, parsing of clauses and
queries, depth-first SLD resolution with backtracking, and a growing set of
built-in predicates for control flow, comparison, type testing, and arithmetic.
The project can be embedded from Gleam code or used through the CLI/REPL.

```sh
gleam add gleamlog@1
```
```gleam
import gleamlog

pub fn main() -> Nil {
  let engine =
    gleamlog.new()
    |> gleamlog.consult_string("
      parent(tom, bob).
      parent(tom, liz).
      grandparent(X, Z) :- parent(X, Y), parent(Y, Z).
    ")

  let solutions = gleamlog.query(engine, "?- grandparent(tom, X).")
  let _ = solutions
}
```

Further documentation can be found at <https://hexdocs.pm/gleamlog>.

## Examples

```sh
cd gleamlog
gleam run -m demo
```

Prolog example programs are in `examples/`.

## Development

```sh
gleam run
gleam test
```
