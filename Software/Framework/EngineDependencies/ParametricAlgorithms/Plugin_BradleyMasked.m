function Plugin = Plugin_BradleyMasked
% SUMMARY:
%  PLUGIN_BRADLEYMASKED configures a segmentation method for adaptive
%  thresholding

    % Description of algorithm
    Plugin.Description        = 'Thresholds with a locally adaptive threshold';
    Plugin.IdealData          = 'Varying feature intensity';
    Plugin.Type               = 'Contour';

    % Parameter 1
    Plugin.controls(1).Name   = 'Radius';
    Plugin.controls(1).Symbol = '$\rho';
    Plugin.controls(1).Units  = 'pixels';
    Plugin.controls(1).Value  = 3;
    Plugin.controls(1).Min    = 0;
    Plugin.controls(1).Max    = 20;
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
    Plugin.AutoEstimate     = @(x) BradleyAutoParams(x);

    % Layer 2 - first computational layer - binarization layer
    Plugin.Layers(2).Name     = 'binarize';
    Plugin.Layers(2).In       = [1 0 0 ];
    Plugin.Layers(2).DataName = 'adaptive-threshold';
    Plugin.Layers(2).Process  = 'Adaptively thresholds image';
    Plugin.Layers(2).Forward  = @(d, p) AdaptiveThreshold(d{1}, p{1});
    % Layer 3 - mask refinement layer
    Plugin.Layers(3).Name     = 'refine';
    Plugin.Layers(3).In       = [0 1 0];
    Plugin.Layers(3).DataName = 'boundary-points';
    Plugin.Layers(3).Process  = 'Binarizes image';
    Plugin.Layers(3).Forward  = @(d, p) ThresholdAndBinarize(d{1}, d{2}, p{2});
    % Layer 4 - contour computation layer (alphashapes)
    Plugin.Layers(4).Name     = 'alphashape';
    Plugin.Layers(4).In       = [0 0 1];
    Plugin.Layers(4).DataName = 'contour-points';
    Plugin.Layers(4).Process  = 'Alpha shape';
    Plugin.Layers(4).Forward  = @(d, p) SimpleAlphaShape(d{3}, p{3});

    
end