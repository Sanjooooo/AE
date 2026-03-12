function plotSceneOnly(map, params)
%PLOTSCENEONLY Plot only the scene map without planned path.
% Supports both 3D view and top view. In top view, NFZ circles are explicitly drawn.

hold on; grid on; view(params.figView);
xlim(map.xlim); ylim(map.ylim); zlim(map.zlim);
xlabel('X / m'); ylabel('Y / m'); zlabel('Z / m');

isTopView = false;
[az, el] = view;
if abs(az) < 1e-6 && abs(el - 90) < 1e-6
    isTopView = true;
end

% ---------- Obstacles ----------
for k = 1:size(map.obstacles, 1)
    drawBoxLocal(map.obstacles(k, :), [0.85 0.33 0.10], 0.25);
end

% ---------- NFZ ----------
for k = 1:size(map.nfz, 1)
    if ~isTopView
        drawCylinderLocal(map.nfz(k, :), [0.93 0.69 0.13], 0.20);
    else
        drawNFZTopCircle(map.nfz(k, :), [0.93 0.69 0.13], 1.8);
    end
end

% ---------- Wind hotspots ----------
if isfield(map, 'windHotspots') && ~isempty(map.windHotspots)
    hs = map.windHotspots;
    scatter3(hs(:,1), hs(:,2), hs(:,3), 45, ...
        'filled', 'MarkerFaceColor', [0.2 0.45 0.9], ...
        'MarkerEdgeColor', [0.2 0.45 0.9]);
end

% ---------- Start / Goal ----------
plot3(params.start(1), params.start(2), params.start(3), ...
    'gs', 'MarkerSize', 10, 'LineWidth', 2);
plot3(params.goal(1), params.goal(2), params.goal(3), ...
    'rp', 'MarkerSize', 11, 'LineWidth', 2);

% ---------- Manual legend handles ----------
hObs  = patch(nan, nan, [0.85 0.33 0.10], 'FaceAlpha', 0.25, 'EdgeColor', [0.85 0.33 0.10]);
hNFZ  = plot3(nan, nan, nan, '-', 'Color', [0.93 0.69 0.13], 'LineWidth', 1.8);
hWind = scatter3(nan, nan, nan, 45, 'filled', 'MarkerFaceColor', [0.2 0.45 0.9], 'MarkerEdgeColor', [0.2 0.45 0.9]);
hStart = plot3(nan, nan, nan, 'gs', 'MarkerSize', 10, 'LineWidth', 2);
hGoal  = plot3(nan, nan, nan, 'rp', 'MarkerSize', 11, 'LineWidth', 2);

legend([hObs, hNFZ, hWind, hStart, hGoal], ...
    {'Obstacles', 'NFZ', 'Wind hotspots', 'Start', 'Goal'}, ...
    'Location', 'northeastoutside');
end

function drawBoxLocal(box, faceColor, faceAlpha)
[x, y, z] = ndgrid([box(1), box(2)], [box(3), box(4)], [box(5), box(6)]);
verts = [x(:), y(:), z(:)];
faces = [1 3 4 2; 5 6 8 7; 1 2 6 5; 3 7 8 4; 1 5 7 3; 2 4 8 6];
patch('Vertices', verts, 'Faces', faces, ...
      'FaceColor', faceColor, 'FaceAlpha', faceAlpha, 'EdgeColor', faceColor);
end

function drawCylinderLocal(cyl, faceColor, faceAlpha)
[xx, yy, zz] = cylinder(cyl(3), 50);
zz = zz * (cyl(5) - cyl(4)) + cyl(4);
xx = xx + cyl(1);
yy = yy + cyl(2);
surf(xx, yy, zz, ...
    'FaceColor', faceColor, 'FaceAlpha', faceAlpha, 'EdgeColor', 'none');

% top rim
th = linspace(0, 2*pi, 200);
xt = cyl(1) + cyl(3)*cos(th);
yt = cyl(2) + cyl(3)*sin(th);
zt = cyl(5) * ones(size(th));
plot3(xt, yt, zt, '-', 'Color', faceColor, 'LineWidth', 1.2);
end

function drawNFZTopCircle(cyl, colorVal, lw)
th = linspace(0, 2*pi, 300);
x = cyl(1) + cyl(3)*cos(th);
y = cyl(2) + cyl(3)*sin(th);
z = zeros(size(th));
plot3(x, y, z, '-', 'Color', colorVal, 'LineWidth', lw);
end