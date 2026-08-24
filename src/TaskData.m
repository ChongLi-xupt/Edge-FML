classdef TaskData
    % TaskData - Task specification for edge computing
    % Defines workload characteristics and requirements
    %
    % Author: 拓守恒 (Shouheng Tuo)
    % Email: shouheng.tuo@example.com
    % Date: 2025-12-01
    % Reference: FML.MD - Task Specification Model

    properties
        taskType          % t: Task type index [1, T]
        dataSize          % D_t: Data size in MB
        workload          % W_t: Computation workload in CPU cycles
        deadline          % D_t^dl: Deadline in seconds
        securityLevel     % s_t^min: Minimum security level required [1,4]
        priority          % Task priority [1,5]
        accessFreq        % Cache access frequency
    end

    methods
        function obj = TaskData(type, D, W, dl, s_min, pri, freq)
            % Constructor
            if nargin > 0
                obj.taskType = type;
                obj.dataSize = D;
                obj.workload = W;
                obj.deadline = dl;
                obj.securityLevel = s_min;
                obj.priority = pri;
                obj.accessFreq = freq;
            end
        end
    end
end
