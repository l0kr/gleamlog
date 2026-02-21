type_demo(X) :- var(X), X = hello.
type_demo(X) :- atom(X), nonvar(X).
type_demo(X) :- integer(X), number(X), atomic(X).
type_demo(X) :- float(X), number(X), atomic(X).
type_demo(X) :- compound(X), nonvar(X).
type_demo(X) :- is_list(X), nonvar(X).
