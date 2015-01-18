function [xstats,ax]=dose_contour(x,ax)
% [medians,axis]=dose_contour(x)
% x is a structure array of length equal to the number of doses that contains the following fields:
%   data = an Nx2 matrix of the data for the hidden x-axis and y-axis, already transformed if necessary
%   doseLabel = the label for each dose
% ax is an axis handle (optional)

if nargin<3
    ax=gca;
end

axloc=get(ax,'position');

n=length(x);

nax=zeros(n,1);
yL=nan(n,1);
xstats(n).median=nan;
xstats(n).std=nan;
xstats(n).sem=nan;


for i=1:n
    xstats(i).median=median(x(i).data(:,2));
    xstats(i).std=std(x(i).data(:,2));
    xstats(i).sem=xstats(i).std/sqrt(size(x(i).data,1));
    
    nax(i)=axes('position',[axloc(1) + (i-1)*axloc(3)/n, axloc(2), axloc(3)/n, axloc(4)]);
    
    if ~isempty(x(i).data)
        [densityMatrix,paramGrid]=estimateDensity(x(i).data);
        contourLevels = percentileContour(densityMatrix,paramGrid,0.2:0.2:0.8);
%         plot(x(i).data(:,1),x(i).data(:,2),'.')
%         hold on
        c=contour(paramGrid{1},paramGrid{2},densityMatrix,contourLevels,'color',[0 0 0],'linewidth',0.2);
%         hold off
        
        %transpose fmat to match old convention?
        fmat=densityMatrix;
        
        [~,mx]=max(max(fmat,[],2)); %row of fmat where max occurs
        xMed=paramGrid{1}(mx,1);
        
        x1=paramGrid{1}(find(fmat > c(1),1,'first'));
        x2=paramGrid{1}(find(fmat > c(1),1,'last'));
        
        yAbove=sum(fmat>c(1),1);
        y1=paramGrid{2}(1,find(yAbove,1,'first'));
        y2=paramGrid{2}(1,find(yAbove,1,'last'));
              
        xW=max(x2-xMed,xMed-x1);
        
        set(nax(i),'xLim',[xMed-2*xW xMed+2*xW]);
        yL(i,1)=2*y1-y2;
        yL(i,2)=2*y2-y1;
        
    end
end

yLmax=max(yL(:,2));
yLmin=min(yL(:,1));

for i=1:n
    set(nax(i),'ylim',[yLmin yLmax],'visible','off');
end


set(gcf,'CurrentAxes',ax)
errorbar(0.5:n-0.5,[xstats.median],[xstats.sem],'.-','color',[0 0 1]);
set(ax,'ylim',[yLmin yLmax],'color','none','activepositionproperty','position')

