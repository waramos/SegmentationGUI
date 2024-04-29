function Plugin = PluginTemplate
% SUMMARY:
% PLUGINTEMPLATE lays out the plugin configuration for a parametric 
% segmentation method that uses three parameters.

    % Parameter 1
    Plugin.controls(1).Name   = 'Parameter 1 Name'; % Name of parameter
    Plugin.controls(1).Symbol = '$\...'; % LaTeX formatting for greek letters
    Plugin.controls(1).Units  = '';  % Parameter units
    Plugin.controls(1).Value  = 0;   % Initial default value
    Plugin.controls(1).Min    = 0;   % Lower bound of parameter
    Plugin.controls(1).Max    = 10;  % Upper bound of parameter

    % Parameter 2
    Plugin.controls(2).Name   = '';
    Plugin.controls(2).Symbol = '$\...';
    Plugin.controls(2).Units  = '';
    Plugin.controls(2).Value  = 0;
    Plugin.controls(2).Min    = 0;
    Plugin.controls(2).Max    = 10;

    % Parameter 3
    Plugin.controls(3).Name   = '';
    Plugin.controls(3).Symbol = '$\...';
    Plugin.controls(3).Units  = '';
    Plugin.controls(3).Value  = 0;
    Plugin.controls(3).Min    = 0;
    Plugin.controls(3).Max    = 10;

    % The auto estimation of parameter values
    Plugin.AutoEstimate       = @(I) AutoEstimateParams(I); % Custom parameter auto estimation function

    % Layer struct to feed forward network
    % Layer 1
    Plugin.Layers(1).Name     = 'Function 1 Name';
    Plugin.Layers(1).In       = [1 0 0];
    Plugin.Layers(1).DataName = '';                            % Layer output name
    Plugin.Layers(1).Process  = 'Smooths image';               % Layer purpose
    Plugin.Layers(1).Forward  = @(d, p) Function1(d{1}, p{1}); % Function handle - in this case is using data cell array, index 1 and parameter cell array, index 1 as inputs

    % Layer 2 - mask refinement layer
    Plugin.Layers(2).Name     = 'Function 2 Name';
    Plugin.Layers(2).In       = [0 1 0];
    Plugin.Layers(2).DataName = '';
    Plugin.Layers(2).Process  = '';
    Plugin.Layers(2).Forward  = @(d, p) Function1(d{2}, p{2});

    % Layer 3 - ... computation layer
    Plugin.Layers(3).Name     = '';
    Plugin.Layers(3).In       = [0 0 1];
    Plugin.Layers(3).DataName = '';
    Plugin.Layers(3).Process  = '';
    Plugin.Layers(3).Forward  = @(d, p) Function1(d{3}, p{3});


    function J = Function1(I, p1)
        % Function 1 will transform I with some computations that involve
        % parameter 1.
        J = I;
    end

    function J = Function2(I, p2)
        % Function 2 will transform I with some computations that involve
        % parameter 2.
        J = I;
    end

    function J = Function3(I, p3)
        % Function 3 will transform I with some computations that involve
        % parameter 3.
        J = I;
    end

    function Params = AutoEstimateParams(I)
        % An example of ways in which someone might attempt to find
        % approximately helpful parameter values to start with.
        p1 = mean(I(:));
        p2 = size(I, 1)/10;
        p3 = std(I(:));
        Params = [p1 p2 p3];
    end
end