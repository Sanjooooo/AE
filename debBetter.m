function tf = debBetter(f1, d1, f2, d2)
%DEBBETTER Deb's feasibility rules.
% Returns true if solution 1 is better than solution 2.

if d1.isFeasible && ~d2.isFeasible
    tf = true;
elseif ~d1.isFeasible && d2.isFeasible
    tf = false;
elseif d1.isFeasible && d2.isFeasible
    tf = f1 < f2;
else
    if d1.V == d2.V
        tf = f1 < f2;
    else
        tf = d1.V < d2.V;
    end
end
end