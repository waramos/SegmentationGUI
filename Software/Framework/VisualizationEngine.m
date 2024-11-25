classdef VisualizationEngine < handle
% VISUALIZATIONENGINE determines the type of visualization required for
% data that is tied to an image. The computed results to be plotted can be
% a point cloud, ordered point cloud (contour/boundary), mask(s), or labels
% (uint8 or uint16 image). Visualizations will depend on data
% dimensionality and how it is shaped. Arrays with two columns will be
% limited to scatter and line plots for representation of point clouds or
% contours. Binary 2D arrays with more than 2 columns are limited to mask
% representations as an image plotted atop the primary axes with some
% transparency. Integer valued 2D arrays are then limited to a label matrix
% representation as an image plotted atop the primary axes with some
% transparency but unlike the mask data, the label matrix will span the
% colormap rather than only using a single color.
%
% William A. Ramos, Kumar Lab @ MBL, Woods Hole, June 2024

    properties
        % Access to classes held by GUI
        Server                                           % Maintains information about the image being analyzed

        % Axes for plot visualization
        UIAxes                                           % Holds plot of image of interest. Could be raw or auxiliary image
        UIAxes2                                          % Plots computational results atop the other axes to overlay atop image of interest
        opacity      (:,:) {mustBeFinite} = 0.4;         % Alphamap for transparency of masks and label matrices

        % Plot handles and info
        Image                                            % Image plot handle to allow direct replacement of CData for efficient visualization
        Plot                                             % Primitive line object (contour / pointcloud) or image plot handle (mask or label matrix)
        Plotoob                                          % Out of bound points plot only exists when points present
        mrows                                            % Number of image rows
        ncols                                            % Number of image columns
        numchannels                                      % Number of channels
        croprows                                         % Row limit if crop exists
        cropcols                                         % Column limit if crop exists

        % Data to be visualized
        Data (:,:) {mustBeFinite} = []                   % Data can be points (Mx2 matrix) or mask/label image (MxN matrix)

        % Major / Minor axes 
        Majeig = cell(4,1)                               % Major axis / moment of inertia plot handle
        Mineig = cell(4,1)                               % Minor axis / moment of inertia plot handle

        % Visualization settings
        view           (1, 1) logical = true             % Flag for whether or not a plot is on
        eigs           (1, 1) logical = false            % Flag for whether the major/minor moments should be plotted
        vistype        (1, :) char  ...
                       {mustBeMember(vistype, ...
                       {'contour', 'pointcloud', ...
                       'mask', 'label', ''})}    = 'contour' % Set of available plot options. When the type changes, the visualization changes
        color        (1,3) {mustBeNumeric}   = [1 0 0]   % Color applies to plots with point/lines or a logical mask
        linewidth    (1,1) {mustBeNumeric}   = 3         % Width of line for the plot
        markerwidth  (1,1) {mustBeNumeric}   = 16        % Width of marker for the plot
        marker         {mustBeMember(marker, {'o', ...
                       '+', '*', '.', 'x', '_', '|' ...
                       'square', 'diamond', '^', ...
                       'v', '>', '<', 'pentagram', ...
                       'hexagram'})}         = '.'       % Marker type for a point cloud plot
        linestyle      {mustBeMember(linestyle, ...
                       {'-', '--', ':', '-.', ...
                       'none'})}             = '-'       % Line style when creating a contour line plot
        cmap                                             % Cell array containing colormaps for multiple plots/axes
        transposed     (1, 1) logical        = false     % Determines whether images and plotted data need to be transposed in the window
        autocontrast   (1, 1) logical        = false     % Determines whether or not to autocontrast images
        manualcontrast (1, 1) logical        = false     % Determines whether or not manual contrast is in place

        % Misc handles
        contrastGUI                                      % Handle to MATLAB's image contrast GUI
    end

    properties (Dependent)
        isrgb
    end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Constructor, Get/Set Methods
    methods
        function obj = VisualizationEngine(app)
            % Constructor
            if nargin == 1
                obj.UIAxes = app.UIAxes;
            end

            % Initializes second set of axes atop first for data overlay
            obj.InitSecondAxes

            % Sets default colormaps 
            obj.SetColormaps
        end


        function SetColormaps(obj, clrmap1, clrmap2)
            % SETCOLORMAPS will set the colormaps for the two axes. By
            % default, the primary colormap will be the bone colormap and
            % the second colormap will be the complement of whatever the
            % primary colormap is.
            if nargin < 2 || isempty(clrmap1)
                obj.cmap{1} = bone;
            end

            if nargin < 3 || isempty(clrmap2)
                % Sets the second colormap as the complement of the 
                obj.cmap{2} = 1 - obj.cmap{1};
            end

        end


        % Get methods
        function isrgb = get.isrgb(obj)
            % axes image data returns true if color, false if grayscale
            isrgb = obj.numchannels == 3;
        end


        % Pseudo-set methods
        function SetImageCrop(obj, row, col)
            % SETIMAGECROP will adjust the data to stay within the bounds
            % of any crop the user chooses to apply.
            obj.croprows = row;
            obj.cropcols = col;
        end


        function AdjustVisualizationType(obj)
            % ADJUSTVISUALIZATIONTYPE will automatically figure out what
            % type of visualization to produce depending on what the data
            % look like that have been loaded into the class.

            % Automatic determination of visualization type
            vtype = obj.DetermineResultType;

            % Updates visualization type if new type differs from previous
            if ~strcmp(obj.vistype, vtype)
                obj.vistype = vtype;

                % Deletes the points plot and adjusts axes
                if ~isempty(obj.Plot) && isvalid(obj.Plot)
                    obj.Plot.delete
                    obj.Plot        = [];
                    obj.UIAxes.XLim = [1 obj.cropcols(2)-obj.cropcols(1)+1];
                    obj.UIAxes.YLim = [1 obj.croprows(2)-obj.croprows(1)+1];
                end

                % Deleting the out of bounds points
                if ~isempty(obj.Plotoob) && isvalid(obj.Plotoob)
                    obj.Plotoob.delete
                    obj.Plotoob     = [];
                end

                % Clears eigen plots as well
                obj.ClearEigPlots

                % Keeps plot cleared unless a valid type is established
                if ~isempty(vtype)
                    obj.UpdateResultsPlot
                end
            end
        end


        function vtype = DetermineResultType(obj)
            % DETERMINERESULTTYPE will set the visualization type according 
            % to the currently loaded data. This function is only called in
            % the adjust visualization type 
            D      = obj.Data;
            [r, c] = size(D, [1 2]);

            % If no data is present, visualization type cleared.
            if isempty(D)
                vtype = '';
                return
            end

            if c == 2
                % Data with 2 columns is a set of points
                if all(D(1,:) == D(end,:)) && r > 1
                    % Contour curves are closed and more than one point
                    vtype = 'contour';
                else
                    % A pointcloud set can be as small as one point
                    vtype = 'pointcloud';
                end

            elseif c > 2
                % Data with more than 2 columns is a mask or label matrix
                if islogical(D)
                    vtype = 'mask';
                elseif isa(D, 'uint8') || isa(D, 'uint16')
                    vtype = 'label';
                end

            end
        end


    end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Color Setting functions
    methods(Access = public)
        function ChangePlotColor(obj, c)
            % SETPLOTCOLOR allows the user to set the color for plot
            % markers and mask data
            switch obj.vistype
                case 'contour'
                    if nargin < 2 || isempty(c)
                        c = uisetcolor(obj.color, 'Results Plot Color');
                    end
                    obj.color      = c;
                    obj.Plot.Color = obj.color;

                case 'pointcloud'
                    if nargin < 2 || isempty(c)
                        c = uisetcolor(obj.color, 'Results Plot Color');
                    end
                    obj.color   = c;
                    obj.Plot.Color = obj.color;

                case 'mask'
                    if nargin < 2 || isempty(c)
                        c = uisetcolor(obj.color, 'Results Plot Color');
                    end
                    obj.color   = c;
                    obj.cmap{2} = [0 0 0; c];
                    colormap(obj.UIAxes2, obj.cmap{2})

                case 'label'
                    if nargin < 2 || isempty(c)
                        c = ColormapSelector;
                    end
                    obj.cmap{2} = c;
                    colormap(obj.UIAxes2, obj.cmap{2})

            end
        end


        function ChangeColormap(obj, cmap)
            % SETCOLORMAP will either allow the user to explicitly set the
            % colormap or ask the user via a dialog window to select a
            % choice from preexisting options.
            if nargin < 2 || isempty(cmap)
                cmap = ColormapSelector;
            end

            % User closed colormap selection prompt, no change made
            if isempty(cmap)
                return
            end

            % Setting underlying image's colormap
            obj.cmap{1} = cmap;
            colormap(obj.UIAxes, obj.cmap{1});

            % Label data gets complementary color map by default
            if isempty(obj.cmap{2})
                obj.cmap{2} = fliplr(obj.cmap{1});
            end
        end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Plot updating functions
        function UpdateImagePlot(obj, I)
            % UPDATEIMAGEPLOT will update the image that is plotted by
            % grabbing the latest image from the image server. 

            % Tranposing the image if set to transpose
            if obj.transposed
                I = pagetranspose(I);
            end

            % Gets size info
            obj.GetImageSize(I)

            % Won't replace the image unless deleted
            if isempty(obj.Image) || ~isvalid(obj.Image)
                obj.Image = imagesc(obj.UIAxes, I);
                axis(obj.UIAxes, 'equal')
                colormap(obj.UIAxes, obj.cmap{1})
            else
                obj.Image.CData = I;
            end

            % If the image has changed, then presumably, the engine's
            % results have also changed
            obj.UpdateResultsPlot
        end


        function GetImageSize(obj, I)
            % GETIMAGESIZE gets size information about the image
            [obj.mrows, obj.ncols, obj.numchannels] = size(I, [1 2 3]);
        end


        function [P, idx] = Check4Crop(obj)
            % CHECK4CROP bound checks points based on cropping bounds.
            % Init
            P   = [];
            idx = [];
            if ~isempty(obj.Data)
                % Correcting and finding out of bound points if needed
                P   = obj.Data;
                if ~isempty(obj.cropcols)
                    % Bounds converted to x, y
                    lb     = [obj.cropcols(1) obj.croprows(1)];
                    ub     = [obj.cropcols(2) obj.croprows(2)];

                    % Finding out of bound points
                    idx    = P(:,1)>ub(1) | P(:,2)>ub(2);
                    idx    = idx | (P(:,1)<lb(1) | P(:,2)<lb(2));

                    % Upper bound affected by lb
                    ub = ub-lb;

                    % Keeps point visualization in bounds
                    P(:,1) = P(:,1) - (lb(1) - 1);
                    P(:,2) = P(:,2) - (lb(2) - 1);
                    P      = min(P, ub);
                    P      = max(P, 1);
                end
            end
        end


        function UpdateResultsPlot(obj)
            % UPDATERESULTSPLOT will update the data plot according to the
            % visualization type that is set. If the plotted results have
            % an existing handle, graphics objects will be preserved, and
            % their properties will simply be altered accordingly for
            % efficient visualization.

            % Unset visualization type prompts a check
            % Can clear and readjust plot
            obj.AdjustVisualizationType

            try
                % Updates to plotted results depends on visualization type
                switch obj.vistype
                    case 'contour'
                        obj.PointVisualization(true)
    
                    case 'pointcloud'
                        obj.PointVisualization(false)
    
                    case 'mask'
                        obj.OverlayVisualization(true)
    
                    case 'label'
                        obj.OverlayVisualization(false)
    
                end

                % Places major / minor axes over the other plots if desired
                if obj.eigs
                    obj.PlotMajMinMoments
                else
                    % Clears moments plot
                    obj.ClearEigPlots
                end

            catch
            end
        end

        function [X, Y, idx] = AdjustPointsForPlot(obj)
            % Consider crop, plot bounds, and transpose
            [P, idx] = obj.Check4Crop;
            [X, Y]   = obj.TransposePoints(P);
        end


        function PointVisualization(obj, isclosedcurve)
            % POINTVISUZLIZATION will visualize points as a line plot or
            % point cloud depending a logical flag for a line (true flag).
            % This will also simply plot on the same axes as the image data
            % plot to reduce any potential latency since the second axes
            % only need to be used for additional image data to be plotted
            % overlayed on the image data.

            % Ensures points fit on axes properly
            [X, Y, idxoob] = obj.AdjustPointsForPlot;

            if isclosedcurve
                % Results in a closed curve (i.e. contour)
                Markertype = 'none';
                Linestyle  = obj.linestyle;
            else
                % Results in a scatter plot (i.e. point cloud)
                Markertype = obj.marker;
                Linestyle  = 'none';
            end

            % Ensures the line plot goes over the ROI
            if obj.view && ~isempty(X)
                if isempty(obj.Plot)
                    % Creates the graphics object to hold plotted data and
                    % turns off datatips 
                    hold(obj.UIAxes, 'on')
                    obj.Plot               = plot(obj.UIAxes, X, Y, ...
                                                  'Color', obj.color,...
                                                  'LineWidth', obj.linewidth,...
                                                  'Marker', Markertype,...
                                                  'MarkerSize', obj.markerwidth,...
                                                  'LineStyle', Linestyle);
                    obj.Plot.PickableParts = 'none';
                    obj.Plot.HitTest       = false;
                    
                else
                    % Replaces the plotted data while maintaining the
                    % graphics object. Also updates color if changed
                    obj.Plot.XData      = X;
                    obj.Plot.YData      = Y;
                    obj.Plot.Color      = obj.color;
                    obj.Plot.LineWidth  = obj.linewidth;
                    obj.Plot.MarkerSize = obj.markerwidth;
                    obj.Plot.Marker     = Markertype;
                end

                % Out of bounds plotting
                oobcolor = 1-fliplr(obj.color);
                Xoob     = X(idxoob);
                Yoob     = Y(idxoob);

                % Init the plot or update it
                if isempty(obj.Plotoob) && any(idxoob)
                    obj.Plotoob               = plot(obj.UIAxes, Xoob, Yoob, ...
                                                     'Color', oobcolor,...
                                                     'LineWidth', obj.linewidth,...
                                                     'Marker', 'x',...
                                                     'MarkerSize', obj.markerwidth,...
                                                     'LineStyle', 'none');
                    obj.Plotoob.PickableParts = 'none';
                    obj.Plot.HitTest          = false;
                elseif ~isempty(obj.Plotoob) && isvalid(obj.Plotoob)
                    % Replaces the plotted data while maintaining the
                    % graphics object. Also updates color if changed
                    obj.Plotoob.XData      = Xoob;
                    obj.Plotoob.YData      = Yoob;
                    obj.Plotoob.Color      = oobcolor;
                    obj.Plotoob.LineWidth  = obj.linewidth;
                    obj.Plotoob.MarkerSize = obj.markerwidth;
                end
                
            else
                % Clearing the plots
                if ~isempty(obj.Plot) && isvalid(obj.Plot)
                    obj.Plot.XData = [];
                    obj.Plot.YData = [];
                end
                if ~isempty(obj.Plotoob) && isvalid(obj.Plotoob)
                    obj.Plotoob.XData = [];
                    obj.Plotoob.YData = [];
                end
            end

            
            % if obj.eigs
            %     % Places major / minor axes over the other plots if desired
            %     obj.PlotMajMinMoments
            % 
            % elseif ~obj.eigs && ~isempty(obj.Majeig{1})
            %     % Clears line plots
            %     obj.ClearEigPlots
            % 
            % end
        end


        function OverlayVisualization(obj, ismask)
            % OVERLAYVISUALIZATION will setup a label matrix or mask to
            % overlay atop the plotted image.

            % "Clears" plot by setting the opacity to zero
            if ~obj.view
                obj.Plot.AlphaData = zeros(size(obj.Image.CData));
                return
            end

            % Will alter the mask to be a cropped region if requested
            D  = obj.Data;
            r  = obj.croprows;
            c  = obj.cropcols;
            r1 = r(1);
            r2 = r(2);
            c1 = c(1);
            c2 = c(2);
            D  = D(r1:r2, c1:c2);

            % Transposes if transpose is on
            if obj.transposed
                D = D';
            end
            % D = double(D);

            if isempty(obj.Plot)
                % Initial image plot handle and image aspect ratio
                obj.Plot = imagesc(obj.UIAxes2, D);
                axis(obj.UIAxes2, 'image')

                if ismask
                    % Mask has binary colormap
                    clrmap   = [0 0 0; obj.color];

                else
                    % Labels have unique colormap, label scaled alpha
                    clrmap   = obj.cmap{2};

                end

                % Setting colormap and transparency
                colormap(obj.UIAxes2, clrmap)

            else
                % Directly alters CData for efficient visualization
                obj.Plot.CData = D;
            end

            % Setting Alpha with alpha as a map 
            % obj.Plot.AlphaData = obj.opacity*alphaMap;

            % Faster to set scalar across the image
            obj.Plot.AlphaData = obj.opacity;

            % % Places major / minor axes over the other plots if desired
            % if obj.eigs
            %     obj.PlotMajMinMoments
            % else
            %     % Clears moments plot
            %     obj.ClearEigPlots
            % end

            % Overlayed image visualizations tend to get moved for some
            % reason so this ensures the second axes maintain the same
            % position as the primary axes to remain properly aligned
            % obj.UIAxes2.InnerPosition = obj.UIAxes.InnerPosition;
        end


        function UpdateAxesLimits(obj, Rows, Cols)
            % UPDATEAXESLIMITS ensures the axes restore limits properly
            % when differently oriented images or differently sized images
            % are loaded into the axes (i.e. the CData shape changes)

            % Number of rows and columns of newly loaded image
            newM = Rows(2) - Rows(1) + 1;
            newN = Cols(2) - Cols(1) + 1;
            y    = [1 newM];
            x    = [1 newN];

            % Will flip limits if image is transposed
            if obj.transposed
                obj.UIAxes.YLim  = x;
                obj.UIAxes.XLim  = y;
                obj.UIAxes2.YLim = x;
                obj.UIAxes2.XLim = y;
            else
                obj.UIAxes.YLim  = y;
                obj.UIAxes.XLim  = x;
                obj.UIAxes2.YLim = x;
                obj.UIAxes2.XLim = y;
            end
        end


        function PlotMajMinMoments(obj)
            % PLOTMAJMINMOMENTS will compute the eigen vectors of a point
            % cloud, contour curve, or mask. Data is first converted to
            % masks and this can then be computed on to find the major and
            % minor moments of inertia.

            if ~isempty(obj.Data) && ~isempty(obj.vistype)
                % Gets a mask and then computes the eigenvectors
                Mask             = obj.GetDataAsMask;
                [Majmom, Minmom] = obj.ComputeMaskEigenVectors(Mask);

                % Computes the plotted image's complementary color
                c = obj.ComputeComplementaryColor(Mask);

                % Will have to plot atop any mask overlay if one is present
                hold(obj.UIAxes2, 'on')
                
                % Plotting
                if isempty(obj.Majeig{1})
                    % Initialization
                    obj.InitEigPlot(Majmom, Minmom, c)

                else
                    % Updates plots if they exist
                    obj.UpdateEigPlots(Majmom, Minmom, c)

                end

            else
                % Clearing plots when data is invalid
                obj.ClearEigPlots
            end
        end


        function Mask = GetDataAsMask(obj)
            % GETDATAASMASK will either be able to produce a mask by simply
            % pulling the data reference or will convert points to a mask.
            if any(strcmp(obj.vistype, {'contour', 'pointcloud'}))
                if obj.transposed
                    P      = [obj.Data(:,2) obj.Data(:,1)];
                    % Cropping of image shifts the coordinates in the display
                    P(:,1) = P(:,1) - (obj.croprows(1) - 1);
                    P(:,2) = P(:,2) - (obj.cropcols(1) - 1);
                    P      = min(P, [obj.croprows(2) obj.cropcols(2)]);
                else
                    P      = obj.Data;
                    % Cropping of image shifts the coordinates in the display
                    P(:,1) = P(:,1) - (obj.cropcols(1) - 1);
                    P(:,2) = P(:,2) - (obj.croprows(1) - 1);
                    P      = min(P, [obj.cropcols(2) obj.croprows(2)]);
                end

                % Bounds check points
                P      = max(P, 1);
                % Computing the major and minor axes from the mask
                Mask   = poly2mask(P(:,1), P(:,2), obj.mrows, obj.ncols);

            elseif strcmp(obj.vistype, 'mask')
                if obj.transposed
                    Mask = obj.Data';
                else
                    Mask = obj.Data;
                end
            end
        end


        function ClearEigPlots(obj)
            % CLEAREIGHPLOTS will clear the eigenvector plots
            if ~isempty(obj.Majeig{1}) && isa(obj.Majeig{1}, 'matlab.graphics.chart.primitive.Line')
                for i = 1:numel(obj.Majeig)
                    % Clear major axes
                    obj.Majeig{i}.XData = [];
                    obj.Majeig{i}.YData = [];

                    % Clear minor axes
                    obj.Mineig{i}.XData = [];
                    obj.Mineig{i}.YData = [];

                end
            end
        end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Contrast functions
        function Autocontrast(obj)
            % AUTOCONTRAST deletes a manual contrast GUI handle if it
            % exists and then automatically contrast the axes' image
            try
                obj.contrastGUI.delete
            catch
            end
            obj.AutoContrastAxes(obj.autocontrast)
        end


        function ManualContrast(obj)
            % MANUALCONTRAST will disable autocontrast and launch a manual
            % contrast GUI.
            if obj.manualcontrast
                obj.autocontrast = false;
                if obj.numchannels == 1
                    obj.contrastGUI = imcontrast(obj.UIAxes);
                else
                    obj.manualcontrast = false;
                end
            else
                % Will delete the manual contrast GUI if it exists
                if ~isempty(obj.contrastGUI)
                    obj.contrastGUI.delete;
                    % Resets the contrast to the original bounds of the
                    % image
                    lb = min(obj.Image.CData(:));
                    ub = max(obj.Image.CData(:));
                    obj.UIAxes.CLim = double([lb ub]);
                end
            end
        end
    end




    methods (Access = private)
        function InitSecondAxes(obj)
            % Initializes second axes to have masks/data plotted atop.
            obj.UIAxes2       = uiaxes(obj.UIAxes.Parent);
            axis(obj.UIAxes2, 'equal')
            obj.UIAxes2.Color = 'none';
            obj.UIAxes2.YDir  = 'reverse';
            obj.UIAxes.YDir   = 'reverse';
            linkprop([obj.UIAxes obj.UIAxes2],...
                     {'Position', 'InnerPosition', 'XLim', 'YLim',...
                      'XLimMode', 'YLimMode',...
                      'XLimitMethod', 'YLimitMethod',...
                      'XTick', 'YTick', 'XColor', 'YColor',...
                      'Clipping', 'ClippingStyle', 'YDir', 'XDir'});
            linkaxes([obj.UIAxes obj.UIAxes2], 'xy')
            disableDefaultInteractivity(obj.UIAxes2)
            obj.UIAxes2.Toolbar.Visible = false;
        end


        function AutoContrastAxes(obj, acflag)
        % AXESAUTOCONTRAST will auto contrast an image in an axes object by
        % extracting the plotted image and setting color limits based off of the
        % bottom value at the 1st percentile and top value at the 99.9-th 
        % percentile. If the autocontrast flag is set to false, the color limits
        % are set based on the overall min and max of the image.
        
            if nargin < 2
                acflag = true;
            end
            % Will find the image object plotted in the axes and extract
            im  = obj.Image.CData;
            im  = double(im);
        
            % Grayscale
            if size(im, 3) == 1
                [lb, ub] = obj.FilteredBounds(im, acflag);
                % Sets axes color limits and ensures imcontrast can work by making
                % double 
                obj.UIAxes.CLim = double([lb, ub]);
            elseif size(im, 3) == 3
                % Leaves range alone
                return
            end
        end


        function [X, Y] = TransposePoints(obj, P)
            % TRANSPOSEPOINTS will transpose points if transpose is enabled
            if ~isempty(P)
                X      = P(:,1);
                Y      = P(:,2);
                % Transpose consideration
                if obj.transposed
                    % Swap of x, y coordinates
                    [X, Y] = deal(Y, X);
                end

            else
                X = [];
                Y = [];

            end
        end


        function c = ComputeComplementaryColor(obj, Mask)
            % COMPUTECOMPLEMENTARYCOLOR will compute the complement of
            % either the colormap or the average color from the masked ROI
            % of an RGB image.

            if size(obj.Image.CData, 3) == 3
                % RGB Image Case
                I = obj.Image.CData;
                R = I(:,:,1);
                G = I(:,:,2);
                B = I(:,:,3);
                R = R(Mask);
                G = G(Mask);
                B = B(Mask);
                R = mean(R(:));
                G = mean(G(:));
                B = mean(B(:));
                c = [R G B];
                c = c/255;

            else
                % Grayscale image case - looks at colormap
                if ischar(obj.cmap{1}) || isstring(obj.cmap{1})
                    % In case the colormap is a name
                    c = feval(obj.cmap{1}); 
                else
                    c = obj.cmap{1};
                end

                % Average RGB value of the masked region
                roi   = obj.Image.CData(Mask);
                roi_m = mean(roi, 'all');
                cl    = obj.UIAxes.CLim;
                r     = (cl(2) - cl(1));
                roi_m = roi_m - cl(1);

                % Clips in case the mean of the ROI is below the lower
                % color limit
                roi_m = max(roi_m, 0);
                v     = roi_m/r;
                nc    = size(c, 1);
                idx   = round(v*nc);
                idx   = min(idx, nc);
                idx   = max(idx, 1);
                c     = c(idx,:);

            end

            % Complementary color
            c = fliplr(c);
        end


        function InitEigPlot(obj, majmoment, minmoment, c)
            % INITEIGPLOT will initialize the eigenvector plot with data
            % representing the major and minor moments of inertia

            % Main lines plotted - first cell
            obj.Majeig{1}  = plot(obj.UIAxes2, ...
                                  majmoment(:,1), majmoment(:,2),...
                                  'Color', c,...
                                  'LineWidth', obj.linewidth);
            obj.Mineig{1}  = plot(obj.UIAxes2, ...
                                  minmoment(:,1), minmoment(:,2),...
                                  'Color', c,...
                                  'LineWidth', obj.linewidth);

            % Dotted complementary lines atop - second cell
            obj.Majeig{2}  = plot(obj.UIAxes2, ...
                                  majmoment(:,1), majmoment(:,2),...
                                  'Color', 1-c,...
                                  'LineWidth', obj.linewidth,...
                                  'LineStyle', ':');
            obj.Mineig{2}  = plot(obj.UIAxes2, ...
                                  minmoment(:,1), minmoment(:,2),...
                                  'Color', 1-c,...
                                  'LineWidth', obj.linewidth,...
                                  'LineStyle', ':');

            % Centroid Plot - third cell in MajEig
            obj.Majeig{3} = plot(obj.UIAxes2, ...
                                 mean(majmoment(:,1)), mean(majmoment(:,2)),...
                                 'Color', c,...
                                 'LineStyle', 'none',...
                                 'Marker', 'o',...
                                 'MarkerSize', obj.markerwidth,...
                                 'LineWidth', obj.linewidth);

            % Ensure proper axes aspect ratio
            % axis(obj.UIAxes, 'image')
            % axis(obj.UIAxes2, 'image')
        end


        function UpdateEigPlots(obj, Majmom, Minmom, c)
            % UPDATEEIGPLOTS will update the x/y data for the eigen vector
            % plots

            % Main lines update
            obj.Majeig{1}.XData = Majmom(:,1);
            obj.Majeig{1}.YData = Majmom(:,2);
            obj.Mineig{1}.XData = Minmom(:,1);
            obj.Mineig{1}.YData = Minmom(:,2);
            obj.Majeig{1}.Color = c;
            obj.Mineig{1}.Color = c;

            % Dotted lines update
            obj.Majeig{2}.XData = Majmom(:,1);
            obj.Majeig{2}.YData = Majmom(:,2);
            obj.Mineig{2}.XData = Minmom(:,1);
            obj.Mineig{2}.YData = Minmom(:,2);
            obj.Majeig{2}.Color = 1-c;
            obj.Mineig{2}.Color = 1-c;

            % Centroid Update
            obj.Majeig{3}.XData = mean(Majmom(:,1));
            obj.Majeig{3}.YData = mean(Majmom(:,2));
            obj.Majeig{3}.Color = 1-c;
        end
    end



    methods(Static)
        function [Majmom, Minmom] = ComputeMaskEigenVectors(Mask, assegments)
            % COMPUTEMASKEIGENVECTORS will compute the eigen vectors of an
            % image mask, i.e. major and minor moments of inertia. By 
            % default, this will produce line segments in the format of an 
            % array with coordinates.

            % By default, the moments of inertia 
            if nargin < 2 || isempty(assegments)
                assegments = true;
            end

            % Centroid from coordinates of positive pixels
            [y, x] = find(Mask);
            c      = [mean(x) mean(y)];

            % Moments of inertia
            C      = zeros(2);
            dx     = x-c(1);
            dy     = y-c(2);
            C(1,1) = mean(dx.^2);
            C(2,1) = mean(dx.*dy);
            C(1,2) = C(2,1);
            C(2,2) = mean(dy.^2);
            [V,D]  = eigs(C);
            D      = 2*sqrt(diag(D));

            % Major and minor moments / eigen vecs as coordinates
            AxesCoords = [-V(:,1)'; V(:,2)'];
            Majmom     = [c(:)';c(:)'+D(1)*AxesCoords(1,:)];        
            Minmom     = [c(:)';c(:)'+D(2)*AxesCoords(2,:)];

            % Converting to line segments with 2 points
            if assegments
                Majdx       = diff(Majmom(:,1));
                Majdy       = diff(Majmom(:,2));
                Majmom(1,1) = Majmom(1,1) - Majdx;
                Majmom(1,2) = Majmom(1,2) - Majdy;
                Mindx       = diff(Minmom(:,1));
                Mindy       = diff(Minmom(:,2));
                Minmom(1,1) = Minmom(1,1) - Mindx;
                Minmom(1,2) = Minmom(1,2) - Mindy;
            end
        end


        function [lb, ub] = FilteredBounds(I, acflag)
            % FILTEREDBOUNDS will compute the upper .1 percentile and lower
            % 1 percentile of the median filtered image to establish bounds
            % to adjust contrast of an image. If the second input argument
            % is false, the max and min of the original image are returned
            % instead.
            if acflag
                if ~islogical(I)
                    % Color limits based off of percentiles in sorted pixel list
                    I      = medfilt2(I);
                    ordI   = sort(I(:));
                    n      = numel(I);
                    lb_idx = round(0.01*n);
                    ub_idx = round(0.999*n);
                    lb     = ordI(lb_idx);
                    ub     = ordI(ub_idx);
                    if lb == ub
                        ub = lb + 1;
                    end

                else
                    % Logical image
                    lb = 0;
                    ub = 1;

                end
            else
                % Will just include the full range
                [lb, ub] = bounds(I(:));
            end
        end
    end
end