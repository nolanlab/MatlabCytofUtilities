function [contourLevels, percentiles] = percentileContour(densityMatrix,paramGrid,fracs)
%contourLevels = probability_contours(densityMatrix,fracs) returns a vector
%of densities that approximately correspond to the levels of the fractions in fracs.
% 
%Inputs: densityMatrix, an NxN matrix of densities over a grid such as produced from estimateDensity.m with 2-dimensional data
% fracs, the fractions at which you want to plot contours (such as 0.1:0.1:0.9)
% 
% Outputs: v is a vector the same length as fracs with the densities
%   corresponding to the input fractions
% 
% Example: 
% x=[randn(1000,2); [0.5*randn(1000,1)+2 randn(1000,1)]; [randn(1000,1) 3*randn(1000,1) + 3]];
% [densityMatrix,paramGrid,densityLevel]=estimateDensity(x);
% contourLevels = percentileContour(densityMatrix,paramGrid);
% figure
% hold on
% plot(x(:,1),x(:,2),'.')
% contour(paramGrid{1},paramGrid{2},densityMatrix,contourLevels,'k','linewidth',1.5)


if nargin<3
fracs=0.1:0.1:0.9;  %the percentages at which you want to plot contourss
end

dA=prod(([paramGrid{1}(end) paramGrid{2}(end)]-[paramGrid{1}(1) paramGrid{2}(1)])/size(densityMatrix,1));

fdA=densityMatrix(:)*dA;
maxf=max(fdA(:));
fints=linspace(0,maxf,1000);
s=0;
contourLevels=zeros(size(fracs));
percentiles=zeros(size(fracs));
j=1;
for i=1:length(fracs)    
    while s<fracs(i) && j <= length(fints)
    fi=fints(j);
    s=sum(fdA(fdA<fi));
    j=j+1;
    end
   contourLevels(i)=fi/dA;  %these will be the density levels corresponding to the probabilities listed in fracs
   percentiles(i)=s; 
end