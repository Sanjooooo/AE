function previewSceneMap(sceneId)
%PREVIEWSCENEMAP Preview a scene map in 3D and top view.
%
% Usage:
%   previewSceneMap
%   previewSceneMap(1)
%   previewSceneMap(2)
%   previewSceneMap(3)
%   previewSceneMap(4)

if nargin < 1
    sceneId = 1;
end

params = defaultParams();
params.sceneId = sceneId;
map = createMap(params);

% 3D view
figure('Color', 'w');
plotSceneOnly(map, params);
title(sprintf('Scene %d - 3D View', sceneId));

% Top view
figure('Color', 'w');
view(2);
plotSceneOnly(map, params);
view(2);
axis equal;
title(sprintf('Scene %d - Top View', sceneId));
end