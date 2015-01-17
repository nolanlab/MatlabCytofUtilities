function ord=get_fcs_order(hcell)
%ord=get_fcs_order(hcell) where hcell is c array of fcs headers and ord is
%list of integers labeling where hcell{i} came in sequence


dns=zeros(1,length(hcell));

for i=1:length(hcell)
    dn=[hcell{i}.date ' ' hcell{i}.starttime];
    if length(dn)>1
    dns(i)=datenum(dn);
    else
        display('No date information in header!');
        dns(i)=Inf;
    end
end

[~,ord]=sort(dns);