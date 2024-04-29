function I = DownSampleUpSample(I, factor)
    % Simple 'pyramid' denoising
    if nargin < 2
        factor = 1.5;
    end
    [M,N,D] = size(I,[1 2 3]);
    % In case of RGB
    for i = 1:D
        im = I(:,:,D);
        im = medfilt2(im, [3 3], 'symmetric');
        im = imresize(im,max(1,ceil([M N]/factor)),'lanczos3');
        im = imgaussfilt(im, 1.6, 'Padding', 'symmetric');
        im = imresize(im,max(1,[M N]),'lanczos3');
        I(:,:,i) = im;
    end
end