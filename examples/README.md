# GleamLog Examples

These files are small Prolog programs you can load in the GleamLog REPL.

Try:

- `consult('examples/family.pl').`
- `consult('examples/lists.pl').`
- `consult('examples/arithmetic.pl').`
- `consult('examples/control.pl').`
- `consult('examples/types.pl').`
- `examples/demo.gleam` for a Gleam embedding example
- `src/demo.gleam` is the runnable module used by `gleam run -m demo`

Run the Gleam demo:

- `cd gleamlog`
- `gleam run -m demo`

Example queries:

- `?- grandparent(tom, X).`
- `?- ancestor(tom, X).`
- `?- member(X, [a, b, c]).`
- `?- append([1,2], [3,4], X).`
- `?- factorial(5, X).`
- `?- max(10, 7, M).`
- `?- classify(8, Label).`
- `?- type_demo(X).`
