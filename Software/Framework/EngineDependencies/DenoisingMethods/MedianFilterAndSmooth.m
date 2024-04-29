function I = MedianFilterAndSmooth(I, mn, sigma)
    if nargin < 3
        sigma = 1.6;
    end
    if nargin < 2
        mn = [3 3];
    end
    % In case of RGB
    for i = 1:size(I, 3)
        I(:,:,i) = medfilt2(I(:,:,i), mn, 'symmetric');
    end
    I = imgaussfilt(I, sigma, 'Padding', 'symmetric');
end