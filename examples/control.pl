max(X, Y, X) :- X >= Y, !.
max(_, Y, Y).

classify(N, positive) :- N > 0 -> true ; fail.
classify(0, zero).
classify(N, negative) :- N < 0.

pick(a).
pick(b).
pick_once(X) :- once(pick(X)).

not_equal(X, Y) :- \+ (X = Y).
