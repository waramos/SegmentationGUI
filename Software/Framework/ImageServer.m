classdef ImageServer < handle
% IMAGESERVER is a class capable of loading in multidimensional image
% data from various sources. Data can be 2D images, 3D .tif stacks, and
% video data of .avi and .mp4 formats. Aside from files or folders, 
% sources of data can also be webcams or image acquisition devices like
% sCMOS cameras connected to the computer via a capture card. Devices will
% appear as long as the user has necessary drivers installed and the
% device firmware is compatible with MATLAB's image acquisition toolbox.
% The general flow in using this class is to first set the source of your
% data, then call the read method to update the 2D image currently being
% viewed. If the user would like to set a crop to have less data loaded up,
% this can be implemented after the source is set.
% 
% NOTE: For a future version - If the user has bioformats, server will
% leverage the bioformats package to load in commercial microscope image 
% formats.
%
% William A. Ramos, Kumar Lab @MBL February 2024
% email: wramos@mbl.edu

    properties (Access = private)
        % Image related
        Source                     % Source determines how additional images are passed into the image server. Can be a numerical array from workspace, image datastore, a file, 
        variable                   % When source is a matfile object, this has the variable name that holds the data
        fidx                       % When source is an imagedata store or live folder, this refers to the file index
        BFReader                   % Need to initialize the Bio Formats reader object to configure acceptable file formats

        % Options
        lazyloading    = true      % Loads portions of data on the fly for memory efficiency at cost of speed. Accounts for systems with less RAM
    end



    properties (GetAccess = public, SetAccess = private)
        % Parent GUI
        GUI

        % Image
        Stack                      % Holds full ND image array if lazyloading is off or user has directly passed the array into the class
        Slice                      % The current slice being viewed
        newstackreq                % New stack requested - true when user has changed index 4 or 5 which requires loading a new stack

        % Image metadata - persistent and dependent on source
        filefolder                 % Path to file
        filename                   % Image file name (if loaded from filepath / imds) OR variable name (if loaded via matfile object)
        fileext                    % Extension of file

        % Dimension sizes metadata - persistent and dependent on source
        mrows                      % Number of rows in image (y dim)
        ncols                      % Number of columns in image (x dim)
        numslices                  % Number of z slices in image stack
        numframes                  % Number of timepoints
        numfiles                   % Number of files in the datastore/folder. Updates if user is imaging as new files are written (live folder source type)
        channels                   % Number of channels - bioformats / workspace array compatible

        % 2D Slice Indexing
        slice                      % Z index - D3 - slice currently loaded
        framenum                   % T index - D4 - timepoint currently loaded
        channel                    % C index - D5 - channel currently loaded - only compatible with bioformats and numerical arrays
        dim4idx                    % T/F index - D4 - Represents data's 4th dimension. Can either be time or file index, depending on source type

        % Crop ROI
        croprows                   % crop ROI coordinates (D1 - rows) - row vector of image's row indices used for crop
        cropcols                   % crop ROI coordinates (D2 - cols) - row vector of image's col indices used for crop

        % Acceptable formats - can eventually include the BIOFORMATS /
        % commercial formats as well
        filefilt = {'*.mat; *.png; *.jfif; *.jpg; *.jpeg; *.tif; *.tiff; *.avi; *.mp4; *.mpg; *.mpeg',...
                    'All Array Data Formats (*.mat, *.png, *.jfif, *.jpg, *.jpeg, *.tif, *.tiff, *.avi, *.mp4, *.mpg, *.mpeg)';...
                    
                    '*.png; *.jfif; *.jpg; *.jpeg; *.tif; *.tiff',...
                    '2D Images (*.png, *.jfif, *.jpg, *.jpeg, *.tif, *.tiff)';...
                
                    '*.mat',...
                    'MATLAB Data (*.mat)';...

                    '*.tif; *.tiff',...
                    '3D Image Stack (*.tif, *.tiff)';...

                    '*.avi; *.mp4; *.mpg; *.mpeg',...
                    'Videos (*.avi, *.mp4, *.mpg, *.mpeg)'};

        % Video reader formats
        vidformats

        % BioFormats file extensions property - used if user has BF
        bffileexts 

        % BioFormats integration - if user has bfmatlab, the following
        % formats are also compatible with this class:
        % https://bio-formats.readthedocs.io/en/v7.2.0/formats/dataset-table.html
    end



    properties (Dependent)
        fullFID                    % returns the full file ID (filepath)
        mrowscrop                  % queries y dimension size based on the crop coordinates
        ncolscrop                  % queries x dimension size based on the crop coordinates
        sizes                      % queries data source dimensionality/size. Dimension sizes will depend on the source type - will return a vector when queried
        dataloaded                 % queries whether data is loaded in the server - returns a logical flag (true if data loaded)
        isstacknavigable           % queries whether user can navigate dimension 3 of data by checking dimensionality of data source - returns a logical flag (true if navigable)
        istimenavigable            % queries whether user can navigate dimension 4 of data by checking dimensionality of data source - returns a logical flag (true if navigable)
        Classmethods               % queries the class methods the user can use - returns cell array of list of publicly available class methods
        Classproperties            % queries the properties the user can use - returns cell array of list of publicly available class properties
        Datasources                % queries available options for data sources
        dim4                       % queries either time or file index depending on which is larger and data source type. Useful for bounds checking
    end



    methods(Access = public)
        %% Initialization and Settings
        function obj = ImageServer(fid)
            % IMAGESERVER Constructor. Can take input to instatiate with
            % data immediately loaded up.
            %
            % INPUTS: 
            % fid (optional) - filepath, folder path, or numerical array.
            
            % Loads data according to input type
            if nargin == 1
                obj.LoadImage(fid)
            end

            % Video reader compatible formats
            vf             = VideoReader.getFileFormats;
            obj.vidformats = {vf.Extension};

            % Check to see that user has bioformats
            if obj.UserHasBF
                % Appending the BF formats
                obj.BFReader   = bfGetReader;
                bfformats      = bfGetFileExtensions;
                obj.filefilt   = vertcat(bfformats(1,:), obj.filefilt, bfformats(2:end,:));
                obj.bffileexts = GetAllBFExtensions;
            end
        end

        function SetGUIHandle(obj, f)
            % SETGUIHANDLE allows user to set a GUI uifigure handle to
            % enable certain prompt functionality. Otherwise, terminal line
            % interactivity is used by default.
            if isa(f, 'matlab.ui.Figure')
                obj.GUI = f;
            else
                msg = 'Input was not a uifigure.';
                msg = [msg newline 'No GUI figure handle was passed' ...
                       'into the class.'];
                warning(msg)
            end
        end


        function LoadImage(obj, s)
            % obj.LOADIMAGE(s)
            % 
            % SUMMARY:
            % LOADIMAGE will load a new image into the class. The input can
            % be a filepath for a 2D image or 3D stack, a path to a folder
            % that will then become an imagedatastore, or an array which is
            % then passed to the class. If no arguments are passed, then
            % the user will be prompted to select file(s) to load in via a
            % GUI window.
            %
            % INPUTS:
            % s (optional) a folder/filepath or image array
            % Intended Datatype: string, char, uint8, uint16, single, double
            %
            % OUTPUTS:
            % None. The class will update its ImageSlice and ImageStack
            % properties to reflect the newly loaded in image.
            if nargin < 2
                s = [];
            end

            % Resetting crop properties to ensure full loading of images
            obj.ResetIndices    % Resets indices to 1 for dimensions 3-4
            
            if ischar(s) || isstring(s)
                % Creates image datastore or loads individual image
                obj.LoadFromString(s)

            elseif isnumeric(s)  && ~isempty(s)
                % Array variable passed to method
                obj.LoadFromArray(s)

            elseif isempty(s) 
                % Will load new image via ui prompt window
                obj.SetupFileSource(obj.filefolder);

            elseif iscell(s)
                obj.SetupMultiFileSource(s)

            end

            % Checks to ensure data is properly formated in terms of data
            % type and dimensionality
            obj.CheckType
            obj.CheckDims
        end


        function ResetIndices(obj)
            % RESETINDICES will set all relevant indices to 1 to ensure 
            % the next loaded image is the first image in the data source.
            % All data that is loaded in will have 1 slice and 1 timepoint
            % by default. This is used as initialization of the values
            % which will be adjusted if greater than 1 and enables indexing
            % in the branching of the read function for different data 
            % source types.
            obj.slice    = 1;
            obj.framenum = 1;
            obj.fidx     = 1;
            obj.channel  = 1;
            obj.dim4idx  = 1;
            obj.channel  = 1;
        end
        

        function Reset(obj)
            % obj.RESET
            %
            % SUMMARY:
            % RESET will reset indices, crop coordinates and reload the
            % first image if a source is still set. This will also reenable
            % lazy loading, helping to reduce memory load upon resetting.

            % Set defaults
            obj.ResetIndices

            % Resetting crop
            obj.ResetCropCoords

            % Reenable lazy loading by default
            obj.SetLazyLoading(true)

            % Resets view to be original full image if a crop was set and
            % data is available
            if obj.dataloaded
                obj.Read
            end
        end


        function SetSource(obj, choice)
            % obj.SETSOURCE(choice)
            % obj.SETSOURCE
            %
            % SETSOURCE will allow the user to set a desired data source.
            % The source can be a folder, a file or multiple files, a
            % webcam, an image acquisition device like an sCMOS, or a "live
            % data" folder which is monitored for new files. This latter
            % option works to load in the latest file saved to a folder as
            % the assumption is that the user might be actively acquiring
            % new data and saving to the same folder.
            %
            % INPUTS:
            % choice (optional: source name) the data source choice can be
            % specified. If the choice does not exist, a warning will be
            % given with available options to try.
            % Intended datatypes: 
            %
            % OUTPUTS:
            % None. This will only set the source but not actually capture
            % the data or load data until the user calls the read function.

            % Scan for available data sources - at least 3 are always
            % available in the full list: File, Folder, Live
            List     = obj.Datasources; % struct output
            fulllist = List.fullList;   % full list of all options
            imaqobjs = List.imaqobjs;   % image acquisition objects/devices only
            
            if nargin < 2 || isempty(choice)
                % Ask user to select source
                [idx, selectionmade] = listdlg('ListString', fulllist,...
                                               'SelectionMode', 'single',...
                                               'Name', 'Select Image Source',...
                                               'ListSize', [260 80]);
                if ~selectionmade
                    return
                end
                choice = fulllist{idx};
            else
                % Checks to see that user selected a valid input option
                selectionmade = strcmp(fulllist, choice);
                if ~selectionmade
                    % Adding line break to list to make list of options
                    fulllist = cellfun(@(x) ['- ' x newline], fulllist, 'UniformOutput', false);
                    % Warning message regarding invalid selection
                    wmsg = ['Input choice not valid. Source does not exist.' newline...
                            'Please choose one of the following: ' newline ...
                            fulllist{:}];
                    warning(wmsg)
                    return
                end
            end
            
            % Indices will always get reset to 1 but crop coordinates will
            % only need to be reset when the user has other data already
            % loaded in since new data will have different dimension sizes
            obj.ResetIndices
            
            switch choice
                case 'Webcam/USB Device'
                    % Webcam takes snapshots when read is called
                    % User is prompted to select the webcam from a list
                    obj.SetupWebcamSource

                case 'Folder'
                    % Use prompted to select folder of files w/ same format
                    obj.SetupMultiFileSource

                case 'File'
                    % Single file or multiple files read in sequentially
                    obj.SetupFileSource

                case {imaqobjs.name}
                    % Image acquisition device (webcam, sCMOS, etc.)
                    % Finds the choice made in the imaq list to pass proper
                    % device name and device ID to the videoinput class
                    idx        = contains({imaqobjs.name}, choice);
                    obj.Source = videoinput(imaqobjs(idx).devName, imaqobjs(idx).id);

                case 'Live'
                    % Live folder w refresh whenever read function called
                    obj.SetupLive(obj.filefolder);

            end

            % Will first initialize the crops
            % First image is loaded up upon setting up the source
            obj.Read
        end


        function SetCropCoords(obj, coords)
            % obj.SETCROPCOORDS(coords)
            %
            % SUMMARY:
            % SETCROPCOORDS will set coordinates from a 2D ROI rectangle as
            % the region to grab image data from. Takes 2x2 matrix and set 
            % the first column as the x coordinates and the second column 
            % as the y coordinates.
            %
            % INPUTS:
            % coords (required: coordinate) a 2x2 matrix where the first
            % column is the x coordinate and the second column is the y
            % coordinates. The first row is the lower bound of the ROI and
            % the second row is the upper bound of the ROI.
            % Intended Datatype: uint8, uint16, single, double
            %
            % OUTPUTS:
            % None. The ImageSlice property of the class is updated to have
            % been loaded from the specified ROI from the original image
            % file.

            % Bound Check on the crop coordinates
            coords       = double(coords);
            coords(1,:)  = max(coords(1,:), [1 1]);
            coords(2,:)  = min(coords(2,:), [obj.ncols obj.mrows]);
            obj.cropcols = coords(:,1)';
            obj.croprows = coords(:,2)';

            % Updates image slice to have the adjusted crop
            obj.Read
        end


        function ResetCropCoords(obj)
            % obj.RESETCROPCOORDS
            %
            % SUMMARY:
            % RESETCROPCOORDS will reset crop coordinates to then change 
            % the ROI that is loaded to encompass the full 2D bounds of an
            % image.
            
            % Resets to default coordinates
            if ~isempty(obj.mrows)
                obj.croprows = [1 obj.mrows];
                obj.cropcols = [1 obj.ncols];
            end
        end
        

        function SetLazyLoading(obj, flag)
            % obj.SETLAZYLOADING(flag)
            % SUMMARY:
            % SETLAZYLOADING toggles lazy loading per a logical flag.
            %
            % INPUTS:
            % flag (required: state flag) true will toggle lazy loading on
            % and false will disable lazy loading.
            % Intended Datatype: logical
            %
            % OUTPUTS:
            % None. Will change image loading behavior.
            obj.lazyloading = flag;
        end


        %% Source Setup Functions
        function SetupWebcamSource(obj)
            % SETUPWEBCAMSOURCE will check to see which webcam objects are
            % available
            % Sets up webcam as image server object
            wcl         = webcamlist;
            [idx, flag] = listdlg('ListString', wcl,...
                                  'SelectionMode', 'single',...
                                  'Name', 'Select webcam',...
                                  'ListSize', [260 80]);
            if flag
                obj.Source = webcam(wcl{idx});
            else
                return
            end
        end


        function SetupMultiFileSource(obj, f)
            % SETUPMULTIFILESOURCE will prompt user to select a folder to 
            % load files from or take input. If the user has passed in a
            % cell array of filepaths, they can be accessed sequentially.
            % Creates image data store based off of a folder or cell array
            % of files

            % User selects folder
            if nargin < 2 || isempty(f)
                f     = mfilename('fullpath');
                cpath = fileparts(f);
                f     = uigetdir(cpath, 'Select source folder');
            end

            % Sets up an imagedatastore (imds) to load in files
            if ischar(f) || isstring(f) || iscell(f)
                obj.Refresh2D
                obj.Source   = imageDatastore(f, 'ReadFcn', @obj.ReadFromMultipleFiles);
                obj.numfiles = numel(obj.Source.Files);
                obj.fidx     = 1; % init file index
                obj.Read

            else
                return
            end
        end


        function SetupFileSource(obj, fpath)
            % SETUPFILESOURCE will launch a user interface window to ask 
            % the user to select file(s) to load in. If a filepath is given,
            % this is where the function will start searching, otherwise,
            % it looks at the parent working directory or the last folder
            % used to load up images.
            if nargin < 2 && isempty(obj.filefolder)
                fpath = pwd;
            elseif nargin < 2 && ~isempty(obj.filefolder)
                fpath = obj.filefolder;
            end
            
            [file, folder] = uigetfile(obj.filefilt, 'Select image data', fpath, 'MultiSelect','on');

            % If a GUI window is open, it will be brought to the front
            % again since the prompt may have launched it back
            obj.GUIFocus

            % file = 0 when user exits, hence a numeric check
            if isnumeric(file)
                % No file loads
                return
            else
                obj.newstackreq = true;
            end

            if ischar(file)
                % Ensures 2D size data is reset
                obj.Refresh2D

                % Single file selection
                fpath = fullfile(folder, file);
                obj.LoadFromString(fpath)

            elseif iscell(file)
                % Multi file selection - expects same format
                files = cellfun(@(x) fullfile(folder, x), file, 'UniformOutput', false);
                obj.SetupMultiFileSource(files)

            end
        end


        function Refresh2D(obj)
            % REFRESH2D clears 2D information which forces the class to
            % then get size information as a result of new data being
            % loaded in.

            % Resets the indices upon a successful selection
            obj.ResetIndices

            % Clears ROI information to enable a fresh load
            obj.mrows = [];
            obj.ncols = [];
        end


        function SetupLive(obj, f, fext)
            % SETUPLIVE will prompt the user to select a folder and file
            % format to be observed live. Whenever the read function is
            % called, this observed folder will be scanned for any new
            % files of the desired file format.

            % Sets folder to be observed
            if nargin < 2 || isempty(f)
                f     = mfilename('fullpath');
                cpath = fileparts(f);
                f     = uigetdir(cpath, 'Select source folder');
            end

            
            if isnumeric(f)
                % Returns if user exits out of the folder selection window
                return
            else
                % Otherwise, source folder is updated
                obj.filefolder = f;
            end

            % Asks user for file extension with default of '.tif'
            answer = inputdlg('File extension', 'Set file type', [1 40], {'.tif'});
            % Returns if user exits out of the file format selection
            if isempty(answer)
                return
            end
            
            % Sets the extension to be observed
            if nargin < 3 || isempty(fext)
                % parse answer cell array for requested file extension
                fext = answer{:};
                % add period in file extension if not already included
                if ~strcmp(fext(1), '.')
                    fext = ['.' fext];
                end
            end

            % Setting the desired file extension
            obj.fileext = fext;

            % Enables the live loading
            obj.LoadLive
        end


        %% Read and Checks
        function Read(obj, d3idx, d4idx, d5idx)
            % obj.READ(d3idx, d4idx, d5idx)
            % obj.READ(d3idx, [], d5idx)
            % obj.READ([], d4idx, d5idx)
            % obj.READ(d3idx, d4idx)
            % obj.READ([], d4idx)
            % obj.READ(d3idx)
            % obj.READ
            %
            % SUMMARY:
            % READ will read in a 2D image for the specified indices of the
            % third and fourth dimensions of data when the data source is a
            % file, collection of files, folder, or multidimensional array.
            % If the data source is instead an image acquisition device or
            % webcam, a snapshot is instead taken. If the data source is a
            % "live data" source type, it will grab the next latest file 
            % from a folder that it is actively monitoring.
            %
            % INPUTS:
            % d3idx (optional: z slice index) specifies which z slice to grab
            % from a volume, if applicable. 
            % Intended Datatype: uint8, uint16, single, double
            %
            % d4idx (optional: 4th dimension index) specifies which timepoint,
            % stack file, or 4th dimension to grab, if applicable.
            % Intended Datatype: uint8, uint16, single, double
            %
            % OUTPUTS:
            % None. Will update the ImageStack and ImageSlice properties of
            % the class.

            if nargin < 4 || isempty(d5idx)
                % Current channel index preserved when not requested
                d5idx = obj.channel;
            end

            if nargin < 3 || isempty(d4idx)
                % Current stack / file index preserved when not requested
                d4idx = obj.dim4idx;
            end

            if nargin < 2 || isempty(d3idx)
                % Current slice index preserved when not requested
                d3idx = obj.slice;
            end
            

            % If there is no data source, the function exits since there is
            % no data to index
            if isempty(obj.Source)
                return
            end

            % Bound checks requested indices and determines which ones
            % changed
            d3idx      = obj.CheckD3Bounds(d3idx);
            d4idx      = obj.CheckD4Bounds(d4idx);
            d5idx      = obj.CheckD5Bounds(d5idx);
            idx        = [d3idx d4idx d5idx];

            % Checks if hyper stack dimensions changed
            idxchanged      = obj.CompareIndices(idx);
            obj.newstackreq = any(idxchanged(2:3));

            obj.SetD3Index(d3idx)
            obj.SetD4Index(d4idx)
            obj.SetD5Index(d5idx)

            switch class(obj.Source)
                case 'matlab.io.datastore.ImageDatastore'
                    % folder of image files
                    obj.Source.readimage(obj.fidx);

                case 'webcam'
                    % webcam object source
                    obj.ReadFromWebcam

                case {'uint8', 'uint16', 'single', 'double'}
                    % image array from workspace
                    obj.ReadFromArray

                case {'string', 'char'}
                    % single file
                    obj.LoadFromString

                case 'struct'
                    % live data - always just grabs latest file from folder
                    obj.LoadLive

                case 'matlab.io.MatFile'
                    % .mat file source
                    obj.ReadFromMData

                case 'VideoReader'
                    % Video file source
                    obj.ReadFromVideoFile

                case 'videoinput'
                    % Image acquisition device source
                    obj.ReadFromImAq

                case 'loci.formats.ChannelSeparator'
                    % Bioformats reader object
                    obj.ReadFromBF

            end
        end 


        function answer = SetIndicesPrompt(obj)
            % SETINDICESPROMPT will ask the user to input index values 
            % for the third and fourth dimensions of their data if those
            % dimensions are non-singleton and then update the
            % corresponding values.
            prompts   = {};
            def_inpts = {};
            if obj.numslices > 1
                prompts{end+1}   = 'Slice:';
                def_inpts{end+1} = num2str(obj.slice);
                sflag            = true;
            else
                sflag            = false;
            end

            if obj.dim4 > 1
                prompts{end+1}   = 'Stack/Timepoint:';
                def_inpts{end+1} = num2str(obj.dim4idx);
                tflag            = true;
            else
                tflag            = false;
            end

            % Will ask user to navigate when higher dimensions are > 1
            if tflag || sflag
                t_msg     = 'Slice/Stack navigation';
                answers   = myInputDlg(prompts, t_msg, [], def_inpts);
                if ~isempty(answers)
                    if sflag && tflag
                        d3idx = str2double(answers{1});
                        d4idx = str2double(answers{2});
                    elseif sflag && ~tflag
                        d3idx = str2double(answers{1});
                        d4idx = 1;
                    elseif ~sflag && tflag
                        d3idx = 1;
                        d4idx = str2double(answers{1});
                    end
                    answer = [d3idx d4idx];
                else
                    answer = [];
                end
            end
        end
    end



    methods (Access = private)
        %% Post Source Set Functions
        function SetSize(obj, sz)
            % SETSIZE will initialize all dimensions as singletons and then
            % assign the data's dimension sizes to non-singleton dimensions
            % of the actual data. This assignment is always done in the
            % order of YXZTC (3 spatial dimensions, time, and channel).

            % Inits dims sets the non-singleton dims
            nd            = length(sz);
            dims          = ones(1, 5); 
            dims(1:nd)    = sz;

            % Updates class dimension properties
            obj.mrows     = dims(1);
            obj.ncols     = dims(2);
            obj.numslices = dims(3);
            obj.numframes = dims(4);
            obj.channels  = dims(5);
        end


        function [idx, jdx] = GetCropIndices(obj)
            % CROPINDICES checks to see if a crop ROI has been set and then
            % returns the appropriate indices to use.
            % Indices in case of ROI
            if ~isempty(obj.croprows)
                idx = obj.croprows(1):obj.croprows(2);
                jdx = obj.cropcols(1):obj.cropcols(2);

            else
                idx = ':';
                jdx = ':';

            end
        end


        function D3 = CheckD3Bounds(obj, z)
            % CHECKZBOUNDS will check the bounds on the z dimension of data
            % before setting the requested z index.
            z  = min(obj.numslices, z);
            z  = max(z, 1);
            D3 = z;
        end


        function D4 = CheckD4Bounds(obj, D4)
            % CHECKD4BOUNDS will check the bounds on either the number of
            % timepoints in an array/matfile or number of files available 
            % in a datastore.
            D4    = min(obj.dim4, D4);
            D4    = max(1, D4);
        end


        function D5 = CheckD5Bounds(obj, D5)
            % CHECKD4BOUNDS will check bounds on number of channels
            % available.
            D5 = min(obj.channels, D5);
            D5 = max(1, D5);
        end


        function SetD3Index(obj, z)
            % SETD3INDEX will set the third dimensions index after bounds
            % have been checked. This index represents the position along
            % the z axis in a stack if a stack exists.
            if isempty(z)
                z = 1;
            end
            obj.slice = z;
        end


        function SetD4Index(obj, D4)
            % SETD4INDEX will set the fourth dimension index to either the
            % current timepoint index or the current file index, depending
            % on which there are more of per the data source type.
            if isempty(D4)
                D4 = 1;
            end
            obj.dim4idx = D4;

            % Assigns the fourth dim index to appropriate property
            if isempty(obj.numfiles) || obj.numfiles == 1
                obj.framenum = D4;
            elseif isempty(obj.numframes) || obj.numframes == 1
                obj.fidx     = D4;
            end
        end


        function SetD5Index(obj, D5)
            % SETD5INDEX will set the fifth dimension index set the current
            % channel
            if isempty(D5)
                D5 = 1;
            end
            obj.channel = D5;
        end


        function CheckType(obj)
            % CHECKTYPE will convert logical to uint8 to prevent algorithms
            % from erroring.
            if islogical(obj.Slice)
                obj.Slice = uint8(obj.Slice);
            end
        end

        
        function CheckDims(obj)
            % CHECKDIMS will ensure that indexed data has no singleton 
            % dimensions.
            sz = size(obj.Slice);
            if any(sz==1)
                obj.Slice = squeeze(obj.Slice);
            end
        end

        

    %% Data Loading
    % Functions for data loading will accept a single input. The input will
    % either be a string or array. This "loads" the data source for the
    % first time
        function I = LoadFromString(obj, s)
            % LOADFROMSTRING will take a string/character array argument to
            % load in a 2D image or 3D stack. Alternatively, if the path is
            % to a folder, an image data store will be created so that the
            % user can navigate across files.

            % If no argument is passed, it assumes the same file as before
            % is being utilized - assumption is that a different region has
            % been specified prior to calling this function
            if nargin < 2
                s = [obj.filefolder filesep obj.filename obj.fileext];
            elseif (~isa(obj.Source, 'matlab.io.datastore.ImageDatastore') && obj.fidx ~= 1) || ~obj.dataloaded 
                % Memory check with 500 MB threshold allowed
                good2load = obj.MemoryCheck(s, 5e8, obj.lazyloading);
                if ~good2load
                    return
                end
            end

            % Getting number of output arguments
            nout = nargout;

            % Checks if string is folder or file
            str_type = exist(s, 'file');
            if str_type == 7 
                % Folder/multiple files converted to image datastore -
                % first image is immediately loaded by 
                obj.Source   = imageDatastore(s, 'ReadFcn', @obj.ReadFromMultipleFiles);
                obj.numfiles = numel(obj.Source.Files);
                obj.fidx     = 1;

                % Reads in the first image
                obj.Read                
                return

            elseif str_type == 2
                % String is to a file that exists, function continues

            else
                % String identifies neither a file nor a folder, function
                % will exit
                return

            end

            % Check if this is a new file being loaded from a different
            % place
            [newfpath, ~, fext] = fileparts(s);
            newfile      = isempty(obj.mrows) ||...
                           isempty(obj.fileext) ||...
                           ~strcmp(newfpath, obj.filefolder) ||...
                           ~strcmp(fext, obj.fileext);

            % Save file selection info
            [obj.filefolder, obj.filename, obj.fileext] = fileparts(s);
            switch obj.fileext
                case '.mat'
                    % M-data (matfile) source with variable/array
                    if newfile
                        obj.LoadFromMData(s)
                    else
                        obj.ReadFromMData
                    end

                case {'.tif', '.tiff'}
                    % Tiff image file sources
                    if newfile
                        obj.LoadFromTiff(s)
                    else
                        obj.ReadFromTiff
                    end

                    % Prevents source overwrite if called from imds source
                    obj.Check4IMDS(nout)

                case {'.png', '.jpg', '.jpeg', '.jfif'}
                    % Non-tiff image file sources
                    if newfile
                        obj.LoadFromImageFile(s)
                    else
                        obj.ReadFromImageFile
                    end

                    % Prevents source overwrite if called from imds source
                    obj.Check4IMDS(nout)

                case {'.avi', '.mp4', '.mpg', '.mpeg'}
                    % Video setup as a videoreader object
                    if newfile
                        obj.LoadFromVideoFile(s)
                    else
                        obj.ReadFromVideoFile
                    end

                case obj.bffileexts
                    % Does nothing if user cannot use BF
                    if isempty(obj.bffileexts)
                        warning(['User does not have BioFormats. ' ...
                                 'No data loaded'])
                        return
                    end
                    % bioformats compatible file extensions
                    if newfile
                        obj.LoadFromBF(s)
                    else
                        obj.ReadFromBF
                    end
            end

            % Ensures image output when class method is called from
            % imds source - when mult. files loaded up
            if nout == 1
                I = obj.Slice;
            end
        end


        function LoadFromMData(obj, s)
            % matfile object use reduces memory usage
            mfobj   = matfile(s);
            vars    = fieldnames(mfobj);
            idx     = ~strcmp(vars, 'Properties');
            vars    = vars(idx);
            numvars = numel(vars);

            % .mat file data to be loaded - user selects variable
            if numvars > 1
                [idx, tf] = listdlg('ListString', vars);
                % user exits variable selection
                if ~tf
                    return
                end
                % verifying response
                vname = vars{idx};
            else
                vname = vars{1};
            end

            % Saves variable name for future access from matfile
            obj.variable = vname;

            % Check that variable is valid array data
            fileinfo = whos(mfobj, obj.variable);
            isArr    = strcmp(fileinfo.class, {'uint8', 'uint16', 'uint32', 'single', 'double'});
            if any(isArr)
                % Source settings and dimension information
                obj.Source = mfobj;
                obj.SetSize(fileinfo.size)
                
                % Ensures the full 2D slice is loaded upon initial load
                obj.ResetCropCoords

                % Reading in the MData variable
                obj.ReadFromMData

            else
                % Errors when user select variable that is not a numerical
                % array
                emsg = 'Selected variable is not a numerical array';
                error(emsg)

            end
        end
        

        function LoadFromTiff(obj, s)
            % Number of slices in a z stack
            imInfo = imfinfo(s);
            sz     = [imInfo(1).Height imInfo(1).Width numel(imInfo)];
            obj.SetSize(sz)

            % Ensures the full 2D slice is loaded upon initial load
            obj.ResetCropCoords

            % Time dimension is singleton
            obj.framenum  = 1;
            obj.numframes = 1;

            % Will read in 
            obj.ReadFromTiff
        end


        function LoadFromImageFile(obj, s)
            % LOADFROMIMAGEFILE will load up data
            % 2D images - assumes no z slices
            imInfo    = imfinfo(s);
            sz        = [imInfo.Height imInfo.Width 1];
            obj.SetSize(sz);

            % Ensures the full 2D slice is loaded upon initial load
            obj.ResetCropCoords

            % Performs the actual reading of the 2D image
            obj.ReadFromImageFile
        end


        function LoadFromVideoFile(obj, s)
            % Setting up initial video source
            obj.Source = VideoReader(s);            
            sz         = [obj.Source.Height obj.Source.Width 1 obj.Source.NumFrames];
            obj.SetSize(sz)

            % Ensures the full 2D slice is loaded upon initial load
            obj.ResetCropCoords

            % Reads in 2D frame from video
            obj.ReadFromVideoFile
        end


        function LoadFromBF(obj, s)
            % LOADFROMBF will load from bioformats and commercial
            % microscope file formats.

            % Setting up the source and getting dimension lengths
            obj.Source  = bfGetReader(s);
            sz          = GetBFArraySize(obj.Source, 'yxztc');
            obj.SetSize(sz)

            % Resets the ROI to grab full frame
            obj.ResetCropCoords

            % Reading in first 2D plane from BioFormats compatible data
            obj.ReadFromBF
        end


        function LoadFromArray(obj, A)
            % LOADFROMARRAY will allow the user to directly pass an array
            % form the workspace into the image server class to allow for
            % easy navigation via method calls which allows for easy
            % integration into GUIs.

            % dimensionality of N-Dimensional image array
            sz = size(A);
            nd = ndims(A);
            if nd == 1
                % In case of incorrectly sized data
                warning('Cannot load data with less than 2 dimensions.')
                return

            end

            % Ensures the full 2D slice is loaded upon initial load
            obj.numfiles = 0;
            obj.SetSize(sz)
            obj.ResetCropCoords
            
            % Overwrite occurs if valid data loaded in
            obj.Source     = A;
            obj.filename   = [];
            obj.filefolder = [];
            obj.fileext    = [];

            % First slice read in
            obj.Slice     = A(:,:,1,1,1);
        end


        function LoadLive(obj)
            % LOADLIVE will check a folder to see if new files have been
            % saved in the folder. This function will then load in the
            % oldest file if it is the first time it is called. Everytime
            % after that, it will load the next latest file and update
            % information on the directory so it keeps a live update of
            % folder contents.

            % Creates the source as a struct
            if ~isa(obj.Source, 'struct')
                obj.Source      = [];
                obj.Source.type = 'Live';
            end

            % path to data with specified file extension
            datapath = [obj.filefolder filesep '*' obj.fileext];

            % Reordering data by date
            data     = dir(datapath);
            [~, idx] = sort([data.datenum],'ascend');
            data     = data(idx);
            nfiles   = numel(data);

            % Checks for new files
            if isempty(obj.numfiles)
                % First time looking at folder
                obj.numfiles = nfiles;
                obj.fidx     = 1;

            elseif obj.numfiles < nfiles
                % New files added in folder - updates numfiles
                obj.numfiles = nfiles;
                obj.fidx     = obj.fidx + 1;

            elseif obj.numfiles == nfiles
                % Progressing through folder while it is static
                obj.fidx = obj.fidx + 1;

            else
                % User deleted or removed files from folder
                error('Folder has lost files since last accessed.')

            end

            % Loads first accessible file
            idx  = obj.fidx;
            next = true;
            while next
                if idx>nfiles
                    warning('No new data available.')
                    break
                end
                % File ID and checks for accessibility
                fid = fullfile(data(idx).folder,data(idx).name);                
                x   = fopen(fid, 'r'); 
                if x == -1
                    idx = idx+1;
                else
                    % If on the first file, set size, and reset the indices
                    if obj.fidx == 1
                        imInfo = imfinfo(fid);
                        sz     = [imInfo(1).Height imInfo(1).Width numel(imInfo)];
                        obj.SetSize(sz)
                        obj.ResetCropCoords
                    end

                    fclose(x);
                    if strcmp(obj.fileext, '.tif')
                        obj.Slice = obj.MaxProjection(fid, obj.croprows, obj.cropcols, obj.lazyloading);
                    else
                        obj.Slice = imread(fid);
                    end
                    % In case colors get organized along 4th dimension as
                    % occurs in some file formats
                    obj.Slice = squeeze(obj.Slice);
                    % Gettings file metadata
                    [obj.filefolder, obj.filename, obj.fileext] = fileparts(fid);
                    next = false;
                end
            end
        end


        %% Data Reading
        % Each type of file or datasource will need a different read
        % function to be called in the read method of the class as well as
        % the load method when first initialized. While load functions will
        % initialize metadata and data information prior to loading a 2D
        % image, these functions will only read the 2D slice and a 3D stack
        % if lazy loading is off. This prevents full loading of time and
        % channel dimensions since a user would rarely try to load all 5
        % dimensions unless they are directly working with arrays. The way 
        % in which this data is read in will depend on crop settings and 
        % the indices that are set to navigate the data sources.
        function ReadFromMData(obj)
            % READFROMMDATA will read in a 2D image from the MData variable
            % data source.
            
            % Getting indices in case of crop and other dims as well
            [idx, jdx] = obj.GetCropIndices;
            z          = obj.Slice;
            t          = obj.framenum;
            c          = obj.channel;

            % Dynamic indexing not feasible on matfile but this ensures
            % fast loading of ND array data
            if obj.sizes(3) == 3 || ~obj.lazyloading
                % Assumes RGB
                if obj.newstackreq
                    % Avoids reloading a stack if its the same one
                    obj.Stack     = obj.Source.(obj.variable)(idx, jdx, :, t, 1);
                    obj.Stack     = squeeze(obj.Stack);
                end
                obj.Slice     = obj.Stack(idx, jdx, :);

            elseif obj.sizes(3) >3 && ~obj.lazyloading
                % Assumes stack
                if obj.newstackreq
                    % Avoids reloading a stack if its the same one
                    obj.Stack     = obj.Source.(obj.variable)(idx, jdx, :, t, c);
                    obj.Stack     = squeeze(obj.Stack);
                end
                obj.Slice     = obj.Stack(idx, jdx, z);

            else
                % Grayscale image
                obj.Slice     = obj.Source.(obj.variable)(idx, jdx, z, t, c); % Can add channels and such later
                obj.Slice     = squeeze(obj.Slice);

            end
        end


        function ReadFromTiff(obj)
            % READFROMTIFF will read in image data from a tif file.

            % Constructs full file id for current image
            s = [obj.filefolder filesep obj.filename obj.fileext];

            % In case of crop - have to get values differently for the
            % tiffreadvolume function
            if ~isempty(obj.croprows) && ~isempty(obj.cropcols)
                y = [obj.croprows(1) obj.croprows(2)];
                x = [obj.cropcols(1) obj.cropcols(2)];
            else
                y = [1 inf];
                x = [1 inf];
            end

            % Z Index
            z = obj.slice;

            % Stack read when lazy loading off
            if ~obj.lazyloading
                % Will only load the full stack when lazy loading is off
                if obj.newstackreq
                    % Avoids reloading a stack if its the same one
                    obj.Stack = tiffreadVolume(s, 'PixelRegion', {[y(1) y(2)], [x(1) x(2)], [1 inf]});
                end

                if obj.numslices == 3
                    % RGB case
                    obj.Slice = obj.Stack;
                else
                    % Grayscale case
                    obj.Slice = obj.Stack(:, :, z);
                end
            else
                if obj.numslices == 3
                    % RGB case
                    obj.Slice = tiffreadVolume(s, 'PixelRegion', {[y(1) y(2)], [x(1) x(2)], [1 inf]});
                else
                    % Grayscale case
                    obj.Slice = tiffreadVolume(s, 'PixelRegion', {[y(1) y(2)], [x(1) x(2)], [z z]});
                    obj.Slice = squeeze(obj.Slice);
                end
            end
        end


        function idxchanged = CompareIndices(obj, idx)
            % COMPAREINDICES compares a vector of values to the current
            % indices to determine which dimensions' indices will change.
            % This function is useful for determining if a stack is already
            % loaded into memory or a new one needs to be loaded. This
            % reduces loading overhead by prevent reloads when unnecessary.
            %
            % INPUTS:
            %
            % idx - a 3 element vector of integers where the elements 
            % represent the indices of dimensions 3 through 5,
            % respectively.

            % Original indices prior to reading in data from specified
            % indices
            z = obj.slice;
            t = obj.dim4idx;
            c = obj.channel;

            % Reshaping the old indices and new indices to match shape
            oldidx = [z t c];

            % True if indices changed for any dimensions 1-5. Each col is a
            % dimension of the data array
            idxchanged = idx ~= oldidx;
        end


        function ReadFromImageFile(obj)
            % READFROMIMAGEFILE will read in a 2D image with any set crop
            % Constructs full file id for current image
            s = [obj.filefolder filesep obj.filename obj.fileext];

            % In case of crop
            [idx, jdx] = obj.GetCropIndices;

            % Index all of the 3rd dimension in case of RGB images
            if obj.newstackreq
                % Avoids reloading a stack if its the same one
                obj.Stack  = squeeze(imread(s));
            end
            obj.Slice  = obj.Stack(idx, jdx, :);
        end


        function ReadFromVideoFile(obj)
            % READFROMVIDEOFILE will be called for videoinput objects
            % In case of crop
            [idx, jdx] = obj.GetCropIndices;

            % Reading data in
            obj.Slice  = obj.Source.read(obj.framenum);
            obj.Slice  = obj.Slice(idx, jdx, :);
        end


        function ReadFromBF(obj)
            % READFROMBF will read data in from a bioformats compatible
            % file format. This function is called when the source is a
            % bioformats reader object.

            % Getting crop indices
            [idx, jdx] = obj.GetCropIndices;

            % Note that BF will flip channel and time
            dimvec = [obj.slice obj.framenum obj.channel];

            % External lazy loading function that converts high dimensional
            % indices to plane indices for the BF reader
            % Stack read when lazy loading off
            if ~obj.lazyloading
                if obj.newstackreq
                    % Avoids reloading a stack if its the same one
                    I          = LoadFromBioFormatsAsVol(obj.fullFID);
                    obj.Stack  = I;
                end

                % Indexing out requested slice
                obj.Slice  = obj.Stack(idx, jdx, dimvec(1), dimvec(2), dimvec(3));
                obj.Slice  = squeeze(obj.Slice);

            else
                % Lazy loading case
                I         = LoadFromBioFormats(obj.Source, dimvec);
                obj.Slice = I(idx, jdx);

            end
        end


        function ReadFromWebcam(obj)
            % READFROMWEBCAM will read from a usb webcam device that has
            % been recognized via MATLAB's support package for usb webcams.
            % Grabs crop indices if they exist
            [idx, jdx] = obj.GetCropIndices;
            obj.Stack  = obj.Source.snapshot;
            obj.Slice  = obj.Stack(idx, jdx, :);
        end


        function ReadFromImAq(obj)
            % READFROMIMAQ will read from a video inpute device that is
            % setup via the image acquisition toolbox.
            % Grabs crop indices if they exist
            [idx, jdx] = obj.GetCropIndices;
            obj.Stack  = getsnapshot(obj.Source);
            obj.Slice  = obj.Stack(idx, jdx, obj.slice);
        end


        function ReadFromArray(obj)
            % READFROMARRAY will simply access the preloaded stack and
            % directly read in a 2D slice from it per the indices that are
            % set.

            % Grabs crop indices if they exist
            [idx, jdx] = obj.GetCropIndices;

            if obj.numslices > 1
                % Z stack case
                if ~obj.lazyloading
                    if obj.newstackreq
                        % Avoids reloading a stack if its the same one
                        obj.Stack = obj.Source(idx, jdx, :, obj.dim4idx, obj.channel);
                    end
                end

                % RGB case
                if obj.numslices == 3
                    obj.Slice = obj.Source(idx, jdx, :, obj.dim4idx, obj.channel);
                else
                    obj.Slice = obj.Source(idx, jdx, obj.slice, obj.dim4idx, obj.channel);
                end

            else
                % Single plane
                obj.Slice = obj.Source(idx, jdx, :, obj.dim4idx, obj.channel);

            end
        end


        function Check4IMDS(obj, nout)
            % CHECK4IMDS will check the source to see if the data source is
            % an ImageDatastore (imds) or just a single file
            % Prevents overwriting the source unless dealing w single file
            if nout == 0 && ~isa(obj.Source, 'matlab.io.datastore.ImageDatastore') && ~isa(obj.Source, 'struct')
                obj.Source = 'File';
            end
        end


        function I = ReadFromMultipleFiles(obj, fid)
            % READFROMMULTIPLEFILES ensures that when multiple files are 
            % selected into an imagedatastore, the data can be read in 
            % properly per the file format.
            obj.LoadFromString(fid)
            if nargout == 1
                I = obj.Slice;
            end
        end


        function good2load = MemoryCheck(obj, fid, threshold, lazyloadflag)
            % MEMORYCHECK will compare the size of the file the user wants
            % to load in to the available memory on the computer. If the
            % file is larger than the available RAM, the file will not load
            % as this function will throw an error and display a message
            % for the user. The fraction argument is a scaling factor used
            % in case of lazy loading as the user might only be loading a
            % single z plane rather than an entire stack.

            % Threshold for memory to be reserved  - 500 MB by default
            if nargin < 2 || isempty(threshold)
                threshold = 5e8;
            end

            % Lazy loading reduces memory load for tif stacks and video
            % files
            [~, ~, ext] = fileparts(fid);
            istiff      = contains(ext, {'tif', 'tiff'});
            isvid       = contains(ext, obj.vidformats);
            if lazyloadflag && istiff
                finfo   = imfinfo(fid);
                zslices = numel(finfo);
                factor  = 1/zslices;
                
            elseif lazyloadflag && isvid
                vidobj  = VideoReader(fid);
                tpts    = vidobj.NumFrames;
                factor  = 1/tpts;

            else
                factor  = 1;

            end

            % System's available memory
            if ispc
                % PC (windows) uses GB
                [~, m]  = memory;
                freemem = m.PhysicalMemory.Available;

            elseif isunix && ~ismac
                % Linux used kb
                [~,w]   = unix('free | grep Mem');
                stats   = str2double(regexp(w, '[0-9]*', 'match'));
                freemem = stats(end);
                freemem = freemem*1e3;

            elseif ismac
                % Mac uses variable memory magnitude
                [~, c]   = unix('top -l 1 | grep -E "^Phys"');
                idx      = regexp(c, 'unused');
                idxs     = regexp(c, ',');

                % Finds the number of bytes available
                nidx     = idxs(end)+2:idx-2;
                c        = c(nidx);

                % Scale/Magnitude of number of bytes
                isGB     = contains(c, 'G');
                isMB     = contains(c, 'M');
                isTB     = contains(c, 'T');
                midx     = [isMB isGB isTB];
                memscale = [1e6 1e9 1e12];
                memscale = memscale(midx);
                freemem  = str2double(c(1:end-1));
                freemem  = freemem*memscale;

            else
                % Unknown / unsupported platform
                error('Platform not supported.')
                
            end

            % File size in bytes - extension agnostic
            fileinfo = dir(fid);
            fmemsize = fileinfo.bytes;
            fmemsize = fmemsize*factor;

            % File size converted to GB
            freemem   = freemem/(1e9);
            fmemsize  = fmemsize/(1e9);
            threshold = threshold/(1e9);

            % Suggests the user is out of memory
            outofmem = fmemsize > (freemem-threshold);

            % UI case enables user override
            if outofmem
                % Prints warning to CL
                msg = 'Please check memory usage. File may be too large to load';
                warning(msg)

                % Message to user to enable override
                msg       = ['Current free memory: ' num2str(freemem) ' GB'];
                msg       = [msg newline 'File size: ' num2str(fmemsize) ' GB'];
                %msg       = [msg newline 'Memory buffer'];
                msg       = [msg newline newline 'Load anyways?'];

                if ~isempty(obj.GUI)
                    % Launches a UI for potential user override
                    selection = uiconfirm(obj.GUI, msg,...
                                          'Limited Memory', 'Options',...
                                          {'Yes', 'No'},...
                                          'DefaultOption', 'No');
                else
                    % Terminal line input for override
                    msg       = [msg newline ...
                                 'Please type yes or no and hit enter.'...
                                 newline];
                    selection = input(msg, 's');
                end
            else
                selection = 'Yes';
            end

            % User will not load data 
            if ~strcmpi(selection, 'Yes')
                good2load = false;
                return
            end

            % Displays table w/ info on remaining memory and file size
            Header = {'File Size (GB)', 'Remaining Memory (GB)'};
            T      = table(fmemsize, freemem, 'VariableNames', Header);
            disp(T)

            % User can load data
            good2load = true;
        end
    end



    methods (Static, Access = private)
        %% Static Methods
        % Will perform checks or minor computations independent of class
        % props. The behavior of the methods below will depend on external 
        % factors.

        function bfavailable = UserHasBF
            % USERHASBF will check to see that the user has important
            % bioformats functions needed to properly load in data with
            % both lazy loading and eager loading capabilities.

            bfFiles      = {'bfGetFileExtensions.m', 'bfGetPlane.m',...
                            'bfGetPlaneAtZCT.m', 'bfopen.m', ...
                            'bfOpen3DVolume.m'};
            bfavailable  = cellfun(@(c) exist(c, 'file'), bfFiles);
            bfavailable  = bfavailable == 2;
            missingfiles = bfFiles(~bfavailable);
            bfavailable  = all(bfavailable);

            

            % Warning when not all bioformats is available
            if ~bfavailable
                % Appending the names of missing files needed to use BF
                bfmsg = ['Bioformats loading may not operate as '...
                         'intended. User is missing the following' ...
                         ' files:'];
                for fname = missingfiles
                    bfmsg = [bfmsg newline fname{:}];
                end

                % Bioformats 
                bfmsg = [bfmsg newline ...
                         'For proper installation of OME Bioformats, ' ...
                         'visit: ' ...
                         'https://docs.openmicroscopy.org/bio-formats/5.7.1/users/matlab/index.html'];
                warning(bfmsg)
            end
        end

        function GUIFocus
            % GUIFOCUS will focus a GUI window in case it was sent to the
            % back by the launching of a prompt window
            guihandle = gcbf;
            if ~isempty(guihandle)
                figure(guihandle)
            end
        end


        function I = MaxProjection(fid, m, n, memFlag)
            % MAXPROJECTION will produce the maximum intensity projection
            % of an image in a memory efficient manner if the mem flag is
            % true. Otherwise, the entire tif stack is loaded in and the
            % max projection is computed.
            if nargin < 2 || isempty(m)
                m = inf;
            end

            if nargin < 3 || isempty(n)
                n = inf;
            end

            if nargin < 4 || isempty(memFlag)
                memFlag = true;
            end

            % Either computes memory efficient or time efficient max proj.
            if memFlag
                % Memory efficient
                % Extracting metadata
                finfo  = imfinfo(fid);
                depth  = numel(finfo);
                finfo  = finfo(1);
                bdepth = finfo.BitsPerSample;
                bdepth = ['uint' num2str(bdepth(1))]; % in case of RGB
                I      = zeros(m, n, bdepth);
                % Max computed slice by slice
                for z = 1:depth
                    im = tiffreadVolume(fid, "PixelRegion", {[1 m] [1 n] [z z]});
                    I  = max(im, I);
                end
            else
                % Time efficient
                I = tiffreadVolume(fid, 'PixelRegion', {[1 m] [1 n] [1 inf]});
                I = max(I, [], 3);
            end
        end


        function ImAqObjList = CheckForImAq
            % CHECKFROIMAQ will scan the system devices with the image
            % acquisition toolbox to detect valid image acquisition devices
            % it can use to 
            % Resets image acquisition hardware to track viable options
            imaqreset
            hardware    = imaqhwinfo;
            ImAqAdList  = hardware.InstalledAdaptors;
            nObjs       = numel(ImAqAdList);
            blank       = cell(1, nObjs);
            ImAqObjList = struct('name', blank, 'devName', blank, 'id', blank);
            for i = 1:nObjs
                % Gets device name and the constructor command
                imaqobj                = imaqhwinfo(ImAqAdList{i});
                ImAqObjList(i).name    = imaqobj.DeviceInfo.DeviceName;
                ImAqObjList(i).devName = imaqobj.AdaptorName;
                ImAqObjList(i).id      = [imaqobj.DeviceIDs{:}];
            end
        end
    end


    
    methods
        %% Dependent Property Get Functions
        function fid = get.fullFID(obj)
            % get.fullFID returns the full filepath to the data that is
            % loaded in
            fname = [obj.filename obj.fileext];
            if isempty(fname)
                fid = [];
            else
                fid = fullfile(obj.filefolder, fname);
            end
        end

        % Size related
        function sz = get.sizes(obj)
            % get.size will get all dimensions for the source data loaded
            % up
            d4 = obj.dim4;
            d5 = obj.channels;
            sz = [obj.mrows obj.ncols obj.numslices d4 d5];
        end


        function d4 = get.dim4(obj)
            % get.dim4 will return the size of the fourth dimension. This
            % will either be the number of frames/timepoints or the number
            % of files present in the data source.
            d4 = max([obj.numframes, obj.numfiles, 1]);

            % In case there are no frames or files, fourth dim is = 1
            if isempty(d4)
                d4 = 1;
            end
        end


        function mrows = get.mrowscrop(obj)
            % get.mrowscrop returns the size of the second dimension in the
            % image slice. This will differ from the actual data size since
            % the user might have cropped out a region.
            mrows = obj.croprows(2) - obj.croprows(1) + 1;
        end


        function ncols = get.ncolscrop(obj)
            % get.ncolscrop returns the size of the second dimension in the
            % image slice. This will differ from the actual data size since
            % the user might have cropped out a region.
            ncols = obj.cropcols(2) - obj.cropcols(1) + 1;
        end


        %% User Access Info
        function methodslist = get.Classmethods(obj)
            % get.classmethods will get the list of publicly accessible
            % class methods
            if nargout == 1
                methodslist = methods(obj);
            elseif nargout == 0
                methods(obj)
            end
        end


        function propslist = get.Classproperties(obj)
            % get.classproperties will get the list of publicly accessible
            % class properties
            if nargout == 1
                propslist = properties(obj);
            elseif nargout == 0
                properties(obj)
            end
        end


        %% Data/Class State Info
        function flag = get.dataloaded(obj)
            % get.dataloaded will check to see if the server has data
            % loaded up
            flag = ~isempty(obj.Slice) && ~isempty(obj.Source);
        end


        function flag = get.isstacknavigable(obj)
            % get.isstacknavigable will check if user can move through the
            % third dimension of the data source
            flag = ~isempty(obj.numslices) && (obj.numslices > 1);
        end


        function flag = get.istimenavigable(obj)
            % get.istimenavigable will check if user can move through the
            % fourth dimension of the data source
            flag = ~isempty(obj.dim4) && (obj.dim4 > 1);
        end


        %% Option Queries
        function List = get.Datasources(obj)
            % Default initial list of options
            list         = {'Folder', 'File', 'Live'};

            % Check for image acquisition objects and make cell array list
            try
                Imaqobjs = obj.CheckForImAq;
                list     = [list Imaqobjs.name];
            catch
                Imaqobjs = [];
            end

            % Check for webcams
            wcl = webcamlist;
            if ~isempty(wcl)
                list = [list 'Webcam/USB Device'];
            end

            % Convert to struct to keep track of different types of objs
            List.fullList = list;
            List.imaqobjs = Imaqobjs;
            List.webcams  = wcl;
        end


        %% Accesible Limit Checks
        function inbounds = WithinD1Bounds(obj, idx)
            % WITHIND1BOUNDS will check an index value to see if it is
            % within the bounds of valid indices for the first dimension.
            % This can be useful to know when allowing or blocking certain
            % GUI behaviors if the user tries to navigate to indices
            % outside the allowed bounds.
            inbounds = (idx >= 1) && (idx <= obj.mrows);
        end

        function inbounds = WithinD2Bounds(obj, idx)
            % WITHIND2BOUNDS will check an index value to see if it is
            % within the bounds of valid indices for the second dimension.
            % This can be useful to know when allowing or blocking certain
            % GUI behaviors if the user tries to navigate to indices
            % outside the allowed bounds.
            inbounds = (idx >= 1) && (idx <= obj.ncols);
        end

        function inbounds = WithinD3Bounds(obj, idx)
            % WITHIND3BOUNDS will check an index value to see if it is
            % within the bounds of valid indices for the third dimension.
            % This can be useful to know when allowing or blocking certain
            % GUI behaviors if the user tries to navigate to indices
            % outside the allowed bounds.
            inbounds = (idx >= 1) && (idx <= obj.numslices);
        end


        function inbounds = WithinD4Bounds(obj, idx)
            % WITHIND4BOUNDS will check an index value to see if it is
            % within the bounds of valid indices for the fourth dimension.
            % This can be useful to know when allowing or blocking certain
            % GUI behaviors if the user tries to navigate to indices
            % outside the allowed bounds. Recall that the fourth dimension
            % of the data depends on the data source type so dim4 is a
            % dependent prop.
            inbounds = (idx >= 1) && (idx <= obj.dim4);
        end
    end
end