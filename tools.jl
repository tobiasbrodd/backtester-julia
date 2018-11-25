module Tools

using Missings

export sma, ema

function sma(X, n)
    if n < 1 || length(X) < n
        return X
    end

    Y::Array{Union{Float64,Missing},1}  = missings(n-1)

    for i in n:length(X)
        push!(Y, sum(X[i-n+1:i]) / n)
    end

    return Y
end

function ema(X, n)
    if n < 1 || length(X) < n
        return X
    end

    Y::Array{Union{Float64,Missing},1} = missings(n-1)
    K = 2.0 / (n + 1)

    push!(Y, X[n])

    for i in n+1:length(X)
        push!(Y, K*X[i] + (1-K)*Y[end])
    end

    return Y
end

end