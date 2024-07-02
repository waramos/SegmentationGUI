function Plugin = Plugin_BlobDetect
% PLUGIN_BLOBDETECT lays out the plugin configuration for a blob detection
% method that first filters out local variance by applying an ordered
% filter with a known size. A threshold is then applied to the image and
% the centroids to blobs are found.

    % Description of algorithm
    Plugin.Description        = 'Filters locally to improve blob centroid detection';
    Plugin.IdealData          = 'Varying feature intensity with known object size.';
    Plugin.Type               = 'Pointcloud';

    % Parameter 1
    Plugin.controls(1).Name   = 'Radius';
    Plugin.controls(1).Units  = 'std devs';
    Plugin.controls(1).Value  = 3;
    Plugin.controls(1).Min    = 1;
    Plugin.controls(1).Max    = 100;

    % Parameter 2
    Plugin.controls(2).Name   = 'Threshold';
    Plugin.controls(2).Units  = '% AU range';
    Plugin.controls(2).Value  = 50;
    Plugin.controls(2).Min    = 0;
    Plugin.controls(2).Max    = 100;

    % Parameter 3
    Plugin.controls(3).Name   = 'NA';
    Plugin.controls(3).Units  = 'NA';
    Plugin.controls(3).Value  = 1;
    Plugin.controls(3).Min    = 1;
    Plugin.controls(3).Max    = 100;

    % The auto estimation of parameter values
    Plugin.AutoEstimate       = @(I) AutoThresholdEstimate(I);

    % Layer struct to feed forward network
    % Thresholds image
    Plugin.Layers(1).In       = [1 0 0];
    Plugin.Layers(1).Process  = 'Local Minimum Filter';
    Plugin.Layers(1).Forward  = @(d, p) ReduceLocalDiffs(d{1}, p{1});
    % Refines the mask
    Plugin.Layers(2).In       = [0 1 0];
    Plugin.Layers(2).Process  = 'Threshold';
    Plugin.Layers(2).Forward  = @(d, p) ThresholdWFill(d{2}, p{2});
    % Converts a mask to an alpha shape
    Plugin.Layers(3).In       = [0 0 1];
    Plugin.Layers(3).Process  = 'Clustering';
    Plugin.Layers(3).Forward  = @(d, p) PixelCluster(d{3}, p{3});  
end


function J = ReduceLocalDiffs(I, r)
    % Removes potential bad pixels
    I = medfilt2(I, 'symmetric');

    % Accounting for local differences
    h = DiskKernel(r);
    J = ordfilt2(I, 1, h);
    J = max(I-J, 0);
end


function Mask = ThresholdWFill(I, threshold)
% THRESHOLDWFILL will perform a threshold with a single value and then fill
% in the resulting mask after performing a minor morphological open.

    % Applies simple threshold
    [mn, mx]  = bounds(I(:));
    mx_mn     = mx-mn;
    threshold = (threshold/100)*mx_mn + mn;
    
    Mask = I>threshold;

    % Morph filter and fill mask
    Mask = imopen(Mask, [0 1 0; 1 1 1; 0 1 0]);
    Mask = imfill(Mask, 'holes');
end


function P = PixelCluster(Mask, ~)
% PIXELCLUSTER will get index values to clusters of pixels to create a
% point cloud representing the centroids of the connected components
    C = regionprops(Mask, 'Centroid');
    P = cat(1, C.Centroid);
end


function h = DiskKernel(r)
% DISKKERNEL produces a disk shaped kernel with radius, r, for filtering.
    h = -r:r;
    h = h+h';
    h = h.^2+h.^2';
    h = sqrt(h)<=r;
end