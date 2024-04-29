function InitPaths(flag)
% INITPATHS will add all paths that are nested below the folder that this
% function is found in. Facilitates getting all folders ready for a GUI app
% to launch
% if flag is false, will remove all paths
    if nargin == 0
        flag = true;
    end

    Parent     = fileparts(mfilename("fullpath"));
    AllFolders = genpath(Parent);

    if flag
        addpath(AllFolders)
    else
        rmpath(AllFolders)
    end
end