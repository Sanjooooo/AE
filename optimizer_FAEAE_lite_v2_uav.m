function result = optimizer_FAEAE_lite_v2_uav(objFun, params, map, refX, algCfg, runSeed)
%OPTIMIZER_FAEAE_LITE_V2_UAV
% More aggressive but still task-consistent lightweight FAEAE for UAV path planning.
%
% Main changes relative to lite-v1:
% 1) AOS is active only in the early/mid stage, then frozen.
% 2) Repair is staged and low-frequency; only near-feasible elite-side candidates are repaired.
% 3) Regeneration is stricter: confirmed stagnation only, worst infeasible only, and no immediate full repair.
%
% This version is designed to cut Scene-4/Scene-3 runtime further without directly reducing popSize/maxIter.

if nargin >= 6 && ~isempty(runSeed)
    rng(runSeed, 'twister');
end

params = localWriteFlags(params, algCfg);
params = localDefaultLiteV2Params(params);
if isfield(algCfg, 'lite') && isstruct(algCfg.lite)
    params.lite = localMergeStruct(params.lite, algCfg.lite);
end

if isfield(algCfg, 'popSize'), params.popSize = algCfg.popSize; end
if isfield(algCfg, 'maxIter'), params.maxIter = algCfg.maxIter; end

if isempty(refX)
    refCtrl = localSimpleReferencePath(params);
    refX = encodeControlPoints(refCtrl);
else
    try
        decodeSolution(refX, params); %#ok<VUNUS>
    catch
        refCtrl = localSimpleReferencePath(params);
        refX = encodeControlPoints(refCtrl);
    end
end

% Keep initialization unchanged for fair-init compatibility.
if params.useInit
    refCtrl0 = decodeSolution(refX, params);
    [pop, fit, detail] = init_FAEAE(params, map, refCtrl0);
else
    refCtrl0 = decodeSolution(refX, params);
    [pop, fit, detail] = init_baseline_AE(params, map, refCtrl0);
end

aos = initAOS(params);
bestHist = inf(params.maxIter, 1);

[bestFit, bestX, bestDetail] = localExtractBest(pop, fit, detail);

nEvals = numel(fit);
lastRegenIter = -inf;
consecutiveStagnation = 0;
freezeIter = max(1, ceil(params.lite.aosFreezeFrac * params.maxIter));

tStart = tic;

for t = 1:params.maxIter
    [~, order] = sort(fit, 'ascend');
    eliteNum = max(2, ceil(params.core.eliteFrac * params.popSize));
    elitePool = pop(order(1:eliteNum), :);
    eliteMean = mean(elitePool, 1);

    repairQuota = max(1, round(params.lite.repairEliteFrac * params.popSize));
    repairSet = order(1:repairQuota);

    for i = 1:params.popSize
        fold = fit(i);
        dold = detail(i);

        if params.useAOS
            opIdx = localSelectOperator(aos, t, freezeIter, params);
        else
            opIdx = 2;
        end

        xElite = elitePool(randi(eliteNum), :);
        Xnew = applyOperator_FAEAE_lite_v2(i, pop, bestX, refX, eliteMean, xElite, opIdx, t, params);

        [fnew, dnew] = objFun(Xnew);
        nEvals = nEvals + 1;

        if params.useRepair && localNeedFullRepair(i, repairSet, dnew, t, params)
            repParams = params;
            repParams.repair.iter = params.lite.repairIters;
            [Xrep, ~] = repairPath(Xnew, map, repParams);
            [frep, drep] = objFun(Xrep);
            nEvals = nEvals + 1;

            if debBetter(frep, drep, fnew, dnew)
                Xnew = Xrep;
                fnew = frep;
                dnew = drep;
            end
        end

        accepted = debBetter(fnew, dnew, fold, dold);
        if accepted
            pop(i, :) = Xnew;
            fit(i) = fnew;
            detail(i) = dnew;
        end

        if params.useAOS && (t <= freezeIter) && accepted
            reward = computeReward(fold, dold, fit(i), detail(i), params);
            aos = updateAOS(aos, opIdx, reward);
        end
    end

    [bestFit, bestX, bestDetail] = localExtractBest(pop, fit, detail, bestFit, bestX, bestDetail);
    bestHist(t) = bestFit;

    if params.useRegen && ((t - lastRegenIter) >= params.lite.regenCooldown)
        if stagnationDetected(bestHist, pop, detail, t, params)
            consecutiveStagnation = consecutiveStagnation + 1;
        else
            consecutiveStagnation = 0;
        end

        if consecutiveStagnation >= params.lite.regenConfirmNeed
            [pop, fit, detail, regenNum] = localRegenerateWorstInfeasible(pop, fit, detail, bestX, elitePool, objFun, params, t);
            if regenNum > 0
                nEvals = nEvals + regenNum;
                lastRegenIter = t;
                [bestFit, bestX, bestDetail] = localExtractBest(pop, fit, detail, bestFit, bestX, bestDetail);
                bestHist(t) = bestFit;
            end
            consecutiveStagnation = 0;
        end
    end
