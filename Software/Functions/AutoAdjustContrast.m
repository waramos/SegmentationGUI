function AutoAdjustContrast(ax, acflag)
% AUTOADJUSTCONTRAST will auto contrast an image in an axes object by
% extracting the plotted image and setting color limits based off of the
% bottom value at the 1st percentile and top value at the 99.9-th 
% percentile. If the autocontrast flag is set to false, the color limits
% are set based on the overall min and max of the image.

    if nargin < 2
        acflag = true;
    end
    % Will find the image object plotted in the axes and extract
    imH = ax.Children.findobj('Type', 'Image');
    im  = imH.CData;
    im  = double(im);

    % Grayscale
    if size(im, 3) == 1
        [lb, ub] = FilteredBounds(im, acflag);
        % Sets axes color limits and ensures imcontrast can work by making
        % double 
        ax.CLim = double([lb, ub]);
    elseif size(im, 3) == 3
        % Leaves range alone
        return
    end
end


function [lb, ub] = FilteredBounds(I, acflag)
    if acflag
        if ~islogical(I)
            % Color limits based off of percentiles in sorted pixel list
            I      = medfilt2(I);
            ordI   = sort(I(:));
            n      = numel(I);
            lb_idx = round(0.01*n);
            ub_idx = round(0.999*n);
            lb     = ordI(lb_idx);
            ub     = ordI(ub_idx);
            if lb == ub
                ub = lb + 1;
            end
        else
            % Logical image
            lb = 0;
            ub = 1;
        end
    else
        % Will just include the full range
        lb = min(I(:));
        ub = max(I(:));
    end
end