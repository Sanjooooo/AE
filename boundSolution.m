function X = boundSolution(X, params)
%BOUNDSOLUTION Clamp solution vector to box bounds.

X = min(max(X, params.lb), params.ub);
end