end

runTime = toc(tStart);

bestCtrl = decodeSolution(bestX, params);
bestPath = bsplinePath(bestCtrl, params.degree, params.nSamples);

result = struct();
result.bestFit = bestFit;
result.bestDetail = bestDetail;
result.bestX = bestX;
result.bestCtrl = bestCtrl;
result.bestPath = bestPath;
result.bestHist = bestHist;
result.runTime = runTime;
result.finalFeasible = bestDetail.isFeasible;
result.finalViolation = localGetViolation(bestDetail);
result.nEvals = nEvals;

if params.useAOS
    result.aosCounts = aos.counts;
    result.aosMeanReward = aos.meanReward;
else
    result.aosCounts = zeros(1, 3);
    result.aosMeanReward = zeros(1, 3);
end

% compatibility aliases
result.bestFitness = bestFit;
result.bestPosition = bestX(:);
result.convergence = bestHist(:);
result.runtime = runTime;
end

% ========================================================================
function opIdx = localSelectOperator(aos, t, freezeIter, params)
if t <= freezeIter
    opIdx = selectOperator_UCB(aos, t, params);
    return;
end

if params.lite.aosFreezeUseBestReward && isfield(aos, 'counts') && isfield(aos, 'meanReward')
    counts = aos.counts(:).';
    rewards = aos.meanReward(:).';
    rewards(counts <= 0) = -inf;
    [mx, idx] = max(rewards);
    if isfinite(mx)
        opIdx = idx;
        return;
    end
end

opIdx = params.lite.aosFrozenOp;
end

% ========================================================================
function tf = localNeedFullRepair(i, repairSet, dnew, t, params)
tf = false;
if ~isstruct(dnew) || ~isfield(dnew, 'isFeasible') || ~isfield(dnew, 'V')
    return;
end
if dnew.isFeasible
    return;
end
if dnew.V > params.lite.repairMaxViolation
    return;
end
if ~any(repairSet == i)
    return;
end

phase = t / params.maxIter;
if phase < params.lite.repairStartFrac
    return;
elseif phase < params.lite.repairFullStartFrac
    tf = mod(t, params.lite.repairPeriodMid) == 0;
else
    tf = mod(t, params.lite.repairPeriodLate) == 0;
end
end

% ========================================================================
function [pop, fit, detail, regenNum] = localRegenerateWorstInfeasible(pop, fit, detail, bestX, elitePool, objFun, params, t)
regenNum = 0;
N = size(pop, 1);
D = size(pop, 2);

isFeasible = localFeasibleMask(detail);
infeasibleIdx = find(~isFeasible);
if isempty(infeasibleIdx)
    return;
end

viol = zeros(numel(infeasibleIdx), 1);
for k = 1:numel(infeasibleIdx)
    viol(k) = localGetViolation(detail(infeasibleIdx(k)));
end
[~, ord] = sort(viol, 'descend');
infeasibleIdx = infeasibleIdx(ord);

regenNum = max(1, round(params.lite.regenRatio * N));
regenNum = min(regenNum, numel(infeasibleIdx));
targetIdx = infeasibleIdx(1:regenNum);

