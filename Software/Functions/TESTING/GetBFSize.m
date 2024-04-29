function dimvec = GetBFSize(bfreaderObj, dimorder)
% GETBFSIZE will extract metadata and gather the dimension size information
% for OME bioformats data. This function takes advantage of the
% standardized format by using regular expressions.
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
% Date: April 10, 2024

    % dimension order
    if nargin < 2
        dimorder = [];
    end

    % In case the user has passed a file ID / filepath
    if ischar(bfreaderObj) || isstring(bfreaderObj)
        bfreaderObj = bfGetReader(bfreaderObj);
    end

    % Metadata extraction from the bf reader object
    mdata = bfreaderObj.getCoreMetadataList;
    mdata = char(mdata);

    % Finding location of dimensional specifications
    dimstring = {'sizeX', 'sizeY', 'sizeZ', 'sizeC', 'sizeT'};
    d_idx     = regexp(mdata, dimstring);
    d_idx     = [d_idx{:}];

    % Index of final line based on line break index
    end_idx   = regexp(mdata, newline);
    e_idx     = end_idx > d_idx(end);
    e_idx_idx = find(e_idx, 1);
    end_idx   = end_idx(e_idx_idx);
    end_idx   = end_idx - 1;

    % Converting indexing array to have indices for end of each line
    d_idx  = d_idx';
    d_idx2 = [d_idx(2:end)-1; end_idx];
    d_idx  = [d_idx d_idx2];

    % Parsing metadata
    dimvec = ones(1, 5);
    for i = 1:5
        idx       = d_idx(i, 1):d_idx(i, 2);
        dsz       = d(idx);
        e_idx     = regexp(dsz, '= ');
        dsz       = dsz(e_idx+1:end);
        dimvec(i) = str2double(dsz);
    end

    % Ordering of dimension lengths in vector
    if ~isempty(dimorder)
        dimorder = regexp(dimorder, {'x', 'y', 'z', 't', 'c'});
        dimorder = [dimorder{:}];
        dimvec   = dimvec(dimorder);
    else
        % Flips the order of the X and Y to follow MATLAB conventions
        dimvec(1:2) = dimvec(2:-1:1);
    end
end