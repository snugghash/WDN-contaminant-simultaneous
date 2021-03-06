if(exist('WdnPath'))
    % Get data from .inp file
    [model, adjGraph, incGraph, nodesNum, edgesNum, edgeWeights, vulnerableNodes, vulnerableNum, demandNodes, pipeIDs, nodeIDs, pipeStartNodes, pipeEndNodes] = getWdnData(WdnPath);
elseif(exist('adjGraph'))
    %% Given adjacency matrix, figure out everything else
    incGraph = adj2inc(adjGraph,0);
    % Total number of nodes
    nodesNum = size(adjGraph,1);
    edgesNum = size(incGraph,1);
    for i=1:size(incGraph,1)
        pipeStartNodes(i) = find(incGraph(i,:)>0);
        pipeEndNodes(i) = find(incGraph(i,:)<0);
    end
    pipeIDs = 1:size(incGraph,1);
    vulnerableNum = size(vulnerableNodes,2);
else
    % Get data from .inp file
    [model, adjGraph, incGraph, nodesNum, edgesNum, edgeWeights, vulnerableNodes, vulnerableNum, demandNodes, pipeIDs, nodeIDs, pipeStartNodes, pipeEndNodes] = getWdnData('bangalore_expanded221.inp');
end
if(exist('vulnerableN'))
    vulnerableNodes = vulnerableN;
    vulnerableNum = length(vulnerableNodes);
end
if(exist('demandN'))
    demandNodes = demandN;
end
NUMBER_BIGGER_THAN_NETWORK = 10000;
maxDistanceToDetection = NUMBER_BIGGER_THAN_NETWORK;

%% Sensor placement
% Given vulnerable, find affected for each vulnerable
% 1 step away affected nodes
% affectedN = adjGraph(vulnerableN,:)>=1;
% Find all affected nodes per vulnerable node, each vulnerable node has a row in the A matrix
A1 = zeros(vulnerableNum,nodesNum);
for i=1:vulnerableNum
    tmp1 = graphtraverse(adjGraph,vulnerableNodes(i));
    A1(i,tmp1) = -1;
end
%Decision variable coefficient vector -- f
f1 = ones(nodesNum,1);
%Constraints -Ax >= -b; where (-b)=1
b1 = -1.*ones(size(A1,1),1);
%Integer variables
intcon1 = 1:nodesNum;
%Equality constraints
Aeq1 = zeros(0,size(f1,1));
beq1 = [];
% Forcing sensors at these point to see obj. fun. value. As it turns out, not feasible.
Aeq1i = 0;
if(exist('forcedSensors'))
    for i=forcedSensors
        Aeq1i = Aeq1i + 1;
        Aeq1(Aeq1i,i) = 1;
    end
    beq1 = [beq1; ones(Aeq1i,1)];
end
% Forcing lack of sensors
if(exist('forcedNoSensors'))
    Aeq1j = 0;
    for i=forcedNoSensors
        Aeq1i = Aeq1i + 1;
        Aeq1j = Aeq1j + 1;
        Aeq1(Aeq1i,i) = 1;
    end
    beq1 = [beq1; zeros(Aeq1j,1)];
end
clear('Aeq1i')
assert(size(Aeq1,1) == size(beq1,1));

%% Actuator placement %Inspired by Venkat Reddy's implementation of partitioning.
%Objective
f2 = [zeros(1,size(incGraph,2)), ones(1,size(incGraph,1))]';

% Inequality constraint
% TODO This does not account for zero flows or demand to source transitions
% when flow is opposite.
A2 = [-incGraph -eye(size(incGraph,1))*edgeWeights;
    incGraph -eye(size(incGraph,1))*edgeWeights]; % TODO edgeWeights must be in the order of incGraph (1:size(incGraph,1) === pipeIDs)
b2 = zeros(size(incGraph,1)*2,1);

% Set the partitions of source to 0 and demands to 1
% Equality constraint
Aeq2i = 0;
Aeq2 = zeros(0,size(f2,1));
for i=vulnerableNodes
    Aeq2i = Aeq2i+1;
    Aeq2(Aeq2i,i) = 1;
end
beq2 = zeros(vulnerableNum,1);
for i=demandNodes
    Aeq2i = Aeq2i+1;
    Aeq2(Aeq2i,i) = 1;
end
beq2 = [beq2; ones(length(demandNodes),1)];

% Get the distances to be needed among the nodes.
tmp2 = graphallshortestpaths(adjGraph);
allDistances = tmp2(vulnerableNodes,:);
assert(isequal(size(allDistances), [vulnerableNum nodesNum]));
shortestPathsFromVulnerableNodes = min(allDistances);
tmp3 = sort(shortestPathsFromVulnerableNodes);
maxDistance = tmp3(end-1);
shortestPathsFromVulnerableNodes(shortestPathsFromVulnerableNodes==Inf) = NUMBER_BIGGER_THAN_NETWORK;
distanceEdgesFromVulnerableNodes = shortestPathsFromVulnerableNodes(pipeStartNodes);

allDistances(allDistances==Inf) = -1;
longestPossiblePathFromVulnerableNode = max(allDistances);

%% Solving combined MILP
%Integer constraint
intcon2 = nodesNum+1:nodesNum*2+edgesNum;

% New decision variables for transformed space.
f3 = [0; zeros(nodesNum,1)];
intcon3 = (nodesNum*2+edgesNum+1):(nodesNum*2+edgesNum+1+nodesNum);

