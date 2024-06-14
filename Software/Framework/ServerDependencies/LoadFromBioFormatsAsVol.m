function V = LoadFromBioFormatsAsVol(s)
% LOADFROMBIOFORMATSASVOL will load in a bioformats image file without lazy
% loading and unpack into a volume (3D+ array).
    V = bfOpen3DVolume(s);
    V = V{1};
    V = V{1};
end