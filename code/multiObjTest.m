%% Given adjacency matrix
%adjGraph = sparse([1 1 2 2 2 3 3 4 5],[2 3 4 5 3 4 5 6 6],[2 2 1 1 1 1 1 2 2],6,6);
%incGraph = adj2inc(adjGraph,0);
%
% Total number of nodes
%nodesNum = 6;
%edgesNum = 9;
% Vulnerable nodes
%vulnerableN = [1,2];
%demandNodes=6;
%sourceNodes=[1 2];
incGraph = adj2inc(adjGraph,0);
    % Total number of nodes
    nodesNum = size(adjGraph,1);
    edgesNum = size(incGraph,1);
    % Vulnerable nodes
    %vulnerableNodes = [1,2,4,5];%Test failed, this should've lead to sensor at 6 and actuator after it. Something wrong with shortestPathsFromVulnerableNodes code.
    %demandNodes = [7];
    %Weights/lengths of pipes
    edgeWeights = eye(edgesNum);
    for i=1:size(incGraph,1)
        pipeStartNodes(i) = find(incGraph(i,:)>0);
        pipeEndNodes(i) = find(incGraph(i,:)<0);
    end
    pipeIDs = 1:size(incGraph,1);
    demandNodes = demandN;

%Weights/lengths of pipes
edgeWeights = eye(edgesNum);
%% Sensor placement
% Given vulnerable, find affected for each vulnerable
% 1 step away affected nodes
% affectedN = adjGraph(vulnerableN,:)>=1;
% Find all affected nodes per vulnerable node, each vulnerable node has a row in the A matrix
A1 = zeros(length(vulnerableN),nodesNum);
for i=1:length(vulnerableN)
    A1(i,graphtraverse(adjGraph,vulnerableN(i))) = -1;
end
%Decision variable coefficient vector -- f
f1 = ones(nodesNum,1);
%Constraints -Ax >= -b; where (-b)=1
b1 = -1.*ones(size(A1,1),1);
%Integer variables
intcon1 = 1:nodesNum;
%Equality constraints
Aeq1 = [];
beq1 = [];

%% Actuator placement
%Objective
f2 = [zeros(1,size(incGraph,2)), ones(1,size(incGraph,1))]';

% Inequality constraint
A2 = [-incGraph -eye(size(incGraph,1))*edgeWeights];
b2 = zeros(size(incGraph,1),1);

% Set the partitions of source to 0 and demands to 1
% Equality constraint
tmp = 0;
Aeq2=zeros(0,size(f2,1));
for i=1:length(vulnerableN)
    tmp = tmp+1;
    Aeq2(tmp,i) = 1;
end
beq2 = zeros(length(vulnerableN),1);
for i=1:length(demandNodes)
    tmp = tmp+1;
    Aeq2(tmp,i) = 1;
end
beq2 = [beq2; ones(length(demandNodes),1)];

%% Solving combined MILP
% Lower and upper bounds/bianry constraint
lowerBound=zeros(1,nodesNum*2+edgesNum);
upperBound=ones(1,nodesNum*2+edgesNum);
%Integer constraint
intcon2 = nodesNum+1:nodesNum*2+edgesNum;
A = [A1 zeros(size(A1,1),size(f2,1)); zeros(size(A2,1),size(f1,1)) A2];
b = [b1;b2];
Aeq = [Aeq1 zeros(size(Aeq1,1),size(f2,1)); zeros(size(Aeq2,1),size(f1,1)) Aeq2];
beq = [beq1 beq2];
f = [f1;f2];
intcon = [intcon1 intcon2];
[x,fval,exitflag,info] = intlinprog(f,intcon, A,b,Aeq,beq,lowerBound,upperBound);
partitionDemand=find(x(nodesNum+1:nodesNum*2))';
partitionSource=setdiff(1:nodesNum,partitionDemand);
plotBiograph
