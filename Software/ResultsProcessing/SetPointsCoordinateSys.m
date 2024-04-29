function P = SetPointsCoordinateSys(T, xypxsz, zspacing, ispixelunits)
% SETPOINTSCOORDINATESYS will extract 3D point cloud data from a table and
% then transform it to be an isotropic pointcloud in either pixel units or
% microns. The units used for the isotropic coordinate transformation are
% determined by a logical.
%
% INPUTS:
% T - data table of point detections across 2D slices in a volume
% xypxsz - x / y pixel sizing across image in microns
% zspacing - image volume spacing between planes, in microns
% ispixelunits - false if user wants micron units, true if pixel units
% desired
%
% OUPUTS:
% P - pointcloud transformed to be isotropic and in the desired coordinate
% system


    % Logical for setting the point cloud in pixel coordinates or physical
    % coordinate space
    if nargin < 4 || isempty(ispixelunits)
        ispixelunits = true;
    end

    % Pointcloud data extracted from the table
    X = T.X;
    Y = T.Y;
    Z = T.Z;

    % Scaling z slices isotropically - units: in pixels
    zfactor = (zspacing/xypxsz);
    Z       = Z*zfactor;
    
    % Microscope/real coordinate space - units: in microns
    if ~ispixelunits
        X = X*xypxsz;
        Y = Y*xypxsz;
        Z = Z*xypxsz;
    end

    % Arranges coordinates in columns so each column is a coord dimension
    if iscolumn(X)
        P = [X Y Z];
    else
        P = [X' Y' Z];
    end
end