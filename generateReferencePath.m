function refCtrl = generateReferencePath(map, params)
%GENERATEREFERENCEPATH Generate reference control points using 3D grid A*.
% This version is a more formalized corridor/path generator than the
% lightweight nudging version. It builds a coarse 3D occupancy/cost grid,
% runs A* from start to goal, and resamples the resulting path into
% B-spline reference control points.
%
% Output:
%   refCtrl : (params.nCtrl + 2) x 3 control point matrix
%
% Notes:
%   1) This is still self-contained and does not require extra toolboxes.
%   2) It is much closer to a "paper-ready" reference-path generator.
%   3) If A* fails, it falls back to a safe straight-line projection.

%% ---------- Grid settings ----------
gridResXY = 5;     % meters
gridResZ  = 4;     % meters

xv = map.xlim(1):gridResXY:map.xlim(2);
yv = map.ylim(1):gridResXY:map.ylim(2);
zv = params.altMin:gridResZ:params.altMax;

nx = numel(xv);
ny = numel(yv);
nz = numel(zv);

%% ---------- Build occupancy and traversal cost ----------
occ = false(nx, ny, nz);
extraCost = zeros(nx, ny, nz);

for ix = 1:nx
    for iy = 1:ny
        for iz = 1:nz
            p = [xv(ix), yv(iy), zv(iz)];

            % Occupancy: obstacle / NFZ
            if pointInAnyBox(p, map.obstacles) || pointInAnyCylinder(p, map.nfz)
                occ(ix, iy, iz) = true;
                extraCost(ix, iy, iz) = inf;
                continue;
            end

            % Traversal cost from wind risk + boundary proximity + altitude preference
            riskCost = queryWindRisk(p, map);

            % Mild boundary cost to discourage edge exploitation at reference-path stage
            boundaryCost = boundaryCostPoint(p, params);

            % Mild height preference toward cruise/reference layer
            heightCost = 0.03 * (p(3) - params.heightRef)^2;

            extraCost(ix, iy, iz) = 2.0 * riskCost + boundaryCost + heightCost;
        end
    end
end

%% ---------- Start/goal node ----------
startIdx = pointToGrid(params.start, xv, yv, zv);
goalIdx  = pointToGrid(params.goal,  xv, yv, zv);

startIdx = moveToNearestFree(startIdx, occ);
goalIdx  = moveToNearestFree(goalIdx, occ);

if isempty(startIdx) || isempty(goalIdx)
    warning('A* reference path: failed to place start/goal into free grid. Fallback used.');
    refCtrl = fallbackReference(map, params);
    return;
end

%% ---------- Run A* ----------
[pathIdx, success] = astar3D(startIdx, goalIdx, occ, extraCost, xv, yv, zv);

if ~success || size(pathIdx,1) < 2
    warning('A* reference path: search failed. Fallback used.');
    refCtrl = fallbackReference(map, params);
    return;
end

%% ---------- Convert grid path to metric path ----------
pathXYZ = zeros(size(pathIdx,1), 3);
for k = 1:size(pathIdx,1)
    pathXYZ(k,:) = [xv(pathIdx(k,1)), yv(pathIdx(k,2)), zv(pathIdx(k,3))];
end

% Ensure exact endpoints
pathXYZ(1,:)   = params.start;
pathXYZ(end,:) = params.goal;

%% ---------- Path simplification ----------
pathXYZ = simplifyPathByLOS(pathXYZ, map);

%% ---------- Resample to reference control points ----------
nFull = params.nCtrl + 2;
refCtrl = resamplePolyline(pathXYZ, nFull);

% Clamp and lightly project if needed
for i = 2:nFull-1
    refCtrl(i,:) = boundPoint(refCtrl(i,:), params);
    if pointInAnyBox(refCtrl(i,:), map.obstacles) || pointInAnyCylinder(refCtrl(i,:), map.nfz)
        refCtrl(i,:) = projectPointOut(refCtrl(i,:), map, params);
    end
