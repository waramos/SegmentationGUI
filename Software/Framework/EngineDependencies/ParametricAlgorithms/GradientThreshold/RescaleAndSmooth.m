function J = RescaleAndSmooth(I, px)
    if px>0
        I   = double(I);
        % Autocontrasting and clipping
        I   = medfilt2(I, 'symmetric');
        [mn, mx] = bounds(I, "all");
        r   = mx-mn;
        vmx = round(0.99*r)+mn;
        vmn = round(0.01*r)+mn;
        I   = max(0, (I-vmn)/(vmx+eps-vmn));
        I   = I*100;
        % Smoothing the image and thresholding
        J   = imgaussfilt(I, px, 'Padding','symmetric');
    else
        J   = double(I);
    end
end