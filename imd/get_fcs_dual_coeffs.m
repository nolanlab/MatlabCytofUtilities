function [masses,intercepts,slopes]=get_fcs_dual_coeffs(filename)
% [masses,intercepts,slopes]=get_fcs_dual_coeffs(filename)
%returns the dual calibration masses, intercepts and slopes as written in
%the XML following the data section of a CyTOF2 fcs file

% extracts the entire xml section 
str=get_fcs_xml(filename);

dualXml=regexp(str,'<DualAnalytesSnapshot>.+</DualAnalytesSnapshot>','match');

massCell=regexp(dualXml,'<Mass>([0-9\.]+)</Mass>','tokens');
masses=str2double(cat(1,massCell{1}{:}));

interceptCell=regexp(dualXml,'<DualIntercept>([0-9\.\-]+)</DualIntercept>','tokens');
intercepts=str2double(cat(1,interceptCell{1}{:}));

slopeCell=regexp(dualXml,'<DualSlope>([0-9\.\-]+)</DualSlope>','tokens');
slopes=str2double(cat(1,slopeCell{1}{:}));



