function [axTicks,axTickLabels]=transformAxisLabels(axisHandle,cofactor,varargin)
%transforms the labels on each specified axis to their raw values when the
%data has been arcsinh-scaled

%Example:
%  x=fca_readfcs('fcs_file.fcs')
%  plot(asinh(x(:,3)/cofactor),asinh(x(:,4)/cofactor),'.')
%  asintransformAxisLabels(gca,cofactor,'x','y')

%Example: %  x=fca_readfcs('fcs_file.fcs')
%  plot3(asinh(x(:,3)/cofactorX),asinh(x(:,4)/cofactorY),asinh(x(:,5)/cofactorZ),'.')
%  asintransformAxisLabels(gca,cofactorX,'x')
%  asintransformAxisLabels(gca,cofactorY,'y')
%  asintransformAxisLabels(gca,cofactorZ,'z')

transformAxisLabels(gca,10,'x','y','z') %transforms all 3 axes


for i=1:length(varargin)
    if ~any(strcmp(varargin{i},{'x' 'y' 'z'}))
        error('Axis choices must be ''x'', ''y'' or ''z''')
    end
    ax=varargin{i};
    axLim=cofactor*sinh(get(axisHandle,[ax 'lim']));
    axMin=floor(log10(axLim(1)));
    axMax=ceil(log10(axLim(2)));
    
    
    axTicks=[];
    axTickLabels={};
    for j=real(axMin):axMax
        axTicks=[axTicks (1:9)*10^j];
        axTickLabels=[axTickLabels num2str(10^j) repmat(cell(1),[1 8])];
    end
    axTicks=[axTicks 10^(j+1)];
    axTickLabels=[axTickLabels num2str(10^(j+1))];
    
    if axLim(1)<0
        negInd=find(axTicks>abs(axLim(1)),1,'first');
        axTicks=[-1*fliplr(axTicks(1:negInd)) 0 axTicks];
        
        flipLabel=fliplr(axTickLabels(2:negInd));
        flipLabel(~cellfun(@isempty,flipLabel))=strcat('-',flipLabel(~cellfun(@isempty,flipLabel)));
        axTickLabels=[flipLabel cell(1) '0' cell(1) axTickLabels(2:end)];
    elseif axLim(1)==0
        axTicks=[0 axTicks];
        axTickLabels=['0' cell(1) axTickLabels(2:end)];
    end
    
    set(axisHandle,[ax 'tick'],asinh(axTicks/cofactor),[ax 'ticklabel'],axTickLabels)
end