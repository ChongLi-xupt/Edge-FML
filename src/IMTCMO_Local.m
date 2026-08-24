classdef IMTCMO_Local < MTDMS_CMOEA_Local
    properties
        VAR0
        Xval
        pbestFrac
    end
    methods
        function obj = IMTCMO_Local(region, tasks, maxGen)
            obj@MTDMS_CMOEA_Local(region, tasks, maxGen, 'standard');
            consVals = [obj.population.constraintViolation]';
            consVals(consVals<0) = 0;
            if isempty(consVals)
                obj.VAR0 = 1;
            else
                obj.VAR0 = max(consVals);
                if obj.VAR0 == 0
                    obj.VAR0 = 1;
                end
            end
            obj.Xval = 0;
            obj.pbestFrac = 0.2;
        end
        function obj = evolve(obj)
            for gen = 1:obj.maxGen
                obj = obj.updateDynamicThreshold(gen);
                cp = (-log(obj.VAR0)-6)/log(1-0.5);
                VAR = obj.VAR0*(1-obj.Xval)^cp;
                offspring = obj.generateMixedOffspring();
                combined = [obj.population(:); offspring(:)];
                obj.population = obj.environmentalSelectionEpsilon(combined, VAR);
                obj = obj.updateEliteArchive();
                obj.Xval = obj.Xval + 1/max(obj.maxGen,1);
            end
        end
        function offspring = generateMixedOffspring(obj)
            K = obj.region.numDevices;
            T = length(obj.tasks);
            offspring = Solution.empty(obj.popSize, 0);
            P = max(1, round(obj.pbestFrac*obj.popSize));
            objs = vertcat(obj.population.objectives);
            [~,ord] = sort(objs(:,1));
            pset = obj.population(ord(1:P));
            for i = 1:obj.popSize
                if i <= obj.popSize/2
                    idx = randperm(obj.popSize,3);
                    x1 = obj.population(idx(1)); x2 = obj.population(idx(2)); x3 = obj.population(idx(3));
                    trial = Solution(K,T);
                    CR = 0.5; Fm = 0.5;
                    for t = 1:T
                        if rand < CR
                            trial.f_resource(t) = x1.f_resource(t) + Fm*(x2.f_resource(t)-x3.f_resource(t));
                        else
                            trial.f_resource(t) = obj.population(i).f_resource(t);
                        end
                        trial.f_resource(t) = max(0.1,min(1.0,trial.f_resource(t)));
                    end
                    for k = 1:K
                        if rand < CR
                            trial.x_offload(k) = x1.x_offload(k);
                        else
                            trial.x_offload(k) = obj.population(i).x_offload(k);
                        end
                        if rand < CR
                            trial.z_security(k) = x2.z_security(k);
                        else
                            trial.z_security(k) = obj.population(i).z_security(k);
                        end
                    end
                    for t = 1:T
                        if rand < CR
                            trial.y_cache(t) = x3.y_cache(t);
                        else
                            trial.y_cache(t) = obj.population(i).y_cache(t);
                        end
                    end
                else
                    trial = Solution(K,T);
                    p = pset(randi(length(pset)));
                    r1 = obj.population(randi(obj.popSize));
                    r2 = obj.population(randi(obj.popSize));
                    CR = 0.7; Fm = 0.5;
                    for t = 1:T
                        base = obj.population(i).f_resource(t);
                        v = base + Fm*(p.f_resource(t)-base) + Fm*(r1.f_resource(t)-r2.f_resource(t));
                        if rand < CR
                            trial.f_resource(t) = v;
                        else
                            trial.f_resource(t) = base;
                        end
                        trial.f_resource(t) = max(0.1,min(1.0,trial.f_resource(t)));
                    end
                    for k = 1:K
                        if rand < CR
                            trial.x_offload(k) = p.x_offload(k);
                        else
                            trial.x_offload(k) = obj.population(i).x_offload(k);
                        end
                        if rand < CR
                            trial.z_security(k) = p.z_security(k);
                        else
                            trial.z_security(k) = obj.population(i).z_security(k);
                        end
                    end
                    for t = 1:T
                        if rand < CR
                            trial.y_cache(t) = p.y_cache(t);
                        else
                            trial.y_cache(t) = obj.population(i).y_cache(t);
                        end
                    end
                end
                trial = obj.repairAndEval(trial);
                offspring(i) = trial;
            end
        end
        function pop = environmentalSelectionEpsilon(obj, combined, VAR)
            N = obj.popSize;
            feasIdx = [];
            infeasIdx = [];
            for i = 1:length(combined)
                if combined(i).constraintViolation <= VAR
                    feasIdx(end+1) = i;
                else
                    infeasIdx(end+1) = i;
                end
            end
            if ~isempty(feasIdx)
                feasPop = combined(feasIdx);
                ranked = obj.nonDominatedSorting(feasPop);
                if length(ranked) >= N
                    pop = ranked(1:N);
                    return;
                else
                    pop = ranked(:);
                end
            else
                pop = Solution.empty(0,0);
            end
            if length(pop) < N && ~isempty(infeasIdx)
                infPop = combined(infeasIdx);
                [~,ord] = sort([infPop.constraintViolation]);
                need = N - length(pop);
                toAdd = infPop(ord(1:min(need,length(infPop))));
                if isempty(pop)
                    pop = toAdd;
                else
                    totalLen = length(pop) + length(toAdd);
                    tmp = Solution.empty(totalLen, 0);
                    tmp(1:length(pop)) = pop(:);
                    tmp(length(pop)+1:totalLen) = toAdd(:);
                    pop = tmp;
                end
            end
        end
        function trial = repairAndEval(obj, trial)
            K = obj.region.numDevices;
            T = length(obj.tasks);
            for k = 1:K
                if trial.x_offload(k) == 1
                    tt = mod(k-1,T)+1;
                    trial.z_security(k) = max(trial.z_security(k), obj.tasks(tt).securityLevel);
                end
            end
            totalAlloc = sum(trial.f_resource);
            if totalAlloc > T
                trial.f_resource = trial.f_resource*(T*0.95/totalAlloc);
            end
            cacheUsed = 0;
            idxs = [];
            for t = 1:T
                if trial.y_cache(t) == 1
                    cacheUsed = cacheUsed + obj.tasks(t).dataSize;
                    idxs(end+1) = t;
                end
            end
            if cacheUsed > obj.region.cacheCapacity && ~isempty(idxs)
                sizes = zeros(length(idxs),1);
                for ii = 1:length(idxs)
                    sizes(ii) = obj.tasks(idxs(ii)).dataSize;
                end
                [~,ord] = sort(sizes,'descend');
                for ii = 1:length(ord)
                    t = idxs(ord(ii));
                    trial.y_cache(t) = 0;
                    cacheUsed = cacheUsed - obj.tasks(t).dataSize;
                    if cacheUsed <= obj.region.cacheCapacity
                        break;
                    end
                end
            end
            [trial.objectives, trial.violations, trial.constraintViolation] = obj.evaluator.evaluate(trial);
        end
    end
end
