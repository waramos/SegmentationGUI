function Plugin = Plugin_GradSift
% SUMMARY:
% PLUGIN_GRADSIFT configures a gradient sifting method

    % Parameter 1
    Plugin.controls(1).Name   = 'Gradient Threshold';
    Plugin.controls(1).Symbol = '$\rho';
    Plugin.controls(1).Units  = '% AU Range';
    Plugin.controls(1).Value  = 5;
    Plugin.controls(1).Min    = 0;
    Plugin.controls(1).Max    = 100;
    % Parameter 2
    Plugin.controls(2).Name   = 'Target-size';
    Plugin.controls(2).Symbol = 'Area Size';
    Plugin.controls(2).Units  = 'pixels';
    Plugin.controls(2).Value  = 50;
    Plugin.controls(2).Min    = 0;
    Plugin.controls(2).Max    = 90000;

    % Parameter 3
    Plugin.controls(3).Name   = 'Tolerance';
    Plugin.controls(3).Symbol = 'Area Tol';
    Plugin.controls(3).Units  = 'pixels';
    Plugin.controls(3).Value  = 100;
    Plugin.controls(3).Min    = 0;
    Plugin.controls(3).Max    = 90000;

    % The auto estimation of parameter values
    % TBD
    Plugin.AutoParams         = @(I) AutoToleranceSiftEstimate(I);

    % Threshold applied to gradient magnitude of image
    Plugin.Layers(1).Name     = 'gradient-thresh';
    Plugin.Layers(1).In       = [1 0 0];
    Plugin.Layers(1).DataName = 'mask';
    Plugin.Layers(1).Process  = 'Thresholds Gradient';
    Plugin.Layers(1).Forward  = @(d, p) GradThresh(d{1}, p{1});
    
    % Size based sifting
    Plugin.Layers(2).Name     = 'sifting';
    Plugin.Layers(2).In       = [0 1 1];
    Plugin.Layers(2).DataName = 'filtered-mask';
    Plugin.Layers(2).Process  = 'Filters by target size and tolerance';
    Plugin.Layers(2).Forward  = @(d, p) SiftMask(d{1}, p{2}, p{3});
end