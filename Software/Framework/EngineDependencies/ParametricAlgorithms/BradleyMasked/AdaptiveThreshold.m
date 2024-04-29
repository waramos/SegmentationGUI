function T = AdaptiveThreshold(I, radius)
% Layer 2 - Computational Layer 1
    % Data from layer 1
    % Parameter 1
    I           = medfilt2(I, 'symmetric');
    w           = 2*ceil(radius)+1;
    T           = adaptthresh(I,...
                  'NeighborhoodSize',[w w],...
                  'ForegroundPolarity','bright',...
                  'Statistic','mean');
end
