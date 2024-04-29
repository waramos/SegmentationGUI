function Mask = FilterBySize(Mask, mnSz, mxSz)

    % Filtering by relative size amongst connected components
    RP   = regionprops(Mask, 'Area');
    Area = [RP.Area];
    sA   = sort(Area);

    % In case user flips the min and max bounds
    if mnSz > mxSz
        [mxSz, mnSz] = deal(mnSz, mxSz);
    end

    % Converting to percent value
    mnSz = mnSz/100;
    mxSz = mxSz/100;

    % Number of CC detected
    nObjects = numel(Area);
    if nObjects < 1
        Mask = false(size(Mask));
        return
    end

    % Filtering by percentile of sizes
    lbIdx = max(floor(mnSz*nObjects), 1);
    lbIdx = min(lbIdx, nObjects);
    ubIdx = max(ceil(mxSz*nObjects), 1);
    ubIdx = min(ubIdx, nObjects);
    mnSz  = sA(lbIdx);
    mxSz  = sA(ubIdx);
    Mask  = bwareafilt(Mask,[mnSz mxSz]);
end