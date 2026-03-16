function algCfg = getUAVAlgorithmConfig(algName, params, cfg)
%GETUAVALGORITHMCONFIG Return algorithm-specific config for UAV comparison.
%
% Inputs:
%   algName - algorithm name
%   params  - defaultParams() output after scene assignment
%   cfg     - comparison config
%
% Output:
%   algCfg  - algorithm-specific configuration

    algName = upper(algName);

    algCfg = struct();
    algCfg.name = algName;

    % ------------------------------------------------------------
    % Shared search settings
    % IMPORTANT:
    % Your current defaultParams.m uses params.popSize, not params.N.
    % ------------------------------------------------------------
    algCfg.dim = params.dim;
    algCfg.lb = params.lb(:)';
    algCfg.ub = params.ub(:)';
    algCfg.popSize = params.popSize;
    algCfg.maxIter = params.maxIter;

    % Common initialization choices
    algCfg.useReferenceInit = false;
    algCfg.referenceInitRatio = 0.0;
    algCfg.referenceNoiseScale = 0.05;   % relative to range
    algCfg.useDebSelection = true;

    % Public lightweight projection
    algCfg.usePublicProjection = true;

    switch algName
        case 'AE'
            algCfg.useReferenceInit = false;
            algCfg.referenceInitRatio = 0.0;

        case 'PSO'
            algCfg.w = 0.7;
            algCfg.c1 = 1.5;
            algCfg.c2 = 1.5;
            algCfg.vmaxRatio = 0.2;
            algCfg.useReferenceInit = false;

        case 'GWO'
            algCfg.useReferenceInit = false;

        case 'HHO'
            algCfg.useReferenceInit = false;

        case 'WOA'
            algCfg.b = 1.0;
            algCfg.useReferenceInit = false;

        case 'FAEAE'
            algCfg.useReferenceInit = true;
            algCfg.referenceInitRatio = 0.7;

            algCfg.useAOS = true;
            algCfg.useRepair = true;
            algCfg.useRegen = true;

        otherwise
            error('Unknown UAV algorithm: %s', algName);
    end
end