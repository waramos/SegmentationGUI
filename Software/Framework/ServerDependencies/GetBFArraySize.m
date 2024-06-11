function dimvec = GetBFArraySize(bfreaderObj, dimorder)
% GETBFARRAYSIZE extracts dimension size information for OME bioformats 
% data. This is essentially a wrapper for various bioformats framework
% function calls.
%
% INPUTS:
% bfreaderObj (required: filepath or reader object) - can either be the
% filepath to the OME bioformats data or a 'loci.formats.ChannelSeparator'
% object which is output from the bfGetReader function.
%
% dimorder (optional: ordering of the dimensions) - must specify by using
% x, y, z, t, c in a character array without spaces. E.g., 'xyztc' or
% 'yxtcz'. This will specify how the dimension lengths are ordered in the
% output.
%
%
% OUTPUTS:
% dimvec (dimension size vector) - a 5 element vector that specifies the
% size of each dimension of the data. This is output in the order of [y x z
% c t] per the ordering in the metadata, except that x and y are flipped
% here in the output to follow MATLAB conventions.
%
% Author: William A. Ramos, Kumar Lab, @ MBL, Woods Hole
% Date: June 10, 2024

    % dimension order
    if nargin < 2
        dimorder = [];
    end

    % In case the user has passed a file ID / filepath
    if ischar(bfreaderObj) || isstring(bfreaderObj)
        bfreaderObj = bfGetReader(bfreaderObj);
    end

    % BF object can give us dimensions easily
    y = bfreaderObj.getSizeY;
    x = bfreaderObj.getSizeX;
    z = bfreaderObj.getSizeZ;
    t = bfreaderObj.getSizeT;
    c = bfreaderObj.getSizeC;

    % Vector of dimensions' sizing
    dimvec = [y x z t c];

    % In case of user requested ordering
    if ~isempty(dimorder)
        dimorder = regexp(dimorder, {'y', 'x', 'z', 't', 'c'});
        dimorder = [dimorder{:}];
        dimvec   = dimvec(dimorder);
    end
end