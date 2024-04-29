function GUIConfig_Default(app, initFlag)
    if nargin < 2
        % If the GUI is being launched for the first time, graphical
        % settings will be initialized. 
        initFlag = true;
    end

    if initFlag
        % Instantiate Image Server, Engine, and Export Module
        app.Server           = ImageServer;
        app.Engine           = SegmentationEngine;
        app.DataExportModule = ExportModule(app.UIFigure);
        app.VisEngine        = VisualizationEngine(app);
        % Will only set the graphical settings upon initial launch
        GraphicalSettings(app)
    end

    % Check fields of struct to enable flexible configurations
    ConfigFields = {'Name', 'Units', 'Min', 'Max', 'Value'};
    FieldCheck   = isfield(app.Engine.Plugin.controls, ConfigFields);

    % Name of parameter
    if FieldCheck(1)
        app.SliderLabel_1.Text = app.Engine.Plugin.controls(1).Name;
        app.SliderLabel_2.Text = app.Engine.Plugin.controls(2).Name;
        app.SliderLabel_3.Text = app.Engine.Plugin.controls(3).Name;
    end

    % Units if the plugin has them
    if FieldCheck(2)
        app.TopSliderUnits.Text      = app.Engine.Plugin.controls(1).Units;
        app.MiddleSliderUnits.Text   = app.Engine.Plugin.controls(2).Units;
        app.BottomSliderUnits.Text   = app.Engine.Plugin.controls(3).Units;
    end

    % Lower bound of params
    if FieldCheck(3)
        app.TopParamMin              = app.Engine.Plugin.controls(1).Min;
        app.MiddleParamMin           = app.Engine.Plugin.controls(2).Min;
        app.BottomParamMin           = app.Engine.Plugin.controls(3).Min;
        app.TopEditFieldMin.Value    = num2str(app.Engine.Plugin.controls(1).Min);
        app.MiddleEditFieldMin.Value = num2str(app.Engine.Plugin.controls(2).Min);
        app.BottomEditFieldMin.Value = num2str(app.Engine.Plugin.controls(3).Min);
    end

    % Upper bound of params
    if FieldCheck(4)
        app.TopParamMax              = app.Engine.Plugin.controls(1).Max;
        app.MiddleParamMax           = app.Engine.Plugin.controls(2).Max;
        app.BottomParamMax           = app.Engine.Plugin.controls(3).Max;
        app.TopEditFieldMax.Value    = num2str(app.Engine.Plugin.controls(1).Max);
        app.MiddleEditFieldMax.Value = num2str(app.Engine.Plugin.controls(2).Max);
        app.BottomEditFieldMax.Value = num2str(app.Engine.Plugin.controls(3).Max);
    end

    % 
    if FieldCheck(5)
        % Slider Value labels
        app.TopSliderValueLabel.Text    = num2str(app.Engine.Plugin.controls(1).Value);
        app.MiddleSliderValueLabel.Text = num2str(app.Engine.Plugin.controls(2).Value);
        app.BottomSliderValueLabel.Text = num2str(app.Engine.Plugin.controls(3).Value);
        % Slider values
        app.TopSlider.Value             = app.UpdateSlider(app.Engine.Plugin.controls(1).Value, app.TopParamMin, app.TopParamMax);
        app.MiddleSlider.Value          = app.UpdateSlider(app.Engine.Plugin.controls(2).Value, app.MiddleParamMin, app.MiddleParamMax);
        app.BottomSlider.Value          = app.UpdateSlider(app.Engine.Plugin.controls(3).Value, app.BottomParamMin, app.BottomParamMax);

        for i = 1:(app.Engine.nLayers)
            % Gets ahold of the engine's default settings so they can be 
            % reset later if needed
            try
                app.Defaults(i) = app.Engine.Plugin.controls(i).Value;
            catch
            end
        end
    end

    % Recursively loops through all graphical elements that have text to
    % ensure the appropriate interpreter and consistent styling is applied
    Check4LaTeX(app.UIFigure)

    % Sets the parameter values to defaults - ensures not passing by ref.
    app.ParamVec = app.Defaults(:);
end


