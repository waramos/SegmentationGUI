function AllExts = GetAllBFExtensions
% GETALLBFEXTENSIONS will parse out all the OME BioFormats compatible file
% format extensions to reorganize into a cell array with the extensions as
% character arrays in each cell. This is useful for string comparisons and
% conditional cases.

    try
        bffileexts = bfGetFileExtensions;
    catch
        % In case a bf reader object has not been initialized 
        bfr        = bfGetReader;
        bffileexts = bfGetFileExtensions;
    end

    % File extensions - drop first row that has all extensions in it
    bffileexts = bffileexts(:,1);
    bffileexts = bffileexts(2:end);

    % Indices corresponding to start of the file extension
    bff_idx = cellfun(@(x) regexp(x, '[.]'), bffileexts, 'UniformOutput', false);
    numexts = numel(bff_idx);

    % All extensions
    AllExts = {};
    for i = 1:numexts
        % Indices of 
        idx  = bff_idx{i};
        fext = bffileexts{i};
        n    = numel(fext);             % Num. of characters in char array
        idx2 = [idx' [idx(2:end)'; n]];
        n    = size(idx2, 1);           % Num. of recognized exts
        z    = zeros(n, 2);
        z(1:n-1, 2) = -3;
        idx2 = idx2 + z;
        ind1 = numel(AllExts) + 1;
        ind2 = ind1 + n - 1;
        ind = ind1:ind2;
        for j = 1:n
            % extension list index
            e_idx          = ind(j);
            AllExts{e_idx} = fext(idx2(j,1):idx2(j,2));
        end
    end

end