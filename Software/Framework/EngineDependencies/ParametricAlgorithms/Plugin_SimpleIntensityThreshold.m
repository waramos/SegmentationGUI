function Plugin = Plugin_SimpleIntensityThreshold
% SUMMARY:
% PLUGIN_INTENSITYTHRESHOLD lays out the plugin configuration for a
% segmentation method that is based on intensity thresholding

    % Description of algorithm
    Plugin.Description        = 'Applies global threshold';
    Plugin.IdealData          = 'Consistent objects intensity';
    Plugin.Type               = 'Contour';

    % Parameter 1
    Plugin.controls(1).Name   = 'Threshold';
    Plugin.controls(1).Value  = 100;
    Plugin.controls(1).Min    = 0;
    Plugin.controls(1).Max    = (2^16)-1;

    % Parameter 2
    Plugin.controls(2).Name   = 'Radius';
    Plugin.controls(2).Value  = 3;
    Plugin.controls(2).Min    = 0;
    Plugin.controls(2).Max    = 20;

    % Parameter 3
    Plugin.controls(3).Name   = 'Shrink Factor';
    Plugin.controls(3).Value  = 0.5;
    Plugin.controls(3).Min    = 0;
    Plugin.controls(3).Max    = 1;

    % The auto estimation of parameter values
    Plugin.AutoEstimate       = @(I) AutoThresholdEstimate(I);

    % Layer struct to feed forward network
    % Thresholds image
    Plugin.Layers(1).In       = [1 0 0];
    Plugin.Layers(1).Process  = 'Thresholds image';
    Plugin.Layers(1).Forward  = @(d, p) HardThreshold(d{1}, p{1});
    % Refines the mask
    Plugin.Layers(2).In       = [0 1 0];
    Plugin.Layers(2).Process  = 'Smooths Mask';
    Plugin.Layers(2).Forward  = @(d, p) RefineMask(d{2}, p{2});
    % Converts a mask to an alpha shape
    Plugin.Layers(3).In       = [0 0 1];
    Plugin.Layers(3).Process  = 'Computes Alpha Shape';
    Plugin.Layers(3).Forward  = @(d, p) Mask2Poly(d{3}, p{3});  
end



function Mask = HardThreshold(I, threshold)
    I    = medfilt2(I, [3 3], 'symmetric');
    Mask = I>threshold;
end