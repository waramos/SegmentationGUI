function J = ClippedLoG(I, sigma)
    % Finding a clipped Laplacian of Gaussian
    sigma = max(sigma, 0.1);
    J     = imgaussfilt(I,sigma);
    J     = imfilter(J,[0 1 0;1 -4 1;0 1 0], "replicate");
    J     = max(J,0);
end