function [xstats,ax,nax]=dose_contour(x,ax)
% [medians,axis]=dose_contour(x)
% x is a structure array of length equal to the number of doses that contains the following fields:
%   data = an Nx2 matrix of the data for the hidden x-axis and y-axis, already transformed if necessary
%   doseLabel = the label for each dose
% ax is an axis handle (optional)

if nargin<2
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
        
        fmat=densityMatrix;
        
        [~,mx]=max(max(fmat,[],2)); %row index of fmat where max occurs
        xMed=paramGrid{1}(mx,1); %x-value of max density
        
        xAbove=sum(fmat>c(1),2); 
        x1=paramGrid{1}(find(xAbove,1,'first')); %min x-value of lowest contour
        x2=paramGrid{1}(find(xAbove,1,'last')); %max x-value of lowest contour

        
        yAbove=sum(fmat>c(1),1);
        y1=paramGrid{2}(1,find(yAbove,1,'first')); %min y-value of lowest contour
        y2=paramGrid{2}(1,find(yAbove,1,'last')); %max y-value of lowest contour
              
        xW=max(x2-xMed,xMed-x1);
        
        %adjust x-axis to center plot at highest density
        set(nax(i),'xLim',[xMed-2*xW xMed+2*xW]);
        
        %keep track of y-limits
        yL(i,1)=2*y1-y2;
        yL(i,2)=2*y2-y1;
        
    end
end

%set all y-limits to widest range
yLmax=max(yL(:,2));
yLmin=min(yL(:,1));

for i=1:n
    set(nax(i),'ylim',[yLmin yLmax],'visible','off');
end


set(gcf,'CurrentAxes',ax)
errorbar(0.5:n-0.5,[xstats.median],[xstats.sem],'.-','color',[0 0 1]);
set(ax,'ylim',[yLmin yLmax],...
    'color','none',...
    'activepositionproperty','position',...
    'xtick',0.5:n-0.5,...
    'xticklabel',{x.doseLabel})

set(gcf,'children',[ax; nax])

