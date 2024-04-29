function pVec = BradleyAutoParams(I)
% BRADLEYAUTOPARAMS will estimate a radius to use for the window size of an
% adaptive thresholding method. This window size needs to be larger than
% the features the user is interested in finding. Therefore, this function
% will estimate a radius based off of the most common frequency present in
% the laplacian of the image. This frequency would suggest 
    I  = double(I);
    Ig = imgaussfilt(I, 1, 'Padding','symmetric');
    k  = [0 1 0; 1 -4 1; 0 1 0];
    L  = imfilter(Ig, k, 'symmetric');

    % Median filtering the laplacian and computing the FFT
    L_mf = medfilt2(L, [3 3], 'symmetric');
    F    = fft2(L_mf);

    % Finding the most common frequency to determine feature size
    F    = real(F);
    F    = abs(F(:));
    [N, edges] = histcounts(F);
    [~, idx]   = max(N);
    diam       = edges(idx+1);
    radius     = ceil(diam/2);

    % KMeans to find the threshold value of foreground
    I_mf   = medfilt2(I, 'symmetric');
    [~, C] = kmeans(I_mf(:), 2);
    th     = max(C);

    % Radius, threshold, and shrink factor
    pVec       = [radius th 0.5];
end