function POS = Seg_BoundaryTool(I, boundarypoints, cmap)
% POS = Seg_BoundaryTool(I, boundarypoints, cmap)
% POS = Seg_BoundaryTool(I, boundarypoints)
% POS = Seg_BoundaryTool(I)
%
% SUMMARY:
% SEG_BOUNDARYTOOL will launch a GUI with an ROI object drawn atop an image
% (if points are given). Otherwise, the user will be allowed to draw an
% ROI. In either case, the user is allowed to the edit the points until
% satisfied with the contour. Clicking the check mark will then return the 
% ROI boundary point values but closing the window will cancel changes.
% 
% INPUTS:
% I - (Required: image array) the image on which the ROI will be drawn.
% Intended Datatypes: uint8, uint16, single, double
%
% boundarypoints - (Nx2 array) if given, a drawfreehand ROI object is 
% created and defined by the points given.
% Intended Datatypes: uint8, uint16, single, double
%
% cmap - (colormap) will display the image with the given colormap.
% Otherwise, bone will be used.
% Intended Datatypes: uint8, uint16, single, double
%
% OUPUTS:
% POS - (Nx2 array) position values for the ROI object to be returned if
% confirmed as correct.
% Intended Datatypes: double

    % Initialization in case no points are given
    if nargin < 2
        boundarypoints = [];
    end

    if nargin < 3
        cmap = bone;
    end

    % Init ROI object var, position var, and ROI type (name) var
    ROI  = [];
    POS  = [];
    name = [];

    % Information on Boundary limits
    nrow = size(I, 1);
    ncol = size(I, 2);

    % Check if image is RGB
    RGBFlag   = size(I, 3) == 3;

    % Figure window
    fig       = uifigure('Units','normalized', 'Position', [0.1 0.1 0.8 0.8], ...
                         'Name', 'Taper Boundary Tool', ...
                         'CloseRequestFcn', @CustomClose);
    fig.Visible = false;
    ax          = uiaxes(fig, 'Units', 'normalized', 'Position', [0 0 1 1]);
    ax.YTick    = [];
    ax.XTick    = [];
    ax.XColor   = 'none';
    ax.YColor   = 'none';

    % Toolbar with different ROI types, reset button, manual contrast tool,
    % ROI deletion, and ROI confirmation
    tb           = uitoolbar(fig);
    IconFolder   = ['SVGIcons' filesep];
    if exist(IconFolder, 'dir') == 7
        figicon      = [IconFolder 'style-border.png'];
        fid1         = [IconFolder 'frame-simple.svg'];
        fid2         = [IconFolder 'frame.svg'];
        fid3         = [IconFolder 'edit-pencil.svg'];
        fid4         = [IconFolder 'restart.svg'];
        fid5         = [IconFolder 'brightness-window.svg'];
        fid6         = [IconFolder 'trash.svg'];
        fid7         = [IconFolder 'cancel.svg'];
        fid8         = [IconFolder 'accept.svg'];
    else
        figicon      = [ipticondir filesep 'DrawROI_24.png'];
        fid1         = [ipticondir filesep 'draw_rectangle_24.png'];
        fid2         = [ipticondir filesep 'draw_polygon_24.png'];
        fid3         = [ipticondir filesep 'DrawFreehand_24.png'];
        fid4         = [ipticondir filesep 'Reset_24.png'];
        fid5         = [ipticondir filesep 'tool_contrast.png'];
        fid6         = [ipticondir filesep 'ClearAll_24.png'];
        fid7         = [ipticondir filesep 'failed_24.png'];
        fid8         = [ipticondir filesep 'CreateMask_24px.png'];
    end
    fig.Icon     = figicon;
    pt1          = uipushtool(tb, 'Icon', fid1, 'ClickedCallback', @DrawROI);
    pt2          = uipushtool(tb, 'Icon', fid2, 'ClickedCallback', @DrawROI);
    pt3          = uipushtool(tb, 'Icon', fid3, 'ClickedCallback', @DrawROI);
    pt4          = uipushtool(tb, 'Icon', fid4, 'ClickedCallback', @DrawROI);
    pt5          = uipushtool(tb, 'Icon', fid5, 'ClickedCallback', @ManContrast);
    pt6          = uipushtool(tb, 'Icon', fid6, 'ClickedCallback', @ClearROI);
    pt7          = uipushtool(tb, 'Icon', fid7, 'ClickedCallback', @CustomClose);
    pt8          = uipushtool(tb, 'Icon', fid8, 'ClickedCallback', @ConfirmROI);

    % User Data field gives callbacks more info
    pt1.UserData = 'rect';
    pt2.UserData = 'poly';
    pt3.UserData = 'free';
    pt4.UserData = 'reset';
    pt5.UserData = 'contrast';
    pt6.UserData = 'clear';
    pt7.UserData = 'cancel';
    pt8.UserData = 'done';

    % Tooltips to give user a hint
    pt1.Tooltip  = 'Rectangle ROI';
    pt2.Tooltip  = 'Polygon ROI';
    pt3.Tooltip  = 'Freehand ROI';
    pt4.Tooltip  = 'Reset ROI';
    pt5.Tooltip  = 'Manual Contrast';
    pt6.Tooltip  = 'Clear ROI';
    pt7.Tooltip  = 'Cancel';
    pt8.Tooltip  = 'Done';

    % Ensure figure is in the middle and focused
    centerfig(fig)
    figure(fig)

    % Plotting image
    iH = imagesc(ax, I);
    axis(ax, 'image');
    colormap(ax, cmap)

    % Simple Autocontrasting of image
    AutoAdjustContrast(ax);

    if ~isempty(boundarypoints)
        ROI = images.roi.Freehand(ax, 'Position', boundarypoints, 'FaceAlpha', 0.1);
    end


    function EnableButtons(flag)
        % ENABLEBUTTONS will disable the push tool buttons for drawing
        % ROIs while the user is in the midst of drawing an ROI to ensure
        % that multiple ROIs cannot be drawn.
        if flag
            pt1.Enable = 'on';
            pt2.Enable = 'on';
            pt3.Enable = 'on';
            pt4.Enable = 'on';
        else
            pt1.Enable = 'off';
            pt2.Enable = 'off';
            pt3.Enable = 'off';
            pt4.Enable = 'off';
        end
    end

    function DrawROI(src, ~)
        % Determines which type of ROI was drawn in order to determine how
        % to process the resulting position points from the contour
        if nargin == 2
            name = src.UserData;
        end

        uiresume(fig)
        drawnow

        if exist('ROI', 'var') && ~isempty(ROI)
            ROI.delete
            ROI = [];
        end
        
        % Turn buttons off
        EnableButtons(false)

        % Drawing a rectangular ROI
        if strcmp(name, 'rect')
            ROI = drawrectangle(ax, 'FaceAlpha', 0.1);

        % Drawing a polygon ROI
        elseif strcmp(name, 'poly')
            ROI = drawpolygon(ax, 'FaceAlpha', 0.1);

        % Drawing a freehand ROI
        elseif strcmp(name, 'free')
            ROI = drawfreehand(ax, 'FaceAlpha', 0.1);

        % Resetting will just have the user return to a freehand object
        % representing the original boundary given to the tool
        elseif strcmp(src.UserData,'reset')
            if ~isempty(boundarypoints)
                ROI = drawfreehand(ax, 'Position', boundarypoints, 'FaceAlpha', 0.1);
            end
            EnableButtons(true)
        end

        % Will exit in case the user closes the window mid drawing
        if ~isvalid(fig)
            return
        end

        if ~isempty(ROI) && isvalid(ROI)
            addlistener(ROI, 'ROIMoved', @UpdatePOS);
            addlistener(ROI, 'MovingROI', @UpdatePOS);
        end
        UpdatePOS([], [])
    end

    % Updates the position - either when ROI moved or check mark clicked
    function UpdatePOS(~, ~)
        if ~isempty(ROI) && isvalid(ROI)
            POS = ROI.Position;
            % If the ROI object is a rectangle, the boundary points are
            % organized differently than for other ROI types
            if strcmp(name, 'rect')
                % Settings limits on y boundary
                POSy = [POS(2); POS(2); POS(2)+POS(4); POS(2)+POS(4); POS(2)];
                POSy(POSy<1)    = 1;
                POSy(POSy>nrow) = nrow;

                % Settings limits on x boundary
                POSx = [POS(1); POS(1)+POS(3); POS(1)+POS(3); POS(1); POS(1)];
                POSx(POSx<1)    = 1;
                POSx(POSx>ncol) = ncol;
                POS = [POSx, POSy];
            else
                % Correct x values that go beyond bounds
                ROI.Position(ROI.Position(:, 1) < 1, 1)    = 1;
                ROI.Position(ROI.Position(:, 1) > ncol, 1) = ncol;
                % Correct y values that go beyond bounds
                ROI.Position(ROI.Position(:, 2) < 1, 2)    = 1;
                ROI.Position(ROI.Position(:, 2) > nrow, 2) = nrow;
                POS = ROI.Position;
            end
        else
            % In case the ROI no longer exists and the user tries to exit
            if ~isempty(boundarypoints)
                % Correct x values that go beyond bounds
                boundarypoints(boundarypoints(:, 1) < 1, 1)    = 1;
                boundarypoints(boundarypoints(:, 1) > ncol, 1) = ncol;
                % Correct y values that go beyond bounds
                boundarypoints(boundarypoints(:, 2) < 1, 2)    = 1;
                boundarypoints(boundarypoints(:, 2) > nrow, 2) = nrow;
                BP = boundarypoints;
                boundarypoints = [BP(1,1) BP(1,2); BP(2,1) BP(1,2); BP(2,1) BP(2,2); BP(1,1) BP(2,2); BP(1,1) BP(1,2)];
            else
                boundarypoints = [1 1; ncol 1; ncol nrow; 1 nrow; 1 1];
            end
            POS = boundarypoints;
        end

        % If contour loop is not closed, this will close it
        if any(POS(1,:) ~= POS(end,:))
            POS(end+1, :) = POS(1, :);
        end
    end

    % Clears ROI object
    function ClearROI(~, ~)
        if ~isempty(ROI) && isvalid(ROI)
            ROI.delete
            ROI = [];
            EnableButtons(true)
            boundarypoints = [1 1; size(I, [1 2])];
            UpdatePOS
            fig.delete
        end
    end

    % Manual contrast
    function ManContrast(~, ~)
        focus(fig)
        if ~RGBFlag
            imcontrast(iH)
        end
    end

    % Will return the boundary points based off of the ROI and close the
    % tool
    function ConfirmROI(~, ~)
        UpdatePOS
        fig.delete
    end

    function CustomClose(~, ~)
        % Will cancel the changes to boundary points
        POS   = boundarypoints;
        fig.delete
    end

    % Leaves the GUI running and does not return output until the user
    % closes the GUI (figure window) or confirms the ROI
    waitfor(fig)
end