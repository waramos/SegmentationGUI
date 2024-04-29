function SetAppInterrupt(app, interrupt, BusyAction)
% SETAPPINTERRUPT recursively looks at all children of a UIFigure and set
% the interruptible property to be the same across all children. It will
% also set the busy action property so that callback execution control is
% consistent across all components of the figure.
    if nargin < 3
        BusyAction = 'cancel';
    end
    if nargin < 2
        interrupt = 'on';
    end

    if isa(app, 'matlab.ui.Figure')
        obj = app;
    else
        obj = app.UIFigure;
    end

    % Will pull out the containers and their respective children and then
    % set the interruptible and busy action as well
    SetChildren(obj, interrupt, BusyAction)
end

function SetChildren(obj, interrupt, BusyAction)
    if nargin < 3
        BusyAction = 'cancel';
    end
    if nargin < 2
        interrupt = 'on';
    end
    % Get children of a given container
    ChildCheck    = isprop(obj, 'Children');
    if ChildCheck
        Children     = obj.Children;
        N_Containers = numel(Children);
        for i = 1:N_Containers
            % Looking at a single child at a time
            Child          = Children(i);
            % Sets overall interrupt for a container to be on
            SetObjInterrupt(Child, interrupt, BusyAction)
            % Recursively set the interrupt and busy action
            SetChildren(Child)
        end
    else
        % When a ui component has no children, the function returns since
        % there are none that can be set to 
        return
    end
end


function SetObjInterrupt(objProp, interrupt, BusyAction)
    % Sets the interrupt to be on and cancellable
    InterruptCheck = isprop(objProp, 'Interruptible');
    if InterruptCheck
        objProp.Interruptible = interrupt;
        objProp.BusyAction    = BusyAction;
    end
end