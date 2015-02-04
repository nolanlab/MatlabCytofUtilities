function make_rain(filename,varargin)
% makes a figure from an imd file similar to the "rain" seen on the cytof software while
% processing data

freq=76.8; %kHz
time=0;

% parse xml tail at end of imd file for analytes and dual slopes
str=get_imd_xml(filename);
str=str(1:2:length(str));

acqXml=regexp(str,'<AcquisitionMarkers>.+</AcquisitionMarkers>','match');
acqShortnames=regexp(acqXml{1},'<ShortName>([^<>]+)</ShortName>','tokens');
colnames=cat(1,acqShortnames{:});

acqMasses=regexp(acqXml{1},'<Mass>([^<>]+)</Mass>','tokens');
masses=str2double(cat(1,acqMasses{:}));

num_cols=length(masses);

num_rows=1000;
dt=num_rows/freq;


fig=figure('KeyPressFcn',@rain);
colormap(flipud(bone));
fid=fopen(filename,'r');

% if length(varargin)>0
if nargin>1
    byte_chunk=4*num_cols*num_rows;  %number bytes in one screen scroll
    cycle_num=freq*varargin{1};  %desired cycle number
    chunks_before=floor(cycle_num/num_rows);  %
    startpos=byte_chunk*chunks_before;  
    oldtime=chunks_before*num_rows/freq;
    time=(chunks_before + 1)*num_rows/freq;
else
    startpos=0;
    oldtime=0;
    time=dt;
end

fseek(fid,startpos,'bof');
window=[oldtime time];
plot_rain(time,oldtime);



    function rain(src,event)
        
        if strcmp(event.Key,'downarrow')
            oldtime=time;
            time=time+num_rows/freq;
            plot_rain(time,oldtime);

            
        elseif strcmp(event.Key,'uparrow');
            current_pos=ftell(fid);
            offset=2*4*num_cols*num_rows;
            newpos=current_pos-offset;
            if newpos >= 0
            fseek(fid,-offset,0);  %move to where just started, and then back one more
            time=oldtime;
            oldtime=oldtime-num_rows/freq;
            plot_rain(time,oldtime);
            end
        else
            
            window=[oldtime time];
            
            fclose(fid);
            close(fig)
            return;
        end
    end




    function plot_rain(t2,t1)
        x=fread(fid,[num_cols*2 num_rows],'uint16')';
        intensity=x(:,1:2:2*num_cols);
        
        numbins=10;
        n=30;
        
        maxd=max(asinh(max(intensity(:))/5),1);
        edges=5*sinh(linspace(1,maxd,numbins+1));
        [~,bins]=histc(intensity,edges);
        z=zeros(num_rows,n*num_cols+num_cols*2);
        for i=1:num_cols
            for j=1:numbins
                z(bins(:,i)>(j-1),[i*n-(j-1) i*n+(j-1)])=1;
            end
        end
        
        imagesc(z);

        timestamps=(ceil(t1):floor(t2))';
        timelabels=cellstr(num2str(timestamps));
        yticks=(timestamps-t1)*freq;
        
        set(gca,'xtick',n:n:num_cols*n,'xticklabel',[],'ytick',yticks,'yticklabel',timelabels)
        t=text(n:n:num_cols*n,(num_rows+10)*ones(1,num_cols),colnames,'rotation',45,'horizontalalignment','right','fontsize',10);
        ylabel('ms','fontsize',12)
    end


end