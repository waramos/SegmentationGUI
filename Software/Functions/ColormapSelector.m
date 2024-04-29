function cmap = ColormapSelector(depth)
% cmap = ColormapSelector(depth)
% cmap = ColormapSelector()
%
% SUMMARY:
% COLORMAPSELECTOR will return a premade colormap according to the user's
% selection.
%
% INPUTS:
% depth - (colormap depth) determines the number of rows in the matrix that
% describes the colormap (i.e. resolution of map).
% Intended Datatypes: uint8, uint16, single, double
%
% OUTPUTS:
% cmap - (colormap) the predefined colormap with requested depth
% Intended Datatypes: uint8, uint16, single, double

    if nargin < 1 || depth < 1
        depth = 1024;
    end

    % In case someone enters an decimal value
    depth = round(depth);
    
    choices = {'Gray','Fire','Ice','Emerald','Bone','Solar','Thermal',...
    'Haline','Polar','DarkPolar','Ultra','Spectrum','Scatter',...
    'Ocean','Red','Green','Blue','Yellow','Inverted','Parula','DarkParula', 'CoolMagma'};

    idx = listdlg('ListString',choices, 'SelectionMode', 'single');
    if isempty(idx)
        % If window was closed, can assume user was happy with previous
        % colormap choice
        return
    end

    % Evaluates the colormap function
    map  = choices{idx(1)};
    cmap = feval(map, depth);
end

