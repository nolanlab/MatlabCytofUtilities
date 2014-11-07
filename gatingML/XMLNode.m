classdef XMLNode < handle
    %XMLNode represents a reference to a node within an XML document and
    %provides helpful indexing syntax to allow you to use XPath statements
    %to extract data from the document and into basic MATLAB arrays
    %(double, char, cell)
    %
    %Example uses...
    %
    % First, you must always call XMLNode.initialize if you just started
    % MATLAB (this adds our Java class to the dynamic Java path)
    % >> XMLNode.initialize
    %
    % Creating a node
    % >> n = XMLNode('myXML.xml');
    %
    % Indexing using XPath. () indexing returns more XMLNodes
    % >> ageNodes = n('//age')
    % >> adultNodes = n('//people[age > 18]')
    % 
    % Cell indexing converts data to MATLAB array
    % >> agesArray = n{'//age')
    % >> adultNamesArray = n{'//people[age > 18]'}
    %
    % Structure indexing works too, as does nested indexing, and regular
    % numeric indexing
    % >> adultNodes = n('//people[age > 18]')
    % >> thirdAdultNode = adultNodes(3)
    % >> thirtAdultAge = thirdAdultNode.age
    %
    % Loaded document is namespace aware
    % >> displayNamespaces(n)
    % >> agesInXSNamespace = n('//xs:age')
    %
    % Access underlying DOM node
    % >> getJavaNode(n)
    %
    % Add your own namespace prefixes
    % addNamespacePrefix(n,'myPrefix','http://www.namespaceurl.com')
    
