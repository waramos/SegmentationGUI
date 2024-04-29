function Points = BlobHull(PC, sigma, alpha)
    x = PC(:,1);
    y = PC(:,2);
    
    try
        p      = uniquetol([x(:) y(:)], sqrt(2)+eps, 'ByRows', true, 'DataScale', 1);
        x      = p(:, 1);
        y      = p(:, 2);
        bd     = boundary(x, y, alpha);
        p      = [x(bd) y(bd)];
        
        % moving out boundary based on scale of sigma (since hull is around peaks,
        % not blobs)
        t      = circshift(p,[1 0])+circshift(p,[-1 0]);
        t      = t./max(eps,sqrt(sum(t.^2,2)));
        t      = imfilter(t, ones(5, 1)/5, "circular");
        n      = [-t(:,2) t(:,1)];
        Points = p+sigma*n;
    catch
        Points = [];
    end
end