% Fast Tiff writer
% Usage: FWTiff('...') where '...' is 'tiff','bigtiff', 'auto'
%  (1) FWTiff.Open(filename), (2) FWTiff.Write(matrix), (3) FWTiff.Close
% [MP]
classdef FWTiff < handle
    properties (Access=public)
        transpose (1,1) {mustBeInRange(transpose,0,1), mustBeInteger} = 1  % Transpose input to match expected image coordinates?
        version   (1,1) {mustBeInteger}                               = 0  % Tiff version to use: Accepted values: 42 (TIFF), 43 (BIGTIFF), 0 (AUTO)
        verbose   (1,1) {mustBeInRange(verbose,0,1), mustBeInteger}   = 1  % Verbose mode?
    end
    
    properties (Access=private)
        fID       = -1  % Open file ID
        fname     = []  % Open file name
        tagNames  = {'ImageWidth','ImageLength','BitsPerSample','Compression','PhotometricInterpretation','StripOffsets','SamplesPerPixel','StripByteCounts','PlanarConfiguration'}
        tagIDs    = {         256,          257,            258,          259,                        262,           273,              277,              279,                 284 }
        tagTYPE42 = {           4,            4,              3,            3,                          3,             4,                3,                4,                   3 }
        tagTYPE43 = {           4,            4,              3,            3,                          3,            16,                3,               16,                   3 }
    end
    
    methods (Access=public)
        function obj = FWTiff(wMode) % Choose tiff version on construction if desired
            if nargin>0
                switch upper(wMode)
                    case 'TIFF'
                        obj.version = 42;
                    case 'BIGTIFF'
                        obj.version = 43;
                    case 'AUTO'
                        obj.version = 0;
                end
            end
        end
        
        function Open(obj,fname) % Open file for writing
            obj.fID   = fopen(fname,'w','l'); % Open file for writing (little endian format)
            obj.fname = fname; 
            
            if obj.fID<0
                obj.AddMessage([obj.fname,' could not be opened for writing.'],2)
            else
                obj.AddMessage([obj.fname,' opened with file ID ',num2str(obj.fID),'.'])
            end
        end
        
        function Close(obj) % Close file when complete
            if obj.fID<0
                obj.AddMessage('No file is open.',2)
            else
                fclose(obj.fID);
                obj.AddMessage([obj.fname,' closed.'])
            end
            
            obj.fID   = -1;
            obj.fname = [];
        end
        
        function Write(obj,I)
            if obj.fID<0
                obj.AddMessage('No file is open for writing.',2)
            end
            
            if ndims(I)>3
                obj.AddMessage('>3 dimensions not supported.',2);
            end
            
            t=tic;
            
            if obj.transpose
                I = pagetranspose(uint16(I)); % Transpose matrix axes to match image axes (may make a copy...)
            end
            
            switch obj.version
                case 0 % Auto mode
                    GB4    = 4*(2^30);   % This many bytes in 4GB
                    rbytes = numel(I)*2; % Required bytes to store image
                    
                    if rbytes<GB4
                        ver = 42; % Standard TIFF
                    else
                        ver = 43; % BIGTIFF
                    end
                otherwise % Otherwise use selected mode
                    ver = obj.version;
            end
            
            szI(1) = size(I,1);
            szI(2) = size(I,2);
            szI(3) = size(I,3);
            tags   = obj.getTags(ver,szI);      % Generate tag structure
            
            obj.writeTiffHeader(ver);           % Write header data
            obj.writeWORD(I(:));                % Write image data
            obj.writeTiffIFDs(ver,tags,szI(3)); % Write image file directories
            
            obj.AddMessage([obj.fname,' written in ',num2str(toc(t)),' s.']);                
        end
    end
    
    methods (Access=private)
        % Write Tiff header
        function writeTiffHeader(obj,ver)
            switch ver
                case 42 % Standard Tiff header (8 bytes)
                    obj.writeBYTE('II'); % Byte order (little endian)
                    obj.writeWORD(42);   % Version
                    obj.writeDWORD(0);   % Offset to first IFD (placeholder)
                case 43 % BigTiff header (16 bytes)
                    obj.writeBYTE('II'); % Byte order (little endian)
                    obj.writeWORD(43);   % Version
                    obj.writeWORD(8);    % Bytesize of offsets (always eight)
                    obj.writeWORD(0);    % (always zero)
                    obj.writeQWORD(0);   % Offset to first IFD (placeholder)
            end
        end
        
        % Generate minimal essential tag structure
        function tags = getTags(~,ver,sz)
            W = sz(1); L = sz(2); % Looks wrong, but actually no...
            
            % Fill tag structure (in order)
            tags.ImageWidth                = W;
            tags.ImageLength               = L;
            tags.BitsPerSample             = 16;
            tags.Compression               = 1;  % None
            tags.PhotometricInterpretation = 1;  % Min is black
            switch ver
                case 42
                    tags.StripOffsets = 8;  % Byte offset of first strip
                case 43
                    tags.StripOffsets = 16;
            end
            tags.SamplesPerPixel           = 1;  % Grayscale
            tags.StripByteCounts           = L*W*2;
            tags.PlanarConfiguration       = 1;  % Chunky
        end
        
        % Write image file directories
        function writeTiffIFDs(obj,ver,tags,npages)
            fields  = fieldnames(tags);
            nfields = numel(fields);
            
            pos0 = ftell(obj.fID);    % Find current position
            off0 = tags.StripOffsets; % Initial strip offset
            
            switch ver
                case 42 % Write standard TIFF IFDs
                    for j=1:npages
                        obj.writeWORD(nfields); % Write number of entries in tag structure
                        
                        for i=1:nfields % Write tag structure
                            cTag  = obj.tagIDs{strcmp(obj.tagNames,fields{i})}; % Find current tag ID...
                            cVal  = tags.(fields{i});                           % ...and associated value
                            cType = obj.tagTYPE42{i};
                            
                            obj.writeWORD(cTag);  % Tag identifier (Always 2 bytes)
                            obj.writeWORD(cType); % Tag data type                            
                            obj.writeDWORD(1);    % Number of tag values
                            obj.writeDWORD(cVal); % Value of tag
                        end
                        
                        if j<npages % Write pointer to next IFD...
                            cPos = ftell(obj.fID);
                            obj.writeDWORD(cPos+4);
                            tags.StripOffsets = j*tags.StripByteCounts+off0; % Update strip offsets
                        else        % ...or end the IFD
                            obj.writeDWORD(0);
                        end
                    end
                    
                    fseek(obj.fID,4,-1);  % Seek to file start skipping 4 bytes
                    obj.writeDWORD(pos0); % Write pointer to first IFD
                case 43 % Write BIGTIFF IFDs
                    for j=1:npages
                        obj.writeQWORD(nfields); % Write number of entries in tag structure
                        
                        for i=1:nfields % Write tag structure
                            cTag  = obj.tagIDs{strcmp(obj.tagNames,fields{i})}; % Find current tag ID...
                            cVal  = tags.(fields{i});                           % ...and associated value
                            cType = obj.tagTYPE43{i};
                            
                            obj.writeWORD(cTag);  % Tag identifier
                            obj.writeWORD(cType); % Tag data type
                            obj.writeQWORD(1);    % Number of tag values
                            obj.writeQWORD(cVal); % Value of tag
                        end
                        
                        if j<npages % Write pointer to next IFD...
                            cPos = ftell(obj.fID);
                            obj.writeQWORD(cPos+8);
                            tags.StripOffsets = j*tags.StripByteCounts+off0; % Update strip offsets
                        else        % ...or end the IFD
                            obj.writeQWORD(0);
                        end
                    end
                    
                    fseek(obj.fID,8,-1);  % Seek to file start skipping 8 bytes
                    obj.writeQWORD(pos0); % Write pointer to first IFD
            end
        end
        
        % Add message to command window (if warn is 1 or 2, add message and ignore verbose)
        function AddMessage(obj,msg,warn)
            if nargin < 3
                warn = 0;
            end
            
            switch warn
                case 0
                    if obj.verbose
                        disp([class(obj),': ',msg])
                    end
                case 1 % Always display warnings
                    warning on
                    warning([class(obj),': Warning: ',msg])
                case 2
                    error([class(obj),': Error: ',msg])
            end
        end

        %% Binary write functions
        function writeBYTE(obj,byte)   % Write 1 byte
            fwrite(obj.fID,byte,'uint8');
        end
        
        function writeWORD(obj,word)   % Write 2 bytes (word)
            fwrite(obj.fID,word,'uint16');
        end
        
        function writeDWORD(obj,dword) % Write 4 bytes (double word)
            fwrite(obj.fID,dword,'uint32');
        end
        
        function writeQWORD(obj,qword) % Write 8 bytes (quad word)
            fwrite(obj.fID,qword,'uint64');
        end
    end
    
    methods
        function set.version(obj,val)
            if val==0 || val==42 || val==43
                obj.version = val;
            else
                obj.AddMessage('Invalid TIFF version.',2)
            end
        end
    end
end