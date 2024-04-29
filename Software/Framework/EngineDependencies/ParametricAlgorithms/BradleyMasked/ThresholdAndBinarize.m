function PC = ThresholdAndBinarize(I, T, threshold)
% Layer 3 - Computational layer 2
    % Data from layer 1
    % Data from layer 2
    % Parameter 2
    [mn,mx]   = bounds(I(:));
    threshold = threshold/100;
    Mask      = I>(mn+(mx-mn)*threshold);
    
    Mask      = imbinarize(I,T).*Mask;
    Mask      = padarray(Mask, [3 3], 0, 'both');
    s         = [0 1 0; 1 1 1; 0 1 0];
    bd        = imerode(Mask, s);
    bd        = bd(4:end-3, 4:end-3);
    bd        = imdilate(bd, s);
    [y, x]    = find(bd);  
    PC        = [x, y];
end