function Mask = ThresholdImage(I, threshold)
    % Threshold is rescaled as percentage of range
    I         = medfilt2(I, 'symmetric');
    [mn, mx]  = bounds(I(:));
    mx_mn     = mx-mn;
    threshold = (threshold/100)*mx_mn + mn;

    % Light Denoise, Binarization, and removing small connected
    % components
    Mask  = I>threshold;
end