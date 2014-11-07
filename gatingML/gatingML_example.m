xml_filename='example_gatingML.xml'; 
fcs_filename='example_cytof_data_for_gatingML.fcs'; 
% these data are adapted from the publically available data
% https://www.cytobank.org/nolanlab/Normalization_of_Mass_Cytometry_Data_with_Bead_Standards.acs


%read data from fcs file
[~,fcs_hdr,fcs_data]=fca_readfcs(fcs_filename);

obj=gatingML(xml_filename); %create gatingML object
obj=obj.load_fcs_file(fcs_data,fcs_hdr); %associate the fcs data with these gates

%Note that gate names as specified in the Gating-ML file may be adjusted to
%fit variable name requirements. The original name can be found in 
%obj.gates.(gate_name).name

%apply all gates and report number of cells in each
gateNames=fieldnames(obj.gates);
numGates=length(gateNames);
for i=1:numGates
    obj=obj.apply_gate(gateNames{i});
    num_cells=nnz(obj.gates.(gateNames{i}).inGate);
    display([num2str(num_cells) ' cells found in gate ' obj.gates.(gateNames{i}).name])
end

%scatter plot of uncompensated data within a gate using a transformation from 
%the Gating-ML file
trans_names=fieldnames(obj.transforms)

%suppose want to use transformation 'Tr_Arcsinh' and overlay the data in gate 'CD4posTcells'
%on the data in gate 'Tcells' in a biaxial plot of CD4 x CD8

%in this fcs file, CD4 and CD8 are in the 6th and 7th columns. check this:
CD4_col=4;
CD8_col=5;
myParams=obj.fcsData.uncompensated.params([CD4_col CD8_col]) %list of measured parameters of uncompensated data

%create matrix of transformed CD4 and CD8 values of Tcells and of CD4+Tcells
uncompData=obj.fcsData.uncompensated.data; %the full matrix of uncompensated data

Tcell_bool=obj.gates.Tcells.inGate; %logical vector indicating each cell's inclusion in the T cell gate
Tcell_data=uncompData(Tcell_bool,[CD4_col CD8_col]); % filtered data to chosen parameters and cells in the gate
Tcell_data_transformed=obj.transforms.Tr_Arcsinh.fun(Tcell_data); %apply transformation to data

CD4_bool=obj.gates.CD4posTcells.inGate; %logical vector indicating each cell's inclusion in the CD4+Tcell gate
CD4Tcell_data=uncompData(CD4_bool,[CD4_col CD8_col]); % filtered data to chosen parameters and cells in the gate
CD4Tcell_data_transformed=obj.transforms.Tr_Arcsinh.fun(CD4Tcell_data); %apply transformation to data

%make the figure
figure
hold all
plot(Tcell_data_transformed(:,1),Tcell_data_transformed(:,2),'.','markersize',2) %scatter plot of data
plot(CD4Tcell_data_transformed(:,1),CD4Tcell_data_transformed(:,2),'.','markersize',2) %scatter plot of data
xlabel(myParams{1})
ylabel(myParams{2})

%   References:
% 
%    1. Kotecha N, Krutzik PO, Irish JM. Web-based Analysis and Publication
%       of Flow Cytometry Experiments. Current Protocols in Cytometry 2010
%       Jul, Chapter 10, Unit10.17. PMID: 20578106.