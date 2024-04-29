function pVec = AutoGradThresholdEstimate(I)
    I = double(I);
    % Radius of 3 speeds up computation in preprocessing
    p1 = 3;
    J  = RescaleAndSmooth({I, p1});
    % Threshold value can be established w/ default autothreshold algorithm
    p2 = AutoThresholdEstimate(J);
    p2 = p2(1);
    % Midpoint between means from k=2 kmeans done on gradient magnitude
    dx     = I(:, [2:end end]) - I(:, [1 1:end-1]);
    dy     = I([2:end end], :) - I([1 1:end-1], :);
    dx     = dx.^2;
    dy     = dy.^2;
    dM     = sqrt(dx+dy);
    dM     = dM/max(dM(:));
    [~, c] = kmeans(dM(:), 2);
    p3     = mean(c);
    pVec   = [p1 p2 p3];
end