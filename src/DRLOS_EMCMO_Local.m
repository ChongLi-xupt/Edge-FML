classdef DRLOS_EMCMO_Local < MTDMS_CMOEA_Local
    properties
        epsilon
        opSuccess
        opTrials
    end
    methods
        function obj = DRLOS_EMCMO_Local(region, tasks, maxGen)
            obj@MTDMS_CMOEA_Local(region, tasks, maxGen, 'standard');
            obj.epsilon = 0.2;
            obj.opSuccess = zeros(2,1);
            obj.opTrials = zeros(2,1);
        end
        function obj = evolve(obj)
            for gen = 1:obj.maxGen
                obj = obj.updateDynamicThreshold(gen);
                offspring = obj.generateOffspringRL();
                combined = [obj.population(:); offspring(:)];
                obj.population = obj.environmentalSelection(combined);
                obj = obj.updateEliteArchive();
                obj = obj.updatePolicy();
            end
        end
        function obj = updatePolicy(obj)
            rates = (obj.opSuccess+1)./(obj.opTrials+2);
            [~,best] = max(rates);
            obj.epsilon = max(0.05, obj.epsilon*0.98);
            if ~isfinite(best)
                obj.epsilon = 0.2;
            end
        end
        function offspring = generateOffspringRL(obj)
            K = obj.region.numDevices;
            T = length(obj.tasks);
            offspring = Solution.empty(obj.popSize, 0);
            rates = (obj.opSuccess+1)./(obj.opTrials+2);
            [~,best] = max(rates);
            for i = 1:obj.popSize
                if rand < obj.epsilon
                    op = randi(2);
                else
                    op = best;
                end
                obj.opTrials(op) = obj.opTrials(op)+1;
                if op == 1
                    trial = Solution(K,T);
                    p1 = obj.population(randi(obj.popSize));
                    p2 = obj.population(randi(obj.popSize));
                    p3 = obj.population(randi(obj.popSize));
                    for t = 1:T
                        if rand < 0.9
                            trial.f_resource(t) = (p1.f_resource(t)+p2.f_resource(t))/2;
                        else
                            trial.f_resource(t) = p3.f_resource(t);
                        end
                        if rand < 0.1
                            trial.f_resource(t) = trial.f_resource(t) + 0.05*randn();
                        end
                        trial.f_resource(t) = max(0.1,min(1.0,trial.f_resource(t)));
                    end
                    for k = 1:K
                        trial.x_offload(k) = rand < 0.5*double(p1.x_offload(k)) + 0.5*double(p2.x_offload(k));
                        trial.z_security(k) = randi([min([p1.z_security(k),p2.z_security(k)]), max([p1.z_security(k),p2.z_security(k)])]);
                    end
                    for t = 1:T
                        trial.y_cache(t) = rand < 0.5*double(p1.y_cache(t)) + 0.5*double(p2.y_cache(t));
                    end
                else
                    trial = Solution(K,T);
                    idx = randperm(obj.popSize,3);
                    x1 = obj.population(idx(1));
                    x2 = obj.population(idx(2));
                    x3 = obj.population(idx(3));
                    CR = 0.35;
                    Fm = 0.5;
                    for t = 1:T
                        if rand < CR
                            trial.f_resource(t) = x1.f_resource(t) + Fm*(x2.f_resource(t)-x3.f_resource(t));
                        else
                            trial.f_resource(t) = obj.population(i).f_resource(t);
                        end
                        trial.f_resource(t) = max(0.1, min(1.0, trial.f_resource(t)));
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
                end
                trial = obj.repairAndEval(trial);
                offspring(i) = trial;
                if obj.population(i).dominates(trial)
                    % no increment
                elseif trial.dominates(obj.population(i))
                    obj.opSuccess(op) = obj.opSuccess(op)+1;
                elseif trial.constraintViolation < obj.population(i).constraintViolation
                    obj.opSuccess(op) = obj.opSuccess(op)+1;
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
                trial.f_resource = trial.f_resource * (T*0.95/totalAlloc);
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

