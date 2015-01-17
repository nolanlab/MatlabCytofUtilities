function [densityMatrix,paramGrid,densityLevel]=estimateDensity(x,boundaryPerc,numBins)
% [densityMatrix,xm,ym,denslevel]=densityGrid(x,boundaryPerc,numBins) returns a
% matrix of estimated densities determined by the distribution of the data
% in x. 
% 
% Inputs: 
% 
% x, an n x d matrix of n events (i.e. cells) and d parameters.
% boundaryPerc, an optional  amount of space to add in each dimension,
%     which may be useful if there are a lot of events
%     piled up near the min or max. Its units are in 'percent of data range in
%     that dimension', so that if the range of the ith dimension of the data
%     were [0,10], choosing boundaryPerc=10 would compute the density estimate
%     over a grid with range [-1,11] in that dimension.
% numBins, the number of bins each dimension, which defaults to 128.
% 
% Outputs:
% 
% densityMatrix, a matrix of estimated densities. densityMatrix has d dimensions each of
%     which is numBins. For example, if x is an n x 2 matrix and numBins=128,
%     then densityMatrix is an 128 x 128 matrix.
% paramGrid, a cell array where each cell is the grid vector for the ith
%     dimension, i.e. the output from ndgrid
% densityLevel, a vector the same length as x listing the estimated density
%     at the location of each data point. Useful for coloring scatter plots
%     by density
%
% The density estimate is a d-dimensional adaptation of what is found in
% Walther et al., Automatic clustering of flow cytometry data with
% density-based merging, Advances in bioinformatics, 2009.

%default number of bins in each dimension is 128
if nargin<3
    numBins=128;
end

%default to not add any boundary
if nargin<2
    boundaryPerc=0;
end


n=size(x,1);  %number of data points
d=size(x,2);  %number of dimensions 
numBinsTotal = numBins^d; %number of total gridpoints

mins=min(x,[],1);
maxs=max(x,[],1);
Diff=maxs-mins;

%adjust mins and maxs if adding boundary
mins=mins-boundaryPerc/100*Diff;
maxs=maxs+boundaryPerc/100*Diff;

%vector of distances between neighbor grid points in each dimension
Delta = 1/(numBins-1)*(maxs-mins);  


ye=zeros(d,numBins);
multby=zeros(1,d);  %used in coord transfrom from m to k
pointLL=zeros(n,d);  %this will be the "lower left" gridpoint to each data point
for i = 1:d
    ye(i,:) = linspace(mins(i),maxs(i),numBins);
    multby(i)=numBins^(i-1);
    pointLL(:,i)=floor((x(:,i)-mins(i))./Delta(i)) + 1;
end
pointLL(pointLL==numBins)=numBins-1;  %this avoids going over grid boundary

%% assign each data point to its closest grid point

%old 2-D version. z needs to be transposed due to meshgrid conventions.
%GridAssign is equal in d-dim version below to what it would be here if d=2.
% [xgrid,ygrid]=meshgrid(ye(1,:),ye(2,:));
% z=reshape(1:numBinsTotal,numBins,numBins);
% GridAssign=interp2(xgrid,ygrid,z',x(:,1),x(:,2),'nearest');  %this associates each data point with its nearest grid point

z=reshape(1:numBinsTotal,repmat(numBins,[1 d]));
gridVars='';
xVals='';
yeVals='';
for i=1:d
    gridVars=[gridVars ['xi' num2str(i) ',']];
    xVals=[xVals ['x(:,' num2str(i) '),']];
    yeVals=[yeVals ['ye(' num2str(i) ',:),']];
end
%remove trailing commas
gridVars(end)=[];
xVals(end)=[];
yeVals(end)=[]; 

eval(['[' gridVars '] = ndgrid(' yeVals ');'])
z=reshape(1:numBinsTotal,repmat(numBins,[1 d]));
eval(['GridAssign = interpn(' gridVars ',z,' xVals ',''nearest'');'])
    
%% compute w
Deltmat=repmat(Delta,n,1);
shape=numBins*ones(1,d);
wmat=zeros(shape);

indCombs=[0 1];
for i=2:d
    indCombs=combvec(indCombs,[0 1]);
end
indCombs=fliplr(indCombs');
numCombs=size(indCombs,1); %this should be 2^d;

for i=1:numCombs
    pointm=pointLL+repmat(indCombs(i,:),n,1);  %indices of ith neighboring gridpoints
        pointy=zeros(n,d);
        for k=1:d
            pointy(:,k)=ye(k,pointm(:,k));  %y-values of ith neighboring gridpoints
        end
        W=prod(1-(abs(x-pointy)./Deltmat),2);  %contribution to w from ith neighboring gridpoint from each datapoint
        wmat=wmat+accumarray(pointm,W,shape);  %sums contributions for ith gridpoint over data points and adds to wmat
end


%% compute f, sig, df and A
n6 = n^(-1/6);

Zin=cell(1,d);
ZVars='';
LVars='';

h=std(x)*n6;
Z=min(floor(4*h./Delta),numBins-1);
for i =1:d
    Zin{i}=-Z(i):Z(i);
    ZVars=[ZVars ['Zin{' num2str(i) '},']];
    LVars=[LVars ['L{' num2str(i) '},']];
end
ZVars(end)=[];
LVars(end)=[];

phi = @(x) 1/sqrt(2*pi)*exp(-x.^2./2);

eval(['[' LVars '] = ndgrid(' ZVars ');'])

Phimat=phi(L{1}*Delta(1)./h(1))./h(1);
for i=2:d
    Phimat=Phimat .* phi(L{i}*Delta(i)./h(i))./h(i);
end

densityMatrix = 1/n*convn(wmat,Phimat,'same');  %d-dim matrix of estimated densities

if nargout>1
paramGrid=cell(1,d);
for i=1:d
   paramGrid{i}=eval(['xi' num2str(i)]);
end
end

if nargout>2
f=reshape(densityMatrix,1,numBinsTotal);
[~,binInd]=histc(f,linspace(0,max(f),64));
densityLevel=binInd(GridAssign);
end
