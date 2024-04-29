function Plugin = Plugin_ToleranceSift
% SUMMARY:
% SEG_ENGINECONFIG returns a 'net' of layers and parameters. The layers
% field of the net struct is a struct describing how the processing layers
% are connected in terms of input/output. An image is fed into the first
% layer and the forward functions will pass the output (data) of layers to
% corresponding connected layers (output - indices of layers to connect to)

    % Parameter 1
    Plugin.controls(1).Name   = 'Threshold';
    Plugin.controls(1).Symbol = '$\rho';
    Plugin.controls(1).Units  = 'pixel intensity';
    Plugin.controls(1).Value  = 5;
    Plugin.controls(1).Min    = 0;
    Plugin.controls(1).Max    = 100;
    % Parameter 2
    Plugin.controls(2).Name   = 'Target-size';
    Plugin.controls(2).Symbol = '$\epsilon';
    Plugin.controls(2).Units  = '% max size';
    Plugin.controls(2).Value  = 50;
    Plugin.controls(2).Min    = 0;
    Plugin.controls(2).Max    = 100;
    % Parameter 3
    Plugin.controls(3).Name   = 'Tolerance';
    Plugin.controls(3).Symbol = '$\alpha';
    Plugin.controls(3).Units  = '% size range';
    Plugin.controls(3).Value  = 100;
    Plugin.controls(3).Min    = 0;
    Plugin.controls(3).Max    = 100;

    % TBD
    Plugin.AutoEstimate       = @(I) AutoToleranceSiftEstimate(I);

    % Thresholds image
    Plugin.Layers(1).Name     = 'binarize';
    Plugin.Layers(1).In       = [1 0 0];
    Plugin.Layers(1).DataName = 'mask';
    Plugin.Layers(1).Process  = 'Thresholds image';
    Plugin.Layers(1).Forward  = @(d, p) SizeSegment2D(d{1}, p{1});
    % Filters out connected components outside the target size +/- a tol.
    Plugin.Layers(2).Name     = 'size-filter';
    Plugin.Layers(2).In       = [0 1 1];
    Plugin.Layers(2).DataName = 'filtered-mask';
    Plugin.Layers(2).Process  = 'Filters by target size and tolerance';
    Plugin.Layers(2).Forward  = @(d, p) FilterByTargetSize(d{2}, p{2}, p{3});
    % Contour computation layer (alphashapes)
    Plugin.Layers(3).Name     = 'convexhull';
    Plugin.Layers(3).In       = [0 0 1];
    Plugin.Layers(3).Process  = 'Convex hull';
    Plugin.Layers(3).Forward  = @(d, ~) PointsFromMask(d{3});
end