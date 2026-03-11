function path = bsplinePath(ctrlPts, degree, nSamples)
%BSPLINEPATH Evaluate an open-uniform B-spline path.
% No toolbox dependency.

nCtrl = size(ctrlPts, 1);
U = openUniformKnot(nCtrl, degree);
uv = linspace(0, 1, nSamples);
path = zeros(nSamples, size(ctrlPts, 2));

for m = 1:nSamples
    u = uv(m);
    if m == nSamples
        u = 1;  % ensure endpoint is reached
    end
    for i = 1:nCtrl
        Ni = bsplineBasis(i, degree, u, U, nCtrl);
        path(m, :) = path(m, :) + Ni * ctrlPts(i, :);
    end
end
path(end, :) = ctrlPts(end, :);
end

function U = openUniformKnot(nCtrl, p)
% Knot vector length = nCtrl + p + 1
m = nCtrl + p;
U = zeros(1, m + 1);
for j = 0:m
    if j <= p
        U(j + 1) = 0;
    elseif j >= m - p
        U(j + 1) = 1;
    else
        U(j + 1) = (j - p) / (m - 2 * p);
    end
end
end

function N = bsplineBasis(i, p, u, U, nCtrl)
if p == 0
    if (U(i) <= u && u < U(i + 1)) || (u == 1 && i == nCtrl)
        N = 1;
    else
        N = 0;
    end
    return;
end

leftDen = U(i + p) - U(i);
rightDen = U(i + p + 1) - U(i + 1);

leftTerm = 0;
rightTerm = 0;

if leftDen > 0
    leftTerm = ((u - U(i)) / leftDen) * bsplineBasis(i, p - 1, u, U, nCtrl);
end
if rightDen > 0
    rightTerm = ((U(i + p + 1) - u) / rightDen) * bsplineBasis(i + 1, p - 1, u, U, nCtrl);
end

N = leftTerm + rightTerm;
end