% Copyright (c) 2012, The MathWorks, Inc.
% All rights reserved.
% 
% Redistribution and use in source and binary forms, with or without 
% modification, are permitted provided that the following conditions are 
% met:
% 
%     * Redistributions of source code must retain the above copyright 
%       notice, this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright 
%       notice, this list of conditions and the following disclaimer in 
%       the documentation and/or other materials provided with the distribution
%     * Neither the name of the The MathWorks, Inc. nor the names 
%       of its contributors may be used to endorse or promote products derived 
%       from this software without specific prior written permission.
%       
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
% POSSIBILITY OF SUCH DAMAGE.
    

    properties (Access=private)
        xpath  %Java object that allows us to compile and execute XPath statements (typically instance of Java class net.sf.saxon.xpath.XPathEvaluator)
        node   %Java object representing the actual node in the XML tree (typically instance of Java class org.apache.xerces.dom.*)
    end
    
    methods (Static)
        
        function initialize
            %Make sure our namespace context class is on the Java path
            javaaddpath(fileparts(which('XMLNode')));
        end
        
    end
        
    methods
        
        %Constructor can be called in two ways.  Most users will just use
        %the first form, and then use indexing to get any child nodes
        %
        % - Using input file name
        %   >> n = XMLNode('plants.xml')
        %
        % - Using a preexisting node
        %   >> c = xmlread('plants.xml')
        %   >> myNode = c.getFirstChild
        %   >> n = XMLNode(myNode);
        function obj = XMLNode(node,xpath)
            import javax.xml.xpath.*;
            import javax.xml.parsers.*
            import java.io.*
            import javax.xml.stream.*
            import com.mathworks.training.xml.*
            
            %If input is a character array, then assume it is a file name
            %and try and read it
            if ischar(node)
                %Get absolute path to file name
                fileName = which(node);
                
                %Load document using a namespace aware Java factory
                documentFactory = DocumentBuilderFactory.newInstance();
                documentFactory.setNamespaceAware(true)
                documentBuilder = documentFactory.newDocumentBuilder();
                obj.node = documentBuilder.parse(fileName);
                
                %Load document again, this time using javax.xml.stream
                %libraries. These allow us to easily loop through all of
                %the elements of the XML document and grab the namespaces
                inputFactory = XMLInputFactory.newInstance();
                fileInputStream = FileInputStream(fileName);
                fileReader = InputStreamReader(fileInputStream,obj.node.getEncoding);
                reader = inputFactory.createXMLEventReader(fileReader);
                
                %Try and create custom namespace context (this requires
                %that the XMLNodeNamespaceContext.class file be on the Java
                %path
                try
                    namespaceContext = XMLNodeNamespaceContext;
                catch %#ok
                    XMLNode.initialize;
                    error('XMLNode:NoNamespaceContext','Error creating namespace context.  Did you run >> XMLNode.initialize  ??');
                end
                
                %Loop through all XML events (which can kinda be
                %interpreted as "things in an XML file)
                emptyPrefixCount = 0;
                while reader.hasNextEvent
                    evt = reader.nextEvent;
                    
                    %If you encounter a start tag (like <myElement> )
                    if evt.isStartElement
                        
                        %Get the namespaces
                        namespaces = evt.getNamespaces;
                        while namespaces.hasNext
                            
                            %Add each namespace to the custom namespace
                            %context
                            currentNamespace = namespaces.next;
                            prefix = char(currentNamespace.getPrefix);
                            uri = char(currentNamespace.getNamespaceURI);
                            if isempty(prefix) %assign a default name to namespaces that dont have prefixes in the document
                                emptyPrefixCount = emptyPrefixCount + 1;
                                prefix = ['pre' num2str(emptyPrefixCount)];
                            end
                            namespaceContext.addPrefixMapping(prefix,uri);
                        end
                    end
                end
                
                %Create the XPath object (he's the workhorse) and let him
                %know about the namespace
                xpathFactory = XPathFactory.newInstance;
                obj.xpath = xpathFactory.newXPath;
                obj.xpath.setNamespaceContext(namespaceContext);
                
                %Normalize the document
                obj.node.normalize;
                
                %Remove all text nodes that are just whitespace
                res = obj.evaluateXPathExpression('//text()[normalize-space(.) = ""]');
                for i = 1:numel(res)
                    currentXMLnode = getJavaNode(res(i));
                    currentXMLnode.getParentNode().removeChild(currentXMLnode);
                end
            else
                %A node was passed into the constructor
                
                %Use a default XPathFactory if one wasn't specified. This
                %XPathFactory will not be aware of namespaces
                if ~exist('xpath','var')
                    xpathFactory = XPathFactory.newInstance;
                    obj.xpath = xpathFactory.newXPath;
                    warning('XMLNode:BadConstructorInputs','No XPath compiler specified, creating a new one (that will not be namespace aware)');
                else
                    obj.xpath = xpath;
                end
                
                %See if we can call a method from the node, and if it is
                %successful, then we'll assume it is valid
                try
                    node.getNodeValue;
                catch %#ok
                    error('XMLNode:BadNodeValue','XMLNode input must be an element of an XML document');
                end
                
                %If we made it this far, then all is well.
                obj.node = node;
            end
        end
        
        %Get method for the Java node object
        function javaNode = getJavaNode(obj)
            javaNode = obj.node;
        end
        
        %Get method for the Java XPath object
        function javaXPath = getJavaXPath(obj)
            javaXPath = obj.xpath;
        end
        
        %Helper function for adding new namespace prefixes
        function addNamespacePrefix(obj,pre,ns)
            obj.xpath.getNamespaceContext.addPrefixMapping(pre,ns);
        end
        
        %Overloaded subsasgn provides meaningful error
        function obj = subsasgn(~,~,~)  %#ok
            error('XMLNode:IndexedAssignment','You cannot perform indexed assignment on an XMLNode object.  Instead, you can obtain the underlying Java node ( >> getJavaNode(xmlnode) ) and then manipulate that object.');
        end
        
        %Overloaded subsref allows indexing into the object using XPath
        %statements
        function varargout = subsref(obj,A)
            
            %Loop over the indexes and index into the resulting objects
            %sequentially.  This allows users to nest indexing like
            %n.elementA{'//age'}
            currentObj = obj;
            for i = 1:length(A)
                switch A(i).type
                    case '.'
                        %Treat the subscript as an XPath expression
                        xpathStr = A(i).subs;
                        res = currentObj.evaluateXPathExpression(xpathStr);
                    case {'()','{}'}
                        %Use standard () indexing if a numeric index is requested
                        if isnumeric(A(i).subs{1}) || isequal(A(i).subs{1},':')
                            indexToUse = A(i);
                            indexToUse.type = '()';
                            res = builtin('subsref',currentObj,indexToUse);
                        else
                            %Treat the subscript as an XPath expression
                            xpathStr = A(i).subs{1};
                            res = currentObj.evaluateXPathExpression(xpathStr);
                        end
                        
                        %If {} indexing used, attempt to get a MATLAB array
                        %out of the result of the index
                        if strcmp(A(i).type,'{}')
                            try
                                res = res.getMATLABArray;
                            catch %#ok
                            end
                        end
                end
                %Set the result as the current object in case it's time to
                %go again
                currentObj = res;
            end
            
            %There should only ever be one output, but if the user asks for
            %more, we'll just send empty elements for now
            varargout{1} = res;
            for i = 2:nargout
                varargout{i} = []; %#ok
            end
        end
        
        %Display namespaces
        function displayNamespaces(obj)
            disp(['Namespaces:  ' char(obj.xpath.getNamespaceContext.getPrefixURIMap)]);
        end
        
        %Create a fancy display string to help the user navigate the XML
        %tree ( hopefully :-) )
        function disp(obj)
            if numel(obj) > 1
                builtin('disp',obj);
            else
                disp(obj.getDisplayString(obj.node));
                disp(['Namespaces:  ' char(obj.xpath.getNamespaceContext.getPrefixURIMap)]);
            end
        end
        
    end
    
    
    methods (Access=private)
        
                
        %Convert node to MATLAB type
        function data = getMATLABArray(obj)
            txtdata = cell(length(obj),1);
            for i = 1:length(obj)
                %try and extract numeric or character data from each node
                txtdata{i} = obj(i).extractData;
            end
            
            %Try to convert everything to numeric
            onlyNumeric = str2double(txtdata);
            
            if any(isnan(onlyNumeric))
                %all were not numeric, so return txtdata after injecting
                %the actual numbers into it
                data = txtdata;
                for i = 1:numel(onlyNumeric)
                    if ~isnan(onlyNumeric(i))
                        data{i} = onlyNumeric(i);
                    end
                end
            else
                data = onlyNumeric;
            end
        end
        
        
        %Execute XPath expression
        function res = evaluateXPathExpression(obj,xpathString)
            import javax.xml.xpath.*;
            
            %See if the expression will even compile
            try
                expression = obj.xpath.compile(xpathString);
            catch %#ok
                error('XMLNode:BadXPathSyntax','Invalid XPath syntax');
            end
            
            %See if the expression can be successfully evaluated
            try
                tmpRes = expression.evaluate(obj.node,XPathConstants.NODESET);
            catch %#ok
                error('XMLNode:CannotEvaluate','Unable to evaluate XPath command');
            end
            
            %If the result is an ArrayList, then do not treat this as an
            %XMLNode and immediately attempt to convert it to a MATLAB
            %array
            if isa(tmpRes,'java.util.ArrayList')
                res = cell(tmpRes.toArray);
            else
                %Otherwise, make an XMLNode array out of the result
                for i = 1:tmpRes.getLength
                    res(i) = XMLNode(tmpRes.item(i-1),obj.xpath);  %#ok
                end
            end
            
            %If we haven't populated the result yet, then tell the user the
            %XPath statement returned nothing
            if ~exist('res','var')
                
                %See if the user requested a method, and if so give a
                %useful error
                allMethodNames = methods('XMLNode');
                methodNameMatch = strcmp(xpathString,allMethodNames);
                if any(methodNameMatch)
                    methodName = allMethodNames{methodNameMatch};
                    warning('XMLNode:BadMethodCall',['XPath index returned no results.  Did you mean >> ' methodName '(...) ?']);
%                 else
%                     warning('XMLNode:NoResults','XPath index returned no results');
                end
                
                %Set empty output
                res = [];
            end
        end
        
        
        %Extract data to MATLAB format
        function res = extractData(obj)
            res = '';
            switch obj.node.getNodeType
                %Typically we will just give the value of the current node,
                %but if the node is an element with only one child (say,
                %some text) we'll make an exception and give the child's
                %value
                case obj.node.ELEMENT_NODE 
                    %see how many children there are
                    children = obj.node.getChildNodes;
                    if (children.getLength == 1)
                        %if one child, then get its value
                        res = char(children.item(0).getNodeValue);
                    else
                        %if multiple children, then return empty
                        res = '';
                    end
                case obj.node.TEXT_NODE
                    res = char(obj.node.getNodeValue);
                case obj.node.ATTRIBUTE_NODE 
                    res = char(obj.node.getNodeValue);
                case obj.node.CDATA_SECTION_NODE
                    res = char(obj.node.getNodeValue);
            end
            %types of nodes not currently handled because they don't really have data...
            % ENTITY_REFERENCE_NODE
            % ENTITY_NODE
            % PROCESSING_INSTRUCTION_NODE
            % COMMENT_NODE
            % DOCUMENT_NODE
            % DOCUMENT_TYPE_NODE
            % DOCUMENT_FRAGMENT_NODE
            % NOTATION_NODE
        end
                
        
        %Get the string to be displayed in the case of displaying a single
        %XMLNode object to the command window.  Each node will essentially
        %have the string form
        %
        %  xmlString  ## xpathString
        %
        %This is meant to aid the user in being able to construct XPath
        %statements
        function str = getDisplayString(obj,node)
            
            %Get strings for the root node
            xpathStr = obj.getXPathStr(node);
            xmlStr = obj.getXMLStr(node);
            
            %See if the root node has any children
            children = node.getChildNodes;
            if isempty(children)
                numChildren = 0;
            else
                numChildren = children.getLength;
            end
            
            %See if the root node has any attributes
            attributes = node.getAttributes;
            if isempty(attributes)
                numAttributes = 0;
            else
                numAttributes = attributes.getLength;
            end
            
            %Setup initial string with current node
            str = sprintf('%s\t\t<a href="matlab:">%s</a>\n',xmlStr,xpathStr);
            
            %Loop over all node's attributes and display them
            for i = 1:numAttributes
                xpathStr = obj.getXPathStr(attributes.item(i-1));
                xmlStr = obj.getXMLStr(attributes.item(i-1));
                str = sprintf('%s -- %s\t\t<a href="matlab:">%s</a>\n',str,xmlStr,xpathStr);
            end
            
            %Loop over all nodes children
            for i = 1:numChildren
                
                %Display the child
                xpathStr = obj.getXPathStr(children.item(i-1));
                xmlStr = obj.getXMLStr(children.item(i-1));
                str = sprintf('%s -- %s\t\t<a href="matlab:">%s</a>\n',str,xmlStr,xpathStr);
                
                %See if the child has kids of its own
                childsChildren = children.item(i-1).getChildNodes;
                if isempty(childsChildren)
                    numChildsChildren = 0;
                else
                    numChildsChildren = childsChildren.getLength;
                end
                
                %If there's only one kid, then display it.  This is so
                %simple elements with single items of data will be
                %displayed
                if (numChildsChildren == 1)
                    xpathStr = obj.getXPathStr(childsChildren.item(0));
                    xmlStr = obj.getXMLStr(childsChildren.item(0));
                    str = sprintf('%s     -- %s\t\t<a href="matlab:">%s</a>\n',str,xmlStr,xpathStr);
                end
            end
            
        end
        
        
        %Get a string representing how you might obtain the node using
        %XPath
        function str = getXPathStr(obj,node)
            
            
            if node.equals(obj.node)
                %To get the current node, typically you use '.' as the
                %index, except in some edge cases
                switch node.getNodeType
                    case node.ATTRIBUTE_NODE
                        str = '.';
                    case node.CDATA_SECTION_NODE
                        str = 'text()';
                    case node.COMMENT_NODE
                        str = 'comment()';
                    case node.DOCUMENT_FRAGMENT_NODE
                        str = '';
                    case node.DOCUMENT_NODE
                        str = '.';
                    case node.DOCUMENT_TYPE_NODE
                        str = '';
                    case node.ELEMENT_NODE
                        str = '.';
                    case node.ENTITY_NODE
                        str = '';
                    case node.ENTITY_REFERENCE_NODE
                        str = '';
                    case node.NOTATION_NODE
                        str = '';
                    case node.PROCESSING_INSTRUCTION_NODE
                        str = '';
                    case node.TEXT_NODE
                        str = 'text()';
                    otherwise
                        str = '.';
                end
            else
                %If we are not talking about the current node, then look at
                %the node type and return a common XPath syntax to obtain
                %that node
                switch node.getNodeType
                    case node.ATTRIBUTE_NODE
                        str = ['@' char(node.getName)];
                    case node.CDATA_SECTION_NODE
                        str = 'text()';
                    case node.COMMENT_NODE
                        str = 'comment()';
                    case node.DOCUMENT_FRAGMENT_NODE
                        str = '';
                    case node.DOCUMENT_NODE
                        str = '';
                    case node.DOCUMENT_TYPE_NODE
                        str = '';
                    case node.ELEMENT_NODE
                        %For elements, we add the namespace prefix if one
                        %exists
                        prefix = obj.xpath.getNamespaceContext.getPrefix(node.getNamespaceURI);
                        if isempty(prefix)
                            str = char(node.getNodeName);
                        else
                            str = [char(prefix) ':' char(node.getNodeName)];
                        end
                    case node.ENTITY_NODE
                        str = '';
                    case node.ENTITY_REFERENCE_NODE
                        str = '';
                    case node.NOTATION_NODE
                        str = '';
                    case node.PROCESSING_INSTRUCTION_NODE
                        str = '';
                    case node.TEXT_NODE
                        str = 'text()';
                    otherwise
                        str = '';
                end
            end            
            
            %As long is the string is not empty, wrap it in quotes so it 
            %is displayed like an index... ('str')
            if ~strcmp(str,'')
                str = ['(''' str ''')'];
            end
                        
        end
        
        
        %Returns a string that is meant to make the XML node feel like the
        %actual XML document itself
        function str = getXMLStr(~,node)
            
            switch node.getNodeType
                case node.ATTRIBUTE_NODE
                    attributeName = char(node.getName);
                    str = ['@' attributeName];
                case node.CDATA_SECTION_NODE
                    str = char(node.toString);
                    str = sprintf('%s',str);
                case node.COMMENT_NODE
                    str = char(node.toString);
                    str = sprintf('%s',str);
                case node.DOCUMENT_FRAGMENT_NODE
                    str = char(node.toString);
                    str = sprintf('%s',str);
                case node.DOCUMENT_NODE
                    nodeName = char(node.getNodeName);
                    str = ['<' nodeName '>'];
                    str = sprintf('%s',str);
                case node.DOCUMENT_TYPE_NODE
                    str = 'DOCTYPE';
                    str = sprintf('%s',str);
                case node.ELEMENT_NODE
                    nodeName = char(node.getNodeName);
                    str = ['<' nodeName '>'];
                    str = sprintf('%s',str);
                case node.ENTITY_NODE
                    str = char(node.toString);
                    str = sprintf('%s',str);
                case node.ENTITY_REFERENCE_NODE
                    str = char(node.toString);
                    str = sprintf('%s',str);
                case node.NOTATION_NODE
                    str = char(node.toString);
                    str = sprintf('%s',str);
                case node.PROCESSING_INSTRUCTION_NODE
                    str = char(node.toString);
                    str = sprintf('%s',str);
                case node.TEXT_NODE
                    str = char(node.getNodeValue);
                    str = sprintf('%s',str);
                otherwise
                    str = char(node.toString);
                    str = sprintf('%s',str);
            end
                        
        end
        
    end
    
end