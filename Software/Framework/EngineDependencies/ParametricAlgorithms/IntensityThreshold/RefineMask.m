function Mask = RefineMask(Mask, Radius)
    if Radius > 0
        % Closes holes and improves boundary of binary image
        Radius = round(Radius);
        
        % Circular mask kernel
        d    = 2*Radius+1;
        cx   = 1:d;
        cy   = cx';
        h    = ((cx-(Radius+1)).^2 + (cy-(Radius+1)).^2) <= ((Radius)^2);
        Mask = imopen(Mask, h);
        Mask = imclose(Mask, h);
        Mask = imdilate(Mask,[0 1 0;1 1 1;0 1 0]);
    end
end