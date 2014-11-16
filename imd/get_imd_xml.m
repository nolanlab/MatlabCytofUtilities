function str=get_imd_xml(filename)
% str=get_imd_xml(filename) extracts the XML at the end of an IMD file.
% Note that since the IMD files are 16-bit, there is a blank character
% separating every two characters in the str. 
% Example: str=get_imd_xml(file.imd)
%          trimmedStr=str(1:2:end)

db=double('<ExperimentSchema');
db=[db; zeros(size(db))];
startstr=char(db(:))';

fid=fopen(filename,'r','l');
fseek(fid,-1024,'eof');
str=char(fread(fid,1024,'char')');

pos=-2048;

startpos=strfind(str(1:1024),startstr);

while isempty(startpos)
    fseek(fid,pos,'cof');
    
    str=[ char(fread(fid,1024,'char')') str];
    
    startpos=strfind(str(1:1024),startstr);

end
fclose(fid);

str=str(startpos:end);

