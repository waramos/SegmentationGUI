function fHandle = SelectFunctionFromFolder(folder, listTitle, nflag, methodName)

    % Current figure 
    if nargin < 4
        methodName = 'None';
    end
    if nargin < 3
        nflag = true;
    end

    if nargin < 2
        listTitle = 'Please select function';
    end

    if nargin < 1 || isempty(folder)
        f      = mfilename('fullpath');
        folder = fileparts(f);
    end

    % Extracting file names for the folder
    fcont    = dir(folder);
    C        = {fcont.name};
    isfun    = cellfun(@(x) contains(x, '.m'), C);
    file_idx = ~[fcont.isdir];
    file_idx = isfun | file_idx;
    fcont    = fcont(file_idx);
    n        = numel(fcont);
    flist    = cell(n, 1);
    for i = 1:n
        name         = fcont(i).name;
        [~, name, ~] = fileparts(name);
        name         = AddRmStrSpace(name);
        flist{i}     = name;
    end

    % In case a none option is desired
    if nflag
        flist{end+1} = 'None';
    end

    % Launch list dialog selection 
    Parent = gcbf;
    name   = myListDlg(flist, listTitle, 'Select denoise method', [], methodName, Parent);

    if ~isempty(name) && ~strcmp(name, 'None')
        name    = AddRmStrSpace(name, false);
        name    = ['@' name];
        fHandle = eval(name);
    elseif isempty(name)
        fHandle = [];
    elseif strcmp(name, 'None')
        fHandle = NaN;
    end
end