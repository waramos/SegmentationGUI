function Plugin = Plugin_ThresholdDisorderedGradient
% SUMMARY:
% Entropy based thresholding

    % Parameter 1
    Plugin.controls(1).Name   = 'Sigma';
    Plugin.controls(1).Symbol = '$\sigma';
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
    Plugin.controls(3).Name   = 'Gradient Entropy Threshold';
    Plugin.controls(3).Symbol = '$\epsilon_g';
    Plugin.controls(3).Units  = '% entropy range';
    Plugin.controls(3).Value  = 0.1;
    Plugin.controls(3).Min    = 0;
    Plugin.controls(3).Max    = 1;

    % The auto estimation of parameter values
    Plugin.AutoEstimate       = @(I) AutoGradThresholdEstimate(I);

    % Smooths image
    Plugin.Layers(1).Name     = 'smoothing';
    Plugin.Layers(1).In       = [1 0 0 ];
    Plugin.Layers(1).DataName = 'preprocessed-image';
    Plugin.Layers(1).Process  = 'Smooths image';
    Plugin.Layers(1).Forward  = @(d, p) RescaleAndSmooth(d{1}, p{1});
    % Clips additional signal
    Plugin.Layers(2).Name     = 'clipping';
    Plugin.Layers(2).In       = [0 1 0 ];
    Plugin.Layers(2).DataName = 'clipped-image';
    Plugin.Layers(2).Process  = 'Clips image';
    Plugin.Layers(2).Forward  = @(d, p) ClipImage(d{2}, p{2});
    % Computes binary mask by thresholding gradient
    Plugin.Layers(3).Name     = 'gradient-entropy-map';
    Plugin.Layers(3).In       = [0 0 1];
    Plugin.Layers(3).DataName = 'gradient-entropy-map';
    Plugin.Layers(3).Process  = 'Thresholds Gradient Magnitude Entropy';
    Plugin.Layers(3).Forward  = @(d, p) SegmentByInvertedGradient(d{3}, p{3});
    % Convex hull
    Plugin.Layers(4).Name     = 'convhull';
    Plugin.Layers(4).In       = [0 0 0];
    Plugin.Layers(4).DataName = 'contour-points';
    Plugin.Layers(4).Process  = 'Convex Hull';
    Plugin.Layers(4).Forward  = @(d, p) MaskConvHull(d{4});
end