function windVec = queryWindField(points, map)
%QUERYWINDFIELD Simplified 3D wind field.
% points: N x 3

if isempty(points)
    windVec = [];
    return;
end

n = size(points, 1);
windVec = repmat(map.baseWind, n, 1);

hs = map.windHotspots;
for k = 1:size(hs, 1)
    c = hs(k, 1:3);
    sigma = hs(k, 4);
    amp = hs(k, 5);
    rel = points - c;
    swirl = [-rel(:,2), rel(:,1), zeros(n,1)];
    scale = amp * exp(-sum(rel.^2, 2) ./ (2 * sigma^2));
    normSwirl = sqrt(sum(swirl.^2, 2)) + 1e-9;
    swirl = swirl ./ normSwirl;
    windVec = windVec + swirl .* scale;
end
end