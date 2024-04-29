function B = MaskTaperImage(I, mask, fitbg)
% MASKTAPERIMAGE will use a mask to then compute a taper that rescales the
% values from 100% of their original value at the mask boundary to 0% at
% the image boundary. Additionally, this function has a background fitting
% algorithm that detrends any background trend that could arise from uneven
% illumination.

    % Background fitting
    if nargin < 3
        fitbg = false;
    end

    % Will return original image if user did not provide mask
    if nargin < 2
        B = I;
        return
    end

    % Computing the ROI tapered image
    taper = Mask2TukeyTaper(mask);
    B     = I.*taper;

    % Removing background bias and then adding it back (?)
    if fitbg
        BG    = FitBG(I, mask); % NEED to double check math on this func
        B     = (I-BG).*taper + BG;
    end

    function D = Mask2TukeyTaper(mask)
    % MASK2TUKEYTAPER will apply a tukey window out from the mask boundary
    % to the image boundary to ensure a smooth tapering.
        D = FastDistTransform(mask);
        D = (cos(D*pi)+1)/2;
    end
    

    function D = FastDistTransform(mask)
        [M, N]     = size(mask);
        % Distance from the mask boundary
        d1         = bwdist(mask);
        % Distance to the image boundary
        [idy, idx] = find(~mask);
        d2_vals    = min(idx, idy);
        d2_vals    = min(d2_vals, M-idy);
        d2_vals    = min(d2_vals, N-idx);
        d2         = zeros(size(mask));
        ind        = sub2ind([M N], idy, idx);
        d2(ind)    = d2_vals;
        % Normalized distance 
        D          = d1./(d1+d2);
        D          = max(D, 0);
    end
    

    function BG = FitBG(I, mask)
    % FITBG will fit the background of the image
        [M, N] = size(I, [1 2]);
        W      = 1 - mask;
        [y, x] = ndgrid(1:M, 1:N);
        G      = [ones((M*N), 1) x(:) y(:)];
        BG     = G*((G' * (W(:).*G))\(G' * (W(:).*I(:))));
        BG     = reshape(BG, [M N]);
    end
end