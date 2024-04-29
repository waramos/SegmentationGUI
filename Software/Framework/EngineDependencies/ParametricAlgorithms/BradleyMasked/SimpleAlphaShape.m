function Points = SimpleAlphaShape(PC, alpha)
% Layer 4 - Computational Layer 3

    % Data from layer 3
    % Parameter 3
    if isempty(PC)
        % Exits when there are no points
        Points = [];
        return
    end
    x           = PC(:,1);
    y           = PC(:,2);
    % Points are reduced down to minimal point cloud before finding
    % boundary points
    p           = uniquetol([x(:) y(:)], sqrt(2)+eps, 'ByRows', true, 'DataScale', 1);
    x           = p(:, 1);
    y           = p(:, 2);
    bd          = boundary(x, y, alpha);
    Points      = [x(bd) y(bd)];
end