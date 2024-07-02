function Plugin = Plugin_IntensityThreshold
% SUMMARY:
% PLUGIN_INTENSITYTHRESHOLD lays out the plugin configuration for a
% segmentation method that is based on intensity thresholding

    % Description of algorithm
    Plugin.Description        = 'Thresholds and computes convex hull';
    Plugin.IdealData          = 'Invariant relative range and variance';
    Plugin.Type               = 'Contour';

    % Parameter 1
    Plugin.controls(1).Name   = 'Threshold';
    Plugin.controls(1).Symbol = '$\epsilon';
    Plugin.controls(1).Units  = 'intensity %';
    Plugin.controls(1).Value  = 20;
    Plugin.controls(1).Min    = 0;
    Plugin.controls(1).Max    = 100;

    % Parameter 2
    Plugin.controls(2).Name   = 'Radius';
    Plugin.controls(2).Symbol = '$\rho';
    Plugin.controls(2).Units  = 'pixels';
    Plugin.controls(2).Value  = 3;
    Plugin.controls(2).Min    = 0;
    Plugin.controls(2).Max    = 20;

    % Parameter 3
    Plugin.controls(3).Name   = 'Shrink Factor';
    Plugin.controls(3).Symbol = '$\alpha';
    Plugin.controls(3).Units  = 'convexity';
    Plugin.controls(3).Value  = 0.5;
    Plugin.controls(3).Min    = 0;
    Plugin.controls(3).Max    = 1;

    % The auto estimation of parameter values
    Plugin.AutoEstimate       = @(I) AutoThresholdEstimate(I);

    % Layer struct to feed forward network
    % Layer 1
    Plugin.Layers(1).Name     = 'binarize';
    Plugin.Layers(1).In       = [1 0 0];
    Plugin.Layers(1).DataName = 'mask';
    Plugin.Layers(1).Process  = 'Thresholds image';
    Plugin.Layers(1).Forward  = @(d, p) ThresholdImage(d{1}, p{1});
    % Layer 2 - mask refinement layer
    Plugin.Layers(2).Name     = 'refine';
    Plugin.Layers(2).In       = [0 1 0];
    Plugin.Layers(2).DataName = 'refined-mask';
    Plugin.Layers(2).Process  = 'Morphological filtering';
    Plugin.Layers(2).Forward  = @(d, p) RefineMask(d{2}, p{2});
    % Layer 3 - contour computation layer (alphashapes)
    Plugin.Layers(3).Name     = 'alphashape';
    Plugin.Layers(3).In       = [0 0 1];
    Plugin.Layers(3).DataName = 'contour-points';
    Plugin.Layers(3).Process  = 'Alpha shape';
    Plugin.Layers(3).Forward  = @(d, p) Mask2Poly(d{3}, p{3});  
end