end

refCtrl(1,:)   = params.start;
refCtrl(end,:) = params.goal;

end


%% ========================================================================
function idx = pointToGrid(p, xv, yv, zv)
[~, ix] = min(abs(xv - p(1)));
[~, iy] = min(abs(yv - p(2)));
[~, iz] = min(abs(zv - p(3)));
idx = [ix, iy, iz];
end

%% ========================================================================
function idxFree = moveToNearestFree(idx, occ)
% If idx is occupied, search nearest free neighbor by BFS shell expansion.

[nx, ny, nz] = size(occ);
if ~occ(idx(1), idx(2), idx(3))
    idxFree = idx;
    return;
end

maxR = max([nx, ny, nz]);
for r = 1:maxR
    ixRange = max(1, idx(1)-r):min(nx, idx(1)+r);
    iyRange = max(1, idx(2)-r):min(ny, idx(2)+r);
    izRange = max(1, idx(3)-r):min(nz, idx(3)+r);

    best = [];
    bestDist = inf;
    for ix = ixRange
        for iy = iyRange
            for iz = izRange
                if ~occ(ix,iy,iz)
                    d = norm([ix,iy,iz] - idx);
                    if d < bestDist
                        bestDist = d;
                        best = [ix,iy,iz];
                    end
                end
            end
        end
    end

    if ~isempty(best)
        idxFree = best;
        return;
    end
end

idxFree = [];
end

%% ========================================================================
function [pathIdx, success] = astar3D(startIdx, goalIdx, occ, extraCost, xv, yv, zv)
% 3D A* on regular grid.
% Node representation is linear index.

[nx, ny, nz] = size(occ);
numNodes = nx * ny * nz;

startLin = sub2ind([nx, ny, nz], startIdx(1), startIdx(2), startIdx(3));
goalLin  = sub2ind([nx, ny, nz], goalIdx(1),  goalIdx(2),  goalIdx(3));

gScore = inf(numNodes, 1);
fScore = inf(numNodes, 1);
cameFrom = zeros(numNodes, 1, 'uint32');
openSet = false(numNodes, 1);
closedSet = false(numNodes, 1);

gScore(startLin) = 0;
fScore(startLin) = heuristicCost(startIdx, goalIdx, xv, yv, zv);
openSet(startLin) = true;

% 26-neighborhood
nbr = [];
for dx = -1:1
    for dy = -1:1
        for dz = -1:1
            if dx == 0 && dy == 0 && dz == 0
                continue;
            end
            nbr = [nbr; dx dy dz]; %#ok<AGROW>
        end
    end
end

success = false;

while any(openSet)
    openIdx = find(openSet);
    [~, loc] = min(fScore(openIdx));
    currentLin = openIdx(loc);

    if currentLin == goalLin
        success = true;
        break;
    end

    openSet(currentLin) = false;
    closedSet(currentLin) = true;

    [cx, cy, cz] = ind2sub([nx, ny, nz], currentLin);
    cIdx = [cx, cy, cz];

    for kk = 1:size(nbr,1)
        nx2 = cx + nbr(kk,1);
        ny2 = cy + nbr(kk,2);
        nz2 = cz + nbr(kk,3);

        if nx2 < 1 || nx2 > nx || ny2 < 1 || ny2 > ny || nz2 < 1 || nz2 > nz
            continue;
        end
        if occ(nx2, ny2, nz2)
            continue;
        end

        nLin = sub2ind([nx, ny, nz], nx2, ny2, nz2);
        if closedSet(nLin)
            continue;
        end

        stepDist = metricDistance(cIdx, [nx2, ny2, nz2], xv, yv, zv);

        % Add node traversal cost
        tentativeG = gScore(currentLin) + stepDist + extraCost(nx2, ny2, nz2);

        if ~openSet(nLin)
            openSet(nLin) = true;
        elseif tentativeG >= gScore(nLin)
            continue;
        end

        cameFrom(nLin) = currentLin;
        gScore(nLin) = tentativeG;
        fScore(nLin) = tentativeG + heuristicCost([nx2, ny2, nz2], goalIdx, xv, yv, zv);
    end
