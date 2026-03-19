function export_uav_scene_views(sceneIds, outDir, varargin)
%EXPORT_UAV_SCENE_VIEWS Export 3D and top-view figures for UAV scenes.
%
% 用途：
%   1) 只导出每个场景的纯场景图（无路径）
%   2) 可选叠加一条 path / ctrlPts
%
% 基于你仓库现有接口：
%   - defaultParams()
%   - createMap(params)
%   - plotSceneOnly(map, params)
%
% 用法示例：
%   % 只导出 Scene 1/2/4 的场景图
%   export_uav_scene_views([1 2 4], 'scene_figures');
%
%   % 导出全部 4 个场景
%   export_uav_scene_views([], 'scene_figures');
%
%   % 给某个场景叠加路径
%   P = [5 5 12; 20 20 14; 40 50 16; 70 80 15; 95 95 18];
%   C = [5 5 12; 25 18 13; 55 48 17; 80 78 16; 95 95 18];
%   export_uav_scene_views(1, 'scene_figures', 'path', P, 'ctrlPts', C);
%
% 参数：
%   sceneIds : 场景编号向量，例如 [1 2 4]
%              若为空，则默认输出 [1 2 3 4]
%   outDir   : 输出目录
%
% Name-Value 参数：
%   'path'         : N x 3 路径点，可选
%   'ctrlPts'      : M x 3 控制点，可选
%   'saveFig'      : 是否保存 .fig，默认 true
%   'savePng'      : 是否保存 .png，默认 true
%   'visible'      : 'on' 或 'off'，默认 'off'
%   'scene4LowAlt' : 是否对 Scene 4 采用低空走廊增强版参数，默认 true
%
% 输出文件：
%   scene1_3d.png / scene1_top.png / scene1_3d.fig / scene1_top.fig
%   scene2_...
%
% 作者建议：
%   - 论文“场景示意图”直接用这个脚本的纯地图输出
%   - 论文“最优航迹图”继续用你仓库已有 plot_uav_best_paths_exact.m

    if nargin < 1 || isempty(sceneIds)
        sceneIds = [1 2 3 4];
    end
    if nargin < 2 || isempty(outDir)
        outDir = fullfile(pwd, 'scene_figures');
    end

    % -----------------------------
    % Parse inputs
    % -----------------------------
    ip = inputParser;
    ip.addParameter('path', [], @(x) isempty(x) || (isnumeric(x) && size(x,2)==3));
    ip.addParameter('ctrlPts', [], @(x) isempty(x) || (isnumeric(x) && size(x,2)==3));
    ip.addParameter('saveFig', true, @(x) islogical(x) || isnumeric(x));
    ip.addParameter('savePng', true, @(x) islogical(x) || isnumeric(x));
    ip.addParameter('visible', 'off', @(x) ischar(x) || isstring(x));
    ip.addParameter('scene4LowAlt', true, @(x) islogical(x) || isnumeric(x));
    ip.parse(varargin{:});

    pathIn         = ip.Results.path;
    ctrlPtsIn      = ip.Results.ctrlPts;
    saveFigFlag    = logical(ip.Results.saveFig);
    savePngFlag    = logical(ip.Results.savePng);
    visibleMode    = char(ip.Results.visible);
    useScene4LowAlt = logical(ip.Results.scene4LowAlt);

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    fprintf('\n=== Export UAV Scene Views ===\n');
    fprintf('Output folder: %s\n', outDir);

    for i = 1:numel(sceneIds)
        sceneId = sceneIds(i);

        % -----------------------------
        % Build params and map
        % -----------------------------
        params = defaultParams();
        params.sceneId = sceneId;

        % Scene 4：按你现在 formal 的低空物流走廊设定做最小增强
        if sceneId == 4 && useScene4LowAlt
            params.altMin = 8;
            params.altMax = 26;
            params.heightRef = 14;
            params.weights.H = 1.20;

            params.lbSingle(3) = params.altMin;
            params.ubSingle(3) = params.altMax;
            params.lb = repmat(params.lbSingle, 1, params.nCtrl);
            params.ub = repmat(params.ubSingle, 1, params.nCtrl);
        end

        map = createMap(params);

        % -----------------------------
        % 3D figure
        % -----------------------------
        params3d = params;
        params3d.figView = [-37.5, 30];

        fig3d = figure( ...
            'Visible', visibleMode, ...
            'Color', 'w', ...
            'Position', [100 100 1200 850]);

        plotSceneOnly(map, params3d);
        hold on;

        if ~isempty(pathIn)
            plot3(pathIn(:,1), pathIn(:,2), pathIn(:,3), ...
                'b-', 'LineWidth', 2.4);
        end

        if ~isempty(ctrlPtsIn)
            plot3(ctrlPtsIn(:,1), ctrlPtsIn(:,2), ctrlPtsIn(:,3), ...
                'k--o', 'LineWidth', 1.0, 'MarkerSize', 4);
        end

        title(localTitle(sceneId, false, ~isempty(pathIn)), 'Interpreter', 'none');

        if savePngFlag
            exportgraphics(fig3d, fullfile(outDir, sprintf('scene%d_3d.png', sceneId)), ...
                'Resolution', 300);
        end
        if saveFigFlag
            savefig(fig3d, fullfile(outDir, sprintf('scene%d_3d.fig', sceneId)));
        end
        close(fig3d);

        % -----------------------------
        % Top-view figure
        % -----------------------------
        paramsTop = params;
        paramsTop.figView = [0, 90];

        figTop = figure( ...
            'Visible', visibleMode, ...
            'Color', 'w', ...
            'Position', [120 120 1200 850]);

        plotSceneOnly(map, paramsTop);
        view(2);
        axis equal;
        hold on;

        if ~isempty(pathIn)
            plot3(pathIn(:,1), pathIn(:,2), pathIn(:,3), ...
                'b-', 'LineWidth', 2.4);
        end

        if ~isempty(ctrlPtsIn)
            plot3(ctrlPtsIn(:,1), ctrlPtsIn(:,2), ctrlPtsIn(:,3), ...
                'k--o', 'LineWidth', 1.0, 'MarkerSize', 4);
        end

        title(localTitle(sceneId, true, ~isempty(pathIn)), 'Interpreter', 'none');

        if savePngFlag
            exportgraphics(figTop, fullfile(outDir, sprintf('scene%d_top.png', sceneId)), ...
                'Resolution', 300);
        end
        if saveFigFlag
            savefig(figTop, fullfile(outDir, sprintf('scene%d_top.fig', sceneId)));
        end
        close(figTop);

        fprintf('Scene %d done.\n', sceneId);
    end

    fprintf('All figures saved to:\n%s\n', outDir);
end

% ========================================================================
function ttl = localTitle(sceneId, isTop, hasPath)
    if hasPath
        if isTop
            ttl = sprintf('Scene %d - Top View', sceneId);
        else
            ttl = sprintf('Scene %d - 3D View', sceneId);
        end
    else
        if isTop
            ttl = sprintf('Scene %d - Environment Top View', sceneId);
        else
            ttl = sprintf('Scene %d - Environment 3D View', sceneId);
        end
    end
end