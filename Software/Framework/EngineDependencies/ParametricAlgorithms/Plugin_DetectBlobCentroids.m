function Plugin = Plugin_DetectBlobCentroids
% SUMMARY:
% PLUGIN_INTENSITYTHRESHOLD lays out the plugin configuration for a
% segmentation method that is based on intensity thresholding

    % Parameter 1
    Plugin.controls(1).Name   = 'Sigma 1';
    Plugin.controls(1).Symbol = '$\sigma_1';
    Plugin.controls(1).Units  = '';
    Plugin.controls(1).Value  = 2;
    Plugin.controls(1).Min    = 0;
    Plugin.controls(1).Max    = 20;

    % Parameter 2
    Plugin.controls(2).Name   = 'Sigma 2';
    Plugin.controls(2).Symbol = '$\sigma_2';
    Plugin.controls(2).Units  = '';
    Plugin.controls(2).Value  = 5;
    Plugin.controls(2).Min    = 0;
    Plugin.controls(2).Max    = 20;

    % Parameter 3
    Plugin.controls(3).Name   = 'Threshold';
    Plugin.controls(3).Symbol = '$\epsilon';
    Plugin.controls(3).Units  = '';
    Plugin.controls(3).Value  = 10;
    Plugin.controls(3).Min    = 0;
    Plugin.controls(3).Max    = 100;

    % The auto estimation of parameter values
    Plugin.AutoEstimate       = @(I) AutoThresholdEstimate(I);

    % Layer struct to feed forward network
    % Layer 1
    Plugin.Layers(1).Name     = 'Gaussian Filter 1';
    Plugin.Layers(1).In       = [1 0 0];
    Plugin.Layers(1).DataName = 'Filtered Image';
    Plugin.Layers(1).Process  = 'Smooths image';
    Plugin.Layers(1).Forward  = @(d, p) imgaussfilt(medfilt2(d{1}), p{1}, 'Padding','symmetric');

    % Layer 2 - mask refinement layer
    Plugin.Layers(2).Name     = 'Gaussian Filter 2';
    Plugin.Layers(2).In       = [0 1 0];
    Plugin.Layers(2).DataName = "Filtered Images' Difference";
    Plugin.Layers(2).Process  = 'Difference of Gaussian';
    Plugin.Layers(2).Forward  = @(d, p) d{2} - imgaussfilt(medfilt2(d{1}), p{2}, 'Padding','symmetric');

    % Layer 3 - contour computation layer (alphashapes)
    Plugin.Layers(3).Name     = 'Threshold';
    Plugin.Layers(3).In       = [0 0 1];
    Plugin.Layers(3).DataName = 'Mask';
    Plugin.Layers(3).Process  = 'Threshold';
    Plugin.Layers(3).Forward  = @(d, p) SimplyThreshold(d{3}, p{3});

    % Layer 4 - contour computation layer (alphashapes)
    Plugin.Layers(4).Name     = 'Blob Centroids';
    Plugin.Layers(4).In       = [0 0 0];
    Plugin.Layers(4).DataName = 'centroids point cloud';
    Plugin.Layers(4).Process  = 'Find Centroids';
    Plugin.Layers(4).Forward  = @(d, p) GetCentroids(d{4});


    function I = SimplyThreshold(I, t)
        % Normalizing threshold as % of range
        [mn, mx] = bounds(I(:));
        t        = (t/100)*(mx-mn);
        % apply threshold
        I        = (I-mn) > t;
        % morph open - eliminates small cc
        I        = imopen(I, [0 1 0; 1 1 1; 0 1 0]);
    end

    function P = GetCentroids(I, ~)
        % centroid points from connected components in mask
        rp       = regionprops(I, 'Centroid');
        P        = cat(1, rp.Centroid);
    end
end