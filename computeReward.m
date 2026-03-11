function reward = computeReward(oldFit, oldDetail, newFit, newDetail, params)
%COMPUTEREWARD Improved normalized reward for adaptive operator selection.
% Main improvements:
% 1) normalize objective improvement
% 2) normalize violation improvement
% 3) normalize wind-risk improvement
% 4) add a feasibility bonus to encourage valid-path generation
% 5) clip reward to avoid numerical domination by a single very large update

% ---------- Normalized objective improvement ----------
dJ = (oldFit - newFit) / (abs(oldFit) + 1e-9);

% ---------- Normalized constraint violation improvement ----------
% +1 in denominator avoids instability when oldDetail.V = 0
dV = (oldDetail.V - newDetail.V) / (abs(oldDetail.V) + 1 + 1e-9);

% ---------- Normalized risk improvement ----------
dR = (oldDetail.R - newDetail.R) / (abs(oldDetail.R) + 1e-9);

% ---------- Feasibility transition bonus ----------
% Encourage operators that turn infeasible solutions into feasible ones
feasBonus = 0;
if (~oldDetail.isFeasible) && newDetail.isFeasible
    feasBonus = 0.20;
elseif oldDetail.isFeasible && (~newDetail.isFeasible)
    feasBonus = -0.20;
end

% ---------- Weighted reward ----------
reward = params.aos.betaJ * dJ + ...
         params.aos.betaV * dV + ...
         params.aos.betaR * dR + ...
         feasBonus;

% ---------- Reward clipping ----------
reward = max(min(reward, 1.0), -1.0);

end