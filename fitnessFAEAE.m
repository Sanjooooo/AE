function [fit, detail] = fitnessFAEAE(X, map, params)
%FITNESSFAEAE Objective + constraint evaluation for a candidate path.

ctrlPts = decodeSolution(X, params);
path = bsplinePath(ctrlPts, params.degree, params.nSamples);

seg = diff(path, 1, 1);
segLen = sqrt(sum(seg.^2, 2)) + 1e-9;
L = sum(segLen);

% ---------- Energy ----------
windVec = queryWindField(path(1:end-1, :), map);
windMag = sqrt(sum(windVec.^2, 2));
segDir = seg ./ segLen;
windDir = windVec ./ (windMag + 1e-9);
cosTheta = sum(segDir .* windDir, 2);
cosTheta = max(min(cosTheta, 1), -1);
Phi = windMag .* (1 - cosTheta);

E = sum(params.energy.a1 * segLen + ...
        params.energy.a2 * abs(seg(:, 3)) + ...
        params.energy.a3 * Phi);

% ---------- Wind risk ----------
risk = queryWindRisk(path, map);
R = sum(risk(1:end-1) .* segLen);

% ---------- Smoothness ----------
dd = path(3:end, :) - 2 * path(2:end-1, :) + path(1:end-2, :);
S = sum(sum(dd.^2, 2));

% ---------- Height-holding term ----------
H = sum((path(:, 3) - params.heightRef).^2);

% ---------- NEW: Boundary-avoidance term ----------
B = boundaryPenalty(path, params);

% ---------- Constraint violations ----------
[Cobs, obsIdx] = obstacleViolation(path, map.obstacles);
[Cnfz, nfzIdx] = nfzViolation(path, map.nfz);
Ccurv = curvatureViolation(seg, params.turnMax);
Calt = altitudeViolation(path, params.altMin, params.altMax);

P = params.penalty.obs  * Cobs + ...
    params.penalty.nfz  * Cnfz + ...
    params.penalty.curv * Ccurv + ...
    params.penalty.alt  * Calt;

% ---------- Total objective ----------
fit = params.weights.L * L + ...
      params.weights.E * E + ...
      params.weights.R * R + ...
      params.weights.S * S + ...
      params.weights.H * H + ...
      params.weights.B * B + ...
      P;

detail.J = fit;
detail.L = L;
detail.E = E;
detail.R = R;
detail.S = S;
detail.H = H;
detail.B = B;
detail.Cobs = Cobs;
detail.Cnfz = Cnfz;
detail.Ccurv = Ccurv;
detail.Calt = Calt;
detail.V = Cobs + Cnfz + Ccurv + Calt;
detail.isFeasible = (detail.V <= 1e-10);
detail.obsIdx = obsIdx;
detail.nfzIdx = nfzIdx;
end

function B = boundaryPenalty(path, params)
mx = params.boundaryMargin;
my = params.boundaryMargin;

xmin = params.map.xlim(1);
xmax = params.map.xlim(2);
ymin = params.map.ylim(1);
ymax = params.map.ylim(2);

px = zeros(size(path,1),1);
py = zeros(size(path,1),1);

% x-direction penalty
idx1 = path(:,1) < xmin + mx;
px(idx1) = (xmin + mx - path(idx1,1)).^2;

idx2 = path(:,1) > xmax - mx;
px(idx2) = (path(idx2,1) - (xmax - mx)).^2;

% y-direction penalty
idy1 = path(:,2) < ymin + my;
py(idy1) = (ymin + my - path(idy1,2)).^2;

idy2 = path(:,2) > ymax - my;
py(idy2) = (path(idy2,2) - (ymax - my)).^2;

B = sum(px + py);
end

function [count, idx] = obstacleViolation(path, obstacles)
inMask = false(size(path,1),1);
for k = 1:size(obstacles,1)
    box = obstacles(k,:);
    inBox = path(:,1) >= box(1) & path(:,1) <= box(2) & ...
            path(:,2) >= box(3) & path(:,2) <= box(4) & ...
            path(:,3) >= box(5) & path(:,3) <= box(6);
    inMask = inMask | inBox;
end
idx = find(inMask);
count = sum(inMask);
end

function [count, idx] = nfzViolation(path, nfz)
inMask = false(size(path,1),1);
for k = 1:size(nfz,1)
    c = nfz(k,:);
    rxy = hypot(path(:,1)-c(1), path(:,2)-c(2));
    inCyl = (rxy <= c(3)) & (path(:,3) >= c(4)) & (path(:,3) <= c(5));
    inMask = inMask | inCyl;
end
idx = find(inMask);
count = sum(inMask);
end

function c = curvatureViolation(seg, turnMax)
if size(seg,1) < 2
    c = 0;
    return;
end
v1 = seg(1:end-1, :);
v2 = seg(2:end, :);
num = sum(v1 .* v2, 2);
den = sqrt(sum(v1.^2,2)) .* sqrt(sum(v2.^2,2)) + 1e-9;
cosang = max(min(num ./ den, 1), -1);
psi = acos(cosang);
c = sum(max(0, psi - turnMax));
end

function c = altitudeViolation(path, zmin, zmax)
c = sum(max(0, zmin - path(:,3)) + max(0, path(:,3) - zmax));
end