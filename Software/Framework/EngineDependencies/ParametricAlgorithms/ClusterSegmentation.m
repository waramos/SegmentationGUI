

function I = ClusterSegmentation(I,spatialScale,kClusters,clusterNumber)

% filters and shrinks image, then does kmeans with k = ktotal and chooses
% the numbered cluster 'cluster'( an integer ).

% stage 1

r     = max(1,spatialScale/4);
I     = double(I);

I = medfilt2(I);
I = imgaussfilt(I,1);

M = size(I,1);
N = size(I,2);

m = 2*r+1;
n = 2*r+1;
p1 = floor(size(I,1)/m)*m;
py = size(I,1)-p1;
p2 = floor(size(I,2)/n)*n;
px = size(I,2)-p2;

I = FastBlockSum(I(1:p1,1:p2),m,n);
I = I-min(I(:));

I   = I/max(I(:));
L   = I(:,[1 1:end-1]);
R   = I(:,[2:end end]);
T   = I([1 1:end-1],:);
B   = I([2:end end],:);
D   = [I(:) L(:) R(:) T(:) B(:)];

% stage 2
idx = kmeans(D,kClusters);
idx = reshape(idx,size(I));


order = zeros(kClusters,1);
for j = 1:kClusters
    order(j) = mean(I(idx(:)==j),'all');
end

[~,jdx] = sort(order);




% stage 3
% grabbing the cluster
cl = jdx(clusterNumber);
cl = max(1,min(kClusters,cl));
I  = idx==cl;

I = imresize(I,[M-py N-px]);
if py>0
    I = cat(1,I,repmat(I(end,:),[py 1]));
end
if px>0
    I = cat(2,I,repmat(I(:,end),[1 px]));
end

end


function y = FastBlockSum(x,m,n)


% note: assumes m divides NumRows and n divides NumCols
NumRows  = size(x,1);
NumCols  = size(x,2);
NumPages = size(x,3);
x        = reshape(x,[m NumRows/m n NumCols/n NumPages]);
y        = squeeze(sum(x,[1 3]));

end