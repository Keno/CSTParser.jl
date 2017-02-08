
type Iterator{T}
    i::Int
    n::Int
end
+{T}(s::Iterator{T}) = (s.i+=1;s)

start(x::INSTANCE) = 1
next(x::INSTANCE, i) = x, i+1
length(x::INSTANCE) = 1
done(x::INSTANCE, i) = i>1


"""
    start(x::EXPR)

Creates an interator state for `EXPR`s. One can then iterator through all
 elements of an expression as they are ordered in the original code including 
punctuation.
"""
function start(x::EXPR)
    if x.head == CALL
        if x.args[1] isa INSTANCE{IDENTIFIER} || (x.args[1] isa EXPR && x.args[1].head.val == "curly") # normal call
            return Iterator{:call}(1, length(x.args)*2)
        elseif x.args[1] isa INSTANCE # op calls
            if x.args[1].val=="+" || x.args[1].val=="*" # chained ops
                return Iterator{:opchain}(1, max(2, length(x.args)*2-3))
            else
                return Iterator{:op}(1, length(x.args) + length(x.punctuation))
            end
        end
    elseif issyntaxcall(x.head.val)
        if x.head.val ==":"
            return Iterator{:(:)}(1, length(x.args) == 2 ? 3 : 5)
        end
        return Iterator{:syntaxcall}(1, length(x.args) + 1)
    elseif x.head == COMPARISON
        return Iterator{:comparison}(1, length(x.args))
    elseif x.head.val == "if" && x.head.span == 0
        return Iterator{:?}(1, 5)
    elseif x.head.val == "block"
        return Iterator{Symbol(x.head.val)}(1, length(x.args) + length(x.punctuation))
    elseif x.head isa INSTANCE{KEYWORD}
        if x.head.val == "break" || x.head.val == "continue"
            return Iterator{Symbol(x.head.val)}(1, 1)
        elseif x.head.val == "abstract" || x.head.val == "const" || x.head.val == "global" || x.head.val == "local" || x.head.val == "return"
            return Iterator{Symbol(x.head.val)}(1, 2)
        elseif x.head.val == "import" || x.head.val == "importall" || x.head.val == "using"
            return Iterator{:imports}(1, 1 + length(x.args) + length(x.punctuation)) 
        elseif x.head.val == "toplevel"
            @assert length(x.args) > 1
            cnt = 1
            while x.args[1].args[cnt] == x.args[2].args[cnt]
                cnt+=1
            end
            return Iterator{:toplevel}(1, (cnt - 1 + length(x.args))*2)
        elseif x.head.val == "export"
            return Iterator{:export}(1, length(x.args)*2)
        elseif x.head.val == "bitstype" || x.head.val == "typealias"
            return Iterator{Symbol(x.head.val)}(1, 3)
        elseif x.head.val == "module"
            return Iterator{:module}(1, 4)
        elseif x.head.val == "type"
            return Iterator{:type}(1, 4)
        elseif x.head.val == "for"
            return Iterator{:for}(1, 4)
        elseif x.head.val == "while"
            return Iterator{:while}(1, 4)
        elseif x.head.val == "function"
            return Iterator{:function}(1, 4)
        elseif x.head.val == "macro"
            return Iterator{:module}(1, 4)
        elseif x.head.val == "do"
        elseif x.head.val == "if"
            if length(x.args) == 2
                return Iterator{:if}(1, 4)
            elseif x.punctuation[end-1].val=="else"
                return Iterator{:if}(1, 4 + (length(x.punctuation)-2)*3 + 2)
            else
                return Iterator{:if}(1, 4 + (length(x.punctuation)-1)*3)
            end
        elseif x.head.val == "try"
            if isempty(x.args[3].args)
                return Iterator{:try}(1, 3)
            else
                return Iterator{:try}(1, 5 + (x.args[2]!=FALSE))
            end
        end
    elseif x.head.val == "curly"
        return Iterator{:curly}(1, length(x.args)*2)
    elseif x.head.val == "tuple"
        if first(x.punctuation).val == "("
            return Iterator{:tuple}(1, length(x.args) + length(x.punctuation))
        else
            return Iterator{:tuplenoparen}(1, length(x.args) + length(x.punctuation))
        end
    end
end

done(x::EXPR, s::Iterator) = s.i > s.n
length(x::EXPR) = start(x).n

function next(x::EXPR, s::Iterator{:call})
    if isodd(s.i)
        return x.args[div(s.i+1, 2)], +s
    else
        return x.punctuation[div(s.i, 2)], +s
    end
end

function next(x::EXPR, s::Iterator{:opchain})
    if isodd(s.i)
        return x.args[div(s.i+1,2)+1], +s
    elseif s.i == 2
        return x.args[1], +s
    else 
        return x.punctuation[div(s.i, 2)-1], +s
    end
end


function next(x::EXPR, s::Iterator{:op})
    if s.i==1
        return x.args[2], +s
    elseif s.i==2
        return x.args[1], +s
    elseif s.i==3 
        return x.args[3], +s
    end
end

function next(x::EXPR, s::Iterator{:(:)})
    if s.i == 1
        return x.args[1], +s
    elseif s.i == 2
        return x.head, +s
    elseif s.i == 3
        return x.args[2], +s
    elseif s.i == 4
        return x.punctuation[1], +s
    elseif s.i == 5 
        return x.args[3], +s
    end
end

function next(x::EXPR, s::Iterator{:syntaxcall})
    if s.i==1
        return x.args[1], +s
    elseif s.i==2
        return x.head, +s
    elseif s.i==3 
        return x.args[2], +s
    end
