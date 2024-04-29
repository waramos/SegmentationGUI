function Segmentation2TrainingData(fid, targetDir, sz)
% SEGMENTATION2TRAININGDATA will enable a user to convert their
% segmentation results into a training dataset for supevised learning of a
% segmentation task. If the exported file holds masks, the masks are loaded 
% and saved as a .tif, otherwise, if the results were a contour, a mask is
% computed from these points.

    arguments
        fid       {mustBeFile}
        targetDir {mustBeFolder}
        sz        {mustBePositive, mustBeFinite}
    end

    % The file to be converted to training data
    if nargin < 1
        [fname, fpath] = uigetfile('*.mat',"MultiSelect","off");
        fid = [fpath filesep fname];
    end

    % Target to save the images and labels to
    if nargin < 2
        targetDir = uigetdir;
    end

    % if user would like resizing
    if nargin < 3
        Answer = questdlg('Resize images and labels?', 'Data resampling', 'No');
        if strcmp(Answer, 'No')
            sz = [];
        elseif strcmp(Answer, 'Yes')
            sz = inputdlg({'Number of rows', 'Number of columns'}, 'New size', [1 40], {'256', '256'});
            sz = cellfun(@str2double, sz, 'UniformOutput', false);
            sz = sz{:};
        end
    end

    % Checking to see if target directories exists
    if exist(targetDir, "dir") == 0
        mkdir(targetDir)
    end

    LabDir = [targetDir filesep 'Labels'];
    if exist(LabDir, "dir") == 0
        mkdir(LabDir)
    end

    ImDir = [targetDir filesep 'Images'];
    if exist(ImDir, "dir") == 0
        mkdir(ImDir)
    end

    % Loading in the segmentation results 
    load(fid, 'SegmentationResults')
    SegmentationResults = SegmentationResults.SegmentationInfo;

    % Since the above struct has file locations rather than the raw data
    % itself, it can copy the data over if there is no resizing involved,
    % otherwise, the original data is loaded in and then resized.
    
    nResults = numel(SegmentationResults);
    oldFID   = [];
    for i = 1:nResults
        Seg             = SegmentationResults(i);
        rawFID          = Seg.FilePath;
        [~, fname, ext] = fileparts(rawFID);
        
        % Query slice and timepoint across the results to save individual
        % 2D images

        % Saving image data
        if contains(ext, 'tif')
            % Z slice and timepoint indices - makes assumption timepoint
            % might be stacked across 3rd dim as well (e.g. ome bioformats)
            % t_idx  = Seg.TimePoint;
            z_idx  = Seg.Slice;
            newFID = [ImDir filesep fname '_Z' num2str(z_idx) ext];
            I      = tiffreadVolume(rawFID, 'PixelRegion', {[1 inf] [1 inf] [z_idx z_idx]});
            if ~isempty(sz)
                I  = imresize(I, sz);
            end
            imwrite(I, newFID)
        elseif contains(ext, {'png', 'jpeg', 'jpg', 'gif'})
            newFID = [ImDir filesep fname ext];
            copyfile(rawFID, newFID)
        end

        % Sizing info
        if ~strcmp(rawFID, oldFID)
            imInfo = imfinfo(rawFID);
            M      = imInfo.Height;
            N      = imInfo.Width;
        end

        % Limits refresh on file metadata checks
        oldFID = rawFID;

        % Saving mask data
        if size(Seg.Results,2) == 2
            X    = Seg.Results(:,1);
            Y    = Seg.Results(:,2);
            Mask = poly2mask(X, Y, M, N);
        elseif size(Seg.Results,2) >2
            Mask = Seg.Results;
        end
        if ~isempty(sz)
            Mask  = imresize(Mask, sz);
        end
        [~, fname, ext] = fileparts(newFID);
        maskFID = [LabDir filesep fname ext];
        imwrite(Mask, maskFID)

        msg = ['Converted ' num2str(i) '/' num2str(nResults)];
        disp(msg)
    end
end