%% Get adjacency matrix from pipes
% Extracts struct from given file
model = epanet_reader4_extract('bangalore_expanded221.inp');
% cell2mat(cellfun(@str2num,model.pipes.ni,'un',0).') outputs a proper
% numeric matrix. The vectors of similar expressions make up the
% corresponding entries (with opposite sign) in the other triangle.
adjGraph = sparse([cell2mat(cellfun(@str2num,model.pipes.ni,'un',0).') cell2mat(cellfun(@str2num,model.pipes.nj,'un',0).')],[cell2mat(cellfun(@str2num,model.pipes.nj,'un',0).') cell2mat(cellfun(@str2num,model.pipes.ni,'un',0).')],[ones(1,model.pipes.npipes) -1.*ones(1,model.pipes.npipes)]);
% Get incidence matrix
incGraph = adj2inc(adjGraph,0);

% Total number of nodes
nodesNum = model.nodes.ntot;
% Vulnerable nodes
vulnerableN = find(strcmp(model.nodes.type,'R'));
edgesNum = model.pipes.npipes;

demandNodes=find(model.nodes.demand>0);
% type='D' => Demands, type='T' => Tanks, type='R' => Reservoirs
sourceNodes=find(strcmp(model.nodes.type,'R'));

%Weights/lengths of pipes
edgeWeights = eye(edgesNum);
%% Actuator placement %Inspired by Venkat Reddy's implementation of partitioning.
%Objective
f2 = [zeros(1,size(incGraph,2)), ones(1,size(incGraph,1))]';

% Inequality constraint
A2 = [-incGraph -eye(size(incGraph,1))*edgeWeights];
b2 = zeros(size(incGraph,1),1);

% Set the partitions of source to 0 and demands to 1
% Equality constraint
tmp = 0;
Aeq2=zeros(0,size(f2,1));
for i=sourceNodes
    tmp = tmp+1;
    Aeq2(tmp,i) = 1;
end
beq2 = zeros(length(sourceNodes),1);
for i=demandNodes
    tmp = tmp+1;
    Aeq2(tmp,i) = 1;
end
beq2 = [beq2; ones(length(demandNodes),1)];
%% Solving combined MILP
% Lower and upper bounds/bianry constraint
lowerBound=zeros(1,nodesNum+edgesNum);
upperBound=ones(1,nodesNum+edgesNum);
%Integer constraint
intcon2 = 1:nodesNum+edgesNum;
[x,fval,exitflag,info] = intlinprog(f2,intcon2,A2,b2,Aeq2,beq2,lowerBound,upperBound);
partitionDemand=find(x(1:nodesNum))';
partitionSource=setdiff(1:nodesNum,partitionDemand);