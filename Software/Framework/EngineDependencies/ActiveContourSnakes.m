function S = ActiveContourSnakes(I, Mask, n, smoothness, factor, cbias)
% mask = ActiveContour(I, mask, n, smoothness, factor, contractionBias)
% mask = ActiveContour(I, mask, n, smoothness, factor)
% mask = ActiveContour(I, mask, n, smoothness)
% mask = ActiveContour(I, mask, n)
% mask = ActiveContour(I, mask)
%
% SUMMARY:
% ACTIVECONTOURS will apply the active contour (snakes) algorithm to an
% initial guess of a region for an image. The region will grow accordingly.
% 
% INPUTS:
% I - (Required: 2d image array) image on which ROI will be iteratively
% calculated
% Intended Datatypes: uint8, uint16, single, double
%
% mask - (Required: image mask) resulting mask from a user drawn ROI
% Intended Datatypes: logical 
%
% n - (Optional: iterations) number of iterations to compute
% Intended Datatypes: uint8, uint16, single, double
%
% smoothness - (Optional) regularity of segmentation boundary
% Intended Datatypes: uint8, uint16, single, double
%
% factor - (optional: resizing) factor for downscaling that is follwed by
% upscaling. The greater this value, the more compression of high frequency
% information that occurs.
% Intended Datatypes: uint8, uint16, single, double
%
% cbias - (optional: contraction bias) tendency to contract inwards or grow
% outwards. 
% Intended Datatypes: uint8, uint16, single, double
%
% OUPUTS:
% mask - (image mask) result from the active contours algorithm
% Intended Datatypes: logical 
    
    if any(Mask(:))
        if nargin < 6
            % Tendency to contract boundary inward
            cbias = 0;
        end

        if nargin < 5
            % Image preprocessing - smoothing via resizing down then up
            factor = 3;
        end

        if nargin < 4
            % Regularity of boundary of segmented region
            smoothness = 0;
        end

        if nargin < 3
            % Number of iterations in the algorithm
            n = 100;
        end
        
        % Reduces noise by downsampling and then upsampling back to
        % original scale
        [M, N]     = size(I, [1 2]);
        I          = imresize(I,max(1,ceil([M N]/factor)),'nearest');
        I          = imresize(I,max(1,[M N]),'bilinear');

        % In case contour points are given, a mask can be computed
        iscontour = size(Mask, 2) == 2;
        if iscontour
            Mask  = poly2mask(Mask(:,1), Mask(:,2), M, N);
        end

        % Snakes grow towards contour on reduced image - speed up
        I    = imresize(I, ceil([M N]/factor), 'nearest');
        Mask = imresize(Mask, ceil([M N]/factor));
        Mask = activecontour(I, Mask, n,'Chan-vese', 'SmoothFactor', smoothness, 'ContractionBias', cbias);

        % Refinement of mask and elimination of small objects
        Mask = imclose(Mask, [0 1 0; 1 1 1; 0 1 0]);
        CC   = bwconncomp(Mask);
        if numel(CC) > 1
            A      = regionprops(CC, 'Area');
            A      = max([A.Area]);
            A      = A - 1;
            Mask   = bwareaopen(Mask, A);
        end

        % Upscaling to original size and produce snakes improved mask, S
        S = imresize(Mask, [M N]);

        % If input data was a contour, a contour is output instead
        if iscontour
            Mask = S;
            % Can assume that a neutral contraction bias would correspond
            % to a shrinkfactor of 0 for an alpha shape...
            % Maximizing the contraction or minimizing it so that snakes
            % instead move out would require the shrink factor to be closer
            % to its maximum
            ShrinkFactor = (2*cbias.^2)/2;

            bd     = imdilate(Mask, ones(3)) ~= Mask;
            [y, x] = find(bd);
            if ~isempty(x)
                p = uniquetol([x(:) y(:)], sqrt(2)+eps, 'ByRows', true, 'DataScale', 1);
                x = p(:, 1);
                y = p(:, 2);
                b = boundary(x, y, ShrinkFactor);
                x = x(b);
                y = y(b);
                S = [x y];
            else
                S = [];
            end
        end
    end
end