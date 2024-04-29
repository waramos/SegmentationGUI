function I = ClipImage(I, threshold)
    % Image has a value clipped from it. The threshold value is relative to
    % the full range of the image.
    mn_mx     = range(I(:), 'all');
    threshold = (threshold/100)*mn_mx;
    I         = max(I - threshold,0);
end