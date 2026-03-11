function [Xnew, info] = repairPath(X, map, params)
%REPAIRPATH Constraint-aware local repair and smoothing refinement.

ctrlPts = decodeSolution(X, params);
info.nCollisionRepair = 0;
info.nSmoothRepair = 0;
info.nWindRepair = 0;

for rr = 1:params.repair.iter
    path = bsplinePath(ctrlPts, params.degree, params.nSamples);

    % ----- Collision / NFZ repair -----
    for m = 2:size(path, 1) - 1
        p = path(m, :);
        [isViol, dir, penDepth] = violationDirection(p, map);
        if isViol
            k = nearestInteriorControlPoint(p, ctrlPts);
            ctrlPts(k, :) = ctrlPts(k, :) + params.repair.chi * (penDepth + 0.5) * dir;
            ctrlPts(k, :) = boundPoint(ctrlPts(k, :), params);
            info.nCollisionRepair = info.nCollisionRepair + 1;
        end
    end

    % ----- Curvature repair -----
    path = bsplinePath(ctrlPts, params.degree, params.nSamples);
    seg = diff(path, 1, 1);
    [psi, idxBad] = turningAngles(seg, params.turnMax);
    if ~isempty(idxBad)
        for kk = 1:numel(idxBad)
            p = path(idxBad(kk) + 1, :);
            k = nearestInteriorControlPoint(p, ctrlPts);
            if k > 1 && k < size(ctrlPts, 1)
                ctrlPts(k, :) = ctrlPts(k, :) + params.repair.gamma * ...
                    ((ctrlPts(k - 1, :) + ctrlPts(k + 1, :)) / 2 - ctrlPts(k, :));
                ctrlPts(k, :) = boundPoint(ctrlPts(k, :), params);
                info.nSmoothRepair = info.nSmoothRepair + 1;
            end
        end
    end

    % ----- Wind-risk local offset -----
    path = bsplinePath(ctrlPts, params.degree, params.nSamples);
    risk = queryWindRisk(path, map);
    thr = mean(risk) + 0.75 * std(risk);
    idxRisk = find(risk > thr);
    for kk = 1:min(numel(idxRisk), 2)
        p = path(idxRisk(kk), :);
        k = nearestInteriorControlPoint(p, ctrlPts);
        grad = estimateRiskGradient(ctrlPts(k, :), map, params);
        if norm(grad) > 1e-9
            dir = -grad / (norm(grad) + 1e-9);
            ctrlPts(k, :) = ctrlPts(k, :) + params.repair.xi * dir;
            ctrlPts(k, :) = boundPoint(ctrlPts(k, :), params);
            info.nWindRepair = info.nWindRepair + 1;
        end
    end
end

Xnew = encodeControlPoints(ctrlPts);
Xnew = boundSolution(Xnew, params);
end

function [isViol, dir, penDepth] = violationDirection(p, map)
isViol = false;
dir = [0, 0, 0];
penDepth = 0;

for k = 1:size(map.obstacles, 1)
    box = map.obstacles(k, :);
    if inBox(p, box)
        isViol = true;
        center = [(box(1)+box(2))/2, (box(3)+box(4))/2, (box(5)+box(6))/2];
        d = p - center;
        if norm(d) < 1e-9, d = [1, 0.5, 0.1]; end
        dir = d / (norm(d) + 1e-9);
        dx = min(abs([p(1)-box(1), box(2)-p(1)]));
        dy = min(abs([p(2)-box(3), box(4)-p(2)]));
        dz = min(abs([p(3)-box(5), box(6)-p(3)]));
        penDepth = min([dx, dy, dz]);
        return;
    end
end

for k = 1:size(map.nfz, 1)
    cyl = map.nfz(k, :);
    if inCylinder(p, cyl)
        isViol = true;
        dxy = [p(1)-cyl(1), p(2)-cyl(2), 0];
        if norm(dxy) < 1e-9, dxy = [1, -1, 0]; end
        dir = dxy / (norm(dxy) + 1e-9);
        penDepth = max(0, cyl(3) - hypot(p(1)-cyl(1), p(2)-cyl(2)));
        return;
    end
end
end

function tf = inBox(p, box)
tf = p(1) >= box(1) && p(1) <= box(2) && ...
     p(2) >= box(3) && p(2) <= box(4) && ...
     p(3) >= box(5) && p(3) <= box(6);
end

function tf = inCylinder(p, cyl)
tf = hypot(p(1)-cyl(1), p(2)-cyl(2)) <= cyl(3) && ...
     p(3) >= cyl(4) && p(3) <= cyl(5);
end

function k = nearestInteriorControlPoint(p, ctrlPts)
inner = ctrlPts(2:end-1, :);
[~, idx] = min(sum((inner - p).^2, 2));
k = idx + 1;
end

function [psi, idxBad] = turningAngles(seg, turnMax)
if size(seg, 1) < 2
    psi = [];
    idxBad = [];
    return;
end
v1 = seg(1:end-1, :);
v2 = seg(2:end, :);
num = sum(v1 .* v2, 2);
den = sqrt(sum(v1.^2,2)) .* sqrt(sum(v2.^2,2)) + 1e-9;
psi = acos(max(min(num ./ den, 1), -1));
idxBad = find(psi > turnMax);
end

function grad = estimateRiskGradient(p, map, params)
h = 0.8;
grad = zeros(1, 3);
for d = 1:3
    e = zeros(1, 3);
    e(d) = 1;
    p1 = boundPoint(p + h * e, params);
    p2 = boundPoint(p - h * e, params);
    grad(d) = (queryWindRisk(p1, map) - queryWindRisk(p2, map)) / (2 * h);
end
end

function p = boundPoint(p, params)
p(1) = min(max(p(1), params.map.xlim(1)), params.map.xlim(2));
p(2) = min(max(p(2), params.map.ylim(1)), params.map.ylim(2));
p(3) = min(max(p(3), params.altMin), params.altMax);
end