function Points = Mask2Poly(Mask, ShrinkFactor)
    % Produces boundary of mask
    Mask   = padarray(Mask, [3 3], 0, 'both');
    s      = [0 1 0; 1 1 1; 0 1 0];
    bd     = imerode(Mask, s) ~= Mask;
    bd     = bd(4:end-3, 4:end-3);
    bd     = imdilate(bd, s);
    [y, x] = find(bd);
    if ~isempty(x)
        p = uniquetol([x(:) y(:)], sqrt(2)+eps, 'ByRows', true, 'DataScale', 1);
        
%         p = CurveSimplifier(p);
        x = p(:, 1);
        y = p(:, 2);

        % Limit number of points to speed up computation
%         while numel(x) > 2000
%             x = x(1:2:end);
%             y = y(1:2:end);
%         end
        b = boundary(x, y, ShrinkFactor);
        x = x(b);
        y = y(b);
        Points = [x y];
    else
        Points = [];
    end
end