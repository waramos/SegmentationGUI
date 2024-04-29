function ActMat = CNNSegmentation(I, net)
    % Rescaling of the image so that it can enter the CNN
    InputSz = net.Layers(1).InputSize;
    ImSz    = size(I);
    nz      = size(I, 3);

    % If CNN expects a 3 channel input
    if nz < InputSz(3) && nz == 1
        I    = repmat(I, [1 1 InputSz(3)]);
    end

    % Comparing CNN input layer size to image size
    SzRatios = InputSz(1:2)./ImSz(1:2);
    RowMatch = SzRatios(1) == 1;
    ColMatch = SzRatios(2) == 1;

    % Computation can occur faster when image size can exactly match
    % the network input layer size since it allows for use of predict
    % function over the use of the activations function
    FastFlag = SzRatios(1) == SzRatios(2);

    if  ~RowMatch || ~ColMatch
        % Scaling up/down to match with the minclc input layer size
        ratio = max(SzRatios(:));
        % Clipping needed due to potential neg values
        I     = imresize(I, ratio, "lanczos3");
        I     = max(I, 0);
        
    end

    % Push data on to GPU for faster processing
    if canUseGPU
        I = gpuArray(I);
    end

    % DAG/SeriesNetworks use the activations function
    % Getting the CNN output name before the pixel classification layer
    % The original method of using activations and specifying the layer
    % name was too slow, so predict is now used instead regardless of
    % network type. It is ~33% faster

    if FastFlag
        ActMat = predict(net, I);
    else
        if isa(net, 'DAGNetwork') || isa(net, 'SeriesNetwork')
            % DAG/SeriesNetworks use the activations function
            % Getting the CNN output name before the pixel classification layer
            LayerName = net.Layers(end-1).Name;
            ActMat    = activations(net, I, LayerName);
        elseif isa(net, 'dlnetwork')
            % dlnetworks use the predict function
            LayerName = net.Layers(end).Name;
            ActMat    = predict(net, I, 'Outputs', LayerName);
        end
    end

    % Gathering data back onto CPU
    ActMat = gather(ActMat(:,:,2));
    ActMat = imresize(ActMat, ImSz, 'nearest');
    ActMat = double(ActMat);
end