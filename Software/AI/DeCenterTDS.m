function DeCenterTDS(FolderPath, nViews, sz, targetDir, newSz)

    if nargin < 1 || isempty(FolderPath)
        FolderPath = uigetdir(cd, 'Select training data');
    end

    if nargin < 2 || isempty(nViews)
        nViews = 100;
    end

    % Creating image datastores to pull out images
    ImDir  = [FolderPath filesep 'Images'];
    LabDir = [FolderPath filesep 'Labels'];
    ImDS   = imageDatastore(ImDir);
    LabDS  = imageDatastore(LabDir);

    % Setting up folder to save decentered data to
    if nargin < 4 || isempty(targetDir)
        targetDir = uigetdir(cd, 'Select new save location');
    end

    ImDirNew  = [targetDir filesep 'DeCentered' filesep 'Images'];
    LabDirNew = [targetDir filesep 'DeCentered' filesep 'Labels'];

    if nargin < 5 || isempty(newSz)
        newSz = 128;
    end

    % If target directories do not already exist
    if exist(ImDirNew, 'dir') == 0
        mkdir(ImDirNew)
        mkdir(LabDirNew)
    end

    % Size of patches
    if nargin < 3 || isempty(sz)
        sz = 0.5;
    end

    % Number of files to look at
    nFiles = numel(ImDS.Files);
    for fileIdx = 1:nFiles
        % Loading in the images and their corresponding labels
        I    = ImDS.readimage(fileIdx);
        L    = LabDS.readimage(fileIdx);

        % Rescaling data before grabbing patches
        I        = double(I);
        [mn, mx] = bounds(I(:));
        I        = (I-mn)*(255/(mx-mn));
        I        = uint8(I);

        % Getting file names
        ImName          = ImDS.Files{fileIdx};
        [~, fName, ext] = fileparts(ImName);
        

        % Size of original image
        ogSz    = size(I, [1 2]);
        psz     = round(sz*ogSz);
        psz     = min(psz);

        for viewIdx = 1:nViews
            % New file names
            NewName = [fName '_RandomPatch' num2str(viewIdx) '_Size' num2str(newSz) ext];
            ImName  = [ImDirNew filesep NewName];
            LabName = [LabDirNew filesep NewName];
            win     = randomWindow2d(ogSz, [psz psz]);
            x       = win.XLimits;
            y       = win.YLimits;
            % Grabbing the random patch
            I2      = I(y(1):y(2), x(1):x(2));
            L2      = L(y(1):y(2), x(1):x(2));
            % Resizing data to appropriate size
            I2      = imresize(I2, [newSz newSz]);
            L2      = imresize(L2, [newSz newSz]);
            % Writing new patches
            imwrite(I2, ImName)
            imwrite(L2, LabName)
            msg = ['File has been written: ' fName newline...
                   'Patch: ' num2str(viewIdx) '/' num2str(nViews)];
            disp(msg)
        end
    end
end