function GraphicalSettings(app)
    % Folder that the app is running in - to load icons
    [currentfolder, ~]              = fileparts(mfilename('fullpath'));
    IconFolder                      = [currentfolder filesep 'SVGIcons' filesep];
    
    % Toolbar button icons
    app.Load.Icon                   = [IconFolder 'upload.svg'];
    app.LoadMasks.Icon              = [IconFolder 'upload-square.svg'];
    app.InstantNav.Icon             = [IconFolder 'compass.svg'];
    app.LeftArrow.Icon              = [IconFolder 'move-left.svg'];
    app.RightArrow.Icon             = [IconFolder 'move-right.svg'];
    app.UpArrow.Icon                = [IconFolder 'move-up.svg'];
    app.DownArrow.Icon              = [IconFolder 'move-down.svg'];
    app.Batch.Icon                  = [IconFolder 'stack-3.svg'];
    app.AutoContrast.Icon           = [IconFolder 'brightness.svg'];
    app.ManualContrast.Icon         = [IconFolder 'brightness-window.svg'];
    app.TargetColor.Icon            = [IconFolder 'color-picker.svg'];
    app.Square.Icon                 = [IconFolder 'superscript.svg'];
    app.LogScaleButton.Icon         = [IconFolder 'log.svg'];
    app.Inversion.Icon              = [IconFolder 'data-transfer-both.svg'];
    app.ChangeDenoise.Icon          = [IconFolder 'grain-cog.svg'];
    app.DenoiseButton.Icon          = [IconFolder 'noise-toggle.svg'];
    app.ChangeNetwork.Icon          = [IconFolder 'brain-research.svg'];
    app.AIButton.Icon               = [IconFolder 'brain-bulb.svg'];
    app.CropButton.Icon             = [IconFolder 'crop.svg'];
    app.BoundaryTaper.Icon          = [IconFolder 'style-border.svg'];
    app.ChangeMethod.Icon           = [IconFolder 'tools.svg'];
    app.AutoParamsButton.Icon       = [IconFolder 'type.svg'];
    app.ActiveContours.Icon         = [IconFolder 'activity.svg'];
    app.AdjustMask.Icon             = [IconFolder 'mask-square.svg'];
    app.Colormap.Icon               = [IconFolder 'palette.svg'];
    app.ContourColor.Icon           = [IconFolder 'color-filter.svg'];
    app.ContourButton.Icon          = [IconFolder 'circle-dashed.svg'];
    app.TransposeButton.Icon        = [IconFolder 'transpose.svg'];
    app.PlotMajMin.Icon             = [IconFolder 'border-inner.svg'];
    app.ColorBar.Icon               = [IconFolder 'ruler.svg'];
    app.ViewNetResults.Icon         = [IconFolder 'view-grid.svg'];
    app.AuxiliaryView.Icon          = [IconFolder 'photo.svg'];
    app.Overwrite.Icon              = [IconFolder 'remove-square.svg'];
    app.DarkMode.Icon               = [IconFolder 'half-moon.svg'];
    app.ResetButton.Icon            = [IconFolder 'restart.svg'];
    app.InfoTool.Icon               = [IconFolder 'question-mark.svg'];
    app.BrowseButton.Icon           = [IconFolder 'folder.svg'];
    app.ExportButton.Icon           = [IconFolder 'save-floppy-disk.svg'];

    % Toolbar button tooltips
    app.Load.Tooltip                = 'Load Image';
    app.LoadMasks.Tooltip           = 'Load Masks';
    app.Batch.Tooltip               = 'Batch Process';
    app.InstantNav.Tooltip          = 'Instant Navigation';
    app.LeftArrow.Tooltip           = 'Previous Stack/File';
    app.RightArrow.Tooltip          = 'Next Stack/File';
    app.UpArrow.Tooltip             = 'Previous Slice';
    app.DownArrow.Tooltip           = 'Next Slice';
    app.AutoContrast.Tooltip        = 'Auto Contrast';
    app.ManualContrast.Tooltip      = 'Manual Contrast';
    app.TargetColor.Tooltip         = 'Target Color Transform';
    app.Square.Tooltip              = 'Square Image';
    app.LogScaleButton.Tooltip      = 'Log Scale';
    app.Inversion.Tooltip           = 'Image Inversion';
    app.DenoiseButton.Tooltip       = 'Denoise Image';
    app.ChangeDenoise.Tooltip       = 'Change Denoising Method';
    app.AIButton.Tooltip            = 'CNN Preprocessing';
    app.ChangeNetwork.Tooltip       = 'Change Network';
    app.CropButton.Tooltip          = 'Crop';
    app.BoundaryTaper.Tooltip       = 'Boundary Taper';
    app.ChangeMethod.Tooltip        = 'Change Segmentation Method';
    app.AutoParamsButton.Tooltip    = 'Auto Params';
    app.ActiveContours.Tooltip      = 'Active Contour';
    app.AdjustMask.Tooltip          = 'Adjust Mask';
    app.Colormap.Tooltip            = 'Colormap';
    app.ContourColor.Tooltip        = 'Contour Color';
    app.ContourButton.Tooltip       = 'Contour';
    app.TransposeButton.Tooltip     = 'Transpose';
    app.PlotMajMin.Tooltip          = 'Plot Major/Minor Axes';
    app.ColorBar.Tooltip            = 'Color Bar';
    app.ViewNetResults.Tooltip      = 'View Processing Steps';
    app.AuxiliaryView.Tooltip       = 'Auxiliary/Raw Image View';
    app.Overwrite.Tooltip           = 'Overwrite Mode';
    app.DarkMode.Tooltip            = 'Dark Mode';
    app.ResetButton.Tooltip         = 'Reset';
    app.InfoTool.Tooltip            = 'Help';
    app.BrowseButton.Tooltip        = 'Browse Save Location';
    app.ExportButton.Tooltip        = 'Export Data';

    % GUI Title page sizing and position adjustment - Source svg is 100 x 512
    L = app.UIAxes.Position(1);
    B = app.UIAxes.Position(4);
    W = app.UIAxes.Position(3);
    H = app.UIAxes.Position(4)*0.2;
    L = L + (W/2) - 196; % a bit off center since sliders / axes are not centered perfectly but want title to align with them
    B = (B + (H/2) + 50);
    W = 512;
    H = 100;
    % Creating the cover as a vector graphic html object and setting icon
