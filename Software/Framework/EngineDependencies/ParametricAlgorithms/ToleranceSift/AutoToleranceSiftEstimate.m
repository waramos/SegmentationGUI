function paramVector = AutoToleranceSiftEstimate(I)

    % converting to double precision
    I   = medfilt2(I,[3 3], 'symmetric');
    x   = log2(double(I)+1);
    
    % getting sorted list
    x   = sort(x(:));
    
    % cumulative sum of list
    cy  = cumsum(x);
    
    % cumsum of squares
    cy2 = cumsum(x.^2);
    
    % sum of what is left in list
    ry  = cy(end)-cy;
    
    % cumulative sum of squares of what is left
    ry2 = cy2(end)-cy2;
    
    % counts
    x1  = (1:numel(x))';
    x2  = numel(x)-x1;
    
    % variances
    vf = cy2./x1 - (cy./x1).^2;
    vb = ry2./x2 - (ry./x2).^2;
    v  = vf(1:end-1)+vb(1:end-1);
    
    % minimizing
    [~,idx] = min(v);
    
    % output 1, the threshold
    th = x(idx);
    
    % rescaling as percentile
    th     = 2.^(th) - 1;
    th_val = th;
    th     = th/double(max(I(:)));
    th     = th*100;

    % Computing average size of connected components and tolerance to be 3
    % sigma, then scaled relative to range of sizes
    Mask        = I > th_val;
    RP          = regionprops(Mask, 'Area');
    A           = [RP.Area];
    avgSz       = mean(A);
    sigma       = std(A);
    tol         = 3*sigma;
    [mn, mx]    = bounds(A);
    tol         = (avgSz+tol)/(mx-mn); 
    tol         = ceil(tol*100); % round up and bound check 
    tol         = min(tol, 100);

    paramVector = double([th avgSz tol]);
end

