function Mask = SizeSegment2D(I,threshold)
% Thresholds the image with a threshold value based on relative intensity
    I             = medfilt2(I, 'symmetric');
    [mn,mx]       = bounds(I(:));
    mx_mn         = mx-mn;
    threshold     = (threshold/100)*mx_mn + mn;
    Mask          = I>threshold;
end