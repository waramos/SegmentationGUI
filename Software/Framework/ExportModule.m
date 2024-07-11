classdef ExportModule < handle
% EXPORTMODULE is a data-centric module for exporting data into multiple
% standard and commonly used formats. This module can handle masks, point
% clouds, and closed curves computed from images. The cell array of results
% enables flexibility and allows for future development to explore other
% data formats. It even allows the the array to hold different types of
% results but this will then limit the number of viable format options for
% export.
%
% Masks are only saved by default in .mat, .xml, and .json if the results
% are masks. Other formats will require the user to enable the
% "outputmasks" property in this class. 
%
% By default, this module only exports:
% - the settings used to compute the results
% - points into .mat, .json, .xml, .csv, .xlsx
% - masks into .mat, .json, .xml
% - region properties IF the results are masks or closed curves
%
% If export to masks in .tif or .png files is desired, user need to set the
% outmasks property of the class to true before calling the ExportData
% method.
%
% William A. Ramos, Kumar Lab @ MBL, Woods Hole, April 2024


%% Class Properties
    properties (Access = public)
        % Visuals
        Progdlg                  % Progress bar dialog box to show the percent export done
        dmsg                     % Dialog box message to display during export

        % Parent figure
        Parent                   % Upon construction, the class will grab the handle for a GUI figure if the class is instantiated from a callback

        % Toggles masks' export
        outputmasks = false     % Logical determines whether masks need to be computed / determined for point clouds
    end


    properties (GetAccess = public, SetAccess = private)
        % Metadata
        Date                     % Date of export
        Time                     % Time of export

        % Mask Stack Export Settings
        maskfilepath             % File path for exported mask(s) 
        maskfilename             % File name for exported mask(s) 
        maskfileext              % File extension for exported mask(s) 

        % Mask properties (Parameter settings/Stats) Export Settings
        outputpath                % File path for parameter / stats file export
        outputname                % File name for mask properties file 
        outputext                 % File extension for the properties file
        Requestedprops            % List of statistics to be pulled from region props

        % Results output
        Allinfo                   % Results and the settings used to achieve the results
        Results                   % The ZxT cell array that holds segmentation/detection results
        slices                    % Z indices (volume slices) of segmented 2D planes
        timepoints                % T indices (timeseries frame) of segmented 2D planes
    end


    properties (Access = private)
        % Image/Results Metadata
        mrows                    % y dimension of image - Number of rows needed for proper poly2mask computation in case of contour curve with masks requested
        ncols                    % x dimension of image - Number of columns needed for proper poly2mask computation in case of contour curve with masks requested
        
        % Requested properties
        bboxreq                  % Logical whether bounding box is requested
        aspectratioreq           % Logical whether aspect ratio is requested

        % Additional tools
        TiffWriter     % Fast tiff writer - would be good for a fully segmented stack
    end


    properties (Dependent)
        % Dependent properties - can be more dynamic
        saveallowed          % checks if user is at risk at overwriting and enables saving to target location if true
        numslices            % checks number of z slices in dataset
        numframes            % checks number of time frames in dataset
        isvolume             % checks to see if data has a third spatial dimension, i.e. > 1 z slice (first dimension of results cell array)
        istimeseries         % checks to see if data has a temporal dimension, i.e. > 1 frame (second dimension of results cell array)
        rtypemismatch        % checks results for number of different types of result formats. Helpful for file formats that are ideally suited to one result type.
        masksinresults       % checks results for any masks in the results cell array. This format is incompatible with .csv and .xlsx so users have to enable mask writing to either a .tiff or .png for those export formats.
        maskfid              % filepath for masks export
        outputfid            % filepath for output of settings and results
    end




