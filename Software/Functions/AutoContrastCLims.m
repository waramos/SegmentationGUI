function [lb, ub] = AutoContrastCLims(I)
% [bottomlim, toplim] = ImAC(I)
%
% IMAC is an Image AutoContrast function. It will take an image and 
% determine the appropriate limits for automatic contrast adjustment. It 
% can do his based on a kmeans algorithm or based on percentile approach.
%
% INPUTS:     
% I - (Required: image) 2D array
% Intended Datatypes: logical, uint8, uint16, single, double
%
% flg - (Optional: flag) true will compute using the k-means algorithm. If
% the flag is false or absent, a simpler percentile approach will be used.
% Intended Datatypes: logical
%
% NOTES:
% The function will automatically set the bottom limit as 1% of the max 
% value and the top limit as the top 99th percentile of the values after 
% the bottom limit is trimmed off. This contrasts from the k-means approach 
% which will use k=2. From here, the middle point across the range of the 
% first bin will be selected as the bottom limit and the top limit will be
% set as the top 95th percentile of the second bin.

    if ~islogical(I)
        for i = 1:size(I, 3)
            I(:,:,i)      = medfilt2(I(:,:,i));
        end
        I      = double(I);
        ordI   = sort(I(:));
        n      = numel(I);
        lb_idx = round(0.01*n);
        up_idx = round(0.999*n);
        lb     = ordI(lb_idx);
        ub     = ordI(up_idx);
    else
        lb = 0;
        ub = 1;
    end
end