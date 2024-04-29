function PC = ThresholdBlobs(I, J, threshold)
    % non maxima suppression
    Mx  = imdilate(J,ones(3))==J;
    idx = find(Mx(:));
    
    % Thresholding based on range
    threshold = threshold / 100;
    [mn,mx]   = bounds(I(:));
    jdx       = I(idx)>(mn+(mx-mn)*threshold);
    idx       = idx(jdx);
    
    % Boundary Pixels - Ensures curve does not create multiple connected components
    Mask       = zeros(size(I), 'logical');
    Mask(idx)  = 1;
    Mask       = imdilate(Mask, [0 1 0; 1 1 1; 0 1 0]);
    [y, x]     = find(Mask);

    % point cloud
    PC    = [x y];
end