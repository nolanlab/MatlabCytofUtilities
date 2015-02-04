function plot_imd_by_window(filename,push_list,cols,datatype,cell_ind)
% plot_imd_by_window(filename,push_list,cols,datatype,cell_ind)
%
% plots a range of pushes of an imd file in two panels
% the upper subplot shows the summed intensities over all analytes,
%   plus the smoothed sum, and any cell boundaries as input in the
%   push_list
% the lower subplot shows the intensities, pulses, or dual counts of a
% subset of the analytyes as input in cols
% 
% the plot can be interactively advanced to the next chunk or
% sent back to previous chunk by pressing the down and up arrows,
% respectively, or the figure and file can be closed by pressing q      
%
% filename is name of an imd file
% push_list is an nx2 matrix where the first column is the leading push and
%    the second column is the terminating push of cells. it may be set as empty if
%    cell boundaries are not known
% cols are the column indices of the imd file that will be shown in the bar
%   plot in the lower subplot
% datatype is either 'intensity','pulse', or 'dual' indiciating which of
%   those choices to plot in the lower subplot, which defaults to intensity
% cell_ind is the cell index on which to start plotting, which defaults to
% 1


if ~isempty(push_list)
    leading_pushes=push_list(:,1);
    ending_pushes=push_list(:,2);
else
    leading_pushes=[];
    ending_pushes=[];
end

% default to show intensity if data type not specified
if nargin<4
    datatype='intensity';
end

% create filter for kernel smoothing
sigma=3;
ls=-10:10;
gaussFilter=exp(-ls.^2./(2*sigma^2));
gaussFilter=gaussFilter./sum(gaussFilter);

% parse xml tail at end of imd file for analytes and dual slopes
str=get_imd_xml(filename);
str=str(1:2:length(str));

acqXml=regexp(str,'<AcquisitionMarkers>.+</AcquisitionMarkers>','match');
acqShortnames=regexp(acqXml{1},'<ShortName>([^<>]+)</ShortName>','tokens');
colnames=cat(1,acqShortnames{:});

acqMasses=regexp(acqXml{1},'<Mass>([^<>]+)</Mass>','tokens');
masses=str2double(cat(1,acqMasses{:}));

num_cols=length(masses);

if strcmp(datatype,'dual')
% get dual masses, slopes and intercepts
dualXml=regexp(str,'<DualAnalytesSnapshot>.+</DualAnalytesSnapshot>','match');

massCell=regexp(dualXml,'<Mass>([0-9\.]+)</Mass>','tokens');
dualMasses=str2double(cat(1,massCell{1}{:}));

interceptCell=regexp(dualXml,'<DualIntercept>([0-9\.\-]+)</DualIntercept>','tokens');
dualIntercepts=str2double(cat(1,interceptCell{1}{:}));

slopeCell=regexp(dualXml,'<DualSlope>([0-9\.\-]+)</DualSlope>','tokens');
dualSlopes=str2double(cat(1,slopeCell{1}{:}));

slopes=interp1(dualMasses,dualSlopes,masses);
intercepts=interp1(dualMasses,dualIntercepts,masses);

end


fig=figure('KeyPressFcn',@rain,'papersize',[16 8],'paperposition',[0 0 16 8],'color','w');
co=get(0,'DefaultAxesColorOrder');
colormap(co(1:6,:));

fid=fopen(filename,'r');

%default to starting at first push
if nargin<5
    cell_ind=1;
end
   

num_rows=1024; %number of pushes to show in a window



if ~isempty(push_list)
    oldpush=floor(push_list(cell_ind,1)/num_rows)*num_rows;
else
    oldpush=0;
end
startpos=oldpush*4*num_cols; %each push is 4 bytes, 16-bits for pulse and intensity each

push=oldpush+num_rows-1;


fseek(fid,startpos,'bof');

data=plot_rain(oldpush,push);



    function rain(src,event)
        % either advances to next push window by pressing the downarrow, or
        % goes back to previous push window by pressing the uparrow, or
        % closes the figure and the file by pressing q
        
        if strcmp(event.Key,'downarrow')
            
            cell_ind=cell_ind+1;
            set(fig,'Name',num2str(cell_ind))
            oldpush=oldpush+num_rows;
            push=push+num_rows;
            data=plot_rain(oldpush,push);
            
            
        elseif strcmp(event.Key,'uparrow');
            cell_ind=cell_ind-1;
            set(fig,'Name',num2str(cell_ind))
            
            oldpush=oldpush-num_rows;
            push=push-num_rows;
            data=plot_rain(oldpush,push);
            
        elseif strcmp(event.Key,'q');
            fclose(fid);
            close(fig)
            return;
        end
    end


    function intensity=plot_rain(p1,p2)
        % read the imd file and plot the results for the data from
        % push p1 through push p2
        num_rows=p2-p1+1;
        startpos=p1*4*num_cols;
        fseek(fid,startpos,'bof');
        x=fread(fid,[num_cols*2 num_rows],'uint16')';
        intensity=x(:,1:2:2*num_cols);
        pulse=x(:,2:2:2*num_cols);
        
        if strcmp(datatype,'dual')
            %calculate dual values
            dual_start_val=1; %this is the current default in the cytof software
            dual=zeros(size(intensity));
            for j=1:num_cols
                dual(:,j)=round(intensity(:,j)*slopes(j)+intercepts(j));
                use_duals=pulse(:,j)<=dual_start_val & dual(:,j)<pulse(:,j);
                dual(use_duals,j)=pulse(use_duals,j);
            end
        end
        
        summed_int=sum(intensity,2);
        int_conv=conv(summed_int,gaussFilter,'same');
        
        % plot the summed intensity, the smoothed summed intensity, and the
        % cell boundaries in the top subplot 
        subplot(2,1,1)
        cla
        
        hold on
        pl=plot(p1:p2,int_conv,'k');
        pl2=plot(p1:p2,summed_int,'color','k','linestyle','--');
        
        
        leaders=leading_pushes(leading_pushes>=p1 & leading_pushes<=p2);
        enders=ending_pushes(ending_pushes>=p1 & ending_pushes<=p2);
        
        yl=max(200,max(summed_int));
        
        l1=line([leaders'; leaders'],[zeros(size(leaders')); yl*ones(size(leaders'))],'color',[0 0.5 0],'linestyle','-','linewidth',2);
        l2=line([enders'; enders'],[zeros(size(enders')); yl*ones(size(enders'))],'color',[1 0 0],'linestyle','-','linewidth',2);
        
        
        if ~isempty(l1) && ~isempty(l2)
            legend([pl pl2 l1(1) l2(1) ],{'summed intensity' 'convolved summed intensity' 'start of cell event' 'end of cell event'});
        else
            legend([pl pl2  ],{'summed intensity' 'convolved summed intensity' });
        end
        
        
        set(gca,'ylim',[0 yl],'xlim', [p1 p2],'box','on')
        ylabel('summed intensity')
        xlabel('push number')
        
        % plot the columns of intereste of the chosen data type in the
        % lower subplot
        subplot(2,1,2)
        
        switch datatype
            case 'intensity'
                bar(p1:p2,intensity(:,cols),'stacked')
            case 'pulse'
                bar(p1:p2,pulse(:,cols),'stacked')
            case 'dual'
                bar(p1:p2,dual(:,cols),'stacked')
        end
        
        set(gca,'xlim',[p1 p2])
        xlabel('push number')
        legend(colnames(cols));
        
        
    end

end