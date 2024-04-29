
% d      = 'D:\TrainingDataSets\Segmentation\MultiModal\Resized_128x128';

d = 'D:\TrainingDataSets\Segmentation\MultiModal\RandomPatches\DeCentered';
ImDir  = [d filesep 'Images'];
LabDir = [d filesep 'Labels'];
imds   = imageDatastore(ImDir);
labds  = imageDatastore(LabDir);


% Autocontrast option
AutoContrast = false;

% image sizes
M = 128;
N = 128;

nFiles = numel(imds.Files);

% Duration in seconds, Frame rate in FPS
FrameRate = 8;
Duration  = 30;
nFrames   = FrameRate*Duration;
% File frequency is how many files are skipped before viewing the next one
FileFreq  = ceil(nFiles/nFrames);

f       = figure;
f.Color = [1 1 1];
ax      = axes(f);
imH     = [];
pause

dateInfo    = char(datetime('today', 'InputFormat', 'MM_dd_yyyy'));
fname       = ['TrainingDataExample' dateInfo  '.mp4'];
v           = VideoWriter(fname, 'MPEG-4');
v.FrameRate = 8;
v.open

for i = 1:FileFreq:nFiles
    I = imds.readimage(i);
    L = labds.readimage(i);

    % Auto contrasting image
    L        = double(L);
    if AutoContrast 
        I        = double(I);
        I_mf     = medfilt2(I);
        [mn, mx] = bounds(I_mf(:));
        I        = (I-mn)/(mx-mn);
    else
        L = 255*uint8(L);
    end

    % Concatentating images
    J = [I L];

    if isempty(imH)
        imH = imagesc(J);
        axis(ax, 'image')
        ax.XColor = 'none';
        ax.YColor = 'none';
        colormap bone
        clim(ax, [0 255]);
    else
        imH.CData = J;
    end
    

    tmsg = ['Training Dataset - Image ' num2str(i)];
    title(tmsg, 'FontSize', 20)

    rszMsg = ['Images resized to: ' num2str(M) 'x' num2str(N)];
    xlabel(rszMsg, 'FontSize', 16)

    Frame = getframe(f);
    Frame = Frame.cdata;
    v.writeVideo(Frame)
    pause(1/24)
end
v.close