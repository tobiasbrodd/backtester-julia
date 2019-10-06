module Tools

using Missings

export sma, ema

function sma(X, n)
    if n < 1 || length(X) < n
        return X
    end

    Y::Array{Union{Float64,Missing},1} = missings(n-1)

    for i in n:length(X)
        push!(Y, sum(X[i-n+1:i]) / n)
    end

    return Y
end

function ema(X, n::Int64)
    if n < 1 || length(X) < n
        return X
    end

    L::Array{Union{Float64,Missing},1} = missings(n-1)
    alpha = 2.0 / (n + 1)

    push!(L, X[n])

    for i in n+1:length(X)
        push!(L, alpha*X[i] + (1-alpha)*L[end])
    end

    return L
end

function ema(X, alpha::Float64)
    if alpha < 0 || alpha > 1
        return X
    end

    L = [X[1]]

    for x in X[2:end]
        push!(L, alpha*x + (1-alpha)*L[end])
    end

    return L
end

end