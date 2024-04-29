function Mask = FilterByTargetSize(Mask, target, tolerance)
    % Filtering by relative size amongst connected components
    RP    = regionprops(Mask, 'Area');
    Area  = [RP.Area];
    sA    = sort(Area);
    nObjs = numel(Area);

    % Number of CC detected
    if nObjs < 1
        Mask = false(size(Mask));
        return
    end

    % Target as percent converted to a value in the sorted list
    target    = target/100;
    tIdx      = target*nObjs;
    tolerance = tolerance/100;
    tolerance = tolerance*nObjs;
    tolerance = tolerance/2;
    mnIdx     = floor(tIdx - tolerance);
    mxIdx     = ceil(tIdx + tolerance);
    mnIdx     = min(max(mnIdx, 1), nObjs);
    mxIdx     = max(min(mxIdx, nObjs), 0);
    mnSz      = sA(mnIdx);
    mxSz      = sA(mxIdx);

    % Filtering out based on criteria
    Mask   = bwareafilt(Mask,[mnSz mxSz]);
end