eliteNum = size(elitePool, 1);
span = params.ub - params.lb;
tau = t / params.maxIter;
noiseScale = params.lite.regenNoiseScale * (0.65 + 0.35 * (1 - tau));

for p = 1:numel(targetIdx)
    idx = targetIdx(p);
    xElite = elitePool(randi(eliteNum), :);
    alpha = 0.45 + 0.35 * rand();
    beta = 0.08 + 0.10 * rand();
    gamma = 0.04 + 0.04 * rand();

    xnew = alpha * xElite + ...
           (1 - alpha) * bestX + ...
           beta * randn(1, D) .* span + ...
           gamma * rand(1, D) .* (xElite - bestX);

    xnew = boundSolution(xnew, params);
    [fnew, dnew] = objFun(xnew);

    % For worst infeasible individuals, replacement is unconditional.
    pop(idx, :) = xnew;
    fit(idx) = fnew;
    detail(idx) = dnew;
end
end

% ========================================================================
function [bestFit, bestX, bestDetail] = localExtractBest(pop, fit, detail, bestFit, bestX, bestDetail)
if nargin < 4
    bestFit = fit(1);
    bestX = pop(1, :);
    bestDetail = detail(1);
    startIdx = 2;
else
    startIdx = 1;
end
for i = startIdx:size(pop, 1)
    if debBetter(fit(i), detail(i), bestFit, bestDetail)
        bestFit = fit(i);
        bestX = pop(i, :);
        bestDetail = detail(i);
    end
end
end

% ========================================================================
function mask = localFeasibleMask(detail)
mask = false(numel(detail), 1);
for i = 1:numel(detail)
    if isfield(detail(i), 'isFeasible')
        mask(i) = logical(detail(i).isFeasible);
    end
end
end

% ========================================================================
function v = localGetViolation(d)
v = inf;
if isstruct(d) && isfield(d, 'V') && ~isempty(d.V)
    v = d.V;
end
end

% ========================================================================
function params = localWriteFlags(params, algCfg)
params.useInit = true;
params.useAOS = true;
params.useRepair = true;
params.useRegen = true;

if isfield(algCfg, 'useReferenceInit'), params.useInit = logical(algCfg.useReferenceInit); end
if isfield(algCfg, 'useAOS'),           params.useAOS = logical(algCfg.useAOS); end
if isfield(algCfg, 'useRepair'),        params.useRepair = logical(algCfg.useRepair); end
if isfield(algCfg, 'useRegen'),         params.useRegen = logical(algCfg.useRegen); end

if ~isfield(params, 'useHeightTerm'),   params.useHeightTerm = true; end
if ~isfield(params, 'useBoundaryTerm'), params.useBoundaryTerm = true; end
end

% ========================================================================
function params = localDefaultLiteV2Params(params)
params.lite = struct();
params.lite.aosFreezeFrac        = 0.50;
params.lite.aosFreezeUseBestReward = true;
params.lite.aosFrozenOp          = 3;

params.lite.repairStartFrac      = 0.35;
params.lite.repairFullStartFrac  = 0.70;
params.lite.repairEliteFrac      = 0.25;
params.lite.repairMaxViolation   = 20;
params.lite.repairIters          = 1;
params.lite.repairPeriodMid      = 3;
params.lite.repairPeriodLate     = 2;

params.lite.regenCooldown        = 20;
params.lite.regenRatio           = 0.05;
params.lite.regenConfirmNeed     = 2;
params.lite.regenNoiseScale      = 0.05;
end

% ========================================================================
function out = localMergeStruct(a, b)
out = a;
f = fieldnames(b);
for k = 1:numel(f)
    out.(f{k}) = b.(f{k});
end
end

% ========================================================================
function refCtrl = localSimpleReferencePath(params)
nFull = params.nCtrl + 2;
refCtrl = zeros(nFull, 3);
for i = 1:nFull
    tau = (i - 1) / (nFull - 1);
    p = (1 - tau) * params.start + tau * params.goal;
    p(3) = (1 - tau) * params.start(3) + tau * params.goal(3);
    refCtrl(i, :) = p;
end
refCtrl(1, :) = params.start;
refCtrl(end, :) = params.goal;
end
