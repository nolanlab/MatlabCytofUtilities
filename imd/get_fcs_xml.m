function str=get_fcs_xml(filename)
% str=get_fcs_xml(filename)
%returns the entire XML section written into a CyTOF2 FCS file after the
%data section

fid = fopen(filename,'r','b');
fcsheader_1stline   = fread(fid,64,'char');

FcsHeaderStartPos   = str2double(char(fcsheader_1stline(16:18)'));
FcsHeaderStopPos    = str2double(char(fcsheader_1stline(23:26)'));

fseek(fid,FcsHeaderStartPos,'bof');
fcsheader= char(fread(fid,FcsHeaderStopPos-FcsHeaderStartPos+1,'char')');%read the main header

delimiter=char(fcsheader(1));

dataEndPos = regexp(fcsheader,['\$ENDDATA' delimiter '(\d+)' delimiter],'tokens');

if isempty(dataEndPos)
    error('Data end position not found in FCS header.')
end

dataEndPos=str2double(dataEndPos{1});
fseek(fid,dataEndPos,'bof');

endTag='</FCSHeaderSchema>';
str=char(fread(fid,1024,'char')');
endpos=strfind(str(1:1024),endTag);

while isempty(endpos)
    
    str=[ str char(fread(fid,1024,'char')') ];
    
endpos=strfind(str,endTag);

end
fclose(fid);

startpos=strfind(str,'<');
str=str(startpos(1):end);