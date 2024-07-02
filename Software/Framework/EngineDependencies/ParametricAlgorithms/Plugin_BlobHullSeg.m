function Plugin = Plugin_BlobHullSeg
% SUMMARY:
% SEG_ENGINECONFIG returns a 'net' of layers and parameters. The layers
% field of the net struct is a struct describing how the processing layers
% are connected in terms of input/output. An image is fed into the first
% layer and the forward functions will pass the output (data) of layers to
% corresponding connected layers (output - indices of layers to connect to)

    % Description of algorithm
    Plugin.Description        = 'Uses blobs to find a convex hull';
    Plugin.IdealData          = 'Object of interest has blobs inside';
    Plugin.Type               = 'Contour';


    % Parameter 1
    Plugin.controls(1).Name   = 'Sigma';
    Plugin.controls(1).Symbol = '$\sigma';
    Plugin.controls(1).Units  = 'std dev';
    Plugin.controls(1).Value  = 2;
    Plugin.controls(1).Min    = 0;
    Plugin.controls(1).Max    = 10;
    % Parameter 2
    Plugin.controls(2).Name   = 'Threshold';
    Plugin.controls(2).Symbol = '$\epsilon';
    Plugin.controls(2).Units  = '% intensity';
    Plugin.controls(2).Value  = 10;
    Plugin.controls(2).Min    = 0;
    Plugin.controls(2).Max    = 100;
    % Parameter 3
    Plugin.controls(3).Name   = 'Shrink Factor';
    Plugin.controls(3).Symbol = '$\alpha';
    Plugin.controls(3).Units  = '';
    Plugin.controls(3).Value  = 0.5;
    Plugin.controls(3).Min    = 0;
    Plugin.controls(3).Max    = 1;

    % The auto estimation of parameter values
    Plugin.AutoEstimate       = [2 10 0];

    % Layer 2 - first computational layer - binarization layer
    Plugin.Layers(1).Name     = 'cLoG';
    Plugin.Layers(1).In       = [1 0 0];
    Plugin.Layers(1).DataName = 'clipped-LoG';
    Plugin.Layers(1).Process  = 'Computes clipped Laplacian of Gaussian';
    Plugin.Layers(1).Data     = [];
    Plugin.Layers(1).Forward  = @(d, p) ClippedLoG(d{1}, p{1});
    % Layer 3 - mask refinement layer
    Plugin.Layers(2).Name     = 'refine';
    Plugin.Layers(2).In       = [0 1 0];
    Plugin.Layers(2).DataName = 'point-cloud';
    Plugin.Layers(2).Process  = 'Thresholds clipped LoG of Image';
    Plugin.Layers(2).Data     = [];
    Plugin.Layers(2).Forward  = @(d, p) ThresholdBlobs(d{1}, d{2}, p{2});
    % Layer 4 - contour computation layer (alphashapes)
    Plugin.Layers(3).Name     = 'alphashape';
    Plugin.Layers(3).In       = [1 0 1];
    Plugin.Layers(3).DataName = 'contour-points';
    Plugin.Layers(3).Process  = 'Alpha shape';
    Plugin.Layers(3).Data     = [];
    Plugin.Layers(3).Forward  = @(d, p) BlobHull(d{3}, p{1}, p{3});
end