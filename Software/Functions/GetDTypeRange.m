function drange = GetDTypeRange(Data)
% GETDTYPERANGE enables rescaling of parameter values to a range of 0-1 by
% understanding the range of possible values, given a particular datatype.
%
% Data expected to be an array or matrix.
    dtype = underlyingType(Data);
    switch dtype
        case 'uint8'
            drange = [0 255];
        case 'uint16'
            drange = [0 65535];
        case 'single'
            drange = [-(2^31 - 1) (2^31 - 1)];
        case 'double'
            drange = [-(2^63 - 1) (2^63 - 1)];
    end
end