%     P = uipanel("Parent", app.AxesTab, 'Position', [L B W H], 'BackgroundColor', [1 1 1], 'BorderType','none');
%     P.Units = 'normalized';
    app.Cover                  = uihtml(app.AxesTab, 'Position', [L B W H]);
%     app.Cover.Units            = 'normalized';
    app.Cover.HTMLSource       = 'GUIRelated\SVGIcons\title.svg';
    app.Cover.HandleVisibility = 'off';

    % Loading up a snapshot of a segmentation example
    app.CoverImage             = imread("SegmentationSnapshot.png");
    app.UIAxes.Position(4)     = 0.8*app.UIAxes.Position(4);
    imagesc(app.UIAxes, app.CoverImage)
    axis(app.UIAxes, 'image')
    app.UIFigure.Icon          = [IconFolder 'guilogo.png']; 
end


function Check4LaTeX(obj)
    % Sets interpreter based on the name of a given parameter (e.g. if user
    % specifies a name in latex notation) and adjusts the alignment based 
    % on interpreter being utilized

    % Get children of a given container
    ChildCheck    = isprop(obj, 'Children');
    if ChildCheck
        Children     = obj.Children;
        N_Containers = numel(Children);
        for i = 1:N_Containers
            % Looking at a single child at a time
            Child          = Children(i);
            if isprop(Child, 'FontName')
                Child.FontName = 'Century Gothic';
            end
            if isprop(Child, 'Text') && (numel(Child.Text) >= 2)
                if strcmp(Child.Text(1:2), '$\')
                    if isprop(Child, 'Interpreter')
                        Child.Interpreter = 'latex';
                    end
                else
                    if isprop(Child, 'Interpreter')
                        Child.Interpreter = 'html';
                    end
                end
            else
            end
            % Recursive function call
            Check4LaTeX(Child)
        end
    else
        % When a ui component has no children, the function returns since
        % there are none that can be set to 
        return
    end
end