end

function next(x::EXPR, s::Iterator{:?})
    if s.i == 1
        return x.args[1], +s
    elseif s.i == 2 
        return x.punctuation[1], +s
    elseif s.i == 3
        return x.args[2], +s
    elseif s.i == 4 
        return x.punctuation[2], +s
    elseif s.i == 5
        return x.args[3], +s
    end 
end

function next(x::EXPR, s::Iterator{:comparison})
    return x.args[s.i], +s
end

function next(x::EXPR, s::Iterator{:tuple})
    if isodd(s.i)
        return x.punctuation[div(s.i+1, 2)], +s
    else
        return x.args[div(s.i, 2)], +s
    end
end

function next(x::EXPR, s::Iterator{:tuplenoparen})
    if isodd(s.i)
        return x.args[div(s.i+1, 2)], +s
    else
        return x.punctuation[div(s.i, 2)], +s
    end
end

function next(x::EXPR, s::Iterator{:curly})
    if s.i==1
        return x.args[1], +s
    elseif s.i==2
        return x.punctuation[1], +s
    elseif s.i==s.n
        return last(x.punctuation), +s
    elseif isodd(s.i)
        return x.args[div(s.i+1, 2)], +s
    else
        return x.punctuation[div(s.i, 2)], +s
    end
end

function next(x::EXPR, s::Iterator{:block})
    return x.args[s.i], +s
end




# KEYWORDS

function next(x::EXPR, s::Iterator{:function})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    elseif s.i == 3
        return x.args[2], +s
    elseif s.i == 4
        return x.punctuation[1], +s
    end
end

function next(x::EXPR, s::Iterator{:module})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[2], +s
    elseif s.i == 3
        return x.args[3], +s
    elseif s.i == 4
        return x.punctuation[1], +s
    end
end

function next(x::EXPR, s::Iterator{:type})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[2], +s
    elseif s.i == 3
        return x.args[3], +s
    elseif s.i == 4
        return x.punctuation[1], +s
    end
end

function next(x::EXPR, s::Iterator{:abstract})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    end
end

function next(x::EXPR, s::Iterator{:bitstype})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    elseif s.i == 3
        return x.args[2], +s
    end
end


function next(x::EXPR, s::Iterator{:typealias})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    elseif s.i == 3
        return x.args[2], +s
    end
end

function next(x::EXPR, s::Iterator{:while})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    elseif s.i == 3
        return x.args[2], +s
    elseif s.i == 4
        return x.punctuation[1], +s
    end
end

function next(x::EXPR, s::Iterator{:for})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    elseif s.i == 3
        return x.args[2], +s
    elseif s.i == 4
        return x.punctuation[1], +s
    end
end


function next(x::EXPR, s::Iterator{:imports})
    if s.i == 1
        return x.head, +s
    elseif isodd(s.i)
        return x.punctuation[div(s.i-1, 2)], +s
    else
        return x.args[div(s.i, 2)], +s
    end
end


function next(x::EXPR, s::Iterator{:toplevel})
    if s.i == 1
        return x.args[1].head, +s
    elseif isodd(s.i)
        return x.punctuation[div(s.i-1, 2)], +s
    else
        if s.i <= div(s.n, 2)
            return x.args[1].args[div(s.i, 2)], +s
        else
            return last(x.args[div(s.i-div(s.n, 2)+1, 2)].args), +s
        end
    end
end

function next(x::EXPR, s::Iterator{:export})
    if s.i == 1
        return x.head, +s
    elseif isodd(s.i)
        return x.punctuation[div(s.i-1, 2)], +s
    else
        return x.args[div(s.i, 2)], +s
    end
end


function next(x::EXPR, s::Iterator{:const})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    end
end

function next(x::EXPR, s::Iterator{:global})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    end
end

function next(x::EXPR, s::Iterator{:local})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    end
end

function next(x::EXPR, s::Iterator{:return})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    end
end

function next(x::EXPR, s::Iterator{:break})
    if s.i == 1
        return x.head, +s
    end
end

function next(x::EXPR, s::Iterator{:continue})
    if s.i == 1
        return x.head, +s
    end
end

function next(x::EXPR, s::Iterator{:try})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    elseif s.i == s.n
        return last(x.punctuation), +s
    elseif s.i == 3
        return first(x.punctuation), +s
    elseif s.i == 4
        if x.args[2] != FALSE
            return x.args[2], +s
        else
            return x.args[3], +s
        end
    else
        return x.args[3], +s
    end
end


function next(x::EXPR, s::Iterator{:if})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    elseif s.i == 3
        return x.args[2], +s
    elseif s.i == 4
        return x.punctuation[1], +s
    elseif s.i == s.n
        return last(x.punctuation), +s
    else
        haselse = x.punctuation[end-1].val=="else"
        nesteds = length(x.punctuation)-1-haselse
        if haselse && s.i == s.n-1
            n = div(s.i-2, 3)-1
            y = x
            for i = 1:n
                y = y.args[3].args[1]
            end
            return y.args[3], +s
        end
        if mod(s.i-1, 3) == 0
            return x.punctuation[div(s.i-1, 3)], +s
        elseif mod(s.i-2, 3) == 0
            n = div(s.i-2, 3)
            y = x
            for i = 1:n
                y = y.args[3].args[1]
            end
            return y.args[1], +s
        else
            n = div(s.i-2, 3)
            y = x
            for i = 1:n
                y = y.args[3].args[1]
            end
            return y.args[2], +s
        end
    end
end