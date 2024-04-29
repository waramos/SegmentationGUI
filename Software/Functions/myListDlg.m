function answer = myListDlg(List, dlgtitle, prompt, dims, defchoice, Parent)
% MYINPUTDLG is a custom input dialog function that is a workaround for
% MATLAB's default input dialog box function. The goal is to prevent
% flicker from the inputdlg pulling the IDE up to the front

    if nargin < 1 || isempty(List)
        error('No list given')
    end

    % Determines how many edit fields to create
    NFields = numel(List);

    if nargin < 2
        dlgtitle = [];
    end

    % Question to prompt user to select a choice from the list
    if nargin < 3
        prompt = 'Select one of the following:';
    end

    % Sizes figure according to list choice with most characters, the size
    % of title of the list box, or the prompt being asked
    if nargin < 4 || isempty(dims)
        % This might need some adjustments since the list, dlgtitle, and
        % prompt take up different spaces
        PromptW = cellfun(@(x) size(char(x), 2), [List(:)', dlgtitle, prompt]);
        MaxW    = max(PromptW);
        H       = NFields*35+100;
        titleW  = size(char(dlgtitle), 2)*13;
        W       = max(MaxW*5.5+50, titleW);
    else
        % Since dims coming in consider the size of a single edit field,
        % need to scale height and width by the number of edit fields and
        % size of text
        TxtSz   = 12;                     % Text size in points
        NRows   = (NFields*2+1);          % Edit fields (N rows), labels (N rows), buttons (1 row)
        H       = dims(1)*3*TxtSz*NRows;  % Scales up a little extra to ensure space for padding in grid layout
        H       = H + 50;                 % Consider the padding from gridlayout
        W       = dims(2)*TxtSz;
    end

    if nargin < 5 || isempty(defchoice)
        % Automatically sets the default selection as the first option
        defchoice = List{1};
    end
    
    % Initializes the answer output when default inputs specified
    answer = defchoice;

    % Determines where to position the dialog box if called from a GUI
    if nargin < 6 || isempty(Parent)
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
    Pos = [L B W H*.8];
    
    % Fig constructed w/ number of requested edit fields & desired prompts
    fig = uifigure("WindowStyle", "modal", 'Position', Pos, 'CloseRequestFcn', @CancelPushed, 'Visible', 'off');
    if isempty(Parent)
        centerfig(fig)
    end

    % In case title was specified
    if ~isempty(dlgtitle)
        fig.Name = dlgtitle;
    end

    % Blank icon
    fig.Icon = ones(10, 10, 3);

    % Dynamically set input box proportion of grid depending on number of
    % prompts
    ListProportion      = [num2str((NFields+1)/2.8) 'x'];
    % Overlay grid layout to maintain larger ok and cancel buttons
    OverallGrid         = uigridlayout(fig, [3 1], 'RowHeight', {'0.5x', ListProportion, '1.1x'});
    OverallGrid.Padding = [5 5 5 5];
    % Prompt / question above list
    uilabel(OverallGrid, 'Text', prompt, 'WordWrap', 'on');
    % List of options
    ListBox             = uilistbox(OverallGrid, 'Items', List, 'Value', defchoice, 'Multiselect','off', 'ValueChangedFcn', @UpdateAnswer);

    % Grid for the 'ok' and 'cancel' buttons
    ButtonGrid = uigridlayout(OverallGrid, [1 2]);
    uibutton(ButtonGrid, 'push', "ButtonPushedFcn", @OkPushed, 'Text', 'Ok');
    uibutton(ButtonGrid, 'push', "ButtonPushedFcn", @CancelPushed, 'Text', 'Cancel');

    % Makes dialog figure visible
    drawnow             % prevents a flicker in graphical construction
    fig.Visible = 'on';
    

    % Focuses the first edit field so the user can immediately input values
    % and then tab over to the next field / button.
    focus(ListBox)

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
    
    function UpdateAnswer(~, ~)
        % Updates the output variable, answer, as the edit fields have
        % their values changed
        % Pulling value out
        answer = ListBox.Value;
    end
end