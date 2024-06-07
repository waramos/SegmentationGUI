function I = LoadFromBioFormats(bffile, dimvec)
% LOADFROMBIOFORMATS will load a single image plane. This function eases
% lazy loading by asking the user to give a dimension indexing vector that
% can be 1-3 values long. By default, the ordering of the dimensions is
% assumed to be z plane, channel, and time, per the OME bioformats
% documentation from: 
% https://docs.openmicroscopy.org/bio-formats/6.3.1/developers/matlab-dev.html#accessing-planes
% 
% This function is to ease integration with our modular GUI framework.
%
% INPUTS:
% bffile (required: filepath) - string or character array that specifies 
% the file location OR a bioformats reader object.
%
% dimvec (required: dimension indexing vector) - a vector ranging from one
% to three values long. The values should refer to z plane, channel, and
% time indices, z, c, t, in the following format: [z c t]
%
% Author: William A. Ramos, Kumar Lab @ MBL, Woods Hole
% Date: April 10, 2024
% Last Update: May 24, 2024

    if isstring(bffile) || ischar(bffile)
        fid     = bffile;
        reader  = bfGetReader(fid);
    elseif isa(bffile, 'loci.formats.ChannelSeparator')
        reader = bffile;
    end

    % Dimension vector for Z, Color, and Time (z, c, t)
    dvec       = ones(1, 3);
    nd         = numel(dimvec);
    dvec(1:nd) = dimvec;
    z          = dvec(1);
    c          = dvec(2);
    t          = dvec(3);
    plane      = reader.getIndex(z-1, c-1, t-1) + 1;
    I          = bfGetPlane(reader, plane);
end