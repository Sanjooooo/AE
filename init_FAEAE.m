function [pop, fit, detail] = init_FAEAE(params, map, refCtrl)
%INIT_FAEAE Feasibility-guided corridor initialization.

N = params.popSize;
pop = zeros(N, params.dim);
fit = inf(N, 1);
detail = repmat(emptyDetailStruct(), N, 1);

for j = 1:N
    ctrl = refCtrl;
    for i = 2:size(refCtrl, 1) - 1
        qRef = refCtrl(i, :);
        safeDist = estimateLocalClearance(qRef, map, params);
        rho = queryWindRisk(qRef, map);
        r = params.init.eta * safeDist / (1 + params.init.kappa * rho);
        r = max(r, params.init.minRadius);

        q = qRef;
        found = false;
        rr = r;
        for tt = 1:params.init.maxTrial
            cand = qRef + (2 * rand(1, 3) - 1) * rr;
            cand = boundPoint(cand, params);
            if isPointFeasible(cand, map, params)
                q = cand;
                found = true;
                break;
            end
            rr = 0.65 * rr;
        end

        if ~found
            q = projectPointToFree(qRef, map, params);
        end
        ctrl(i, :) = q;
    end

    X = encodeControlPoints(ctrl);
    X = boundSolution(X, params);
    [X, ~] = repairPath(X, map, params);

    pop(j, :) = X;
    [fit(j), detail(j)] = fitnessFAEAE(X, map, params);
end
end

function d = estimateLocalClearance(p, map, params)
% Simple local clearance estimator: distance to nearest obstacle/NFZ surface.
vals = [];
for k = 1:size(map.obstacles, 1)
    box = map.obstacles(k, :);
    dx = max([box(1)-p(1), 0, p(1)-box(2)]);
    dy = max([box(3)-p(2), 0, p(2)-box(4)]);
    dz = max([box(5)-p(3), 0, p(3)-box(6)]);
    vals(end+1) = sqrt(dx^2 + dy^2 + dz^2); %#ok<AGROW>
end
for k = 1:size(map.nfz, 1)
    c = map.nfz(k, :);
    dxy = abs(hypot(p(1)-c(1), p(2)-c(2)) - c(3));
    dz = max([c(4)-p(3), 0, p(3)-c(5)]);
    vals(end+1) = sqrt(dxy^2 + dz^2); %#ok<AGROW>
end
vals(end+1) = min([p(1)-params.map.xlim(1), params.map.xlim(2)-p(1), ...
                   p(2)-params.map.ylim(1), params.map.ylim(2)-p(2), ...
                   p(3)-params.altMin, params.altMax-p(3)]);
d = max(min(vals), 1.0);
end

function tf = isPointFeasible(p, map, params)
tf = true;
for k = 1:size(map.obstacles, 1)
    box = map.obstacles(k, :);
    if p(1) >= box(1) && p(1) <= box(2) && ...
       p(2) >= box(3) && p(2) <= box(4) && ...
       p(3) >= box(5) && p(3) <= box(6)
        tf = false;
        return;
    end
end
for k = 1:size(map.nfz, 1)
    c = map.nfz(k, :);
    if hypot(p(1)-c(1), p(2)-c(2)) <= c(3) && p(3) >= c(4) && p(3) <= c(5)
        tf = false;
        return;
    end
end
if p(3) < params.altMin || p(3) > params.altMax
    tf = false;
end
end

function p = projectPointToFree(p, map, params)
for t = 1:20
    if isPointFeasible(p, map, params), return; end
    grad = [0, 0, 0];
    for k = 1:size(map.obstacles, 1)
        box = map.obstacles(k, :);
        center = [(box(1)+box(2))/2, (box(3)+box(4))/2, (box(5)+box(6))/2];
        if p(1) >= box(1) && p(1) <= box(2) && p(2) >= box(3) && p(2) <= box(4) && p(3) >= box(5) && p(3) <= box(6)
            d = p - center;
            if norm(d) < 1e-9, d = [1, 0.5, 0.2]; end
            grad = grad + d / (norm(d) + 1e-9);
        end
    end
    for k = 1:size(map.nfz, 1)
        c = map.nfz(k, :);
        if hypot(p(1)-c(1), p(2)-c(2)) <= c(3) && p(3) >= c(4) && p(3) <= c(5)
            d = [p(1)-c(1), p(2)-c(2), 0];
            if norm(d) < 1e-9, d = [1, -1, 0]; end
            grad = grad + d / (norm(d) + 1e-9);
        end
    end
    if norm(grad) < 1e-9, grad = [0.5, 1, 0]; end
    p = p + 1.5 * grad / (norm(grad) + 1e-9);
    p = boundPoint(p, params);
end
end

function p = boundPoint(p, params)
p(1) = min(max(p(1), params.map.xlim(1)), params.map.xlim(2));
p(2) = min(max(p(2), params.map.ylim(1)), params.map.ylim(2));
p(3) = min(max(p(3), params.altMin), params.altMax);
end

function s = emptyDetailStruct()
s = struct('J', inf, ...
           'L', inf, ...
           'E', inf, ...
           'R', inf, ...
           'S', inf, ...
           'H', inf, ...
           'B', inf, ...
           'Cobs', inf, ...
           'Cnfz', inf, ...
           'Ccurv', inf, ...
           'Calt', inf, ...
           'V', inf, ...
           'isFeasible', false, ...
           'obsIdx', [], ...
           'nfzIdx', []);
end