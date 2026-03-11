function risk = queryWindRisk(points, map)
%QUERYWINDRISK Query wind-risk density at 3D points.
% points: N x 3

if isempty(points)
    risk = [];
    return;
end

n = size(points, 1);
risk = 0.08 * ones(n, 1);  % base risk

hs = map.windHotspots;
for k = 1:size(hs, 1)
    c = hs(k, 1:3);
    sigma = hs(k, 4);
    amp = hs(k, 5);
    d2 = sum((points - c).^2, 2);
    risk = risk + amp * exp(-d2 ./ (2 * sigma^2));
end

% Mild height modulation around the middle flight layer
risk = risk .* (1 + 0.015 * abs(points(:, 3) - 22));
end