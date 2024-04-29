function Jn = SegmentByInvertedGradient(I, threshold)
    % Gradients in the image
    Ix         = imfilter(I, [-1 0 1], 'symmetric');
    Iy         = imfilter(I, [-1 0 1]', 'symmetric');
    
    % Norm - magnitude of gradients
    Jn         = hypot(Ix, Iy);

    % Thresholding on entropy filtered image
    Jn        = entropyfilt(Jn);
    [mn, mx]  = bounds(Jn(:));
    threshold = threshold*(mx-mn) + mn;
    Jn        = Jn>threshold;

end