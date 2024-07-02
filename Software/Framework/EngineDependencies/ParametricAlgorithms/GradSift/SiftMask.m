function Mask = SiftMask(Mask, sz, tol)
% SIFTMASK will sift the mask based on a target size and a tolerance +/- of
% the target CC size.
    % Adding tolerance to size to enable size range
    sz   = sz + [-tol tol];
    sz   = max(sz, 1);

    Mask = bwareafilt(Mask, sz);
    Mask = imfill(Mask, "holes");
end