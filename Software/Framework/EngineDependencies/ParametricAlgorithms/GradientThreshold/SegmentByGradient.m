function Jn = SegmentByGradient(I, gThreshold)
    % Gradients in the image
    Ix         = imfilter(I, [-1 0 1], 'symmetric');
    Iy         = imfilter(I, [-1 0 1]', 'symmetric');
    % Norm - magnitude of gradients
    Jn         = hypot(Ix, Iy);
    gThreshold = max(Jn(:))*gThreshold;
    % Thresholding the gradient
    Jn         = Jn>gThreshold;
end