%% Constructor and Set/Get methods
    methods
        function obj = ExportModule(f)
            % Contructor
            if nargin < 1 || isempty(f)
                f = gcbf;
            end
            if ~isempty(f)
                obj.Parent = f;
            end

            % Init fast tiff writer in case of fully segmented stack case
            obj.TiffWriter = FWTiff;
        end


        function cansave = get.saveallowed(obj)
            % checks to see if using the currently set filepath would lead
            % to an overwrite and then prompts user to confirm the
            % overwrite, otherwise, the user can write the file.

            % Currently set filepath
            fid = [obj.outputpath filesep obj.outputname obj.outputext];
            if exist(fid, "file") == 2
                % Overwrite might occur, ask user to overwrite results
                prompt = 'File already exists. Proceed and overwrite?';
                if ~isempty(obj.Parent)
                    % GUI dialog
                    Answer  = uiconfirm(obj.Parent, prompt, 'File Overwrite');
                    cansave = strcmp(Answer, 'OK');
                else
                    % CLI dialog
                    prompt  = [prompt ' Enter y/n.'];
                    x       = input(prompt);
                    cansave = isempty(x) || strcmp(x, 'y');
                end
            else
                % User can save if the file does not exist yet
                cansave = true;
            end
        end


        function nslices = get.numslices(obj)
            % checks number of slices present in volume.
            nslices = size(obj.Results, 1);
        end


        function nframes = get.numframes(obj)
            % checks number of frames present in time series.
            nframes = size(obj.Results, 2);
        end


        function hasframes = get.istimeseries(obj)
            % checks second dimension of cell array as it represents time
            hasframes = obj.numframes > 1;
        end


        function hasslices = get.isvolume(obj)
            % checks first dimension of cell array as it represents z
            hasslices = obj.numslices > 1;
        end


        function mismatch = get.rtypemismatch(obj)
            % rtypemismatch returns true if there is a mismatch in the
            % types of results present. This might disable certain export
            % format options or other functionality.
            ntypes   = obj.ResultsFormatInfo;
            mismatch = ntypes>1;
        end


        function masksfound = get.masksinresults(obj)
            % masksinresults returns true if there are any masks in the
            % results array
            [~, typelist] = obj.ResultsFormatInfo;
            masksfound    = any(strcmp(typelist, 'mask'));
        end


        function fid = get.maskfid(obj)
            % maskfid gets full fid for the mask file(s) to be saved
            fid = [obj.maskfilepath filesep obj.maskfilename obj.maskfileext];
        end


        function fid = get.outputfid(obj)
            % outputfid gets full fid for the output file
            fid = [obj.outputpath filesep obj.outputname obj.outputext];
        end


        function [ntypes, typeslist] = ResultsFormatInfo(obj)
            % RESULTSINFO will return a list with the different result
            % types found in the results array and how many different types
            % were found.
            typeslist = cellfun(@obj.CheckResultType, obj.Results(:), 'UniformOutput', false);
            notype    = cellfun(@isempty, typeslist);
            typeslist = typeslist(~notype);
            ntypes    = numel(unique(typeslist));
        end


        function SetImageBounds(obj, yxsz)
            % SETIMAGBOUNDS will set the y and x dimensions of the image to
            % enable proper mask production when masks are requested from
            % contour curves.
            obj.mrows = yxsz(1);
            obj.ncols = yxsz(2);
        end


        function R = GetPoints(obj)
            % GETPOINTS will reorganize the computed results into an array
            % that represents point coordinates.
            R        = obj.Results;
            [r, c]   = find(~cellfun(@isempty, obj.Results));
            nresults = numel(r);

            % If a volume, z slice index is appended
            for i = 1:nresults
                s       = r(i);
                t       = c(i);
                np      = size(R{s, t}, 1);
                R{s, t} = [R{s, t} repmat(s, [np, 1]) repmat(t, [np, 1])];
            end

            % Concatenate as array of points with up to 4 dimensions
            R = vertcat(R{:});

            % Eliminating singleton higher dimensions 
            if ~obj.istimeseries
                % Drops 4th dim
                R = R(:, 1:3);
            end

            if ~obj.isvolume
                % Drops 3rd dim
                if obj.istimeseries
                    R = R(:, [1:2, 4]);
                else
                    R = R(:,1:2);
                end
            end
        end


        function pointsonly = OnlyHasPoints(obj)
            % ONLYHASPOINTS returns true when the results array only has
            % point detections or contours and no other result types. 
            % Check that data is only composed of point detections
            for i = 1:numel(obj.Results)
                [~, typeslist] = obj.ResultsFormatInfo;
                ispoints       = contains(typeslist, {'pointcloud', 'contour'}) & ~contains(typeslist, 'mask');
                pointsonly     = all(ispoints);
            end
        end


        function T = PointsAsTable(obj)
            % Checks that there are only points in the results
            if ~obj.OnlyHasPoints
                T = [];
                return
            end

            % Points and the variable names
            P        = obj.GetPoints;
            varnames = {'X', 'Y'};

            % Consider z dimension
            if obj.isvolume
                varnames = [varnames {'Z'}];
            end

            % Consider t dimension
            if obj.istimeseries
                varnames = [varnames {'T'}];
            end

            T = array2table(P, 'VariableNames', varnames);
        end
    end



