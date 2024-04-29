function mask = ActiveContours(I, mask, n, smoothness, factor, contractionBias)
% mask = ActiveContours(I, mask)
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
% OUPUTS:
% mask - (image mask) result from the active contours algorithm
% Intended Datatypes: logical 

    if any(mask(:))
        if nargin < 3
            % Number of iterations in the algorithm
            n          = 100;
        end
        if nargin < 4
            % Regularity of boundary of segmented region
            smoothness = 0;
        end
        if nargin < 5
            % Image preprocessing - smoothing via resizing down then up
            factor     = 3;
        end
        if nargin < 6
            % Tendency to contract boundary inward
            contractionBias = 0;
        end

        [M, N]     = size(I, [1 2]);
        I          = imresize(I,max(1,ceil([M N]/factor)),'nearest');
        I          = imresize(I,max(1,[M N]),'bilinear');

        if size(mask, 2) == 2
            % If second arugment is the set of contour points, an actual
            % mask will have to be computed and points will have to be
            % produced at the end so that the same format is preserved
            mask      = poly2mask(mask(:,1), mask(:,2), M, N);
            CompPFlag = true;
        else
            CompPFlag = false;
        end

        % Snakes grow towards contour on reduced image - speed up
        I          = imresize(I, ceil([M N]/factor), 'nearest');
        mask       = imresize(mask, ceil([M N]/factor));
        mask       = activecontour(I, mask, n,'Chan-vese', 'SmoothFactor', smoothness, 'ContractionBias', contractionBias);
        % Refinement of mask and elimination of small objects
        mask       = imclose(mask, [0 1 0; 1 1 1; 0 1 0]);
        CC         = bwconncomp(mask);
        if numel(CC) > 1
            A      = regionprops(CC, 'Area');
            A      = max([A.Area]);
            A      = A - 1;
            mask   = bwareaopen(mask, A);
        end
        mask   = imresize(mask, [M N]);

        if CompPFlag
            % Produces boundary of mask
            bd       = imdilate(mask, ones(3)) ~= mask;
            [y, x]   = find(bd);
            if ~isempty(x)
                p    = uniquetol([x(:) y(:)], sqrt(2)+eps, 'ByRows', true, 'DataScale', 1);
                x    = p(:, 1);
                y    = p(:, 2);
                mask = [x y];
            else
                mask = [];
            end
        end
    end
end