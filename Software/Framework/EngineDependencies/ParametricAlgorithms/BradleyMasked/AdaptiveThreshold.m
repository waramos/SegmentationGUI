function T = AdaptiveThreshold(I, radius)
% ADAPTIVETHRESHOLD computes a local threshold map based on the local mean
% of a median filtered image.
    I           = medfilt2(I, 'symmetric');
    w           = 2*ceil(radius)+1;
    T           = adaptthresh(I,...
                  'NeighborhoodSize',[w w],...
                  'ForegroundPolarity','bright',...
                  'Statistic','mean');
end