%% Public methods
    methods (Access = public)
        function loaded = LoadResults(obj, fid, pdlg)
            % LOADRESULTS will allow the user to load up previous
            % segmentation results and then navigate them in the GUI. This
            % is a capability available to .mat, .json, and .xml.
            % 
            % 
            % Loaded flag set to false by default
            loaded = false;

            if nargin < 3 || isempty(pdlg)
                obj.Progdlg = pdlg;
            end
            
            if nargin < 2 || isempty(fid)
                % Asking user to select a file to load in.
                ftypes         = {'*.mat; *.json; *.xml', 'Segmentation Files (*.mat, *.json, *.xml)'};
                [fname, fpath] = uigetfile(ftypes, 'Load segmentation result', []);

                % Window closing cancels results loading
                if fname == 0
                    return
                end

                % File ID
                fid = fullfile(fpath, fname);
            end

            % Converting files to structs
            loadedData = obj.ImportResults2Struct(fid);

            % Progress update
            msg = 'Extracting segmentation information and data.';
            if ~isempty(pdlg)
                pdlg.Title   = 'Importing Data';
                pdlg.Message = msg;

            else
                disp(msg)

            end

            % Will access the struct and load in results
            obj.ParseImportedData(loadedData)

            % Setting loaded flag to true after success
            loaded = true;

            % Progress update
            msg = 'Import successful';
            if ~isempty(pdlg)
                pdlg.Title   = 'Success';
                pdlg.Message = msg;
            else
                disp(msg)
            end
        end


        function ParseImportedData(obj, loadedData)
            % PARSEIMPORTEDDATA will parse out results into this class and
            % then try to pass results into a GUI class. 

            % In case of sparse annotations - grab D3 and D4 indices
            S          = [loadedData.Slice]';
            T          = [loadedData.Timepoint]';
            Data       = {loadedData.Results};
            numresults = numel(loadedData);
            % Ensures data is set to correct indices
            for i = 1:numresults
                s                 = S(i);
                t                 = T(i);
                obj.UpdateData(Data{i}, s, t)
            end

            % Will try to load results and settings back into GUI
            obj.PassImportedSettings2GUI(loadedData)
        end


        % PassImportedSettings2GUI function might change to better
        % encapsulate the classes. Also, not fond of the Segdata struct
        % name, especially considering this should probably generalize a
        % little better... data info struct ... 
        % --> DataInfo? ResultsInfo? ComputeInfo? ProcessingInfo?
        function PassImportedSettings2GUI(obj, loadedData) 
            % If linked to a GUI, settings are passed back to GUI class
            % Might alter to instead return a struct of some sort that the
            % GUI can then manipulate, i.e. the loop below is flexible
            if ~isempty(obj.Parent)
                % Checks for app running and Segdata (might change)
                app          = obj.Parent.RunningAppInstance;
                validFields  = fieldnames(app.Segsettings);

                % In case of sparse annotations - grab D3 and D4 indices
                S          = [loadedData.Slice];
                T          = [loadedData.Timepoint];
                numresults = numel(loadedData);

                % Checks fields that match with GUI's struct
                dataFields  = fieldnames(loadedData);
                idx         = cellfun(@(x) any(strcmp(x, validFields)), dataFields, 'UniformOutput', false);
                fields2drop = dataFields(~[idx{:}]);
                loadedData  = rmfield(loadedData, fields2drop);

                % In case of sparsely indexed results
                loadedData = obj.AppendEmptyFields(app.Segsettings, loadedData);
                for i = 1:numresults
                    s = S(i);
                    t = T(i);
                    app.Segsettings(s, t) = loadedData(i);
                end
                obj.Allinfo = app.Segsettings;

            end
        end


        

        
        function InitData(obj, z, t)
            % INITDATA will initialize a cell array have z number of rows
            % and t number of columns. These dimensions represent 

            if nargin < 2 || isempty(z)
                z = 1;
            end

            if nargin < 3 || isempty(t)
                t = 1;
            end

            % Initializes the data property as empty cell array
            obj.Results = cell(z, t);
        end


        function IndexedData = GetPlaneData(obj, slice_idx, time_idx)
            % GETSLICEDATA will retrieve the mask and points for a given
            % slice.
            IndexedData = obj.Results{slice_idx, time_idx};
        end


        function ResetData(obj)
            % RESETDATA can be called when dealing with results for a new
            % image. Slice and time indices have to be reset to empty as
            % these properties represent the indices of image that have
            % been segmented.
            obj.Results    = [];
            obj.Allinfo    = [];
            obj.slices     = [];
            obj.timepoints = [];
        end


        function SetExportSettings(obj, Exportsettings, Propertylist)
            % SETEXPORTSETTINGS sets the filepaths from an exportsettings
            % struct for both the segmentation info and masks. Segmentation
            % info includes settings used to perform segmentations or
            % detections, any computed region properties from masks or ROI
            % curves, and the ROI curve points or pointclouds from
            % detections. 

            % Parses filepaths from settings struct
            if nargin >= 2 && ~isempty(Exportsettings)
                obj.SetFilePaths(Exportsettings)
            end
            
            % Sets the stats/properties to be computed 
            if nargin == 3 && ~isempty(Propertylist)
                obj.SetRequestedStats(Propertylist)
            end
        end


        function SetFilePaths(obj, Exportsettings)
            % SETFILEPATH will parse the desired export location for the
            % segmentation information (settings and any stats) and for the
            % mask data.
            
            % Results and Settings export location
            obj.outputpath   = Exportsettings.InfoPath;
            obj.outputname   = Exportsettings.InfoName;
            obj.outputext    = Exportsettings.InfoExt;

            % Mask(s) export location - if masks are requested
            obj.maskfilepath = Exportsettings.MaskPath;
            obj.maskfilename = Exportsettings.MaskName;
            obj.maskfileext  = Exportsettings.MaskExt;
        end


        function SetRequestedStats(obj, Propertylist)
            % SETREQUESTEDSTATS will set the stats that have been requested
            % based on a tree with checkbox nodes (ui component) or a cell
            % array with character arrays in each cell.

            % Checkbox tree from GUI or cell array list as input
            if isa(Propertylist, 'matlab.ui.container.CheckBoxTree')
                if ~isempty(Propertylist.CheckedNodes)
                    % Ignores the top most node 'MaskProperties' from GUI
                    obj.Requestedprops = {Propertylist.CheckedNodes.Text};
                    idx                = strcmp(obj.Requestedprops, 'Mask Properties');
                    obj.Requestedprops = obj.Requestedprops(~idx);
                    obj.Requestedprops = cellfun(@(x) AddRmStrSpace(x, false), obj.Requestedprops, 'UniformOutput', false);
                else
                    obj.Requestedprops = [];
                end

            elseif iscell(Propertylist)
                obj.Requestedprops = Propertylist;
                obj.Requestedprops = cellfun(@(x) AddRmStrSpace(x, false), obj.Requestedprops, 'UniformOutput', false);

            end

            % Case for aspect ratio w/o bounding box request
            obj.bboxreq        = any(strcmp(obj.Requestedprops, 'BoundingBox'));
            obj.aspectratioreq = any(strcmp(obj.Requestedprops, 'AspectRatio'));
        end


        

        function ExportData(obj, fig, Segdata)
            % EXPORTDATA will package the segmentation/detection results 
            % alongside the settings used in the GUI and export this in one
            % file according to the selected format. If the user has
            % enabled the mask export, those will also be saved according
            % to the preferred format, either as a tiff stack or multiple
            % png files representing 2D planes. In either case, they will
            % be saved within a folder that will be in the same directory
            % as the target location for the other data.

            % Will not export if there are no results
            if isempty(obj.Results)
                warning('No results to export.')
                return
            end

            % Init the progress bar
            obj.Progdlg = uiprogressdlg(fig, 'Title', 'Export', 'Message', 'Preparing for export...', 'Value', 0);

            % Mask stack export
            try
                % Check if file exists before overwriting
                if ~obj.saveallowed && ~isempty(obj.Progdlg)
                    % User decides not to overwrite, save not allowed.
                    obj.Progdlg.Message = 'Export stopped. Please change export filename.';
                    pause(1)
                    obj.Progdlg.delete
                    return
                end

                % Mask export into image files
                if obj.outputmasks
                    obj.ExportResultsAsImageMasks
                    % Terminal Update
                    disp('Segmented mask(s) saved')
                end

                % Terminal Update
                disp('Gathering results...')
    
                % Update progress bar value
                if ~isempty(obj.Progdlg)
                    obj.Progdlg.Value = 0.5;
                end

                % Progress bar dialog box
                if ~isempty(obj.Requestedprops) && ~isempty(obj.Progdlg)
                    obj.dmsg    = ['Computing properties' ...
                                   newline ...
                                   'Please wait...'];
                    obj.Progdlg.Message = obj.dmsg;
                end

                % Mask property computation
                obj.ConsolidateResults(Segdata)

                % Results and the settings used to get them
                obj.ExportResultsWithSettings
                
            catch ME
                if ~isempty(obj.Progdlg)
                    close(obj.Progdlg)
                end
                warning('Save was unsuccesful...')
                rethrow(ME)
            end

            if ~isempty(obj.Progdlg)
                close(obj.Progdlg)
            end
        end


        function ExportResultsAsImageMasks(obj)
            % MASKSTACKEXPORT is used to export masks that correpond to the
            % results produced from segmentation. If the user had an
            % unordered point cloud as their results, the masks will simply
            % be a blank image with the nearest pixels to points turned on
            % and this will lead to a loss of some subpixel accuracy.
            % Check for timepoints

            % Dialog update
            if ~isempty(obj.Progdlg)
                obj.Progdlg.Message = 'Validating results as masks';
            end

            % First, converts the results data into masks for any cases
            % where masks are not present, e.g. point detections or
            % contours
            R = obj.Results;
            for j = 1:size(obj.Results, 2)
                for i = 1:size(obj.Results, 1)
                    r_ij = R{i,j};
                    if ~strcmp(obj.CheckResultType(r_ij), 'mask')
                        R{i,j}  = obj.Points2Mask(r_ij);
                    end
                end
            end

            % Dialog update
            if ~isempty(obj.Progdlg)
                obj.Progdlg.Message = 'Saving masks as image files...';
            end
            
            switch obj.maskfileext
                case '.tif'
                    % Saves a tiff volume per timepoint
                    obj.ExportStackAsTiff(R)

                case '.png'
                    % Saves png files with each being a 2D plane
                    obj.ExportStackAsPNGs(R)

                case '.mat'
                    % Saves all data in a numerical array

            end
        end


        function ExportStackAsTiff(obj, R)
            % EXPORTSTACKASTIFF will export the stack of masks as a tiff
            % volume. If there are multiple timepoints, those will be saved
            % as separate tiff stacks with a frame identifying
            if obj.istimeseries
                for i = 1:obj.numframes
                    fid = [obj.maskfilepath filesep obj.maskfilename '_T' num2str(i) obj.maskfileext];
                    obj.WriteLogicalTiff(R{:,i}, fid)
                end
            else
                fid = [obj.maskfilepath filesep obj.maskfilename obj.maskfileext];
                obj.WriteLogicalTiff(R, fid)
            end
        end


        function ExportStackAsPNGs(obj, R)
            % EXPORTSTACKASPNGS will export individual 2D slices from the
            % dataset into .png files with the name specifying where in the
            % volume and/or timeseries they came from

            % Name adjusted to consider time
            if obj.istimeseries
                for i = 1:obj.numframes
                    fid = [obj.maskfilepath filesep obj.maskfilename '_T' num2str(i) obj.maskfileext];
                    obj.WriteImageSlices(R{:,i}, fid)
                end
            else
                fid = [obj.maskfilepath filesep obj.maskfilename obj.maskfileext];
                obj.WriteImageSlices(R, fid)
            end
        end


        function ExportStackAsMData(obj, R)
            % EXPORTSTACKASMDATA will write the masks to an mdata file
            % with variable name "Masks".
            fid   = obj.maskfid;
            Masks = R;
            save(fid, Masks, '-v7.3', '-nocompression')
        end


        function Mask = Points2Mask(obj, R)
            % POINTS2MASK will convert a contour curve around an ROI into a
            % mask and an unordered point cloud into a binary image with
            % the points' nearest pixels turned on.

            % Result type determines the algorithm
            rtype = obj.CheckResultType(R);

            % Creating a size vector
            sz = [obj.mrows obj.ncols];

            if strcmp(rtype, 'contour')
                % Boundary curve 
                Mask = obj.Contour2Mask(R, sz);

            elseif strcmp(rtype, 'pointcloud')
                % Unordered pointcloud
                Mask = obj.Pointcloud2Mask(R, sz);

            elseif isempty(rtype)
                % Creates an empty 2D image
                Mask = false(sz);

            end
        end


        function ConsolidateResults(obj, Segdata)
            % CONSOLIDATERESULTS computes region properties for masks in a 
            % mask stack from the segmentation GUI and then proceeds to 
            % extract parameter values, parametric method used, and other 
            % settings used to produce the AllInfo struct as a proprty of
            % the class. This has all information consolidated into one
            % variable/property.

            % Clearing previous region props prior to appending new info
            obj.Allinfo = [];
            
            % Drops aspect ratio since region props cannot compute it
            if ~isempty(obj.Requestedprops) && any(contains(obj.Requestedprops, 'AspectRatio'))
                idx                = strcmp(obj.Requestedprops, 'AspectRatio');
                obj.Requestedprops = obj.Requestedprops(~idx);
            end

            % Number of timepoints and slices that were segmented. These
            % two lists can be sparse and noncontinuous.
            N = numel(obj.timepoints);
            M = numel(obj.slices);
            for idxdim4 = 1:N
                % Initialize struct to hold stats of a given timepoint
                StackSegInfo   = [];

                % Index of segmented frame (timepoint)
                t              = obj.timepoints(idxdim4);

                for jdxdim3 = 1:M
                    % Grabs index of segmented z slice 
                    z           = obj.slices(jdxdim3);
                    Resultsdata = obj.Results{z, t};

                    % Aspect ratio calculation requires bounding box
                    if obj.aspectratioreq && ~obj.bboxreq
                        obj.Requestedprops{end+1} = 'BoundingBox';
                    end

                    % Will determine region props if possible
                    Regionprops = obj.DetermineRegionProps(Resultsdata);
    
                    % Settings used for segmentation extracted one 2D image
                    % at a time
                    Temp = Segdata(z, t);

                    % Adds z and t index information to prevent ambiguity
                    Temp.Slice       = z;  % slice index
                    Temp.Timepoint   = t;  % time index

                    % Regionprops column entry for temporary struct
                    if ~isempty(Regionprops)
                        Temp.RegionProps = Regionprops;
                    else
                        Temp.RegionProps = 'NA';
                    end

                    % Concatenate results to segmentation settings info so
                    % that all information regarding a given z,t index is
                    % in one place
                    Temp.Results = Resultsdata;
                    StackSegInfo = vertcat(StackSegInfo, Temp);

                    % Progress update for user
                    Progress            = ((idxdim4/N)*(jdxdim3/M))*0.5;
                    obj.Progdlg.Value   = 0.5 + Progress;
                    obj.Progdlg.Message = [obj.dmsg newline ...
                                        'Slice ' num2str(jdxdim3) '/' num2str(M) newline ...
                                        'Timepoint: ' num2str(idxdim4) '/' num2str(N)];
                end
                
                % Nests the structs to take time into consideration
                if ~isfield(obj.Allinfo, 'SegmentationInfo')
                    obj.Allinfo(1).SegmentationInfo     = StackSegInfo;
                else
                    obj.Allinfo(end+1).SegmentationInfo = StackSegInfo;
                end
            end

            % Finalizes the struct with all
            obj.SetDateTime
            obj.Allinfo(1).Date = obj.Date;
            obj.Allinfo(1).Time = obj.Time;
        end


        function ExportResultsWithSettings(obj)
            % EXPORTRESULTSWITHSETTINGS exports the results and settings
            % from the GUI in a single file.
            if isempty(obj.Allinfo) 
                % Terminal Update
                disp('No results to save')
                if ~isempty(obj.Progdlg)
                    close(obj.Progdlg)
                end
                return
            end

            % UI Progress update
            if ~isempty(obj.Progdlg)
                obj.Progdlg.Message = 'Writing output file...';
            end

            % Savings results and settings
            switch obj.outputext
                case '.mat'
                    obj.WriteMAT(obj.outputfid)

                case '.json'
                    obj.WriteJSON(obj.outputfid)

                case '.xml'
                    obj.WriteXML(obj.outputfid)

                case '.csv'
                    obj.WriteCSV(obj.outputfid)

                case '.xlsx'
                    obj.WriteXLSX(obj.outputfid)
            end
        end


        function Regionprops = DetermineRegionProps(obj, Resultsdata)
            % DETERMINEREGIONSPROPS will get region props if the data is a
            % mask, otherwise, it will leave the data alone.

            if isempty(obj.Requestedprops)
                Regionprops = [];
                return
            end

            % Point clouds cannot produce region props but a contour can
            % get converted into a masked ROI
            rtype = obj.CheckResultType(Resultsdata);
            if strcmp(rtype, 'pointcloud')
                Regionprops = [];
                return

            elseif strcmp(rtype, 'contour')
                sz          = [obj.mrows obj.ncols];
                Resultsdata = obj.Contour2Mask(Resultsdata, sz);

            end

            % Computes the requested region properties
            Regionprops = regionprops(Resultsdata, obj.Requestedprops);

            % Computes aspect ratio if requested
            if obj.aspectratioreq
                Regionprops = obj.AppendAspectRatio(Regionprops);
            end
        end


        function Regionprops = AppendAspectRatio(obj, Regionprops)
            % RPASPECTRATIO will modify region props to include the aspect
            % ratio calculation. It will remove the bounding box field if
            % the bounding box was not requested as well.

            % Empty Regionprops suggests an empty mask image (no CC)
            if ~isempty(Regionprops) && isfield(Regionprops, 'BoundingBox')
                % Loop over connnected components (CC) for AR computation
                for c = 1:numel(Regionprops)
                    % x:y aspect ratio computed from [L B W H] from BB
                    BB                         = Regionprops(c).BoundingBox;
                    Regionprops(c).AspectRatio = BB(3)/BB(4);
                end

            else
                % Enables a blank entry
                clear Regionprops
                Regionprops.BoundingBox = [];
                Regionprops.AspectRatio = [];
                
            end

            % Bounding box removed if user did not request it despite 
            % requesting the aspect ratio
            if ~obj.bboxreq
                Regionprops = rmfield(Regionprops, 'BoundingBox');
            end
        end


        function UpdateData(obj, Data, z, t)
            % UPDATEDATA will update the data struct that holds masks and
            % contour points as well as settings used to produce the
            % results
            z                 = max(z, 1);
            t                 = max(t, 1);
            obj.Results{z, t} = Data;

            % Updating arrays containing indices of segmented images
            obj.slices     = [obj.slices z];
            obj.timepoints = [obj.timepoints t];
            obj.slices     = unique(obj.slices);
            obj.timepoints = unique(obj.timepoints);
        end
    end



    methods (Access = private)
    %% Export Related
        function SetDateTime(obj)
            % Time and data info for the file being written
            obj.Date = char(datetime('now', 'Format', 'MM-dd-yyyy'));
            obj.Time = char(datetime('now', 'Format', 'hh:mm:ss'));
        end


        function WriteLogicalTiff(obj, I, fid)
            % WRITELOGICALTIFF will write the logical image stack from the
            % cell array of images, I by leveraging the fast tiff writer
            % class.

            % Opening the tiff object to be written
            % obj.TiffWriter.Open(fid)

            % Regular tiff object
            tiffObj = Tiff(fid,'w');

            Im = I{1, 1};

            % Bit Depth (Bits per sample)
            if isa(Im, 'uint8')
                BPS = 8;
            elseif isa(Im, 'uint16')
                BPS = 16;
            elseif isa(Im, 'logical')
                BPS = 1;
            end

            % Generate tag structure
            tags.BitsPerSample       = BPS;
            tags.Compression         = Tiff.Compression.None;
            tags.ImageLength         = size(Im, 1);
            tags.ImageWidth          = size(Im, 2);
            tags.Photometric         = Tiff.Photometric.MinIsBlack;
            tags.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
            tags.SampleFormat        = Tiff.SampleFormat.UInt;
            tags.SamplesPerPixel     = 1;
            % tags.SubFileType         = Tiff.SubFileType.Mask; % Requires Photometric = Photometric.Mask.

            % Only grabs non empty slices
            check = ~cellfun(@isempty, I);
            J     = I(check);
            for j = 1:numel(J)
                tiffObj.setTag(tags);
                write(tiffObj, J{j});
                writeDirectory(tiffObj);
            end
            
            tiffObj.close();
        end


        function WriteMAT(obj, fid)
            % WRITEMAT will write the segmentation settings and results as
            % a struct in addition to a table for the points
            
            % Segmentation settings
            SegmentationResults = obj.Allinfo;

            % Points
            PointDetections = obj.PointsAsTable;

            if exist(fid, 'file') == 2
                save(fid, 'SegmentationResults', 'PointDetections',  '-mat', '-nocompression', '-append')
            else
                save(fid, 'SegmentationResults', 'PointDetections',  '-mat', '-v7.3', '-nocompression')
            end
        end


        function WriteJSON(obj, fid)
            % WRITEJSON will encode the results struct into a JSON format
            % in pretty print and then replace single backslashes with
            % double backslashed to ensure proper encoding upon writing
            S      = obj.Allinfo;
            J      = jsonencode(S, "PrettyPrint", true);
            J      = replace(J, '\', '\\');
            fileID = fopen(fid, 'w');
            fprintf(fileID, J);
            fclose(fileID);
        end


        function WriteXML(obj, fid)
            % WRITEXML will adjust the struct format for proper xml export
            % and then write the file

            % Segmentation results and settings
            S         = obj.Allinfo;
            % Reorganize results for XML export
            P       = {S.SegmentationInfo.Results};
            nslices = size(P, 2);

            for i = 1:nslices
                % Reorganization depends on result type
                ismask = strcmp(obj.CheckResultType(P{i}), 'mask');
                if ismask
                    % Masks will instead have pixel indices written
                    S.SegmentationInfo(i).MaskedPixels = find(P{i});
                    S.SegmentationInfo(i).ImageWidth   = obj.ncols;
                    S.SegmentationInfo(i).ImageHeight  = obj.mrows;
                else
                    % Pointclouds and contours have coordinates saved
                    try
                        X = P{i}(:,1);
                        Y = P{i}(:,2);
                    catch
                        X = [];
                        Y = [];
                    end
                    S.SegmentationInfo(i).X = X;
                    S.SegmentationInfo(i).Y = Y;
                end
            end
            S.SegmentationInfo = rmfield(S.SegmentationInfo, 'Results');
            writestruct(S, fid)
        end


        function WriteCSV(obj, fid)
            % WRITECSV will convert the results struct into a datatable
            % and save with a .csv format. This format is ideally suited
            % for either type of points: contours or pointclouds.
            % A check is done to make sure the user does not try to write
            % masks in .csv format.
            % The user might instead want to enable the mask writing
            % property.
            if obj.rtypemismatch || obj.masksinresults
                msg = ['The .csv file format is best suited for either' ...
                       ' a point cloud representing detections or a' ...
                       ' closed curve representing an ROI boundary.' ...
                       newline ...
                       'No file has been written.'...
                       'Different result types can only be saved in' ...
                       ' .mat, .json, or .xml'];
                warning(msg)
                return
            end

            % Writes the settings
            Seginfo      = rmfield(obj.Allinfo.SegmentationInfo, {'Results', 'RegionProps'});
            T            = struct2table(Seginfo);
            writetable(T, fid, 'FileType','text')

            % Getting points out as table to write to .csv file
            T = obj.PointsAsTable;
            if isempty(T)
                warning(['No point detections written. Ensure points' ...
                    ' were detected and that all computed results were' ...
                    ' of the same type (points or contour curves).'])

            else
                % Writing the results in separate .csv file
                [fp, fn, fe] = fileparts(fid);
                fid2         = [fp filesep fn 'Results' fe];
                writetable(T, fid2, 'FileType','text')

            end
        end


        function WriteXLSX(obj, fid)
            % WRITEXLSX will write to spreadsheet by writing the settings
            % used in the first worksheet, the actual segmentation results
            % in the second worksheet, and the region properties or
            % statistics in N remaining worksheets where N is the number of
            % 2D planes that were segmented.

            % Number of 2D planes segmented and the indices
            n_planes   = numel(obj.Allinfo.SegmentationInfo);
            zslices    = [obj.Allinfo.SegmentationInfo.Slice];
            tframes    = [obj.Allinfo.SegmentationInfo.Timepoint];

            % If results are all masks or contours, there are likely some
            % region properties. If the results are all point clouds or
            % contours, they can get parsed into x and y coordinates in a
            % table. If the results are all masks, no point info is
            % available. If user tries to mix and match formats, they will
            % be advised to use a different format

            if obj.rtypemismatch
                msg = ['The .xlsx file format is best suited for either' ...
                       ' a point cloud representing detections or a' ...
                       ' closed curve representing an ROI boundary.' ...
                       newline ...
                       'No file has been written. '...
                       'Different result types can only be saved in' ...
                       ' .mat, .json, or .xml'];
                warning(msg)
                return

            end
            
            % Settings Worksheet: Writing the settings
            Settings = rmfield(obj.Allinfo.SegmentationInfo, {'RegionProps', 'Results'});
            T        = struct2table(Settings);
            writetable(T, fid, 'FileType','spreadsheet', 'Sheet', 'Settings')

            % Results Worksheet: Writing the points as a table
            T = obj.PointsAsTable;
            if isempty(T)
                warning(['No point detections written. Ensure points' ...
                    ' were detected and that all computed results were' ...
                    ' of the same type (points or contour curves).'])

            else
                writetable(T, fid, 'FileType','spreadsheet', 'Sheet', 'Results')

            end

            % If no properties are requested, return
            if isempty(obj.Requestedprops)
                return
            end

            % Region Props Worksheet(s):
            % Region Props is a nested struct - parsed into sheets
            for i = 1:n_planes
                try
                z         = zslices(i);
                t         = tframes(i);
                sheetname = ['Z' num2str(z) '_T' num2str(t) 'RegionProperties'];
                RP        = obj.Allinfo.SegmentationInfo(i).RegionProps;
                T         = struct2table(RP);
                writetable(T, fid, 'FileType','spreadsheet', 'Sheet', sheetname)
                catch
                end

            end
        end


    %% Import Related
        function S = ImportResults2Struct(obj, fid)
            % IMPORTRESULTS2STRUCT will read in a file format and convert
            % to a struct for the class to parse through. This is expected
            % to work with .mat, .json, and .xml
            
            % Getting file extension to know how to read the data in
            [~, ~, ext] = fileparts(fid);

            % Parse out settings and results based on format
            switch ext
                case '.mat'
                    % Imports both settings and results from MData
                    S = obj.ImportFromMAT(fid);

                case '.json'
                    % Imports both settings and results from JSON file
                    S = obj.ImportFromJSON(fid);

                case '.xml'
                    % Imports both settings and results from an xml file
                    S = obj.ImportFromXML(fid);

            end
        end
    end



    methods (Static)
    %% Import Functions
        function S = ImportFromMAT(fid)
            % IMPORTFROMMAT will read in the struct from a matlab data file
            mf = matfile(fid);
            S  = mf.SegmentationResults;
            S  = S.SegmentationInfo;
        end


        function S = ImportFromJSON(fid)
            % IMPORTFROMJSON will read in JSON data and reformat to a
            % standard format for the settings/results struct
            fext = fileread(fid);
            S    = jsondecode(fext);
            S    = S.SegmentationInfo;
        end


        function S = ImportFromXML(fid)
            % IMPORTFROMXML will read in an XML file and reformat to a
            % standard format for the settings/results struct
            S = readstruct(fid);
            S = S.SegmentationInfo;

            % Will go across fieldnames to evaluate any that should be
            % logicals
            fnames   = fieldnames(S);
            logicals = {'true', 'false'};
            checkFun = @(x) (isstring(x) || ischar(x)) && contains(x, logicals);
            for i = 1:numel(fnames)
                fname  = fnames{i};
                SField = {S(:).(fname)};

                % Overwrite char/str entries on fields with logicals
                isL    = cellfun(checkFun, SField);
                if all(isL)
                    F               = {S(:).(fname)};
                    F               = cellfun(@feval, F);
                    % All falses need false
                    [S(~F).(fname)]  = deal(false);
                    % All trues need true
                    [S(F).(fname)] = deal(true);
                end
            end

            % Parsing the results
            for i = 1:size(S, 2)
                if any(size(S(i).X) > 1) && any(size(S(i).Y) > 1)
                    % Reorganizing points into results field
                    X = {S(i).X};
                    Y = {S(i).Y};
                    P = cellfun(@(x1, x2) [x1' x2'], X, Y, 'UniformOutput', false);
                    S(i).Results = deal(P{:});
                    
                elseif ismissing(S(i).X) || ismissing(S(i).Y)
                    % Masks need to be reconstructed from indices
                    idx          = S(i).MaskedPixels;
                    m            = S(i).ImageHeight;
                    n            = S(i).ImageWidth;
                    Mask         = false(m , n);
                    Mask(idx)    = true;
                    S(i).Results = Mask;
                end
            end

            % Will eliminate any remaining excess information
            excess = {'X', 'Y', 'ImageWidth', 'ImageHeight', 'MaskedPixels'};
            idx    = cellfun(@(x1) any(strcmp(x1, fnames)), excess, 'UniformOutput', false);
            excess = excess([idx{:}]);
            S      = rmfield(S, excess);
        end


        function S2 = AppendEmptyFields(S1, S2)
            % Fieldnames of the app struct
            fn1 = fieldnames(S1);

            % Fieldnames of the loaded data struct
            fn2 = fieldnames(S2);

            % Finding missing fieldnames
            idx = cellfun(@(x) any(strcmp(x, fn2)), fn1, 'UniformOutput', false);
            idx = [idx{:}];
            fn  = fn1(~idx);

            % Appending empty fields to the struct of interest
            for i = 1:numel(fn)
                fname = fn{i};
                [S2(:).(fname)] = deal([]);
            end
        end


        %% Misc Static Funcs
        function rtype = CheckResultType(R)
            % CHECKRESULTTYPE will look at a cell from a cell array and
            % determine if the data is a contour (closed curve), an
            % unordered point cloud, or a mask.

            % Returns empty when given cell has no data
            if isempty(R)
                rtype = [];
                return
            end

            % Point clouds only have 2 columns prior to parsing
            numcols      = size(R, 2);
            ispointcloud = numcols == 2;
            isclosed     = all(R(1,:) == R(end, :));
            isonepoint   = size(R, 1) == 1;

            % A mask image will be larger than 2 pixels across
            ismask       = numcols > 2;

            % Result type 
            if ispointcloud && isclosed && ~isonepoint
                rtype = 'contour';

            elseif ispointcloud && (~isclosed || isonepoint)
                rtype = 'pointcloud';

            elseif ismask
                rtype = 'mask';

            end
        end


        function WriteImageSlices(C, fid)
            % WRITEIMAGESLICES will save the 2D images from the cell array,
            % C.

            % Will save the masks as separate image files in the
            % selected folder
            [path, name, ext] = fileparts(fid);
            issegmented       = ~cellfun(@isempty, C);
            J                 = C(issegmented);
            for i = 1:numel(J)
                Im  = J{i};
                fid = [path filesep name '_Z' num2str(i) ext];
                imwrite(Im, fid)
            end
        end

        % function WriteImageStack
        % end

    %% Algorithms
        function R = Pointcloud2Mask(R, sz)
            % POINTCLOUD2MASK 
            R      = round(R);
            R      = max(R, 1);
            x      = min(R(:,1), sz(2));  % x coordinate
            y      = min(R(:,2), sz(1));  % y coordinate
            idx    = sub2ind(sz, y, x);
            R      = false(sz);
            R(idx) = 1;
        end


        function R = Contour2Mask(R, sz)
            % CONTOUR2MASK will convert 
            x = R(:,1);
            y = R(:,2);
            R = poly2mask(x, y, sz(1), sz(2));
        end
    end
end