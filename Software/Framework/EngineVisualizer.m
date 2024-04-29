classdef EngineVisualizer < handle
    % ENGINEVISUALIZER is a class meant to visualize the 

    properties
        Figure
        Axes

        % Graphical settings
        cmap      = bone
        linewidth = 6
        linecolor = [1 1 1]
        darkMode  = false

    end


    methods (Access = public)
        function obj = EngineVisualizer()
        end

        function obj = PlotPluginSteps(obj, cmap, linecolor, linewidth, darkMode)
            % PLOTPLUGINSTEPS will plot all steps of computation from the
            % first step up through the step property of the engine class
            % which indicates the last desired step of the plugin workflow.
        
            % if ~isempty(obj.EngineVisualizer)
            %     obj.EngineVisualizer.Figure.delete
            %     obj.EngineVisualizer = [];
            % end
        
        
            if nargin == 1
               obj.Check4FigureSettings 
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
            Results = obj.Data;
            if isfield(obj.Plugin.Layers, 'DataName')
                DataNames = {obj.Plugin.Layers.DataName};
            else
                DataNames = cell(numel(obj.Plugin.Layers), 1);
            end
        
            % Grabbing the original image to be plotted first
            if ~isempty(obj.RGB)
                Im = obj.RGB;
            else
                Im = obj.RawImage;
            end
        
            % Size information needed to plot point clouds / contours atop
            % blank background
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
            for i = 1:obj.nlayers+1
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
                    % Axes limits, color, deletes axes outline
                    axis(ax, 'image')
                    ax.Color           = bckgrnd;
                    ax.XLim            = xL;
                    ax.YLim            = yL;
                    ax.XColor          = 'none';
                    ax.YColor          = 'none';
                    ax.Toolbar.Visible = 'off';
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
                    pmsg = obj.Plugin.Layers(i-1).Process;
                    ParameterLabel(i-1)
                else
                    if ~isempty(Points)
                        % Result from final layer
                        hold(ax)
                        obj.EngineVisualizer.Contour = plot(ax, Points(:,1), Points(:,2), 'Color', linecolor, 'LineWidth', linewidth);
                    end
                    name = 'Segmentation Result';
                    title(ax, name, 'FontSize', 14, 'FontName', FName, 'Color', FColor)
                    pmsg = obj.Plugin.Layers(i-1).Process;
                    ParameterLabel(i-1)
                end
        
                % Removing tick marks
                ax.XTick = [];
                ax.YTick = [];
        
                % Setting up with the same look as the GUI
                ax.FontName = FName;
            end
            
            % Title with proper spacing and method information
            Title_msg = ['Engine Processing Steps - Segmentation Method: ' obj.method newline];
            title(t, Title_msg, 'FontSize', 20, 'FontName', FName, 'Color', FColor)
        
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
                    pmsg    = ['Param(s) ' P_nums ': ' P_names newline pmsg];
                    disp(pmsg)
                else
                    pmsg = [pmsg newline];
                end
                xlabel(ax, pmsg, 'FontSize', 12, 'Color', FColor)
            end
        end
    end

    methods (Access = private)
        function Check4FigureSettings(obj)
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
                if isa(fH.RunningAppInstance, 'ROISegmentationGUI')
                    app           = fH.RunningAppInstance;
                    
                end
            end
            obj.cmap      = app.VisEngine.cmap1;
            obj.linecolor = app.VisEngine.plotColor;
            obj.linewidth = app.VisEngine.plotMarkWidth;
            obj.darkMode  = app.DarkMode.State;
            if isstring(obj.cmap) || ischar(obj.cmap)
                obj.cmap = feval(obj.cmap);
            end
        end

    end

end