function Check4ToolBoxes(tlbxList)
    if nargin < 1
        tlbxList = {'Image Processing Toolbox', 'Image Acquisition Toolbox', 'Deep Learning Toolbox'};
    end
    
    vInfo      = ver;
    tList      = {vInfo.Name};
    N          = length(tList);
    missingIdx = zeros(1, length(tlbxList), 'logical');

    % Checking that each of the given toolboxes is installed
    for i = 1:N
        ToolBoxName = tList{i};
        missingT    = strcmp(ToolBoxName, tlbxList);
        missingIdx  = missingT | missingIdx;
    end

    % Gets the missing toolboxes
    missingIdx = ~missingIdx;

    % Launches warning dialog box if any toolboxes are missing
    if any(missingIdx)
        missingT = tlbxList(missingIdx);
        msg      = ['The following toolboxes are needed for the graphical user interface to function properly:' newline newline];
        for i = missingT
                msg = [msg '-- ' i{:} newline];
        end
        warndlg(msg, 'Missing Toolboxes');
    end
end