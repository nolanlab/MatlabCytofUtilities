%Before using the hyperlog transformations, you must build the MEX-functions 
% from the C++ source code via the following commands.
% mex -setup
% mex hyperlogTransform.cpp Hyperlog.cpp
% mex hyperlogInverseTransform.cpp Hyperlog.cpp
% For help, see http://www.mathworks.com/help/matlab/ref/mex.html

% Both hyperlogTransform and hyperlogInverseTransform, originally published 
% by Bagwell, have input parameters T,W,M,A to match the other log-like transformations. 
% See:
% 
%   Bagwell CB. Hyperlog-a flexible log-like transform for negative, zero, 
%   and positive valued data. Cytometry A., 2005:64(1):34?42.
% 
%   J. Spidlen, International Society for the Advancement of 
%   Cytometry Data Standards Task Force, and Brinkman, R.R. (2013). 
%   Gating-ML 2.0 -- International Society for Advancement of
%   Cytometry (ISAC) stanford for representing gating descriptions
%   in flow cytometry. Retrieved from http://flowcyt.sourceforge.net/gating/20130122.pdf
% 


transformedData=hyperlogTransform(fcsData,T,W,M,A);
% Applies the transformation to the values in the matrix fcsData, outputting
% a matrix of the same size as fcsData.

untransformedData=hyperlogInverseTransform(transformedData,T,W,M,A);
% Applies the inverse transformation to the values in the matrix fcsData, outputting
% a matrix of the same size as fcsData.

