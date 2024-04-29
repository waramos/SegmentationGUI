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