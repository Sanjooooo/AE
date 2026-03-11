function params = defaultParams()
%DEFAULTPARAMS Parameter settings for FAE-AE UAV path planning.
% MATLAB version: R2022b

params.seed = 42;

% ---------- Optimization ----------
params.popSize  = 30;
params.maxIter  = 300;
params.nCtrl    = 6;              % number of interior control points
params.dim      = 3 * params.nCtrl;
params.degree   = 3;              % cubic B-spline
params.nSamples = 120;            % sampled points on the path

% ---------- Scene ----------
params.start = [5, 5, 12];
params.goal  = [95, 95, 18];

% 低空巡航参考高度
params.refCruiseZ = 16;

params.map.xlim = [0, 100];
params.map.ylim = [0, 100];
params.map.zlim = [0, 45];

params.lbSingle = [params.map.xlim(1), params.map.ylim(1), 8];
params.ubSingle = [params.map.xlim(2), params.map.ylim(2), 40];
params.lb = repmat(params.lbSingle, 1, params.nCtrl);
params.ub = repmat(params.ubSingle, 1, params.nCtrl);

% ---------- Objective weights ----------
params.weights.L = 1.00;
params.weights.E = 0.60;
params.weights.R = 1.20;
params.weights.S = 0.15;
params.weights.H = 0.80;   % 高度保持项
params.weights.B = 0.80;   % 边界惩罚项

% ---------- Reference / preference ----------
params.heightRef = 16;     % 期望巡航高度
params.boundaryMargin = 12; % 距边界多少米内开始惩罚

% ---------- Penalties ----------
params.penalty.obs  = 150;
params.penalty.nfz  = 200;
params.penalty.curv = 20;
params.penalty.alt  = 30;

% ---------- Energy model ----------
params.energy.a1 = 1.0;
params.energy.a2 = 0.4;
params.energy.a3 = 0.8;

% ---------- Feasibility / kinematics ----------
params.turnMax = deg2rad(55);     % max turning angle between adjacent segments
params.altMin  = 8;
params.altMax  = 40;

% ---------- Initialization ----------
params.init.eta       = 0.45;
params.init.kappa     = 1.80;
params.init.maxTrial  = 8;
params.init.minRadius = 1.0;

% ---------- Repair ----------
params.repair.chi   = 1.15;   % collision penetration scaling
params.repair.gamma = 0.35;   % smoothing factor
params.repair.xi    = 1.00;   % wind-risk lateral shift
params.repair.iter  = 2;      % repair rounds per offspring

% ---------- AOS / UCB ----------
params.aos.nOps   = 3;
params.aos.c      = 0.90;
params.aos.eps    = 1e-9;
params.aos.betaJ  = 1.0;
params.aos.betaV  = 0.8;
params.aos.betaR  = 0.6;

% ---------- Core search coefficients ----------
params.core.alpha1    = 0.45;
params.core.alpha2    = 0.25;
params.core.alpha3    = 0.12;
params.core.eliteFrac = 0.25;

% ---------- Regeneration ----------
params.regen.window = 18;
params.regen.epsF   = 1e-4;
params.regen.epsH   = 0.07;
params.regen.epsPi  = 0.25;
params.regen.tau    = 2;
params.regen.ratio  = 0.25;
params.regen.eliteK = 3;
params.regen.sigma  = 0.08;

% ---------- Visualization ----------
params.figView = [40, 28];
end