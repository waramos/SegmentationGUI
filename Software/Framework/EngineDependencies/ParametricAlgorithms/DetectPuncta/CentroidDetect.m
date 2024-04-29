function P = CentroidDetect(I, t)
    % Normalizing threshold as % of range
    [mn, mx] = bounds(I(:));
    t        = (t/100)*(mx-mn);
    % apply threshold
    I        = (I-mn) > t;
    % morph open - eliminates small cc
    I        = imopen(I, [0 1 0; 1 1 1; 0 1 0]);
    % centroid points
    rp       = regionprops(I, 'Centroid');
    P        = cat(1, rp.Centroid);
end