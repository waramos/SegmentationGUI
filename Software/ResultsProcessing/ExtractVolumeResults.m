function V = ExtractVolumeResults(fid)
% EXTRACTSEGMENTEDVOLUME will pull out the volume that represents either a
% label array or masked array that was produced in the Segmentation GUI.
    load(fid, "SegmentationResults")
    SegmentationResults = SegmentationResults.SegmentationInfo;
    data = SegmentationResults(1).Results(1);

    % Checks on data
    [c, z]            = size(data, [2 3]);
    isimagetype       = c > 2;
    isvolume          = z > 1;
    isnonfloatnumeric = (~islogical(data) || ~isa(data, 'uint8') || ~isa(data, 'uint16'));


    % Error if incorrect result type
    if isimagetype && isvolume && isnonfloatnumeric
        error('Results in this file are not a mask or label matrix. Please try loading different results or load as a pointcloud.')
    end

    V = cat(3, SegmentationResults.Results);
end