function Points = PointsFromMask(Mask)
    % Converting the mask to points
    bd     = imdilate(Mask, ones(3)) ~= Mask;
    [y, x] = find (bd);
    if ~isempty(x)
            p      = uniquetol([x(:) y(:)], sqrt(2)+eps, 'ByRows', true, 'DataScale', 1);
            xx     = p(:,1);
            yy     = p(:,2);
            b      = boundary(xx, yy, 0);
            xx     = xx(b);
            yy     = yy(b);
            Points = [xx, yy];
    else
        Points = [];
    end
end