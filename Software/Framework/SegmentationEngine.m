classdef SegmentationEngine < handle

    % Segmentation Engine will apply one parametric algorithm and hold
    % properties related to the computation that can be passed to the GUI.
    % It will also pass off certain configuration settings (e.g. parameter
    % bounds for edit fields and parameter symbols) as well as

    properties (Access = public)
        % Preprocessing options to be set
        inversion {mustBeA(inversion, 'logical')} = false % Flag determines whether image needs to be inverted
        denoise {mustBeA(denoise, 'logical')}     = false % Flag determines whether image is to be denoised or not
        denoisemethod                                     % Handle to denoising function
        tform                                             % Transform function handle to be applied to raw image
        square {mustBeA(square, 'logical')}       = false % Squares the image to emphasize intensity differences
        logscale {mustBeA(logscale, 'logical')}   = false % True flag means the image will be log scaled: I = log(I + 1)
        RGBTarget                                         % RGB Target color for a color distance transformation in case user desires transform
        taper (:, :) {mustBeNumericOrLogical}             % Array that will lead to tapering to 0 outside the user defined ROI
        TPoints                                           % Coordinates that define start of taper boundary

        % Image metadata
        mrows                                             % Number of rows in image
        ncols                                             % Number of columns in image

        % Image
        Raw                                               % Grayscale image without preprocessing applied
        newimage = true                                   % Determines if new image is getting passed to the engine
        isRGB                                             % Flag will determine if image needs to be transformed. By default, an RGB image will be converted to 
        RGB                                               % A tier above the raw image, if initial image input is RGB

        % Algorithm Layers and Results
        Plugin                                            % The network containing the image processing layers and corresponding parameters (i.e. two structs)
        method     = 'Intensity Threshold'                % Name of the algorithm/method being used in segmentation
        laststep   = 3                                    % Final compute step at which to stop at. By default, upon setting a segmentation method, it is the final 
        resulttype = 'contour'                            % Result type will either be a contour, point cloud, mask, or label matrix
        nlayers                                           % Number of layers (including image input layer)
        stage                                             % stage determines which step to start computation at
        Params                                            % Cell array holding the names to parameters - makes for easy indexing and debugging
        Mask                                              % Mask computed from the points given by the final layer in the net
        EngineVisualizer                                  % Allows user to visualize the processing steps and get updates as changes are made
        Outputs {mustBeA(Outputs, 'cell')} = {}           % Cell array holding the segmentation step results

        % Refinement
        snakes       = false                              % Flag determines whether or not to further refine a mask with active contours
        snakesconfig                                      % Struct containg the settings to use in active contours

        % AI
        networkPath                                       % File path to the network used
        Network                                           % The CNN / Deep network 
        NetworkFun                                        % Function handle to use the AI network
        ai           = false                              % Determines whether the Raw image is to be processed by the AI method prior to being passed to the parametric method 'net'
    end

    


    methods
        %% Constructor and Set/Get methods
        function obj = SegmentationEngine(image, tform)
            % Constructor
            % Initializing the parameters and parametric algorithm (plugin)
            obj.Plugin = Plugin_IntensityThreshold;
            obj.UpdatePluginConfig

            % Init post processing configs
            obj.InitSnakesConfig

            % Input arguments allowed are 2D image and function handles
            if nargin == 1 && ~isempty(image)
                obj.SetImage(image)
            elseif nargin == 2 && ~isempty(image) && ~isempty(tform)
                obj.SetImage(image, tform)
            end
        end
    end



    methods (Access = public)
        function UpdatePluginConfig(obj)
            % UPDATEPLUGINCONFIG extracts information regarding the layers 
            % and resets flow stage and step whenever new plugin is loaded

            % Parses the plugin information
            obj.ParsePluginInfo

            % Construct Flow of parameter use
            obj.ConstructFlow
        end


        function ConstructFlow(obj)
            % CONSTRUCTFLOW
            % Constructs the flow property of the plugin to determine which
            % steps use what parameters
            for p = 1:numel([obj.Plugin.controls])
                for layer = 1:obj.nlayers
                    ps = obj.Plugin.Layers(layer).In;
                    if ps(p) == 1
                        obj.Plugin.flow(p) = layer;
                        break
                    end
                end
            end
        end


        function ParsePluginInfo(obj)
            % PARSEFROMPLUGIN will parse out the number of layers,
            % parameter names, and data output type for visualization
            % settings. 

            % Parsing number of layers and parameter names
            obj.nlayers = numel(obj.Plugin.Layers);
            obj.Params  = {obj.Plugin.controls.Name};

            % Resets the starting and ending compute steps upon new compute
            % method loading
            obj.ResetComputeSteps

            % In case the plugin has a data output type property
            if isprop(obj.Plugin, 'type')
                obj.resulttype = obj.Plugin.type;
            end
        end


        function ResetComputeSteps(obj)
            % Default start at layer 1 and stop at final layer
            obj.stage    = 1;
            obj.laststep = obj.nlayers;
        end


        function Reset(obj, resetflag)
            % RESET will clear computed data results and reset flow stage
            % and step to start and stop at.
            if nargin < 2
                resetflag = true;
            end

            % Clears computed results while keeping input image
            obj.Outputs = cell(1, obj.nlayers);

            % Stage - start step, step - stop step
            obj.stage    = 1;
            obj.laststep = obj.nlayers;
            if resetflag
                % No preprocessing
                obj.SetImage(obj.Raw, []);
            end
        end


        function SetImage(obj, Image, TForm)
            % SETIMAGE will set the raw image as well as the input layer
            % data in the processing net (segmentation pipeline). 
            % Setting transformation function
            if nargin >=3
                obj.tform = TForm;
            else
                TForm     = [];
            end

            if nargin < 2
                % Will just reset the image
                if ~isempty(obj.RGB)
                    Image = obj.RGB;
                else
                    Image = obj.Raw;
                end
            end

            % Only sets when new image is passed in
            if ~obj.newimage
                obj.CheckForNewImage(Image)
            end

            if obj.newimage || ~isempty(TForm) || obj.ai
                % Will set the raw image and then either 
                obj.SetRaw(Image)
                Image = obj.PreprocessImage(obj.Raw);
                
                % If computation limited to ROI, taper is applied
                if ~isempty(obj.taper) || any(~obj.taper(:))
                    try
                        ogclass = class(Image);
                        Image   = MaskTaperImage(Image, obj.taper);
                        Image   = cast(Image, ogclass);
                    catch
                        obj.taper = [];
                        msg       = 'ROI Taper has been reset.';
                        disp(msg)
                    end
                end

                % Setting data in the input layer of the processing net
                obj.Outputs{1} = Image;
                [obj.mrows,...
                    obj.ncols] = size(obj.Outputs{1}, [1 2]);
                obj.stage      = 1;
                obj.newimage   = false;
            end

            % In case the user has the visualizer open
            if ~isempty(obj.EngineVisualizer) && isvalid(obj.EngineVisualizer.Figure)
                obj.UpdateEngineVisualizer
            end
        end


        %% Potentially private
        function SetRaw(obj, Image)
            % Will save the RGB image and perform a simple
            % luminance transform
            if size(Image, 3) == 3
                obj.isRGB = true;
                obj.RGB   = Image;
                % A simple lumincance transform is applied when user
                % has not set a color target, otherwise, a color
                % distance transform is applied
                if isempty(obj.RGBTarget)
                    obj.Raw = rgb2gray(Image);
                else
                    obj.Raw = obj.RGBTransform(Image);
                end
            else
                obj.isRGB = false;
                obj.Raw   = Image;
            end
        end


        function Image = PreprocessImage(obj, Image)
            Image = double(Image);

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % PREPROCESSING PIPELINE:
            % Squaring, log scaling, Inversion, Denoise, Transform, 
            % CNN (AI) feed forward, taper

            if obj.square
                Image = Image.^2;
            end
            
            if obj.logscale
                Image = log(Image+1);
            end

            if obj.inversion
                Image = max(Image(:)) - Image;
            end

            if obj.denoise && ~isempty(obj.denoisemethod)
                Image = obj.denoisemethod(Image);
            end

            % Transform function to be define by the user
            if ~isempty(obj.tform)
                Image = obj.tform(Image);
                disp('Image transformed')
            end

            % AI network and its custom function to feed forward are
            % applied as a preprocessing step
            if obj.ai
                % In case the flag is set before a network is loaded
                cf = gcbf;
                if ~isempty(cf)
                    % Extracts the app class instance to provide access
                    % to properties
                    appClass = cf.RunningAppInstance;
                    % Gets the progress dialog window to provide
                    % updates on processes
                    if isprop(appClass, 'progDlg')
                        pgdlg = appClass.progDlg;
                    else
                    end
                else
                    pgdlg = [];
                end
                if isempty(obj.NetworkFun)
                    obj.SetAINetwork([], pgdlg)
                    if ~isempty(pgdlg)
                        pgdlg.Message = 'Network Loading';
                    end
                end
                if ~isempty(obj.NetworkFun)
                    if ~isempty(pgdlg) && isvalid(pgdlg)
                        pgdlg.Message = 'Network processing data';
                    end
                    Image = obj.NetworkFun(Image, obj.Network);
                    % disp('Image preprocessed by CNN')
                else
                    obj.ai = false;
                end
            end
        end


        function changeflag = SetComputeMethodDlg(obj)
            % SETMETHODDLG will allow the user to change segmentation
            % methods by selecting from a list of available options
            f = gcbf;
            % Getting parametric method options
            PMList = obj.ParametricMethodNames;
            answer = myListDlg(PMList, 'Parametric Segmentation Method' ,'Set Segmentation Method', [], obj.method, f);
            if ~isempty(f)
                % Focuses figure if method launched from GUI
                figure(f)
            end

            % Returns a flag that confirms there was a change in method
            if isempty(answer) || strcmp(answer, obj.method)
                changeflag = false;
            else
                obj.SetComputeMethod(answer)
                changeflag = true;
            end
        end

        
        function SetParameters(obj, paramidx, field, value)
            % SETPARAMETERS assigns value to selected param and field
            % Fields: Name, Symbol, Bounds, Value

            if ~isnumeric(paramidx)
                % Access params by name
                idx      = ismember(obj.Params, paramidx);
                paramidx = find(idx);
            end

            % Machine epsilon as hard limit for non neg numbers
            if value > 0
                value = max(eps, value);
            end

            % Assignment and recomputation flag
            obj.Plugin.controls(paramidx).(field) = value;
            obj.SetComputeStart(paramidx)
            obj.CheckParamBounds
        end


        function SetComputeStop(obj, stopstep)
            % SETCOMPUTESTOP will set the step to stop computation at. This
            % value can only be set to layers that produce output of the
            % following datatypes: logical, integer, or double with a size
            % of Nx2

            % No change has occured - exit
            if stopstep == obj.laststep
                return
            end

            % initial bound check
            stopstep = min(stopstep, obj.nlayers);
            stopstep = max(1, stopstep);

            % Check if outputs are mask or label matrix data type
            imagedtypes = {'logical', 'uint8', 'uint16'};
            dtypes      = cellfun(@class, obj.Outputs, 'UniformOutput',false);
            dtypes      = cellfun(@(x) any(strcmp(x, imagedtypes)), dtypes, 'UniformOutput', false);
            dtypes      = [dtypes{:}];

            % Check if data output is a point cloud (2 column format)
            sizes    = cellfun(@size, obj.Outputs, 'UniformOutput', false);
            is2C     = cellfun(@(x) x(2) == 2, sizes, 'UniformOutput', false);
            isDouble = cellfun(@(x) isa(x, 'double'), obj.Outputs, 'UniformOutput', false);
            isPC     = [is2C{:}] & [isDouble{:}];

            % Steps the user is allowed to stop at
            Validsteps = dtypes | isPC;
            Validsteps = find(Validsteps) - 1;

            % Step is chosen as closest valid one
            [~, idx]     = min(abs(Validsteps-stopstep));
            chosenstep   = Validsteps(idx);
            obj.laststep = chosenstep;

            % Clearing old results
            % obj.ClearOldResults
        end


        function ClearOldResults(obj)
            % CLEAROLDRESULTS will clear the results from the outputs cell
            % array to ensure that old results do not accidentally show up
            % or get visualized. This ensures a refresh of new computations
            % once the user moves the laststep / stop step to be later in
            % the pipeline rather than holding onto old results for later
            % indices of the results array.

            % Need to think about a better way of doing this...
            % Current issue is that upon clearing the results, user cannot
            % call SetComputeSteps for later indices since empty cells will
            % lead to "invalid" indices that the user cannot select as
            % output

            if obj.laststep+1 > numel(obj.Outputs)
                return
            end

            % Empty the results for later indices
            for i = obj.laststep+2:numel(obj.Outputs)
                obj.Outputs{i} = [];
            end
        end


        function SetComputeStart(obj, paramN)
            % SETCOMPUTESTART will find the first layer whose input source
            % is the parameter whose value was changed. However, if the
            % stage was last set to a lower value because a new image was
            % loaded into the engine, this will force the engine to start
            % from the beginning. Otherwise, after a full computation, the
            % stage is set to Inf, so the flow index value will always be
            % less then obj.stage under normal circumstances.
            obj.stage = min(obj.Plugin.flow(paramN), obj.stage);
        end


        function stepidx = FindComputeStep(obj, idx)
            % FINDCOMPUTESTEP will find the first layer whose input source
            % is the parameter index passed into the function. It also
            % checks to see if this value is 
            try
                stepidx = obj.Plugin.flow(idx);
            catch
                error('Index is greater than number of available pipeline steps.')
            end
        end

        function paststop = StepPastStop(obj, idx)
            % STEPPASTSTOP will determine if a parameter index corresponds
            % to a pipeline step that is beyond the pipeline stopping index
            % (last step) which is the last step where computation will
            % take place. This is always less than or equal to the number
            % of layers since the user can always modify where they want to
            % stop at in the pipeline.
            stepidx  = obj.FindComputeStep(idx);
            paststop = stepidx > obj.laststep;
        end


        function Vec2Params(obj, pVec)
            % Will assign a nPars (nLayers - 1) long vector to the
            % parameters
            for i = 1:numel(pVec)
                obj.SetParameters(i, 'Value', pVec(i))
            end
        end

        
        function paramvals = Params2Vec(obj)
            % PARAMS2VEC will parse out the parameter values from the
            % plugin struct and return them in a vector format.
            nparams   = numel(obj.Plugin.controls);
            paramvals = zeros(nparams, 1);
            for p = 1:nparams
                paramvals(p) = obj.Plugin.controls(p).Value;
            end
        end

        
        function AutoParams(obj)
            % Will automatically estimate appropriate parameter values and
            % assign them
            if ~isfield(obj.Plugin, 'AutoParams')
                return
            end
            if isa(obj.Plugin.AutoParams ,'function_handle')
                ParamVec = obj.Plugin.AutoParams(obj.Outputs{1});
            elseif isnumeric(obj.Plugin.AutoParams)
                ParamVec = obj.Plugin.AutoParams;
            end
            Vec2Params(obj, ParamVec)
        end


        function Compute(obj)
            % Parameter values as cell array
            params = {obj.Plugin.controls.Value};

            % Starts computation from first step where the 
            for i = obj.stage:obj.laststep
                % Compute loop improves efficiency by avoiding
                % recomputation of steps where a parameter did not change
                obj.Outputs{i+1} = obj.Plugin.Layers(i).Forward(obj.Outputs, params);
            end

            % Post processing:
            % Active contours...
            obj.PostProcess

            % Reset compute flags
            obj.stage = inf;
        end


        function PostProcess(obj)
            % POSTPROCESS will be the method call made to alter the
            % pipeline output or refine it in a semi-automated and modular
            % fashion. This function definition serves to be a mirror to
            % the PreProcessImage function in that it can further be
            % developed to have an arbitrary number of steps that use
            % either static methods or external functions 
            if obj.snakes
                % Active Contours - aka snakes
                obj.Outputs{end} = ActiveContourSnakes(obj.Outputs{1}, ...
                                                       obj.Outputs{obj.laststep+1}, ...
                                                       obj.snakesconfig.iterations, ...
                                                       obj.snakesconfig.smoothness, ...
                                                       obj.snakesconfig.factor, ...
                                                       obj.snakesconfig.contractionBias);
            end
        end


        function DetermineResultType(obj)
            % DETERMINERESULTTYPE is only used when a method does not
            % change the value of the result type. When new methods are
            % loaded in, the previous type is cleared. This method will
            % determine what the datatype is based off of data shape
            D = obj.Outputs{obj.laststep+1};
            if isempty(D)
                obj.Compute
                D = obj.Outputs{obj.laststep+1};
            end

            % When data is empty, returns empty
            if isempty(D)
                RType = '';

            else
                c = size(D, 2);
                if c == 2
                    % Compares the first and last coordinate values. a closed
                    % curve / contour would have the first and last point
                    % represented by the same coordinates
                    if all(D(1,:) == D(end,:))
                        RType = 'contour';
                    else
                        RType = 'pointcloud';
                    end
                elseif c > 2
                    if islogical(D)
                        RType = 'mask';
                    elseif isa(D, 'uint8') || isa(D, 'uint16')
                        RType = 'label';
                    end
                else
                    RType = '';
                end

            end

            % Setting the results type
            obj.resulttype = RType;
        end


        function Mask = GetMask(obj)
            % GETMASK will check to see if the segmentation results are a
            % point cloud or mask to determine how to produce/return a mask
            SegData  = obj.Plugin.Layers(end).Data;
            if isempty(SegData)
                Mask = zeros(obj.mrows, obj.ncols);
            elseif size(SegData, 2) == 2
                Mask = poly2mask(SegData(:,1), SegData(:,2), obj.mrows, obj.ncols);
            else
                Mask = SegData;
            end
        end


        function Points = Mask2Points(obj, Msk)
            % MASK2POINTS converts a mask to point based on an alpha shapes
            % computation

            if nargin < 2 || isempty(Msk)
                Msk = obj.Mask;
            end

            % Depending on the number of connected components, the
            % algorithm for finding the boundary will change. One will
            % follow the boundary exactly, and the other will consolidate
            % the masked areas as one region
            CC          = bwconncomp(Msk);
            NComponents = CC.NumObjects;
            AlphaFlag   = NComponents > 1;

            % Alpha flag will determine whether alpha shape will compute or
            % exact pixel boundary will be found
            if AlphaFlag
                Msk   = padarray(Msk, [3 3], 0, 'both');
                s      = [0 1 0; 1 1 1; 0 1 0];
                bd     = imerode(Msk, s) ~= Msk;
                bd     = bd(4:end-3, 4:end-3);
                bd     = imdilate(bd, ones(3));
                [y, x] = find(bd);
                if ~isempty(x)
                    p = uniquetol([x(:) y(:)], sqrt(2)+eps, 'ByRows', true, 'DataScale', 1);
                    x = p(:, 1);
                    y = p(:, 2);
                    b = boundary(x, y, 0.9);
                    x = x(b);
                    y = y(b);
                    Points = [x y];
                    % Was originally writing the lines below to take care of
                    % the issue with alpha shapes since it seems that even with
                    % the above boundary adjustments, it would end up cutting a
                    % portion out of the boundary somehow
    %                 [Rows, Cols] = size(bd, [1 2]);
    %                 Msk          = poly2mask(x, y, Rows, Cols);
    %                 Msk          = imclose(Msk, ones(5));
    %                 Msk          = imfill(Msk, 'holes');
    %                 B            =
                else
                    Points = [];
                end
            else
                B      = bwboundaries(Msk);
                if ~isempty(B)
                    P      = B{1};
                    Points = [P(:,2) P(:,1)];
                else
                    Points = [];
                end
            end
        end


        function SaveDataChanges(obj, newData)
            % SAVEDATACHANGES allows user to alter the data from 
            obj.Plugin.Layers(obj.laststep).Data = newData;
        end


        function CheckParamBounds(obj)
            % CHECKPARAMBOUNDS will ensure values being set for a parameter
            % are valid or force the parameter to be an acceptable value
            % within the bounds of the specified range
            for i = 1:numel(obj.Plugin.controls)
                minv                       = obj.Plugin.controls(i).Min;
                maxv                       = obj.Plugin.controls(i).Max;
                value                      = min(maxv, obj.Plugin.controls(i).Value);
                value                      = max(minv, value);
                obj.Plugin.controls(i).Value = value;
            end
        end


        function SetComputeMethod(obj, methodName)
            % Allows user to change the parametric method being implemented
            % in the GUI. This method will parse the name out from the
            % string input argument. 

            % In case the method name comes in as string
            if isstring(methodName)
                methodName = char(methodName);
            end

            % Method name is adjusted to not have spaces in name for proper
            % evaluation
            obj.method = methodName;
            methodName = AddRmStrSpace(methodName, false);

            % Set the method and parse settings
            obj.Plugin = feval(['Plugin_' methodName]);
            obj.UpdatePluginConfig

            % Recomputation will occur from the start
            obj.newimage = true;

            % Clears results and resets the first image
            obj.Reset(true)

            % If the engine visualizer is open, it will be launched
            if ~isempty(obj.EngineVisualizer) && isvalid(obj.EngineVisualizer.Figure)
                obj.Compute
                obj.PlotPluginSteps
            end
        end


        function CheckForNewImage(obj, Im)
            % CheckForNewImage will set NewImFlag true if a new file has 
            % been loaded in or false if the image is the same. This will
            % determine if computation needs to restart or not
            if (size(Im, 1) == size(obj.Raw, 1)) && (size(Im, 2) == size(obj.Raw, 2))
                Eq          = Im ~= obj.Raw;
                obj.newimage = any(Eq, 'all');
            else
                % Different size immediately suggests a new image
                obj.newimage = true;
            end

            if obj.newimage
                obj.RGB = [];
            end
        end


        function SetAINetwork(obj, choice, dlg)
            % Gets figure handle if launched from one
            f = gcbf;
            % UI Progress dialog box
            if nargin < 3 || isempty(dlg)
                dlg.CancelRequested = false;
            end

            % If there is a progress dialog box, its text is updated
            if ~isempty(dlg)
                dlg.Message = 'Selecting Network';
            end

            if nargin < 2 || isempty(choice)
                % Getting the user's choice of network / AI method for
                % preprocessing of data
                List        = obj.ParseAvailableAIMethods;
                List{end+1} = 'None';
                % Default network
                if any(strcmp(List, 'Resnet18_DeepLabV3PlusCNN'))
                    InitChoice = 'Resnet18_DeepLabV3PlusCNN';
                    choice  = myListDlg(List, 'AI Preprocessing', 'Select AI method for image preprocessing', [], InitChoice, f);
                else
                    choice  = myListDlg(List, 'AI Preprocessing','Select AI method for image preprocessing', [], [], f);
                end

                % Keeps GUI atop if engine method called within GUI
                if ~isempty(f)
                    figure(f)
                end
            end

            % Gives user time to cancel in case they don't want AI
            % processing
            if dlg.CancelRequested
                return
            else
                if ~isempty(choice) && ~strcmp(choice, 'None')
                    % If there is a progress dialog box, its text is updated
                    if ~isempty(dlg)
                        dlg.Message = 'Network loading...';
                    end
                    % Enables preprocessing by the AI method (e.g. CNN)
                    [obj.Network, obj.NetworkFun] = obj.GetAIMethod(choice);
                    % In case user cancels processing
                    if ~dlg.CancelRequested
                        obj.TurnOnAI
                    else
                        obj.ai = false;
                    end
                elseif strcmp(choice, 'None')
                    % If there is a progress dialog box, its text is updated
                    if ~isempty(dlg)
                        dlg.Message = 'Unloading network...';
                    end
                    % Network will be unloaded when none is selected
                    obj.Network    = [];
                    obj.NetworkFun = [];
                    obj.TurnOffAI
                    obj.Compute
                else
                    obj.TurnOffAI
                    obj.Compute
                end
            end
        end


        function TurnOffAI(obj, cflag)
            % Will not preprocess the image with AI while still keeping the
            % network loaded if one was loaded into the engine
            if nargin < 2
                % By default, assumes the user does not need to recompute
                cflag = false;
            end
            obj.ai   = false;
            obj.newimage   = true;
            obj.SetImage
            obj.stage(1) = 1;

            % Will not always recompute...helpful in cases where an image
            % has been computed on in a GUI
            if cflag
                obj.Compute
            end
        end


        function TurnOnAI(obj, cflag)
            % Will keep the AI on and process the current image so that
            % future images that are loaded also end up getting processed
            % with the AI network
            if nargin < 2
                % By default, assumes user wants the AI to preprocess the
                % data
                cflag = true;
            end

            if ~isempty(obj.Network)
                % If network is already loaded, computation takes place
                obj.ai             = true;
                if ~isempty(obj.Raw)
                    % Setting the image over again ensures all
                    % preprocessing steps occur in proper order
                    obj.newimage   = true;
                    obj.SetImage
                    obj.stage(1) = 1;
                    % Will not always recompute...helpful in cases where an image
                    % has been computed on in a GUI
                    if cflag
                        obj.Compute
                    end
                end
            else
                % User is asked to select one of the available networks
                obj.SetAINetwork
            end
        end


        function SetDenoiseFunc(obj, flag)
            % SETDENOISEFUNC will set the denoising function selected from
            % a list of available methods.
            if flag
                % Check all files in the folder:
                % ...\EngineDependencies\DenoisingMethods\...
                fid               = mfilename('fullpath');
                folder            = fileparts(fid);
                folder            = [folder filesep 'EngineDependencies' filesep 'DenoisingMethods'];
                % Parsing out the denoising method name so it shows up
                % selected in the list dialog box
                if ~isempty(obj.denoisemethod)
                    MethodName = char(obj.denoisemethod);
                    MethodName = AddRmStrSpace(MethodName, true);
                else
                    MethodName = [];
                end
                MethodName = SelectFunctionFromFolder(folder, 'Select Denoising Function', true, MethodName);
                if isempty(MethodName)
                    return
                elseif isa(MethodName, 'function_handle')
                    % Do nothing
                elseif isnan(MethodName)
                    % In case user selects none, the method is emptied
                    % (i.e. set to none)
                    MethodName = [];
                end
                obj.denoisemethod = MethodName;
            else
                obj.denoisemethod = [];
            end
        end


        function SetComputeROI(obj, TFlag)
            % SETCOMPUTEROI 

            % In case an RGB image is loaded into engine
            if obj.isRGB
                im = obj.RGB;
            else
                im = obj.Raw;
            end

            % Transpose flag
            if nargin < 2
                TFlag = false;
            end
            if TFlag
                im = pagetranspose(im);
            end

            % Assumes that if the previous taper was too large for the
            % current image, a new taper needs to be defined
            if ~isempty(obj.TPoints)
                if max(obj.TPoints(:,1)) > obj.mrows || max(obj.TPoints(:,2)) > obj.ncols
                    obj.TPoints = [];
                end
            end
            Position = Seg_BoundaryTool(im, obj.TPoints);

            if all(Position(1,:) == [1 1]) && all(Position(3, :) == [obj.ncols obj.mrows])
                obj.TPoints = [];
                obj.taper       = [];
                disp('ROI Taper has been reset.')
                return
            end

            % Checks for changes
            if size(obj.TPoints,1) ~= size(Position, 1) || any(obj.TPoints-Position, 'all')
                % Transpose flag
                if TFlag
                    P = [Position(:,2) Position(:,1)];
                else
                    P = Position;
                end
            else
                return
            end

            % Converting contour to mask and interpolating to edge
            r            = 1;
            x            = -r:r;
            x            = (x.^2);
            h            = (x+x')<=r;
            ROImask      = poly2mask(P(:,1), P(:,2), obj.mrows, obj.ncols);
            ROImask      = imdilate(ROImask, h);
            obj.taper    = ROImask;
            obj.TPoints  = P;
            obj.newimage = true;
            obj.SetImage
        end

        function ResetTaperROI(obj)
            obj.taper = [];
        end


        function f = ChooseRGBTarget(obj, r)
            if isempty(obj.RGB)
                % If there is no RGB image, this function will exit
                return
            else
                I = obj.RGB;
            end
        
            if nargin < 2
                % Sets up a neighborhood around a target pixel
                r = 5;
            end

            % Marker size
            MSize = 8*(72/get(0, 'ScreenPixelsPerInch'));
        
            if numel(r) == 1
                r = -r:r;
            end

        
            % If user does not give a target RGB value, the user will be asked
            % to click on a pixel
            if ~isempty(obj.RGBTarget)
                f  = uifigure("Name", 'Select Target Color', 'Units', 'normalized', 'Position', [0.1 0.1 0.8 0.8], 'WindowButtonMotionFcn', @UpdatePlots);
            else
                f  = uifigure("Name", 'Select Target Color', 'Units', 'normalized', 'Position', [0.1 0.1 0.8 0.8]);
            end
        
            % Buttons for GUI
            IconFolder   = []; %['GUIRelated' filesep 'SVGIcons' filesep];
            ToolBar      = uitoolbar('Parent', f);
            Btn1         = uipushtool(ToolBar);
            Btn2         = uipushtool(ToolBar);
            Btn3         = uipushtool(ToolBar);
            Btn4         = uipushtool(ToolBar);

            % Vector graphic icons
            f.Icon       = [IconFolder 'color-picker.png'];
            Btn1.Icon    = [IconFolder 'accept.svg'];
            Btn2.Icon    = [IconFolder 'cancel.svg'];
            Btn3.Icon    = [IconFolder 'restart.svg'];
            Btn4.Icon    = [IconFolder 'gray-filter.svg'];

            % Tooltips
            Btn1.Tooltip         = 'Done';
            Btn2.Tooltip         = 'Cancel';
            Btn3.Tooltip         = 'Clear';
            Btn4.Tooltip         = 'Grayscale Luminance Transform';

            % Callbacks
            Btn1.ClickedCallback = @ConfirmSelection;
            Btn2.ClickedCallback = @CancelSelection;
            Btn3.ClickedCallback = @ClearSelection;
            Btn4.ClickedCallback = @GrayScale;
        
            % If there is a color selected, it will be plotted next to the
            % image, otherwise, only the image is plotted and the user is
            % updated as a new color is selected
        
            % Initialization of confirmation flag and new color
            NewRGB = [];
            ax2    = [];
            ax3    = [];
            p      = [];
        
            % Plots the old color target next to the image
            if ~isempty(obj.RGBTarget)
                NewRGB = obj.RGBTarget; 
                % Image plot
                t  = tiledlayout(1,3, "TileSpacing","compact", "Padding","compact", "Parent", f);
                ax = nexttile(t, 1);
                iH = imagesc(ax, I); %#ok<NASGU>
                ax.YTick    = [];
                ax.XTick    = [];
                ax.XColor   = 'none';
                ax.YColor   = 'none';
                axis(ax, 'image')
                title(ax, 'Original Image')
                % Initializing a plot of the selected neighborhood - updates as
                % mouse moves
                % Average Color of target region
                T = repmat(uint8(obj.RGBTarget), [11 11 1]);
                ax2 = nexttile(t, 2);
                Z   = zeros(11, 11, 3, class(I));
                iH2 = imagesc(ax2, [Z; T]);
                ax2.YTick    = [];
                ax2.XTick    = [];
                ax2.XColor   = 'none';
                ax2.YColor   = 'none';
                axis(ax2, 'image')
                title(ax2, 'Selected Neighborhood and Color')
        
                
        
                % Transformed image visualization
                Theta = obj.RGBTransform(obj.RGB);
                ax3   = nexttile(t, 3);
                iH3   = imagesc(ax3, Theta);
                axis(ax3, 'image')
                colormap(ax3, bone)
                title(ax3, 'Transformed Image')
                ax3.YTick    = [];
                ax3.XTick    = [];
                ax3.XColor   = 'none';
                ax3.YColor   = 'none';
            else
                % Image plot
                t = tiledlayout(1,1, "TileSpacing","compact", "Padding","compact", "Parent", f);
                ax = nexttile(t, 1);
                iH = imagesc(ax, I); %#ok<NASGU>
                axis(ax, 'image')
                title(ax, 'Original Image')
                ax.YTick    = [];
                ax.XTick    = [];
                ax.XColor   = 'none';
                ax.YColor   = 'none';
            end
        
            
            % User prompted to draw a point
            p      = drawpoint("Parent", ax, 'MarkerSize', MSize);
            try
                addlistener(p,'MovingROI', @UpdatePlots);
            catch
                return
            end
            % Eliminate mouse move function once point drawn - no need to preview
            % anymore based off of mouse movement unless point is moved
            if ~isempty(f.WindowButtonMotionFcn)
                set(f, 'WindowButtonMotionFcn', [])
            end
            % Extract
            if ~isempty(p) && isvalid(p)
                pos    = p.Position;
            else
                return
            end
        
            % Getting the neighborhood of pixels around selected point
            [Target, C]   = GetNeighborhoodAndColor(pos);
            NewRGB        = C(1,1,:);
            obj.RGBTarget = NewRGB;
            
            % Reorganizing the plots to fit all 3 when they are not already created
            if isempty(ax2)
                % Deleted original plot to adjust tile layout
                ax.delete
                t.GridSize = [1 3];
                ax         = nexttile(t, 1);
                imagesc(ax, I)
                axis(ax, 'image')
                title(ax, 'Original Image')
                ax.YTick    = [];
                ax.XTick    = [];
                ax.XColor   = 'none';
                ax.YColor   = 'none';
                % Creating next tiles for neighborhood and color plots
                ax2 = nexttile(t, 2);
                ax3 = nexttile(t, 3);
                p   = [];
            end
        
            % Plotting selected neighborhood and target color
            iH2 = imagesc(ax2, [Target; C]);
            axis(ax2, 'image')
            title(ax2, 'Selected Neighborhood and Color')
            ax2.YTick    = [];
            ax2.XTick    = [];
            ax2.XColor   = 'none';
            ax2.YColor   = 'none';
            
            % Target color visualization
            Theta = obj.RGBTransform(obj.RGB);
            iH3   = imagesc(ax3, Theta);
            axis(ax3, 'image')
            colormap(ax3, bone)
            title(ax3, 'Transformed Image')
            ax3.YTick    = [];
            ax3.XTick    = [];
            ax3.XColor   = 'none';
            ax3.YColor   = 'none';
        
            if isempty(p)
                % Plotting the point where user specified
                p = images.roi.Point('Parent', ax, 'Position', pos, 'MarkerSize', MSize);
                addlistener(p,'MovingROI',@UpdatePlots);
            end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Functions for the color selection GUI
            function UpdatePlots(src, ~)
                if isa(src, 'matlab.ui.Figure')
                    coord = get(ax, 'CurrentPoint');
                    coord = [coord(1,1) coord(1,2)];
                else
                    coord = src.Position;
                end
                % Ensures the neighborhood and color updates cannot happen
                % until the user is inside the axes object
                if any(coord<0) || any(coord>[obj.ncols obj.mrows])
                    return
                end
                [NHood, Color] = GetNeighborhoodAndColor(coord);
                NewRGB         = Color(1,1,:);
                obj.RGBTarget  =  NewRGB;
                iH2.CData      = [NHood; Color];
                iH3.CData      = obj.RGBTransform(obj.RGB);
            end
        
            function ConfirmSelection(~, ~)
                focus(f)
                % In case user wants to "confirm" no change in color since they
                % left the selection empty
                obj.RGBTarget =  NewRGB;
                f.delete
    
                % Will trigger the setting of the image
                obj.newimage = true;
                obj.SetImage
            end

            function CancelSelection(~, ~)
                focus(f)
                % Delete the figure
                f.delete
            end
        
            function ClearSelection(~, ~)
                % User prompted to draw a point
                focus(f)
                if ~isempty(p) && isvalid(p) 
                    p.delete
                end
                f.WindowButtonMotionFcn = @UpdatePlots;
                p = drawpoint('Parent', ax, 'MarkerSize', MSize);
                try
                    f.WindowButtonMotionFcn = [];
                    addlistener(p,'MovingROI',@UpdatePlots);
                catch
                end
            end
        
            function GrayScale(~, ~)
                % Will clear the RGB value and cause the image to be
                % transformed from RGB to grayscale with a simple luminance
                % transform since the RGB target will be empty
                NewRGB = [];
                ConfirmSelection
            end
        
            function [Target, NewRGB] = GetNeighborhoodAndColor(coord)
                % Creating neighborhood around point
                x      = coord(1);
                y      = coord(2);
                x      = round(x);
                y      = round(y);
                x      = r + x;
                y      = r + y;
                x      = max(1, x);
                % Bound checking neighborhood
                x      = min(x, obj.ncols);
                y      = max(1, y);
                y      = min(y, obj.mrows);
                x      = unique(x);
                y      = unique(y);
                % Pulling out target region
                Target = I(y, x,:);
        
                % Average Color of target region
                NewRGB = mean(Target, [1 2]);
                NewRGB = repmat(uint8(NewRGB), [size(Target, [1 2]) 1]);
            end
        end


        function Theta = RGBTransform(obj, Image)
            % Ensuring proper data type
            if nargin < 2
                I   = double(obj.RGB) + 1;
            else
                I   = double(Image) + 1;
            end
            Target  = double(obj.RGBTarget) + 1;
        
            % Magnitudes
            mI      = dot(I, I, 3);
            mTarget = dot(Target, Target);
            Mag     = max(mI*mTarget, 1);
            Mag     = sqrt(Mag);
        
            % Dot product between image values and target value
            Target  = reshape(Target, [1 1 3]);
            Target  = repmat(Target, size(I, [1 2]));
            dRGB    = dot(I, Target, 3);
            dRGB    = dRGB./Mag;                     % Eliminating magnitude
            dRGB    = max(dRGB, 0);                  % Overflow issues have previously occured leading to complex numbers
            dRGB    = min(dRGB, 1);                  % Clipping prevents issues from overflow if any
            Theta   = acosd(dRGB);                   % Angle from target
            Theta   = max(Theta(:))-Theta;           % Target objects are brighter
        end


        function ResetRGB(obj)
            % Resets the RGB image as the raw image with a simple luminance
            % transform rather than a color distance transform
            obj.Raw              = rgb2gray(obj.RGB);
            obj.Plugin.Layers(1).Data = obj.Raw;
            obj.Reset(true)
        end

        function InitializeEVPlotLinkage(obj)
            % INITIALIZEEVPLOTLINKAGE will initialize the linking of
            % various properties between the plots inside the engine
            % visualizer to ensure that as the user is moving around in one
            % image, the other views also update in response.
            linkprop(obj.EngineVisualizer.Axes, ...
                {'Clipping', ...
                'XLimMode', 'YLimMode', ...
                'XLimitMethod', 'YLimitMethod', ...
                'XLim', 'YLim'});
        end



        function PlotPluginSteps(obj, cmap, linecolor, linewidth, darkMode)
            % PLOTPLUGINSTEPS will plot all steps of computation from the
            % first step up through the step property of the engine class
            % which indicates the last desired step of the plugin workflow.

            if ~isempty(obj.EngineVisualizer)
                obj.EngineVisualizer.Figure(1).delete
                obj.EngineVisualizer = [];
            end

            % Default Visualization Settings
            if nargin < 5
                % Whether to use a dark or light color theme
                darkMode = false;
            end
            if nargin < 4
                % Thickness of contour plot line
                linewidth = 2;
            end
            if nargin < 3 || isempty(linecolor)
                % Color for contour plot of segmented ROI
                linecolor = [1 1 1];
            end
            if nargin < 2 || isempty(cmap)
                % Image colormap
                cmap = bone;
            elseif ischar(cmap) || isstring(cmap)
                % Function evaluation of colormap
                cmap = feval(cmap);
            end

            % init marker width for Pointclouds
            markerwidth = 16;


            if nargin == 1
                % Checking for a valid segmentation GUI
                flist     = findall(groot, 'Type', 'figure');
                nFigs     = numel(flist);
                for i = 1:nFigs
                    fH = flist(i);
                    % If there is no app class behind the figure, continue
                    % to check next figure
                    if ~isprop(fH, 'RunningAppInstance')
                        continue
                    end

                    % Grabs settings from segmentation GUI if available to
                    % ensure visualization consistency
                    if isa(fH.RunningAppInstance, 'ROISegmentationGUI')          % this will have to all change drastically
                        app         = fH.RunningAppInstance;
                        cmap        = app.Visengine.cmap{1};
                        linecolor   = app.Visengine.color;
                        linewidth   = app.Visengine.linewidth;
                        markerwidth = app.Visengine.markerwidth;
                        darkMode    = app.DarkMode.State;
                        if isstring(cmap) || ischar(cmap)
                            cmap = feval(cmap);
                        end
                    end
                end
            end

            % Font name for labels and titles
            FName = 'Century Gothic';

            % Colorscheme
            if darkMode
                BColor = [0.15 0.15 0.15];
                FColor = [1 1 1];
            else
                BColor = [1 1 1];
                FColor = [0 0 0];
            end
        
            % In case there is an issue with colormap evaluation
            if isempty(cmap)
                cmap = bone;
            end
        
            % Midpoint of colormap
            mp = size(cmap, 1)/2;
            mp = round(mp);
        
            % Unpacking data
            Results = obj.Outputs;
            if isfield(obj.Plugin.Layers, 'DataName')
                DataNames = {obj.Plugin.Layers.DataName};
            else
                DataNames = cell(numel(obj.Plugin.Layers), 1);
            end
        
            % Grabbing the original image to be plotted first
            if ~isempty(obj.RGB)
                Im = obj.RGB;
            else
                Im = obj.Raw;
            end

            % Size information needed to plot point clouds / contours atop
            % blank background with appropriate x and y limits
            sz = size(Im, [1 2]);
            xL = [1 sz(2)];
            yL = [1 sz(1)];
        
            % Points data to be plotted on the raw image
            if ~isempty(Results{end})
                Points = Results{end};
            else
                Points = [];
            end
            
            % Figure with reflow allowed to allow plots to move when figure
            % is resized
            fig = uifigure('Units','normalized',...
                           'Position', [0.1 0.01 0.8 0.8],...
                           'Name', 'Processing Steps',...
                           'Color', BColor ,'CloseRequestFcn', @obj.CloseVisualizer);
            t   = tiledlayout('flow', 'Padding', 'compact', 'Parent', fig);
        
        
            % Engine Visualizer struct with properties
            obj.EngineVisualizer.Figure  = fig;
            obj.EngineVisualizer.cmap    = cmap;
            obj.EngineVisualizer.Contour = [];
        
            % Will create a subplot for each compute step
            for i = 1:obj.laststep+1
                % New subplot per each layer's data
                ax = nexttile(t);
                obj.EngineVisualizer.Axes(i) = ax;

                if i < obj.nlayers+1
                    % Sets background as first color from colormap
                    bckgrnd   = cmap(1,:);
                    if size(Results{i}, 2) > 2
                        % When data is a filtered image, display the image
                        obj.EngineVisualizer.Plots(i) = imagesc(ax, Results{i});
                        colormap(ax, cmap)
                        colorbar(ax, 'southoutside', 'FontSize', 14, 'Color', FColor)

                    elseif size(Results{i}, 2) == 2
                        % When data is a point cloud, create a scatter plot
                        mclr      = cmap(mp,:);
                        x         = Results{i}(:, 1);
                        y         = Results{i}(:, 2);
                        I_blank   = zeros(yL(2), xL(2), 'logical');
                        imagesc(ax, I_blank)                        % plotting a blank image to ensure points plot in image coordinates
                        colormap(ax, cmap)
                        hold(ax, 'on')
                        obj.EngineVisualizer.Plots(i) = scatter(ax, x, y, 'MarkerEdgeColor', mclr);
                        colorbar(ax, 'southoutside', 'FontSize', 14, 'Visible','off')

                    end

                else
                    % Raw image and points for the final subplot
                    obj.EngineVisualizer.Plots(i) = imagesc(ax, Im);
                    axis(ax, 'image')
                    colormap(ax, cmap)
                    colorbar(ax, 'southoutside', 'Visible','off')

                end
                
                % Titles and relevant param info
                if i == 1
                    % Image input layer
                    if obj.ai
                        name = 'Auxiliary Image (w/AI)';
                        % Consider adding information regarding network here
                        xlabel(ax, [' ' newline, ' '], 'FontSize', 12, 'Color', FColor) % ensures proper spacing in layout

                    else
                        name = 'Auxiliary Image';
                        xlabel(ax, [' ' newline, ' '], 'FontSize', 12, 'Color', FColor) % ensures proper spacing in layout

                    end
                    title(ax, name, 'FontSize', 14, 'FontName', FName, 'Color', FColor)

                elseif i > 1 && i < obj.nlayers+1
                    % Computational layer outputs
                    name = ['Layer ' num2str(i-1) ' Output: ' DataNames{i}];
                    title(ax, name, 'FontSize', 14, 'FontName', FName, 'Color', FColor)
                    % try
                        pmsg = obj.Plugin.Layers(i-1).Process;
                    % catch
                    %     pmsg = '';
                    % end
                    ParameterLabel(i-1)

                else
                    % Final layer / result
                    if ~isempty(Points)
                        % Result from final layer - checks if they are a
                        % point cloud or mask...then if PC, can either be a
                        % closed curve (contour) or a PC
                        hold(ax)
                        [r, c] = size(Points, [1 2]);
                        
                        if c == 2
                            if all(Points(1,:) == Points(end,:)) && r > 1
                                obj.EngineVisualizer.Contour = plot(ax, Points(:,1), Points(:,2), 'Color', linecolor, 'LineWidth', linewidth);
                            elseif all(Points(1,:) ~= Points(end,:))
                                obj.EngineVisualizer.Contour = plot(ax, Points(:,1), Points(:,2), 'Color', linecolor,...
                                                                    'LineStyle', 'none', 'Marker','.', 'LineWidth', linewidth, 'MarkerSize', markerwidth);
                            end
                        else
                            % Mask plotting?? or Other plots to consider??
                        end

                    end

                    % Title for figure
                    name = 'Segmentation Result';
                    title(ax, name, 'FontSize', 14, 'FontName', FName, 'Color', FColor)
                    % try
                        pmsg = obj.Plugin.Layers(i-1).Process;
                    % catch
                    %     pmsg = '';
                    % end
                    ParameterLabel(i-1)

                end

                % Axes limits, color, deletes axes outline
                axis(ax, 'equal')
                ax.Color           = bckgrnd;
                ax.XLim            = xL;
                ax.YLim            = yL;
                ax.Toolbar.Visible = 'off';
                ax.Clipping        = 'on';
        
                % Removing tick marks
                ax.XTick = [];
                ax.YTick = [];

                % Font is same as in the GUI for consistent look
                ax.FontName = FName;
            end
            
            % Title with proper spacing and method information
            Title_msg = ['Engine Processing Steps - Segmentation Method: ' obj.method newline];
            title(t, Title_msg, 'FontSize', 20, 'FontName', FName, 'Color', FColor)

            % Ensuring the axes all link
            obj.InitializeEVPlotLinkage
        
            function ParameterLabel(i)
                % Getting parameter index values for a layer
                In_idx     = find(obj.Plugin.Layers(i).In);
                if ~isempty(In_idx)
                    % In case parameter(s) used to get data for the layer - will
                    % add label w/ names and indices of parameters used
                    P_names = {obj.Plugin.controls(In_idx).Name};
                    P_names = strjoin(P_names, ', ');
                    if numel(In_idx) > 1
                        P_nums  = num2cell(In_idx);
                        P_nums  = strjoin(string(P_nums), ', ');
                        P_nums  = char(P_nums);
                    else
                        P_nums  = num2str(In_idx);
                    end
                    pmsg = ['Param(s) ' P_nums ': ' P_names newline pmsg];
                    disp(pmsg)
                else
                    pmsg = [pmsg newline];
                end
                xlabel(ax, pmsg, 'FontSize', 12, 'Color', FColor)
            end
        end
        

        function UpdateEngineVisualizer(obj)
            % UPDATEENGINEVISUALIZER will update the engine visualizer if 
            % it is open
            if isempty(obj.EngineVisualizer)
                return
            end

            % Determines if image data changed
            OldSz  = size(obj.EngineVisualizer.Plots(1).CData);
            NewSz  = size(obj.Outputs{1});
            diffSz = (ndims(OldSz) ~= ndims(NewSz)) || any(OldSz ~= NewSz);
            
            if ~isempty(obj.EngineVisualizer) && isvalid(obj.EngineVisualizer.Figure)
                for i = 1:obj.laststep + 1

                    if i == 1
                        % Always plots the auxiliary image first
                        Img = obj.Outputs{1};
                        obj.EngineVisualizer.Plots(i).CData = Img;

                    elseif (1 < i) && (i < obj.nlayers + 1)
                        Results = obj.Outputs{i};
                        % In case data has points instead of image
                        if size(Results, 2) > 2
                            obj.EngineVisualizer.Plots(i).CData = Results;
                        else
                            if ~isempty(Results)
                                obj.EngineVisualizer.Plots(i).XData = Results(:,1);
                                obj.EngineVisualizer.Plots(i).YData = Results(:,2);
                            end
                        end
                        % Ensures speed up of visualization and slow down
                        % only upon a size change (i.e. crop, diff image,
                        % etc. is loaded)
                        if diffSz
                            axis(obj.EngineVisualizer.Axes(i), 'equal')
                        end
                    else
                        % Determines whether to plot a grayscale or RGB
                        % image
                        if obj.isRGB
                            Img = obj.RGB;
                        else
                            Img = obj.Raw;
                        end

                        % Plots the 
                        try
                            obj.EngineVisualizer.Plots(i).CData = Img;
                        catch
                            obj.EngineVisualizer.Figure.delete
                            obj.EngineVisualizer = [];
                            return
                        end
                    end
                end


                % Updating the latest contour as well in the last plot
                Results = obj.Outputs{end};
                if ~isempty(Results)
                    obj.EngineVisualizer.Contour.XData = Results(:,1);
                    obj.EngineVisualizer.Contour.YData = Results(:,2);
                else
                    obj.EngineVisualizer.Contour.XData = [];
                    obj.EngineVisualizer.Contour.YData = [];
                end

                % Ensuring the axes all link
                obj.InitializeEVPlotLinkage

            else
                obj.EngineVisualizer = [];
            end
        end


        function UpdateEngineVisualizerColors(obj)
            % In the case where a segmentation GUI might be available,
            % will grab the graphics settings from that
            flist     = findall(groot, 'Type', 'figure');
            nFigs     = numel(flist);
            app       = [];
            for i = 1:nFigs
                fH = flist(i);
                % If there is no app class behind the figure, continue
                % to check next figure
                if ~isprop(fH, 'RunningAppInstance')
                    continue
                end

                % If it is a segmentation GUI, we can grab graphics
                % settings from it
                if isa(fH.RunningAppInstance, 'ROISegmentationGUI')
                    app         = fH.RunningAppInstance;
                    cmap        = app.UIAxes.Colormap;
                    linecolor   = app.Visengine.color;
                    linewidth   = app.Visengine.linewidth;
                    markerwidth = app.Visengine.markerwidth;

                    darkMode  = app.DarkMode.State;
                    if isstring(cmap) || ischar(cmap)
                        cmap = feval(cmap);
                    end
                end
            end

            if isempty(app)
                % Default visualization color scheme
                cmap        = gray;
                linecolor   = 'red';
                darkMode    = true;
                linewidth   = 3;
                markerwidth = 16;
            end

            if ~isempty(obj.EngineVisualizer) && isvalid(obj.EngineVisualizer.Figure)
                for i = 1:obj.laststep
                    ax = obj.EngineVisualizer.Axes(i);
                    colormap(ax, cmap)
                    if size(obj.Outputs{i}, 2) == 2
                        obj.EngineVisualizer.Plot(i).Color = linecolor;
                    end

                end

                obj.EngineVisualizer.Contour.Color      = linecolor;
                obj.EngineVisualizer.Contour.LineWidth  = linewidth;
                obj.EngineVisualizer.Contour.MarkerSize = markerwidth;

            else
                return
            end

            % darkMode logical flag is true if dark mode desired
            fig = obj.EngineVisualizer.Figure;
            ChangeObjColor(fig, darkMode)
            
            function ChangeObjColor(gObj, flag)
                ChildCheck = isprop(gObj, 'Children');
                LabelCheck = isprop(gObj, 'XLabel');
                TextCheck  = isprop(gObj, 'Font');
                TitleCheck = isprop(gObj, 'Title');
                if flag
                    BColor = [0.15 0.15 0.15];
                    FColor = [1 1 1];
                else
                    BColor = [1 1 1];
                    FColor = [0 0 0];
                end

                % Changing color of figure
                if isa(gObj, 'matlab.ui.Figure')
                    gObj.Color = BColor;
                elseif isa(gObj, 'matlab.graphics.illustration.ColorBar')
                    gObj.Color = FColor;
                end

                % Checks through all graphical objects recursively
                if ChildCheck
                    Children     = gObj.Children;
                    N_Containers = numel(Children);
                    for j = 1:N_Containers
                        Child = Children(j);
                        if isprop(Child, 'BackgroundColor')
                            Child.BackgroundColor = BColor;
                        end
                        if isprop(Child, 'FontColor')
                            Child.FontColor = FColor;
                        end
                        if isprop(Child, 'ForegroundColor')
                            Child.ForegroundColor = FColor;
                        end
                        ChangeObjColor(Child, flag)
                    end
                end

                % Foreground color applied to text
                if LabelCheck 
                    Child       = gObj.XLabel;
                    Child.Color = FColor;
                end
                if TextCheck
                    Child           = gObj.Font;
                    Child.FontColor = FColor;
                end
                if TitleCheck
                    Child       = gObj.Title;
                    Child.Color = FColor;
                end
            end
        end
    end



    methods (Access = private)
        function InitSnakesConfig(obj)
            % INITSNAKESCONFIG will initialize the active contours
            % configuration
            % Initializing the active contours settings
            obj.snakesconfig.iterations      = 100;
            obj.snakesconfig.smoothness      = 0;
            obj.snakesconfig.factor          = 3;
            obj.snakesconfig.contractionBias = 0;
        end

        function CloseVisualizer(obj, ~, ~)
            % CLOSEVISUALIZER will close the engine visualizer figure and
            % clear the property so that other functions know it is not
            % available
            obj.EngineVisualizer.Figure.delete
            obj.EngineVisualizer = [];
        end


        function [Net, fH] = GetAIMethod(obj, choice)
            if ~isempty(choice)
                P      = mfilename('fullpath');
                P      = fileparts(P);
                folder = [P filesep 'AI' filesep 'Networks' filesep choice];
                fcont  = dir(folder);
                fcont  = fcont(~[fcont.isdir]);
                n      = numel(fcont);
                % Pulls out the function handle and the specific network to be
                % used
                for i = 1:n
                    fname = fcont(i).name;
                    if strcmp(fname(end-3:end), '.mat')
                        % Will only load the net if a valid var type 
                        netcont = load(fname);
                        for j = 1:numel(netcont)
                            Net = [];
                            v   = netcont(j);
                            nm  = fieldnames(v);
                            nm  = nm{:};
                            v   = v.(nm);
                            if isa(v, 'DAGNetwork') || isa(v, 'SeriesNetwork') || isa(v, 'dlnetwork')                                
                                Net = v;
                            end
                        end
                    elseif strcmp(fname(end-1:end), '.m')
                        % Gets the function handle to be used with the
                        % corresponding network
                        [~, f, ~] = fileparts(fname);
                        fH        = str2func(f);
                    end
                    obj.networkPath = fname;
                end
            end
        end
    end



    methods (Static)
        function Net = ConfigureNetFromFcn(fH)
            % Extracts params from a simple function's configuration
            Params = fH();
            % Data results type set from configuration
            if isfield(Params, 'Type')
                Net.Type = Params.Type;
            end
            Params = Params.Params;
        
            for i = 1:numel(Params)
                Params(i).Symbol = num2str(i);
                Params(i).Units  = '';
                Params(i).LblSz  = 16;
            end
            Net.Params = Params;
        end
        

        function List = ParseAvailableAIMethods
            % Finds available AI networks in the AI folder
            P    = mfilename('fullpath');
            P    = fileparts(P);
            PMF  = [P filesep 'AI' filesep 'Networks'];
            F    = dir(PMF);
            F    = F(3:end);
            val  = [F.isdir];
            List = {F(val).name};
            for i = 1:numel(List)
                % Will not add space for names that are acroynms
                name = List{i};
                caps = regexp(name, '([A-Z])');
                df   = diff(caps);
                if sum(df) > numel(name)
                    List{i} = AddRmStrSpace(name, true);
                end
            end
        end
        

        function List = ParametricMethodNames
            % Will find all parametric algorithm methods saved in the parametric
            % algorithms folder and load the names into the GUI. This will allow
            % the user to switch through various 3 parameter algorithms and to
            % develop new ones that can be readily loaded into the engine.
            P    = mfilename('fullpath');
            idx  = regexp(P, filesep);
            idx  = idx(end)-1;
            P    = P(1:idx);

            % Check all files in the folder:
            % ...\EngineDependencies\ParametricAlgorithms\...
            PMF  = [P filesep 'EngineDependencies' filesep 'ParametricAlgorithms'];
            F    = dir(PMF);
            F    = F(3:end);
            val  = ~[F.isdir];
            F    = F(val);
            List = {F.name};
            
            % Only keep those with "Plugin" at beginning of name...
            % Sub folders with names only serve to group function together 
            prefix   = 'Plugin_';
            idx      = numel(prefix) + 1;
            isplugin = contains(List, prefix);
            List     = List(isplugin);

            % Will remove the plugin prefix and drop the file extension
            List     = cellfun(@(x) x(idx:end-2), List, 'UniformOutput', false);
            
            for i = 1:numel(List)
                List{i} = AddRmStrSpace(List{i}, true);
            end
        end
    end
end