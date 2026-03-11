function refCtrl = generateReferencePath(map, params)
%GENERATEREFERENCEPATH Build a coarse reference control-point chain.
% This is a lightweight deterministic initializer, not a full A*/Theta*.
% You can replace it later with a true graph-search corridor.

nFull = params.nCtrl + 2;
refCtrl = zeros(nFull, 3);

for i = 1:nFull
    tau = (i - 1) / (nFull - 1);
    p = (1 - tau) * params.start + tau * params.goal;

    if tau <= 0.2
        zRef = params.start(3) + (params.refCruiseZ - params.start(3)) * (tau / 0.2);
    elseif tau >= 0.8
        zRef = params.refCruiseZ + (params.goal(3) - params.refCruiseZ) * ((tau - 0.8) / 0.2);
    else
        zRef = params.refCruiseZ;
    end
    p(3) = zRef;
    refCtrl(i, :) = nudgePointToFreeSpace(p, map, params);
end

refCtrl(1, :)   = params.start;
refCtrl(end, :) = params.goal;
end

function p = nudgePointToFreeSpace(p, map, params)
maxIter = 25;
step = 2.5;
for t = 1:maxIter
    if isPointFeasible(p, map, params)
        return;
    end
    dir = [0, 0, 0];

    % Push away from box centers
    for k = 1:size(map.obstacles, 1)
        box = map.obstacles(k, :);
        if pointInBox(p, box)
            center = [(box(1)+box(2))/2, (box(3)+box(4))/2, (box(5)+box(6))/2];
            d = p - center;
            if norm(d) < 1e-9, d = [1, 1, 0.3]; end
            dir = dir + d / (norm(d) + 1e-9);
        end
    end

    % Push away from NFZ centers
    for k = 1:size(map.nfz, 1)
        c = map.nfz(k, :);
        if pointInCylinder(p, c)
            d = [p(1)-c(1), p(2)-c(2), 0];
            if norm(d) < 1e-9, d = [1, -1, 0]; end
            dir = dir + d / (norm(d) + 1e-9);
        end
    end

    if norm(dir) < 1e-9
        dir = [0, 1, 0.1];
    end
    p = p + step * dir / (norm(dir) + 1e-9);
    p = boundPoint(p, params);
end
end

function tf = isPointFeasible(p, map, params)
tf = true;
for k = 1:size(map.obstacles, 1)
    if pointInBox(p, map.obstacles(k, :))
        tf = false;
        return;
    end
end
for k = 1:size(map.nfz, 1)
    if pointInCylinder(p, map.nfz(k, :))
        tf = false;
        return;
    end
end
if p(3) < params.altMin || p(3) > params.altMax
    tf = false;
end
end

function tf = pointInBox(p, box)
tf = p(1) >= box(1) && p(1) <= box(2) && ...
     p(2) >= box(3) && p(2) <= box(4) && ...
     p(3) >= box(5) && p(3) <= box(6);
end

function tf = pointInCylinder(p, cyl)
rxy = hypot(p(1)-cyl(1), p(2)-cyl(2));
tf = (rxy <= cyl(3)) && (p(3) >= cyl(4)) && (p(3) <= cyl(5));
end

function p = boundPoint(p, params)
p(1) = min(max(p(1), params.map.xlim(1)), params.map.xlim(2));
p(2) = min(max(p(2), params.map.ylim(1)), params.map.ylim(2));
p(3) = min(max(p(3), params.altMin), params.altMax);
end