function [POS, Img] = Seg_CropTool(I, CropCoords, cmap)
% POS = Seg_BoundaryTool(I, boundarypoints, cmap)
% POS = Seg_BoundaryTool(I, boundarypoints)
% POS = Seg_BoundaryTool(I)
%
% SUMMARY:
% SEG_CROPTOOL will launch a GUI with an ROI object drawn atop an image
% (if points are given). Otherwise, the user will be allowed to draw an
% ROI. In either case, the user is allowed to the edit the points until
% satisfied with the contour. Clicking the check mark will then return the 
% ROI boundary point values but closing the window will cancel changes.
% 
% INPUTS:
% I - (Required: image array) the image on which the ROI will be drawn.
% Intended Datatypes: uint8, uint16, single, double
%
% CropCoords - (2x2 array) initial crop if given, a rectanglular ROI object
% is created and defined by the points given.
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
        CropCoords = [];
    end

    if nargin < 3
        cmap = bone;
    end

    % Init ROI object var, position var, and ROI type (name) var
    ROI  = [];
    POS  = [];
    name = [];
    Img  = [];

    % Determining if RGB
    RGBFlag = size(I, 3) == 3;

    % Figure window    
    fig         = uifigure('Units','normalized', 'Position', [0.1 0.1 0.8 0.8], ...
                  'Name', 'Crop Tool', ...
                  'CloseRequestFcn', @CustomClose, 'Visible','off');
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
        figicon      = [IconFolder 'crop.png'];
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
    pt6.Tooltip  = 'Discard Crop';
    pt7.Tooltip  = 'Cancel';
    pt8.Tooltip  = 'Done';

    % Centers the figure
    centerfig(fig)
    figure(fig)

    % Turn off manual contrast if the image is RGB
    if RGBFlag
        pt5.Enable = false;
    end

    % Information on Boundary limits
    m = size(I, 1);
    n = size(I, 2);

    % Plotting image
    iH = imagesc(ax, I);
    axis(ax, 'image');
    if ~RGBFlag
        colormap(ax, cmap)
    end

    % Simple Autocontrasting of image if grayscale, otherwise left alone
    AutoAdjustContrast(ax);

    % Turns the figure visible again after plotting
    drawnow
    fig.Visible = true;

    if ~isempty(CropCoords)
        % If image was previously cropped, old crop region shows up in the
        % GUI window
        if size(CropCoords, 1) > 1
            % In case the coordinates are formatted as a 2x2 array
            CropCoords = [CropCoords(1,:) CropCoords(2,:)];
        end
        CropCoords = [CropCoords(1:2), CropCoords(3:4)-CropCoords(1:2)];
        ROI        = drawrectangle(ax, 'Position', CropCoords(:)', 'FaceAlpha', 0.1);
        name       = 'rect';
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

        % Focuses the GUI to get rid of blue outline around buttons
        focus(fig)

        % Clears previous ROI so a new one can be drawn
        if ~isempty(ROI) && isvalid(ROI)
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

        % Resetting will just have the user return to a rectangle object
        % representing the original crop region given to the tool (if one
        % was given)
        elseif strcmp(src.UserData,'reset')
            if ~isempty(CropCoords)
                ROI = drawrectangle(ax, 'Position', CropCoords, 'FaceAlpha', 0.1);
            elseif ~isempty(ROI) && isvalid(ROI)
                ROI.delete
                ROI = [];
            end
        end

        % Will exit in case the user closes the window mid drawing
        if ~isvalid(fig)
            return
        end

        % Turn buttons back on
        EnableButtons(true)

        if ~isempty(ROI) && isvalid(ROI)
            addlistener(ROI, 'ROIMoved', @UpdatePOS);
            addlistener(ROI, 'MovingROI', @UpdatePOS);
        end
    end

    function UpdatePOS(~, ~)
        % Updates the POS variable to hold the coordinates of the drawn ROI
        % so that the GUI returns the coordinates in a 2x2 matrix with x
        % coordinates in the first column and y coordinates in the second
        % column
        if ~isempty(ROI) && isvalid(ROI)
            POS = ROI.Position;
            % If the ROI object is a rectangle, the boundary points are
            % organized differently than for other ROI types
            if strcmp(name, 'rect')
                % The 1x4 vector converted to a 2x2 array
                POS = [POS(1:2); POS(1:2)+POS(3:4)];
            else
                % Bounding box for user defined ROI 
                POSx = [min(POS(:,1)) max(POS(:,1))];
                POSy = [min(POS(:,2)) max(POS(:,2))];
                POS  = [POSx' POSy'];
            end
        else
            % In case the ROI no longer exists and the user tries to exit
            POS = CropCoords;
            if ~isempty(POS)
                % The 1x4 vector converted to a 2x2 array
                if size(POS, 2) == 4
                    POS = [POS(1:2); POS(1:2)+POS(3:4)];
                end
            else
                POS = [1 1; size(I, [2 1])];
            end
        end

        % Ensures integer values and bound check for a valid crop
        POS      = round(POS);
        POS      = max(1, POS);
        POS(2,1) = min(n, POS(2,1));
        POS(2,2) = min(m, POS(2,2));

        if nargout == 2
            I = I(POS(1,2):POS(2,2), POS(1,1):POS(2,1));
        end
    end

    function ClearROI(~, ~)
        % Clears ROI object
        if ~isempty(ROI) && isvalid(ROI)
            ROI.delete
            ROI = [];
        end
        CropCoords = [1 1; size(I, [2 1])];
        UpdatePOS
        fig.delete
    end

    function ManContrast(~, ~)
        % Manual contrast
        focus(fig)
        if ~RGBFlag
            imcontrast(iH)
        end
    end

    function ConfirmROI(~, ~)
        % Will return the boundary points based off of the ROI and close the
        % tool
        UpdatePOS
        fig.delete
    end

    function CustomClose(~, ~)
        % Will cancel the changes to boundary points
        if ~isempty(CropCoords)
            POS = CropCoords;
            % The 1x4 vector converted to a 2x2 array
            POS = [POS(1:2); POS(1:2)+POS(3:4)];
        end
        fig.delete
    end

    % Leaves the GUI running and does not return output until the user
    % closes the GUI (figure window) or confirms the ROI
    waitfor(fig)
end