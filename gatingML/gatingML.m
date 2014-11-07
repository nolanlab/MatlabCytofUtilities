classdef gatingML
    %gatingML class.
    %   An object of the gatingML class is a set of compensations,
    %   transformations, and gates as defined by a Gating-ML file.
    %
    %   To create a gatingML object by specifying the Gating-ML file, use the
    %   gatingML constructor.  To associate the gatingML
    %   object with a particular fcs file, use the load_fcs_file method. To apply
    %   gates to the loaded fcs file, use the apply_gate method.
    %
    %   gatingML requires the XMLNode function (#34711) and the fca_readfcs
    %   function (#9608) available on the Mathworks File Exchange. If you will
    %   be using the logicle and/or hyperlog transformations, you will need the
    %   logicleTransform (#45022) and/or hyperlogTransform (#45034).
    %
    %   A gatingML object has the following properties:
    %
    %      xml  An XMLNode object created from the Gating-ML file
    %      transforms     A structure array of transformations included in the
    %           Gating-ML file. A function to apply a transformation with name
    %           trans_name is found in obj.transforms.(trans_name).fun
    %      comps  A structure array of compensations included in the Gating-ML
    %           file, each including the compensation matrix and relevant parameters
    %      gates  A structure array of gates included in the Gating-ML file,
    %           with fields listing original gate name, parent gate, and gate type.
    %           The method apply_gate adds the field inGate, which is a logical
    %           vector indicating each cell's inclusion in the gate.
    %      fcsData  A structure array of compensated data matrices, which are
    %           created by gatingML.load_fcsfile. The original data is assumed
    %           to have the channel-to-scale transformations already applied.
    %           To load this data from an fcs file, use the third output (fcsdatscaled)
    %           from the function fca_readfcs. The method load_fcs_file
    %           then creates a matrix and list of relevant parameters for each compensation.
    %      fcsHdr  An fcs file header created from fca_readfcs.m, which is
    %           created by the method load_fcs_file
    %
    %   References:
    %
    %           J. Spidlen, International Society for the Advancement of
    %           Cytometry Data Standards Task Force, and Brinkman, R.R. (2013).
    %           Gating-ML 2.0 -- International Society for Advancement of
    %           Cytometry (ISAC) stanford for representing gating descriptions
    %           in flow cytometry. Retrieved from http://flowcyt.sourceforge.net/gating/20130122.pdf
    %
    %           J. Spidlen and N. Gopalakrishnan. gatingMLData: Data and XML
    %           files for Gating-ML Test suite. R package version 2.1.4.
    
    
    
    
    properties
        xml
        transforms
        comps
        gates
        fcsData
        fcsHdr
    end
    
    methods
        
        function obj=gatingML(xml_filename)
            %obj=gatingML(xml_filename) loads in a gating-ML file,
            %including all transformations, compensations and gates listed
            
            if ~exist('XMLNode.m','file')
                error('XMLNode not found on your search path.')
            end
            
            if exist('logicleTransform','file')~=3
                warning('logicleTransform not found on your search path. You will not be able to apply logicle transformations.')
            end
            
            if exist('hyperlogTransform','file')~=3
                warning('hyperlogTransform not found on your search path. You will not be able to apply hyperlog transformations.')
            end
            
            currentdir=pwd;
            [pathstr,fname,ext] = fileparts(xml_filename);
            if ~isempty(pathstr)
                cd(pathstr)
            end
            
            XMLNode.initialize
            obj.xml=XMLNode([fname ext]);
            if ~isempty(pathstr)
                cd(currentdir);
            end
            obj=load_transforms(obj);
            
            obj=load_compensations(obj);
            
            obj=load_gates(obj);
        end
        
        
        function obj=load_fcs_file(obj,fcs_data,fcs_hdr)
            %obj=obj.load_fcs_file(fcs_data,fcs_hdr) loads in data from an fcs
            %file. It assumes that the the channel-to-scale transformations
            %as specifieed by the $PnE and $PnG keywords have already
            %been applied, e.g., the  third output 'fcsdatscaled' from the
            %fca_readfcs.m function. Any compensation matrices stored in
            %the fcs_hdr will be added to the compensation list.
            %EXAMPLE:
            %[fcs_unscaled,fcs_hdr,fcs_data]=fca_readfcs(filename);
            %obj=obj.load_fcs_file(fcs_data,fcs_hdr);
            
            obj.fcsHdr=fcs_hdr;
            params={fcs_hdr.par.name};
            
            %add fcs compensation
            if ~isempty(fcs_hdr.CompMat)
                obj.comps.fcs.isInverted=false;
                obj.comps.fcs.matrix=fcs_hdr.CompMat; %uncompData/matrix;
                obj.comps.fcs.fluors=fcs_hdr.CompLabels;
                obj.comps.fcs.dets=fcs_hdr.CompLabels;
            end
            
            %compute compensated data for all compensations
            if ~isempty(obj.comps)
                compNames=fieldnames(obj.comps);
                num_comps=length(compNames);
                for i=1:num_comps
                    comp=obj.comps.(compNames{i});
                    num_dets=length(comp.dets);
                    det_inds=zeros(1,num_dets);
                    for j=1:num_dets
                        det_inds(j)=find(strcmp(comp.dets{j},params)); %col of fcs file
                        if isempty(det_inds)
                            error(['Parameter listed in compensation ' compNames{i} ' not found in fcs file.'])
                        end
                    end
                    uncompData=fcs_data(:,det_inds);
                    if comp.isInverted
                        obj.fcsData.(compNames{i}).data=uncompData*comp.matrix;
                    else
                        obj.fcsData.(compNames{i}).data=uncompData/comp.matrix;
                    end
                    obj.fcsData.(compNames{i}).params=comp.fluors;
                end
            end
            
            %attach uncompensated data
            obj.fcsData.uncompensated.data=fcs_data;
            obj.fcsData.uncompensated.params=params;
        end
        
        function obj=apply_gate(obj,gate_name)
            %obj=obj.apply_gate(gate_name) adds the field 'inGate' to the
            %gate struct with name gate_name. inGate is a logical vector
            %the size of fcs_data with true indicating a cell's inclusion
            %in the gate. if the gate has a parent gate, the parent gate
            %must be applied first
            
            %check for fcs data
            if isempty(obj.fcsData)
                error('You must first load fcs data.')
            end
            gate_var=genvarname(gate_name);
            gate_id=obj.gates.(gate_var).name;
            gateType=obj.gates.(gate_var).type;
            num_cells=size(obj.fcsData.uncompensated.data,1);
            
            %check for parent gate
            parent=obj.gates.(gate_var).parent;
            if ~isempty(parent)
                parent_var=genvarname(parent);
                parent_bool=obj.gates.(parent_var).inGate;
                if isempty(parent_bool)
                    error('You must first apply the parent gate.')
                end
            else
                parent_bool=true(num_cells,1);
            end
            
            %apply gate
            switch gateType
                case 'PolygonGate'
                    gate_bool=polygon_gate(obj,gate_id,parent_bool);
                case 'EllipsoidGate'
                    gate_bool=ellipsoid_gate(obj,gate_id,parent_bool);
                case 'RectangleGate'
                    gate_bool=rectangle_gate(obj,gate_id,parent_bool);
                case 'QuadrantGate'
                    gate_bool=quadrant_gate(obj,gate_id,parent_bool);
                case 'BooleanGate'
                    gate_bool=boolean_gate(obj,gate_id,parent_bool);
            end
            
            obj.gates.(gate_var).inGate=false(num_cells,size(gate_bool,2));
            obj.gates.(gate_var).inGate(parent_bool,:)=gate_bool;
        end
        
    end
    
    methods (Access = private)
        
        function obj=load_gates(obj)
            ids=obj.xml{'/gating:Gating-ML/gating:*/@gating:id'}; %note that this has parent quadrant ids, not their actual gate children
            num_ids=length(ids);
            for i=1:num_ids
                y=obj.xml(['/gating:Gating-ML/gating:*[@gating:id="' ids{i} '"]']);
                
                %gate type
                gateNode=getJavaNode(obj.xml(['/gating:Gating-ML/gating:*[@gating:id="' ids{i} '"]']));
                gateType=char(gateNode.getTagName);
                %find parent population
                parent=y{'@gating:parent_id'};
                
                if strcmp(gateType,'gating:QuadrantGate') %special case: split up quadrant gates
                    quad_children_ids=obj.xml{['/gating:Gating-ML/gating:QuadrantGate[@gating:id="' ids{i} '"]/gating:Quadrant/@gating:id']};
                    num_quad_children=length(quad_children_ids);
                    for j=1:num_quad_children
                        gate_var=genvarname(quad_children_ids{j});
                        obj.gates.(gate_var).name=quad_children_ids{j};
                        if ~isempty(parent)
                            obj.gates.(gate_var).parent=parent{1};
                        else
                            obj.gates.(gate_var).parent=[];
                        end
                        obj.gates.(gate_var).type=gateType(8:end); %omit 'gating:'
                        obj.gates.(gate_var).quadParent=ids{i}; %special to quads
                    end
                else
                    gate_var=genvarname(ids{i});
                    obj.gates.(gate_var).name=ids{i};
                    if ~isempty(parent)
                        obj.gates.(gate_var).parent=parent{1};
                    else
                        obj.gates.(gate_var).parent=[];
                    end
                    obj.gates.(gate_var).type=gateType(8:end); %omit 'gating:'
                end
            end
        end
        
        function obj=load_transforms(obj)
            trans_ids=obj.xml{'/gating:Gating-ML/transforms:transformation/@transforms:id'};
            num_trans=length(trans_ids);
            for i=1:num_trans
                trans_prefix=['gating:Gating-ML/transforms:transformation[@transforms:id="' trans_ids{i} '"]/'];
                transNode=getJavaNode(obj.xml([trans_prefix 'transforms:*']));
                transType=char(transNode.getTagName);
                trans_var=genvarname(trans_ids{i});
                obj.transforms.(trans_var).name=trans_ids{i}; %original undoctored id
                switch transType
                    case 'transforms:flin'
                        T=obj.xml{[trans_prefix 'transforms:flin/@transforms:T']};
                        A=obj.xml{[trans_prefix 'transforms:flin/@transforms:A']};
                        obj.transforms.(trans_var).fun=@(d) (d+A)./(T+A);
                    case 'transforms:flog'
                        T=obj.xml{[trans_prefix 'transforms:flog/@transforms:T']};
                        M=obj.xml{[trans_prefix 'transforms:flog/@transforms:M']};
                        obj.transforms.(trans_var).fun=@(d) (1/M*log10(d./T) + 1);
                    case 'transforms:fasinh'
                        T=obj.xml{[trans_prefix 'transforms:fasinh/@transforms:T']};
                        M=obj.xml{[trans_prefix 'transforms:fasinh/@transforms:M']};
                        A=obj.xml{[trans_prefix 'transforms:fasinh/@transforms:A']};
                        obj.transforms.(trans_var).fun=@(d) (asinh(sinh(M*log(10))/T*d) + A*log(10))/((M+A)*log(10));
                    case 'transforms:logicle'
                        T=obj.xml{[trans_prefix 'transforms:logicle/@transforms:T']};
                        W=obj.xml{[trans_prefix 'transforms:logicle/@transforms:W']};
                        M=obj.xml{[trans_prefix 'transforms:logicle/@transforms:M']};
                        A=obj.xml{[trans_prefix 'transforms:logicle/@transforms:A']};
                        obj.transforms.(trans_var).fun=@(d) (logicleTransform(d,T,W,M,A));
                    case 'transforms:hyperlog'
                        T=obj.xml{[trans_prefix 'transforms:hyperlog/@transforms:T']};
                        W=obj.xml{[trans_prefix 'transforms:hyperlog/@transforms:W']};
                        M=obj.xml{[trans_prefix 'transforms:hyperlog/@transforms:M']};
                        A=obj.xml{[trans_prefix 'transforms:hyperlog/@transforms:A']};
                        obj.transforms.(trans_var).fun=@(d) (hyperlogTransform(d,T,W,M,A));
                    case 'transforms:fratio'
                        A=obj.xml{[trans_prefix 'transforms:fratio/@transforms:A']};
                        B=obj.xml{[trans_prefix 'transforms:fratio/@transforms:B']};
                        C=obj.xml{[trans_prefix 'transforms:fratio/@transforms:C']};
                        obj.transforms.(trans_var).fun=@(v1,v2) (A*(v1 - B)./(v2 - C));
                        rat_params=obj.xml{[trans_prefix 'transforms:fratio/data-type:fcs-dimension/@data-type:name']};
                        obj.transforms.(trans_var).params=rat_params;
                end
            end
        end
        
        function obj=load_compensations(obj)
            compNames=obj.xml{'gating:Gating-ML/transforms:spectrumMatrix/@transforms:id'};
            
            num_comps=length(compNames); %number of compensation matrices
            
            for i=1:num_comps
                fluorochromes=obj.xml{['/gating:Gating-ML/transforms:spectrumMatrix[@transforms:id="' compNames{i} '"]/transforms:fluorochromes/data-type:fcs-dimension/@data-type:name']};
                num_fluors=length(fluorochromes);
                detectors=obj.xml{['/gating:Gating-ML/transforms:spectrumMatrix[@transforms:id="' compNames{i} '"]/transforms:detectors/data-type:fcs-dimension/@data-type:name']};
                num_dets=length(detectors);
                
                trans_vals=obj.xml{['/gating:Gating-ML/transforms:spectrumMatrix[@transforms:id="' compNames{i} '"]/transforms:spectrum/transforms:coefficient/@transforms:value']};
                
                isInverted=obj.xml{['/gating:Gating-ML/transforms:spectrumMatrix[@transforms:id="' compNames{i} '"]/@transforms:matrix-inverted-already']};
                
                comp_var=genvarname(compNames{i});
                
                if isempty(isInverted) || strcmp(isInverted{1},'false')
                    obj.comps.(comp_var).isInverted=false;
                    obj.comps.(comp_var).matrix=reshape(trans_vals,[num_dets num_fluors])'; %uncompData/matrix;
                else
                    obj.comps.(comp_var).isInverted=true;
                    obj.comps.(comp_var).matrix=reshape(trans_vals,[ num_fluors num_dets])'; %uncompData*matrix;
                end
                obj.comps.(comp_var).fluors=fluorochromes;
                obj.comps.(comp_var).dets=detectors;
            end
            
        end
        
        function ingate=polygon_gate(obj,gate_id,parent_bool)
            
            xpath_prefix=['/gating:Gating-ML/gating:PolygonGate[@gating:id="' gate_id '"]/'];
            num_pts=nnz(parent_bool);
            pts=zeros(num_pts,2);
            
            %find columns of data in which polygon is drawn
            for j=1:2
                jstr=num2str(j);
                node_prefix=[xpath_prefix 'gating:dimension[' jstr ']/'];
                pts(:,j)=get_data_vec(obj,node_prefix,parent_bool);
            end
            
            %get ordered vertices of polygon
            y=obj.xml{[xpath_prefix 'gating:vertex/gating:coordinate/@data-type:value']};
            n=length(y)/2;
            v1=reshape(y,[2 n])';
            
            %compute winding number (odd wn means in the gate), since built=in
            %inpolygon.m will give a different answer for self-intersecting polygons.
            
            %x-coords of vertices
            a1=repmat(v1(:,1)',[num_pts 1]);
            
            %y-coords of vertices
            b1=repmat(v1(:,2)',[num_pts 1]);
            
            %determinant-like terms
            c11=bsxfun(@minus,a1,pts(:,1));
            c12=bsxfun(@minus,b1,pts(:,2));
            c21=circshift(c11,[0 -1]);
            c22=circshift(c12,[0 -1]);
            
            angs=atan2(c11.*c22 - c12.*c21, c11.*c21 + c12.* c22);
            
            ingate=logical(mod(round(sum(angs,2)./(2*pi)),2));
            
            %check to see if pts are ON any line segments
            dists_to_vertices=sqrt(c11.^2 + c12.^2);
            sum_of_adjacent_dists=dists_to_vertices+circshift(dists_to_vertices,[0 -1]);
            
            dists_between_verts=sqrt(sum((v1-circshift(v1,[-1 0])).^2,2)');
            dists_compare=abs(bsxfun(@minus,sum_of_adjacent_dists, dists_between_verts));
            
            ongate=any(dists_compare<eps,2);
            
            ingate=ingate | ongate;
        end
        
        
        function ingate=ellipsoid_gate(obj,gate_id,parent_bool)
            
            xpath_prefix=['/gating:Gating-ML/gating:EllipsoidGate[@gating:id="' gate_id '"]/'];
            %find columns of data in which ellipsoid is defined
            
            y=obj.xml([xpath_prefix 'gating:dimension']);
            num_dims=length(y);
            num_pts=nnz(parent_bool);
            pts=zeros(num_pts,num_dims);
            
            for j=1:num_dims
                jstr=num2str(j);
                node_prefix=[xpath_prefix 'gating:dimension[' jstr ']/'];
                pts(:,j)=get_data_vec(obj,node_prefix,parent_bool);
            end
            
            %get ordered means of polygon
            mu=obj.xml{[xpath_prefix 'gating:mean/gating:coordinate/@data-type:value']};
            mu=mu';
            
            %get ordered rows of covariance matrix
            c=obj.xml{[xpath_prefix 'gating:covarianceMatrix/gating:row/gating:entry/@data-type:value']};
            c=reshape(c,[num_dims num_dims])';
            
            distanceSquare=obj.xml{[xpath_prefix 'gating:distanceSquare/@data-type:value']};
            
            a=bsxfun(@minus,pts,mu)';
            d=c\a;
            d2=sum(a.*d,1)';
            ingate=d2<distanceSquare;
        end
        
        function ingate=rectangle_gate(obj,gate_id,parent_bool)
            
            xpath_prefix=['/gating:Gating-ML/gating:RectangleGate[@gating:id="' gate_id '"]/'];
            
            %find columns of data in which rectangle is defined
            y=obj.xml([xpath_prefix 'gating:dimension']);
            num_dims=length(y);
            %         cols=zeros(1,num_dims);
            mins=zeros(num_dims,1);
            maxs=zeros(num_dims,1);
            num_pts=nnz(parent_bool);
            pts=zeros(num_pts,num_dims);
            
            for j=1:num_dims
                jstr=num2str(j);
                node_prefix=[xpath_prefix 'gating:dimension[' jstr ']/'];
                pts(:,j)=get_data_vec(obj,node_prefix,parent_bool);
                %get gate boundaries in jth dimension
                m=obj.xml([xpath_prefix 'gating:dimension[' jstr ']/@gating:min']);
                if ~isempty(m)
                    mins(j)=m{1};
                else
                    mins(j)=-inf;
                end
                m=obj.xml([xpath_prefix 'gating:dimension[' jstr ']/@gating:max']);
                if ~isempty(m)
                    maxs(j)=m{1};
                else
                    maxs(j)=inf;
                end
            end
            
            ingate=true(num_pts,1);
            for j=1:num_dims
                ingate=ingate & pts(:,j)>=mins(j) & pts(:,j)<maxs(j);
            end
            %could actually put this inside first loop
            
        end
        
        function ingate=quadrant_gate(obj,gate_id,parent_bool)
            
            quad_id=obj.gates.(genvarname(gate_id)).quadParent; %for now, doing all quads at once via quadParent
            
            %Quadrants: note there will be num_quads gates here, as opposed to 1 in all other types
            xpath_prefix=['/gating:Gating-ML/gating:QuadrantGate[@gating:id="' quad_id '"]/'];
            %parse dividers
            y=obj.xml([xpath_prefix 'gating:divider']);
            num_divs=length(y);
            num_pts=nnz(parent_bool);
            pts=zeros(num_pts,num_divs);
            subids=cell(1,num_divs);
            vals=cell(1,num_divs); %there can be more than one val per div
            
            %read in ids, cols and vals for each divider
            for j=1:num_divs
                jstr=num2str(j);
                node_prefix=[xpath_prefix 'gating:divider[' jstr ']/'];
                pts(:,j)=get_data_vec(obj,node_prefix,parent_bool);
                subids{j}=obj.xml{[xpath_prefix 'gating:divider[' jstr ']/@gating:id']};
                subids{j}=subids{j}{1};
                vals{j}=obj.xml{[xpath_prefix 'gating:divider[' jstr ']/gating:value']};
                vals{j}=[-inf; sort(vals{j}); inf]; %prep for quad assignment below
                
            end
            
            
            ingate=true(num_pts,1);
            
            %find the relevant subquad
            div_ids=obj.xml{[xpath_prefix 'gating:Quadrant[@gating:id="' gate_id '"]/gating:position/@gating:divider_ref']};
            locs=obj.xml{[xpath_prefix 'gating:Quadrant[@gating:id="' gate_id '"]/gating:position/@gating:location']};
            
            %associate loc with a region in each dim and assign cells in that
            %region
            for k=1:length(div_ids)
                ind=find(strcmp(div_ids{k},subids));
                lower_ind=find(locs(k)>=vals{ind},1,'last');
                lowerbound=vals{ind}(lower_ind);
                upperbound=vals{ind}(lower_ind+1);
                ingate=ingate & pts(:,ind)>=lowerbound & pts(:,ind)<upperbound;
            end
            
        end
        
        
        function ingate=boolean_gate(obj,gate_id,parent_bool)
            
            xpath_prefix=['/gating:Gating-ML/gating:BooleanGate[@gating:id="' gate_id '"]/'];
            
            %going to apply parent gate after in this case
            
            if ~isempty(obj.xml([xpath_prefix 'gating:and'])) %AND gate
                
                num_refs=length(obj.xml([xpath_prefix 'gating:and/gating:gateReference']));
                
                ingate=true(size(obj.fcsData.uncompensated.data,1),1);
                
                for j=1:num_refs
                    ref_name=obj.xml{[xpath_prefix 'gating:and/gating:gateReference[' num2str(j) ']/@gating:ref']};
                    compl_flag=obj.xml{[xpath_prefix 'gating:and/gating:gateReference[' num2str(j) ']/@gating:use-as-complement']};
                    try
                        ref_bool=obj.gates.(genvarname(ref_name{1})).inGate;
                    catch err
                        if strcmp(err.identifier,'MATLAB:nonExistentField')
                            error('You must first apply the parent gate.')
                        else
                            rethrow(err);
                        end
                    end
                    if strcmp(compl_flag,'true')
                        ingate = ingate & ~ref_bool;
                    else
                        ingate = ingate & ref_bool;
                    end
                end
                
                
            elseif ~isempty(obj.xml([xpath_prefix 'gating:or'])) %OR gate
                
                num_refs=length(obj.xml([xpath_prefix 'gating:or/gating:gateReference']));
                ingate=false(size(obj.fcsData.uncompensated.data,1),1);
                for j=1:num_refs
                    ref_name=obj.xml{[xpath_prefix 'gating:or/gating:gateReference[' num2str(j) ']/@gating:ref']};
                    compl_flag=obj.xml{[xpath_prefix 'gating:or/gating:gateReference[' num2str(j) ']/@gating:use-as-complement']};
                    try
                        ref_bool=obj.gates.(genvarname(ref_name{1})).inGate;
                    catch err
                        if strcmp(err.identifier,'MATLAB:nonExistentField')
                            error('You must first apply the parent gate.')
                        else
                            rethrow(err);
                        end
                    end
                    if strcmp(compl_flag,'true')
                        ingate = ingate | ~ref_bool;
                    else
                        ingate = ingate | ref_bool;
                    end
                end
                
            elseif ~isempty(obj.xml([xpath_prefix 'gating:not'])) %NOT gat
                ref_name=obj.xml{[xpath_prefix 'gating:not/gating:gateReference/@gating:ref']};
                compl_flag=obj.xml{[xpath_prefix 'gating:not/gating:gateReference/@gating:use-as-complement']};
                try
                    ref_bool=obj.gates.(genvarname(ref_name{1})).inGate;
                catch err
                    if strcmp(err.identifier,'MATLAB:nonExistentField')
                        error('You must first apply the parent gate.')
                    else
                        rethrow(err);
                    end
                end
                if strcmp(compl_flag,'true')
                    ingate=ref_bool;
                else
                    ingate=~ref_bool;
                end
                
            end
            
            ingate=ingate(parent_bool);
            
            
        end
        
        function data_vec=get_data_vec(obj,node_prefix,parent_bool)
            
            %select relevant data matrix and parameter list given the compensation
            y=obj.xml{[node_prefix '@gating:compensation-ref']};
            if strcmp(y{1},'uncompensated') || (strcmp(y{1},'FCS') && isempty(obj.fcsHdr.CompMat))
                nodeData=obj.fcsData.uncompensated.data;
                nodeParams=obj.fcsData.uncompensated.params;
            elseif strcmp(y{1},'FCS')
                nodeData=obj.fcsData.fcs.data;
                nodeParams=obj.fcsData.fcs.params;
            else
                nodeData=obj.fcsData.(genvarname(y{1})).data;
                nodeParams=obj.fcsData.(genvarname(y{1})).params;
            end
            
            %get single compensated column vector from fcs- or new-dimension
            z=obj.xml([node_prefix 'data-type:fcs-dimension/@data-type:name']);
            if ~isempty(z) %fcs-dimension
                col=strcmp(z{1},nodeParams);
                if ~any(col) %try using uncompensated dimension if dim not found in compensation
                    col=strcmp(z{1},obj.fcsData.uncompensated.params);
                    nodeData=obj.fcsData.uncompensated.data;
                end
                data_vec=nodeData(parent_bool,col);
            else %new-dimension
                z=obj.xml{[node_prefix 'data-type:new-dimension/@data-type:transformation-ref']};
                param_cols=zeros(1,2);
                trans_var=genvarname(z{1});
                for k=1:2
                    param_cols(k)=find(strcmp(obj.transforms.(trans_var).params{k},nodeParams));
                end
                data_vec=obj.transforms.(trans_var).fun(nodeData(parent_bool,param_cols(1)),nodeData(parent_bool,param_cols(2)));
            end
            
            %transform column vector
            y=obj.xml{[node_prefix '@gating:transformation-ref']};
            
            if ~isempty(y)
                trans_var=genvarname(y{1});
                data_vec=obj.transforms.(trans_var).fun(data_vec);
            end
        end
        
    end
end