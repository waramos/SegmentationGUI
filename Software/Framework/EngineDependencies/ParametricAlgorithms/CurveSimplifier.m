

function p = CurveSimplifier(p,windingTolerance,stages)
    if nargin < 3
        stages = 3;
    end
    
    if nargin < 2
        windingTolerance = 0.05;
    end
    
    n    = size(p,1);
    idx  = true(n,1);
    flag = rand>0.5;
    for iteration = 1:stages
    
        if flag
    
            for pos = 2:2:n-1
        
                q = p(pos-1:pos+1,:);
                q = q-mean(q,1);
                q = q/max(abs(q(:)));
                s = svd(q);
                if s(2)<(windingTolerance*s(1))
                    idx(pos) = false;
                end
            end
            q = p([n-1 n 1],:);
            q = q-mean(q,1);
            q = q/max(abs(q(:)));
            s = svd(q);
            if s(2)<(windingTolerance*s(1))
                idx(n) = false;
            end
    
        else
            q = p([end 1 2],:);
            q = q-mean(q,1);
            q = q/max(abs(q(:)));
            s = svd(q);
            if s(2)<(windingTolerance*s(1))
                idx(1) = false;
            end
            for pos = 3:2:n-1
        
                q = p(pos-1:pos+1,:);
                q = q-mean(q,1);
                q = q/max(abs(q(:)));
                s = svd(q);
                if s(2)<(windingTolerance*s(1))
                    idx(pos) = false;
                end
            end
            if idx(1)
                q = p([n-1 n 1],:);
                q = q-mean(q,1);
                q = q/max(abs(q(:)));
                s = svd(q);
                if s(2)<(windingTolerance*s(1))
                    idx(n) = false;
                end
            end
    
        end
    
        p    = p(idx,:);
        nx   = size(p,1);
        if (nx == n) && (iteration<stages)
            return;
        else
            if mod(n-nx,2)==0
                flag = ~flag;
            end
            n = nx;
            idx = true(n,1);
        end
    
    end
end