function cmap = DarkParula(N)
    n    = round(2*N/3);
    cmap = parula(n);
    cmap = [linspace(0,1,round(N/3))'.*cmap(1,:);cmap]; 
end

function cmap = Gray(N)
    cmap = gray(N);
end

function cmap = Fire(N)

    n1    = round(N/3); n2 = round(2*N/3); n3 = N;
    Blue  = [zeros(1,n2) linspace(0,1,n3-n2)];
    Green = [zeros(1,n1) linspace(0,1,n2-n1) ones(1,n3-n2)];
    Red   = [linspace(0,1,n1) ones(1,n3-n1)];
    cmap  = [Red(:) Green(:) Blue(:)];

end

function cmap = Ice(N)

    n1    = round(N/3); n2 = round(2*N/3); n3 = N;
    Red   = [zeros(1,n2) linspace(0,1,n3-n2)];
    Green = [zeros(1,n1) linspace(0,1,n2-n1) ones(1,n3-n2)];
    Blue  = [linspace(0,1,n1) ones(1,n3-n1)];
    cmap  = [Red(:) Green(:) Blue(:)];

end

function cmap = Emerald(N)

    n1    = round(N/3); n2 = round(2*N/3); n3 = N;
    Blue  = [zeros(1,n2) linspace(0,1,n3-n2)];
    Red   = [zeros(1,n1) linspace(0,1,n2-n1) ones(1,n3-n2)];
    Green = [linspace(0,1,n1) ones(1,n3-n1)];
    cmap  = [Red(:) Green(:) Blue(:)];

end

function cmap = Bone(N)
    levels = linspace(0,1,N);
    cmap   = [levels(:) levels(:) levels(:)];
end

function cmap = Solar(N)
    n1    = round(N/3); n2 = round(2*N/3); n3 = N;
    Blue  = [zeros(1,n2) linspace(0,1,n3-n2)];
    Green = [linspace(0,1,n2) ones(1,n3-n2)];
    Red   = [linspace(0,1,n1) ones(1,n3-n1)];
    cmap  = [Red(:) Green(:) Blue(:)];
end

function cmap = Thermal(N)
    if mod(N,2)==0
        N=N+1;
    end

    n = floor(N/2);

    n1     = round(n/3); 
    n2     = round(2*n/3); 
    n3     = n;
    Red    = [zeros(1,n2) linspace(0,1,n3-n2)];
    Green  = [zeros(1,n1) linspace(0,1,n2-n1) ones(1,n3-n2)];
    Blue   = [linspace(0,1,n1) ones(1,n3-n1)];
    IceMap = [Red(:) Green(:) Blue(:)];

    n1      = round(n/3); n2 = round(2*n/3); n3 = n;
    Blue    = [zeros(1,n2) linspace(0,1,n3-n2)];
    Green   = [zeros(1,n1) linspace(0,1,n2-n1) ones(1,n3-n2)];
    Red     = [linspace(0,1,n1) ones(1,n3-n1)];
    FireMap = [Red(:) Green(:) Blue(:)];

    cmap    = [flipud(IceMap);0 0 0;FireMap];
end

function cmap = Ultra(N)
    n1    = round(N/3); n2 = round(2*N/3); n3 = N;
    Green = [zeros(1,n2) linspace(0,1,n3-n2)];
    Blue  = [linspace(0,1,n2) ones(1,n3-n2)];
    Red   = [linspace(0,1,n1) ones(1,n3-n1)];
    cmap  = [Red(:) Green(:) Blue(:)];
end

function cmap = Ocean(N)
    n2    = round(2*N/3); n3 = N;
    Blue  = [zeros(1,n2) linspace(0,1,n3-n2)];
    Green = [linspace(0,1,n2) fliplr(linspace(0,1,n3-n2))];
    Red   = zeros(1,N);
    cmap  = [Red(:) Green(:) Blue(:)];
end

function cmap = Haline(N)
  colors = [...
      0 0 0;...
      0 0 1;...
      0 0.5 1;...
      0 1 0.5;...
      1 1 0;...
      1 1 1];
  [x,y]   = meshgrid(1:3,1:size(colors,1));
  [xf,yf] = meshgrid(1:3,linspace(1,size(colors,1),N));
  cmap    = interp2(x,y,colors,xf,yf);
end

function cmap = Polar(N)
  colors = [...
      0 0 1;...
      1 1 1;...
      1 0 0];
  [x,y]   = meshgrid(1:3,1:size(colors,1));
  [xf,yf] = meshgrid(1:3,linspace(1,size(colors,1),N));
  cmap    = interp2(x,y,colors,xf,yf);
end

function cmap = DarkPolar(N)
  colors = [...
      0 0 1;...
      0 0 0;...
      1 0 0];
  [x,y]   = meshgrid(1:3,1:size(colors,1));
  [xf,yf] = meshgrid(1:3,linspace(1,size(colors,1),N));
  cmap    = interp2(x,y,colors,xf,yf);
end

function cmap = Red(N)
  colors = [...
      1 1 1;...
      1 0 0];
  [x,y]   = meshgrid(1:3,1:size(colors,1));
  [xf,yf] = meshgrid(1:3,linspace(1,size(colors,1),N));
  cmap    = interp2(x,y,colors,xf,yf);
end

function cmap = Green(N)
  colors = [...
      1 1 1;...
      0 1 0];
  [x,y]   = meshgrid(1:3,1:size(colors,1));
  [xf,yf] = meshgrid(1:3,linspace(1,size(colors,1),N));
  cmap    = interp2(x,y,colors,xf,yf);
end

function cmap = Blue(N)
  colors = [...
      1 1 1;...
      0 0 1];
  [x,y]   = meshgrid(1:3,1:size(colors,1));
  [xf,yf] = meshgrid(1:3,linspace(1,size(colors,1),N));
  cmap    = interp2(x,y,colors,xf,yf);
end

function cmap = Yellow(N)
  colors = [...
      0 0 0;...
      1 1 0];
  [x,y]   = meshgrid(1:3,1:size(colors,1));
  [xf,yf] = meshgrid(1:3,linspace(1,size(colors,1),N));
  cmap    = interp2(x,y,colors,xf,yf);
end

function cmap = Inverted(N)
     colors = [...
      1 1 1;...
      0 0 0];
  [x,y]   = meshgrid(1:3,1:size(colors,1));
  [xf,yf] = meshgrid(1:3,linspace(1,size(colors,1),N));
  cmap    = interp2(x,y,colors,xf,yf);
end

function cmap = Spectrum(N)
    colors = [...
      0.5 1 0;...
      1 0 0;...
      0.1 0.5 0;...
      1 1 0;...
      0 1 1;...
      0 0 1;...
      0.5 0 1;...
      1 0.2 1];
  [x,y]   = meshgrid(1:3,1:size(colors,1));
  [xf,yf] = meshgrid(1:3,linspace(1,size(colors,1),N));
  cmap    = interp2(x,y,colors,xf,yf);
end

function cmap = Parula(N)
    cmap = parula(N);
end

function cmap = Scatter(N)
    cmap      = parula(N);
    cmap(1,:) =[1 1 1];
    cmap      = imfilter(cmap,ones(5,1)/5,'replicate');
    cmap(1,:) =[1 1 1];
end

function cmap = CoolMagma(N)
    cmap = 1 - flipud(Haline(N));
end

