member(X, [X | _]).
member(X, [_ | T]) :- member(X, T).

append([], Ys, Ys).
append([X | Xs], Ys, [X | Zs]) :- append(Xs, Ys, Zs).

length([], 0).
length([_ | T], N) :- length(T, N0), N is N0 + 1.

reverse([], []).
reverse([H | T], R) :- reverse(T, RT), append(RT, [H], R).
