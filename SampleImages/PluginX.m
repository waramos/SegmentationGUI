


function  plugin = PluginX()

% slider configuration. These are the control settings for the sliders and
% parameters. Some entries left out, you can add them if needed.
plugin.controls(1).Name   = 'sigma1';
plugin.controls(1).Min    = eps;
plugin.controls(1).Max    = 10;
plugin.controls(1).Value  = 1;
plugin.controls(2).Name   = 'sigma2';
plugin.controls(2).Min    = 1;
plugin.controls(2).Max    = 25;
plugin.controls(2).Value  = 3;
plugin.controls(3).Name   = 'threshold';
plugin.controls(3).Min    = eps;
plugin.controls(3).Max    = 100;
plugin.controls(3).Value  = 15;

plugin.flow = [1 1 2];

% variables in handles:
% i is the cell array of images 
% i.e. i{1} is the input image, i{2} the output of layer1 going to layer 2, etc
% this is better than a stack or such, since the images can be different
% data types, or even point clouds etc.
% p is the cellarray of parameters. I used a cell array to match i, a
% vector would work too. Using the same syntax seemed more symmetric and
% also would allow more generality down the road. i.e. the first param is
% p{1}, second is p{2} etc

% Feed Forward Network
plugin.Layers(1).Forward     = @(i,p) imgaussfilt(i{1},p{1})-imgaussfilt(i{1},p{2});
plugin.Layers(1).In          = [1 1 0];

plugin.Layers(2).Forward     = @(i,p) double(i{2}>p{3});
plugin.Layers(2).In          = [0 0 1];

% version that uses multiple image matrices
% plugin.Layers(1).Forward     = @(i,p) imgaussfilt(i{1},p{1})-imgaussfilt(i{1},p{2});
% plugin.Layers(2).In          = [1 1 0];
% plugin.Layers(2).Forward     = @(i,p) double((i{1}>p{3})&(i{2}>p{3}));
% plugin.Layers(2).In          = [0 0 1];



% version that uses a single layer
% plugin.Layers(1).Forward     = @(i,p) double((imgaussfilt(i{1},p{1})-imgaussfilt(i{1},p{2}))>p{3});
% plugin.Layers(1).In           = [1 1 1];

% same as
% plugin.Layers(1).Forward     = @(i,p) SomeFunk(i{1},p{1},p{2},p{3});
% plugin.Layers(1).In           = [1 1 1];

% example with three layers
% plugin.Layers(1).Forward     = @(i,p) imgaussfilt(i{1},p{1});
% plugin.Layers(1).In          = [1 0 0];
% plugin.Layers(2).Forward     = @(i,p) i{2}-imgaussfilt(i{2},sqrt(max(0,p{2}^2-p{1}^2)));
% plugin.Layers(1).In          = [0 1 0];
% plugin.Layers(3).Forward     = @(i,p) double(i{3}>p{3});
% plugin.Layers(1).In          = [0 0 1];



end