function Plugin = Plugin_ThresholdAndSift
% SUMMARY:
% PLUGIN_THRESHOLDANDSIFT will threshold an image and then sift based off
% of size of the connected components

    % Parameter 1
    Plugin.controls(1).Name   = 'Threshold';
    Plugin.controls(1).Symbol = '$\rho';
    Plugin.controls(1).Units  = '% AU range';
    Plugin.controls(1).Value  = 5;
    Plugin.controls(1).Min    = 0;
    Plugin.controls(1).Max    = 100;
    % Parameter 2
    Plugin.controls(2).Name   = 'Min-size';
    Plugin.controls(2).Symbol = '$\epsilon';
    Plugin.controls(2).Units  = '% size range';
    Plugin.controls(2).Value  = 0;
    Plugin.controls(2).Min    = 0;
    Plugin.controls(2).Max    = 100;
    % Parameter 3
    Plugin.controls(3).Name   = 'Max-size';
    Plugin.controls(3).Symbol = '$\alpha';
    Plugin.controls(3).Units  = '% size range';
    Plugin.controls(3).Value  = 100;
    Plugin.controls(3).Min    = 0;
    Plugin.controls(3).Max    = 100;

    % TBD
    Plugin.AutoEstimate       = @(I) AutoThreshSiftEstimate(I);

    % Threshold image
    Plugin.Layers(1).Name     = 'binarize';
    Plugin.Layers(1).In       = [1 0 0];
    Plugin.Layers(1).DataName = 'mask';
    Plugin.Layers(1).Process  = 'Thresholds image';
    Plugin.Layers(1).Forward  = @(d, p) SizeSegment2D(d{1}, p{1});
    % Connected component size based filtering
    Plugin.Layers(2).Name     = 'size-filter';
    Plugin.Layers(2).In       = [0 1 1];
    Plugin.Layers(2).DataName = 'filtered-mask';
    Plugin.Layers(2).Process  = 'Filters by size limits';
    Plugin.Layers(2).Forward  = @(d, p) FilterBySize(d{2}, p{2}, p{3});
    % Contour calculation (alphashapes)
    Plugin.Layers(3).Name     = 'alphashape';
    Plugin.Layers(3).In       = [0 0 1];
    Plugin.Layers(3).Process  = 'Alpha shape';
    Plugin.Layers(3).Forward  = @(d, p) PointsFromMask(d{3});
end