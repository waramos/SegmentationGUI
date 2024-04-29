function I = GradThresh(I, gThreshold)
    % Smoothing the image and thresholding
    I   = imgaussfilt(I, 2.5, 'Padding','symmetric');
    % Gradients in the image
    Ix  = imfilter(I, [-1 0 1], 'symmetric');
    Iy  = imfilter(I, [-1 0 1]', 'symmetric');
    % Norm - magnitude of gradients
    I          = hypot(Ix, Iy);
    gThreshold = max(I(:))*(gThreshold/100);
    % Thresholding the gradient
    I         = I>gThreshold;
    % Morphological Filtering
    I = imopen(I, ones(3));
    I = imclose(I, ones(3));
end