%Before using the logicle transformations, you must build the MEX-functions 
% from the C++ source code via the following commands.
% mex -setup
% mex logicleTransform.cpp Logicle.cpp
% mex logicleInverseTransform.cpp Logicle.cpp
% For help, see http://www.mathworks.com/help/matlab/ref/mex.html

% Both logicleTransform and logicleInverseTransform have input parameters
% T,W,M,A as defined in: 
%
%   Moore WA and Parks DR. Update for the logicle data scale including 
%       operational code implementations. Cytometry A., 2012:81A(4):273?277.


transformedData=logicleTransform(fcsData,T,W,M,A);
% Applies the transformation to the values in the matrix fcsData, outputting
% a matrix of the same size as fcsData.

untransformedData=logicleInverseTransform(transformedData,T,W,M,A);
% Applies the inverse transformation to the values in the matrix fcsData, outputting
% a matrix of the same size as fcsData.

