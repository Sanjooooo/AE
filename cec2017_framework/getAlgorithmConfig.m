function algCfg = getAlgorithmConfig(algName, dim, maxFEs)

algName = upper(algName);

algCfg = struct();
algCfg.name = algName;
algCfg.dim = dim;
algCfg.maxFEs = maxFEs;

% Default common settings
algCfg.popSize = 30;
algCfg.maxIter = ceil(maxFEs / algCfg.popSize);

switch algName
    case 'AE'
        % Keep close to your current AE baseline
        algCfg.popSize = 30;
        algCfg.maxIter = ceil(maxFEs / algCfg.popSize);

    case 'WOA'
        algCfg.popSize = 30;
        algCfg.maxIter = ceil(maxFEs / algCfg.popSize);
        algCfg.b = 1.0;   % spiral coefficient

    case 'PSO'
        algCfg.popSize = 30;
        algCfg.maxIter = ceil(maxFEs / algCfg.popSize);
        algCfg.w = 0.7;
        algCfg.c1 = 1.5;
        algCfg.c2 = 1.5;
        algCfg.vmaxRatio = 0.2;

    case 'GWO'
        algCfg.popSize = 30;
        algCfg.maxIter = ceil(maxFEs / algCfg.popSize);

    case 'HHO'
        algCfg.popSize = 30;
        algCfg.maxIter = ceil(maxFEs / algCfg.popSize);

    case 'FAEAE'
        % Keep close to your current FAE-AE CEC settings
        algCfg.popSize = 30;
        algCfg.maxIter = ceil(maxFEs / algCfg.popSize);

    otherwise
        error('Unknown algorithm: %s', algName);
end

end