% Lower and upper bounds/bianry constraint
lowerBound = [zeros(1,nodesNum*2+edgesNum) 0 ones(1,nodesNum)];
upperBound = [ones(1,nodesNum*2+edgesNum) NUMBER_BIGGER_THAN_NETWORK NUMBER_BIGGER_THAN_NETWORK.*ones(1,nodesNum)];

A = [A1 zeros(size(A1,1),size(f2,1)+size(f3,1)); zeros(size(A2,1),size(f1,1)) A2 zeros(size(A2,1),size(f3,1))];
b = [b1;b2];
Aeq = [Aeq1 zeros(size(Aeq1,1),size(f2,1)+size(f3,1)); zeros(size(Aeq2,1),size(f1,1)) Aeq2 zeros(size(Aeq2,1),size(f3,1))];
beq = [beq1;beq2];
f = [f1;f2;f3];
intcon = [intcon1 intcon2 intcon3];

%Use inequality constraints to force sensor nodes(and all nodes at or lesser distance from vulnerable nodes) to be in the source
%partition. Observability => all are critical, can make another objective
%for identifiability easily.

% Get max sensor distance. This alone --because of the minimization-- changes
% the solution but the objective value remains same.
for i=1:nodesNum
    newConstraintIndex = size(A,1)+1;
    A(newConstraintIndex,i) = shortestPathsFromVulnerableNodes(i);
    A(newConstraintIndex,1+nodesNum*2+edgesNum) = -1;
end
b = [b; zeros(nodesNum,1)];

% Maximum distance to detection enforcing
A(size(A,1)+1,1+nodesNum*2+edgesNum) = 1;
b(size(b,1)+1) = maxDistanceToDetection;

% Make the partition vector 1 for demand partition and NUMBER_BIGGER_THAN_NETWORK for source.
% Decision variables bounds [1, NUMBER_BIGGER_THAN_NETWORK]. Don't maximize.
for i=1:nodesNum
    newConstraintIndex = size(A,1)+1;
    A(newConstraintIndex,i+nodesNum) = -NUMBER_BIGGER_THAN_NETWORK;
    A(newConstraintIndex,1+nodesNum*2+edgesNum+i) = -1;
    b(newConstraintIndex) = -NUMBER_BIGGER_THAN_NETWORK;
    newConstraintIndex = size(A,1)+1;
    A(newConstraintIndex,i+nodesNum) = (NUMBER_BIGGER_THAN_NETWORK-1);
    A(newConstraintIndex,1+nodesNum*2+edgesNum+i) = 1;
    b(newConstraintIndex) = NUMBER_BIGGER_THAN_NETWORK;
end

% Force all partitioning to happen after the distance.
for i=1:nodesNum
   newConstraintIndex = size(A,1)+1;
   A(newConstraintIndex,1+nodesNum*2+edgesNum+i) = -shortestPathsFromVulnerableNodes(i)-NUMBER_BIGGER_THAN_NETWORK;
   A(newConstraintIndex,1+nodesNum*2+edgesNum) = 1+1/NUMBER_BIGGER_THAN_NETWORK; %TODO Fix sad implementation using floating point arithmetic if using nodes. But N ~< E so using them is better. MATLAB's tolerance for zero is around 10^-14
end
b = [b; -NUMBER_BIGGER_THAN_NETWORK*ones(nodesNum,1)];

% Get a different sensor placement solution by preventing the last.
%Aeq(size(Aeq,1)+1,[66]) = [1];
%beq(size(beq,1)+1) = 0; % No others are feasible?

% % Implementation using edges
% for i=1:edgesNum
%    newConstraintIndex = size(A,1)+1;
%    A(newConstraintIndex,i+nodesNum*2) = -distanceEdgesFromVulnerableNodes(i);
%    A(newConstraintIndex,1+nodesNum*2+edgesNum) = 1;
% end
% b = [b; zeros(edgesNum,1)];

[x,fval,exitflag,info] = intlinprog(f,intcon,A,b,Aeq,beq,lowerBound,upperBound);
if(exist('x')==0)
    return;
end
sensorNodes = find(x(1:nodesNum))
% Order of network
actuatorPipes = find(x((nodesNum*2+1):(nodesNum*2+edgesNum))~=0);
% Order of IDs
actuatorEdges = pipeIDs(actuatorPipes)
partitionDemand=find(x(nodesNum+1:nodesNum*2))';
partitionSource=setdiff(1:nodesNum,partitionDemand);
distanceToDetection = x(nodesNum*2+edgesNum+1)
distanceVulnerableToSensors = allDistances(:,sensorNodes)

if(exist('model'))
    plotNetwork('bangalore_expanded221.inp',model,nodesNum,edgesNum,vulnerableNodes,vulnerableNum,demandNodes,nodeIDs,pipeStartNodes,pipeEndNodes,adjGraph,incGraph,x);
else
    plotBiograph;
end

% Testing the partitioned network
% Remove actuator edges
adjGraphContained = adjGraph;
adjGraphContained(pipeStartNodes(actuatorPipes),pipeEndNodes(actuatorPipes)) = 0;
adjGraphContained(pipeEndNodes(actuatorPipes),pipeStartNodes(actuatorPipes)) = 0;
tmp2 = graphallshortestpaths(adjGraphContained);
allDistancesContained = tmp2(vulnerableNodes,:);
assert(isequal(size(allDistancesContained), [vulnerableNum nodesNum]));
shortestPathsFromVulnerableNodesContained = min(allDistancesContained);
for i=demandNodes
    assert(shortestPathsFromVulnerableNodesContained(i)>NUMBER_BIGGER_THAN_NETWORK);
end
%BGobj = biograph(adjGraph, [], 'ShowArrows', true);
