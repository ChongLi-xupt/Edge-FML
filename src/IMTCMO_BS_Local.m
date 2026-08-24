classdef IMTCMO_BS_Local < IMTCMO_Local
    properties
        Ns
        g
        cnt
    end
    methods
        function obj = IMTCMO_BS_Local(region, tasks, maxGen)
            obj@IMTCMO_Local(region, tasks, maxGen);
            obj.Ns = max(10, round(0.2*obj.popSize));
            obj.g = 10;
            obj.cnt = 0;
        end
        function obj = evolve(obj)
            for gen = 1:obj.maxGen
                obj = obj.updateDynamicThreshold(gen);
                cp = (-log(obj.VAR0)-6)/log(1-0.5);
                VAR = obj.VAR0*(1-obj.Xval)^cp;
                obj.cnt = obj.cnt + 1;
                injected = [];
                if obj.cnt == 1 || mod(obj.cnt, obj.g) == 0
                    injected = obj.directedSampling(VAR);
                    comb0 = [obj.population(:); injected(:)];
                    obj.population = obj.environmentalSelectionEpsilon(comb0, VAR);
                end
                offspring = obj.generateMixedOffspring();
                if ~isempty(injected)
                    combined = [obj.population(:); offspring(:)];
                else
                    combined = [obj.population(:); offspring(:)];
                end
                obj.population = obj.environmentalSelectionEpsilon(combined, VAR);
                obj = obj.updateEliteArchive();
                obj.Xval = obj.Xval + 1/max(obj.maxGen,1);
            end
        end
        function samplepop = directedSampling(obj, VAR)
            K = obj.region.numDevices;
            T = length(obj.tasks);
            samplepop = Solution.empty(obj.Ns, 0);
            chooseDiv = rand > 0.5;
            objs = vertcat(obj.population.objectives);
            [~,ord] = sort(objs(:,1));
            guide = obj.population(ord(1));
            for i = 1:obj.Ns
                s = Solution(K,T);
                if chooseDiv
                    for t = 1:T
                        s.f_resource(t) = min(1.0, max(0.1, guide.f_resource(t) + 0.2*randn()));
                    end
                    for k = 1:K
                        if rand < 0.3
                            s.x_offload(k) = 1 - guide.x_offload(k);
                        else
                            s.x_offload(k) = guide.x_offload(k);
                        end
                        if rand < 0.3
                            s.z_security(k) = max(1, min(4, guide.z_security(k) + randi([-1,1])));
                        else
                            s.z_security(k) = guide.z_security(k);
                        end
                    end
                    for t = 1:T
                        if rand < 0.3
                            s.y_cache(t) = 1 - guide.y_cache(t);
                        else
                            s.y_cache(t) = guide.y_cache(t);
                        end
                    end
                else
                    for t = 1:T
                        s.f_resource(t) = min(1.0, max(0.1, 0.5*guide.f_resource(t) + 0.5*rand()));
                    end
                    for k = 1:K
                        s.x_offload(k) = guide.x_offload(k);
                        s.z_security(k) = guide.z_security(k);
                    end
                    for t = 1:T
                        s.y_cache(t) = guide.y_cache(t);
                    end
                end
                s = obj.repairAndEval(s);
                samplepop(i) = s;
            end
        end
    end
end