end

if ~success
    pathIdx = [];
    return;
end

% Reconstruct
pathLin = goalLin;
while pathLin(1) ~= startLin
    prev = cameFrom(pathLin(1));
    if prev == 0
        success = false;
        pathIdx = [];
        return;
    end
    pathLin = [prev; pathLin]; %#ok<AGROW>
end

pathIdx = zeros(numel(pathLin), 3);
for i = 1:numel(pathLin)
    [ix, iy, iz] = ind2sub([nx, ny, nz], pathLin(i));
    pathIdx(i,:) = [ix, iy, iz];
end
end

%% ========================================================================
function h = heuristicCost(aIdx, bIdx, xv, yv, zv)
h = metricDistance(aIdx, bIdx, xv, yv, zv);
end

%% ========================================================================
function d = metricDistance(aIdx, bIdx, xv, yv, zv)
pa = [xv(aIdx(1)), yv(aIdx(2)), zv(aIdx(3))];
pb = [xv(bIdx(1)), yv(bIdx(2)), zv(bIdx(3))];
d = norm(pb - pa);
end

%% ========================================================================
function path2 = simplifyPathByLOS(path, map)
% Line-of-sight simplification: remove unnecessary intermediate nodes.

if size(path,1) <= 2
    path2 = path;
    return;
end

path2 = path(1,:);
i = 1;
while i < size(path,1)
    j = size(path,1);
    found = false;

    while j > i + 1
        if lineFree(path(i,:), path(j,:), map)
            path2 = [path2; path(j,:)]; %#ok<AGROW>
            i = j;
            found = true;
            break;
        end
        j = j - 1;
    end

    if ~found
        path2 = [path2; path(i+1,:)]; %#ok<AGROW>
        i = i + 1;
    end
end

% Remove duplicates if any
keep = true(size(path2,1),1);
for k = 2:size(path2,1)
    if norm(path2(k,:) - path2(k-1,:)) < 1e-9
        keep(k) = false;
    end
end
path2 = path2(keep,:);
end

%% ========================================================================
function tf = lineFree(p1, p2, map)
% Check segment against obstacles/NFZ using dense interpolation.

n = max(10, ceil(norm(p2 - p1) / 2));
tt = linspace(0, 1, n).';
pts = p1 + (p2 - p1) .* tt;

for k = 1:size(pts,1)
    p = pts(k,:);
    if pointInAnyBox(p, map.obstacles) || pointInAnyCylinder(p, map.nfz)
        tf = false;
        return;
    end
end
tf = true;
end

%% ========================================================================
function ctrl = resamplePolyline(path, nPts)
% Resample a polyline into nPts equally spaced points by arc length.

if size(path,1) == 1
    ctrl = repmat(path, nPts, 1);
    return;
end

seg = diff(path, 1, 1);
segLen = sqrt(sum(seg.^2, 2));
cumLen = [0; cumsum(segLen)];
totalLen = cumLen(end);

if totalLen < 1e-9
    ctrl = repmat(path(1,:), nPts, 1);
    return;
end

target = linspace(0, totalLen, nPts).';
ctrl = zeros(nPts, 3);

for i = 1:nPts
    s = target(i);
    idx = find(cumLen <= s, 1, 'last');

    if idx == numel(cumLen)
        ctrl(i,:) = path(end,:);
    else
        ds = cumLen(idx+1) - cumLen(idx);
        if ds < 1e-12
            ctrl(i,:) = path(idx,:);
        else
            tau = (s - cumLen(idx)) / ds;
            ctrl(i,:) = (1 - tau) * path(idx,:) + tau * path(idx+1,:);
        end
    end
end
end

