function answer = myInputDlg(prompt, dlgtitle, dims, definput, Parent)
% MYINPUTDLG is a custom input dialog function that is a workaround for
% MATLAB's default input dialog box function. The goal is to prevent
% flicker from the inputdlg pulling the IDE up to the front

    if nargin < 1 || isempty(prompt)
        error('No prompt given')
    end

    % Determines how many edit fields to create
    NFields = numel(prompt);

    if nargin < 2
        dlgtitle = [];
    end

    % Sizes figure according to prompts or given dims (width and height)
    if nargin < 3 || isempty(dims)
        % Need to also consider the length of the dialog box title
        PromptW = cellfun(@(x) size(char(x), 2), prompt);
        MaxW    = max(PromptW);   % max width of prompt
        H       = NFields*40+100;
        titleW  = size(char(dlgtitle), 2)*13;
        W       = max(MaxW*15+50, titleW);
    else
        % Since dims coming in consider the size of a single edit field,
        % need to scale height and width by the number of edit fields and
        % size of text
        TxtSz   = 14;                     % Text size in pixels
        NRows   = (NFields*2+1);          % Edit fields (N rows), labels (N rows), buttons (1 row)
        H       = dims(1)*3*TxtSz*NRows;  % Scales up a little extra to ensure space for padding in grid layout
        H       = H + 50;                 % Consider the padding from gridlayout
        W       = dims(2)*TxtSz;
    end

    % Initializing the answer cell array since answers may hold different
    % datatypes
    answer = cell(NFields, 1);

    if nargin < 4 || isempty(definput)
        % Automatically sets the default input as empty
        definput = cell(NFields, 1);
    else
        % Initializes the answer output when default inputs specified
        answer = definput;
    end

    % Determines where to position the dialog box if called from a GUI
    if nargin < 5 || isempty(Parent)
        Parent = gcbf;
    end
    if ~isempty(Parent)
        % Will center the dialog box over the GUI that called it
        if strcmp(Parent.Units, 'normalized')
            ScrSz = get(0, 'ScreenSize');
            FPos  = Parent.Position.*[ScrSz(3:4) ScrSz(3:4)];
        else
            FPos = Parent.Position;
        end
        B    = FPos(2) + FPos(4)/2 - H/2;
        L    = FPos(1) + FPos(3)/2 - W/2;
        B    = round(B);
        L    = round(L);
    else
        L = 100;
        B = 100;
    end

    % Defines a default position for the dialog box
    Pos = [L B W H];
    
    % Fig constructed w/ number of requested edit fields & desired prompts
    fig = uifigure("WindowStyle", "modal", 'Position', Pos, 'CloseRequestFcn', @CancelPushed, 'Visible', 'off');

    % In case title was specified
    if ~isempty(dlgtitle)
        fig.Name = dlgtitle;
    end

    % Blank icon
    fig.Icon = ones(10, 10, 3);

    % Dynamical set input box proportion of grid depending on number of
    % prompts
    InputProportion     = [num2str(NFields+1) 'x'];
    % Overlay grid layout to maintain larger buttons
    OverallGrid         = uigridlayout(fig, [2 1], 'RowHeight', {InputProportion, '1x'});
    OverallGrid.Padding = [5 5 5 5];
    % Grid layout insures consistent spacing
    GridRows = (2*NFields);
    spaces   = {'1x', '2x'};
    spacing  = repmat(spaces, [1, NFields]);
    grid     = uigridlayout(OverallGrid, [GridRows 1], 'RowHeight', spacing);
    grid.Padding = [5 5 5 5];
    for i = 1:NFields
        PromptQuest          = prompt{i};
        InputFields(i).Label = uilabel(grid, "Text", PromptQuest);
        InputFields(i).Field = uieditfield(grid, "ValueChangedFcn", @(evt, src) UpdateAnswer(evt, src, i), 'Value', definput{i});
    end

    % Grid for the 'ok' and 'cancel' buttons
    ButtonGrid = uigridlayout(OverallGrid, [1 2]);
    uibutton(ButtonGrid, 'push', "ButtonPushedFcn", @OkPushed, 'Text', 'Ok');
    uibutton(ButtonGrid, 'push', "ButtonPushedFcn", @CancelPushed, 'Text', 'Cancel');

    % Makes dialog figure visible
    drawnow             % prevents a flicker in graphical construction
    fig.Visible = 'on';
    

    % Focuses the first edit field so the user can immediately input values
    % and then tab over to the next field / button.
    focus(InputFields(1).Field)

    % Stops execution until the figure is closed / deleted
    uiwait(fig)

    function OkPushed(~, ~)
        % Confirms the changes made to inputs and spits them out in the
        % output variable, answer, after deleting the figure
        fig.delete
    end
    
    function CancelPushed(~, ~)
        % Empties the output variable, answer, and deleted the figure. This
        % doubles as a close request function
        answer = [];
        fig.delete
    end
    
    function UpdateAnswer(~, ~, idx)
        % Updates the output variable, answer, as the edit fields have
        % their values changed
        % Pulling value out
        answer{idx} = InputFields(idx).Field.Value;
    end
end