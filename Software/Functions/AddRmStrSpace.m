function s_new = AddRmStrSpace(s, flag)
    % If flag is positive, space is added, else, space is removed between
    % words
    if nargin < 2
        flag = true;
    end

    % Beginning of new string
    s_new = '';
    if flag
        % Looks for capital letters
        idx   = regexp(s, '([A-Z])');
        n     = numel(idx);
        for i = 1:n
            ind1 = idx(i);
            if i < n
                ind2 = idx(i+1) - 1;
            else
                ind2 = numel(s);
            end
            s_frag = s(ind1:ind2);
            if i >1
                s_new  = strjoin({s_new, s_frag}, ' ');
            else
                s_new  = s_frag;
            end
        end
    else
        % Looks for whitespace
        idx   = regexp(s, ' ');
        n     = numel(idx);
        if n > 0
            for i = 1:n+1
                if i == 1
                    ind1 = 1;
                    ind2 = idx(i) - 1;
                elseif i < n + 1
                    ind1 = idx(i-1) + 1;
                    ind2 = idx(i) - 1;
                else
                    ind1 = ind2 + 2;
                    ind2 = numel(s);
                end
                s_frag = s(ind1:ind2);
                s_new  = strcat(s_new, s_frag);
            end
        else
            s_new = s;
        end
    end
end
