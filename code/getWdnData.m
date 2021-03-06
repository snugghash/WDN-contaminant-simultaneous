function [model, adjGraph, incGraph, nodesNum, edgesNum, edgeWeights, vulnerableNodes, vulnerableNum, demandNodes, pipeIDs, nodeIDs, pipeStartNodes, pipeEndNodes] = getWdnData(fileName)

% Extracts struct from given file
model = epanet_reader4_extract(fileName);

% Total number of nodes
nodesNum = model.nodes.ntot;
% Number of edges
edgesNum = model.pipes.npipes + model.valves.nv + model.pumps.npumps;

% Vulnerable nodes are the ones of type 'R'
% type='D' => Demands, type='T' => Tanks, type='R' => Reservoirs
vulnerableNodes = find(strcmp(model.nodes.type,'R'));
demandNodes = find(model.nodes.demand>0);
nodeIDs = cell2mat(cellfun(@str2num,model.nodes.id,'un',0).');
vulnerableNodes =  nodeIDs(vulnerableNodes)';
demandNodes = nodeIDs(demandNodes)';
vulnerableNum = length(vulnerableNodes);

%Weights/lengths of pipes
edgeWeights = eye(edgesNum);


%% Get adjacency matrix from pipes
% cell2mat(cellfun(@str2num,model.pipes.ni,'un',0).') outputs a proper
% numeric matrix. The vectors of similar expressions make up the
% corresponding entries (with opposite sign) in the other triangle.
%
% TODO Check if we still need to establish nj->ni. Technically we 
% should establish directed connections for flow AFTER hydraulic 
% simulation, except for valves(which can be done statically).
% Check everytime if negative flow exists, then must switch.
% Or something. This is clearly not the best.
adjGraph = sparse([cell2mat(cellfun(@str2num,model.pipes.ni,'un',0).'); cell2mat(cellfun(@str2num,model.valves.ni,'un',0).'); cell2mat(cellfun(@str2num,model.pumps.ni,'un',0).')], [cell2mat(cellfun(@str2num,model.pipes.nj,'un',0).'); cell2mat(cellfun(@str2num,model.valves.nj,'un',0).'); cell2mat(cellfun(@str2num,model.pumps.nj,'un',0).')], ones(1,model.pipes.npipes + model.valves.nv + model.pumps.npumps));
adjGraph(nodesNum,nodesNum) = 0;

%% Edges
% Retrieve the mapping from IDs in the retrieved thingy(the index of pipeIDs) to the actual edges numbering on the network model as in *.inp file.
% From here on out, pipe* refers to stuff in the internal number of the stored/retrieved data.
pipeIDs = [cell2mat(cellfun(@str2num,model.pipes.id,'un',0).'); cell2mat(cellfun(@str2num,model.valves.id,'un',0).'); cell2mat(cellfun(@str2num,model.pumps.id,'un',0).')];
pipeStartNodes = [cell2mat(cellfun(@str2num,model.pipes.ni,'un',0).'); cell2mat(cellfun(@str2num,model.valves.ni,'un',0).'); cell2mat(cellfun(@str2num,model.pumps.ni,'un',0).')];
pipeEndNodes = [cell2mat(cellfun(@str2num,model.pipes.nj,'un',0).'); cell2mat(cellfun(@str2num,model.valves.nj,'un',0).'); cell2mat(cellfun(@str2num,model.pumps.nj,'un',0).')];

%% Negative flows
% These are numbered according to the network model's edges, not according to pipeIDs
negativeEdges = readNegativeFlows('report.out');
% Find the pipeIDs corresponding to the edges of negativeEdges
pipeIdxs = arrayfun(@(x)find(pipeIDs==x,1),negativeEdges);
changeToNegativeStartNodes = pipeStartNodes(pipeIdxs);
changeToNegativeEndNodes = pipeEndNodes(pipeIdxs);
idx1 = sub2ind(size(adjGraph), changeToNegativeStartNodes, changeToNegativeEndNodes);
idx2 = sub2ind(size(adjGraph), changeToNegativeEndNodes, changeToNegativeStartNodes);
adjGraph(idx1) = 0; %Change to zero for existing, create new edge for the transpose position. Changed from negative edges because of graphtraverse ignoring negative edges.
adjGraph(idx2) = 1;

%% Get incidence matrix
%incGraph1 = adj2inc(adjGraph);

% This matrix is in the order of pipeIDs, not network edges.
incGraph3 = sparse([(1:size(pipeStartNodes,1))';(1:size(pipeStartNodes,1))'], [pipeStartNodes;pipeEndNodes], [ones(size(pipeStartNodes,1),1);-1*ones(size(pipeStartNodes,1),1)]);
for i=1:size(pipeIdxs)
    incGraph3(pipeIdxs(i),:) = -incGraph3(pipeIdxs(i),:);
end
%for i=1:150
%    assert(size(find(incGraph3(:,i)),1)==size(find(incGraph1(:,i)),1));
%end
incGraph = incGraph3;

