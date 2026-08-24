classdef ICMA_Local < MTDMS_CMOEA_Local
    properties
        W
        Zmin
    end
    methods
        function obj = ICMA_Local(region, tasks, maxGen)
            obj@MTDMS_CMOEA_Local(region, tasks, maxGen, 'standard');
            M = 3;
            [W,~] = UniformPoint(obj.popSize, M);
            obj.W = W;
            obj.Zmin = inf(1,M);
        end
        function obj = evolve(obj)
            for gen = 1:obj.maxGen
                obj = obj.updateDynamicThreshold(gen);
                for i = 1:length(obj.population)
                    obj.Zmin = min(obj.Zmin, obj.population(i).objectives);
                end
                offspring = obj.generateOffspring();
                combined = [obj.population(:); offspring(:)];
                obj.population = obj.environmentalSelectionIndicator(combined);
                obj = obj.updateEliteArchive();
            end
        end
        function selected = environmentalSelectionIndicator(obj, combined)
            N = obj.popSize;
            pop = combined;
            K = size(obj.W,1);
            if K < N
                M = 3;
                [W2,~] = UniformPoint(N, M);
                obj.W = W2;
                K = size(W2,1);
            end
            vals = zeros(length(pop), K);
            for i = 1:length(pop)
                f = pop(i).objectives;
                if pop(i).constraintViolation > obj.thetaT
                    pen = pop(i).constraintViolation;
                else
                    pen = 0;
                end
                for k = 1:K
                    w = obj.W(k,:);
                    vals(i,k) = max((f - obj.Zmin).*w) + 1e3*pen;
                end
            end
            assign = zeros(length(pop),1);
            bestVal = inf(K,1);
            bestIdx = zeros(K,1);
            for i = 1:length(pop)
                [mval,k] = min(vals(i,:));
                if mval < bestVal(k)
                    bestVal(k) = mval;
                    bestIdx(k) = i;
                end
                assign(i) = k;
            end
            chosen = bestIdx(bestIdx>0);
            remaining = setdiff(1:length(pop), chosen);
            if length(chosen) < N
                [~,ord] = sortrows([min(vals(remaining,:),[],2)], 1);
                need = N - length(chosen);
                chosen = [chosen; remaining(ord(1:min(need,length(ord))))'];
            elseif length(chosen) > N
                chosen = chosen(1:N);
            end
            selected = pop(chosen);
        end
    end
end