%% ========================================================================
function tf = pointInAnyBox(p, obstacles)
tf = false;
for k = 1:size(obstacles, 1)
    box = obstacles(k,:);
    if p(1) >= box(1) && p(1) <= box(2) && ...
       p(2) >= box(3) && p(2) <= box(4) && ...
       p(3) >= box(5) && p(3) <= box(6)
        tf = true;
        return;
    end
end
end

%% ========================================================================
function tf = pointInAnyCylinder(p, nfz)
tf = false;
for k = 1:size(nfz, 1)
    c = nfz(k,:);
    if hypot(p(1)-c(1), p(2)-c(2)) <= c(3) && ...
       p(3) >= c(4) && p(3) <= c(5)
        tf = true;
        return;
    end
end
end

%% ========================================================================
function c = boundaryCostPoint(p, params)
mx = params.boundaryMargin;
my = params.boundaryMargin;

xmin = params.map.xlim(1);
xmax = params.map.xlim(2);
ymin = params.map.ylim(1);
ymax = params.map.ylim(2);

cx = 0;
cy = 0;

if p(1) < xmin + mx
    cx = 0.08 * (xmin + mx - p(1))^2;
elseif p(1) > xmax - mx
    cx = 0.08 * (p(1) - (xmax - mx))^2;
end

if p(2) < ymin + my
    cy = 0.08 * (ymin + my - p(2))^2;
elseif p(2) > ymax - my
    cy = 0.08 * (p(2) - (ymax - my))^2;
end

c = cx + cy;
end

%% ========================================================================
function p = boundPoint(p, params)
p(1) = min(max(p(1), params.map.xlim(1)), params.map.xlim(2));
p(2) = min(max(p(2), params.map.ylim(1)), params.map.ylim(2));
p(3) = min(max(p(3), params.altMin), params.altMax);
end

%% ========================================================================
function p = projectPointOut(p, map, params)
% Push a point out of obstacles / NFZ if needed.

for t = 1:25
    if ~pointInAnyBox(p, map.obstacles) && ~pointInAnyCylinder(p, map.nfz)
        return;
    end

    dir = [0,0,0];

    for k = 1:size(map.obstacles, 1)
        box = map.obstacles(k,:);
        if p(1) >= box(1) && p(1) <= box(2) && ...
           p(2) >= box(3) && p(2) <= box(4) && ...
           p(3) >= box(5) && p(3) <= box(6)
            center = [(box(1)+box(2))/2, (box(3)+box(4))/2, (box(5)+box(6))/2];
            d = p - center;
            if norm(d) < 1e-9, d = [1, 0.5, 0.2]; end
            dir = dir + d / (norm(d) + 1e-9);
        end
    end

    for k = 1:size(map.nfz, 1)
        c = map.nfz(k,:);
        if hypot(p(1)-c(1), p(2)-c(2)) <= c(3) && p(3) >= c(4) && p(3) <= c(5)
            d = [p(1)-c(1), p(2)-c(2), 0];
            if norm(d) < 1e-9, d = [1, -1, 0]; end
            dir = dir + d / (norm(d) + 1e-9);
        end
    end

    if norm(dir) < 1e-9
        dir = [0.5, 1.0, 0.0];
    end

    p = p + 1.5 * dir / (norm(dir) + 1e-9);
    p = boundPoint(p, params);
end
end

%% ========================================================================
function refCtrl = fallbackReference(map, params)
% Fallback if A* fails.

nFull = params.nCtrl + 2;
refCtrl = zeros(nFull, 3);

for i = 1:nFull
    tau = (i - 1) / (nFull - 1);
    p = (1 - tau) * params.start + tau * params.goal;
    p(3) = (1 - tau) * params.start(3) + tau * params.goal(3);

    if pointInAnyBox(p, map.obstacles) || pointInAnyCylinder(p, map.nfz)
        p = projectPointOut(p, map, params);
    end
    refCtrl(i,:) = p;
end

refCtrl(1,:) = params.start;
refCtrl(end,:) = params.goal;
end