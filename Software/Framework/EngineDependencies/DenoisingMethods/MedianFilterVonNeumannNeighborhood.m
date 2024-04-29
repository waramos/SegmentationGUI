function I = MedianFilterVonNeumannNeighborhood(I, k)

    if nargin < 2
        % Kernel designation for the ordfilt
        k = [0 1 0; 1 1 1; 0 1 0];
    end

    med_idx = sum(k(:));
    for i = 1:size(I,3)
        im       = I(:,:,i);
        im       = ordfilt2(im, med_idx, k, 'symmetric');
        I(:,:,i) = im;
    end
end