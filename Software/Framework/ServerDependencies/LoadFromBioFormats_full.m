function V = LoadFromBioFormatsAsVol(s)
% LOADFROMBIOFORMATS will load in a bioformats image file without lazy
% loading and unpack into a volume (3D stack).
    V = bfOpen3DVolume(s);
    V = V{1};
    V = V{1};
end