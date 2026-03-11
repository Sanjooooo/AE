function plotSceneAndPath(map, path, ctrlPts, params)
%PLOTSCENEANDPATH Visualize environment and planned path.

figure('Color', 'w'); hold on; grid on; view(params.figView);
xlim(map.xlim); ylim(map.ylim); zlim(map.zlim);
xlabel('X / m'); ylabel('Y / m'); zlabel('Z / m');
title('FAE-AE Planned 3D UAV Path');

% Obstacles
for k = 1:size(map.obstacles, 1)
    drawBox(map.obstacles(k, :), [0.85 0.33 0.10], 0.25);
end

% NFZ cylinders
for k = 1:size(map.nfz, 1)
    drawCylinder(map.nfz(k, :), [0.93 0.69 0.13], 0.18);
end

% Path and control points
plot3(path(:,1), path(:,2), path(:,3), 'b-', 'LineWidth', 2.0);
plot3(ctrlPts(:,1), ctrlPts(:,2), ctrlPts(:,3), 'ko--', 'LineWidth', 1.0, 'MarkerSize', 5);
plot3(params.start(1), params.start(2), params.start(3), 'gs', 'MarkerSize', 10, 'LineWidth', 2);
plot3(params.goal(1), params.goal(2), params.goal(3), 'rp', 'MarkerSize', 11, 'LineWidth', 2);
legend({'Obstacles', 'NFZ', 'Best path', 'Control points', 'Start', 'Goal'}, 'Location', 'northeastoutside');
end

function drawBox(box, faceColor, faceAlpha)
[x, y, z] = ndgrid([box(1), box(2)], [box(3), box(4)], [box(5), box(6)]);
verts = [x(:), y(:), z(:)];
faces = [1 3 4 2; 5 6 8 7; 1 2 6 5; 3 7 8 4; 1 5 7 3; 2 4 8 6];
patch('Vertices', verts, 'Faces', faces, 'FaceColor', faceColor, 'FaceAlpha', faceAlpha, 'EdgeColor', faceColor);
end

function drawCylinder(cyl, faceColor, faceAlpha)
[xx, yy, zz] = cylinder(cyl(3), 40);
zz = zz * (cyl(5) - cyl(4)) + cyl(4);
xx = xx + cyl(1);
yy = yy + cyl(2);
surf(xx, yy, zz, 'FaceColor', faceColor, 'FaceAlpha', faceAlpha, 'EdgeColor', 'none');
end