parent(tom, bob).
parent(tom, liz).
parent(bob, ann).
parent(ann, sue).
parent(liz, pat).

grandparent(X, Z) :- parent(X, Y), parent(Y, Z).

ancestor(X, Y) :- parent(X, Y).
ancestor(X, Z) :- parent(X, Y), ancestor(Y, Z).
