module Backtester

include("./tools.jl")

using DataFrames, CSV, Gadfly, .Tools

function get_dataframe(;path, filename)
    df = CSV.File(path * filename) |> DataFrame
    return format(df)
end

function format(df)
    rename!(df, Symbol("High price") => :High)
    rename!(df, Symbol("Low price") => :Low)
    rename!(df, Symbol("Closing price") => :Close)
    rename!(df, Symbol("Average price") => :Average)
    rename!(df, Symbol("Total volume") => :Volume)
    deletecols!(df, :Average)
    deletecols!(df, :Volume)
    deletecols!(df, :Turnover)

    df = df[(df.Close .!= 0), :]

    sort!(df, :Date)

    return df
end

function find_first_long_crossing(df)
    delta = 0.0
    for i in 1:size(df, 1)
        if df.Short[i] === missing || df.Long[i] === missing
            continue
        end
        delta_prev = delta
        delta = df.Short[i] - df.Long[i]
        if delta > 0 && delta_prev < 0
            return i
        end
    end

    return 1
end

function remove_signals!(df, position)
    for i in 1:position-1
        df.Positions[i] = 0.0
    end
end

function macd_long_strategy!(df; short::Int64=6, long::Int64=26)
    df.Short = ema(df.Close, short)
    df.Long = ema(df.Close, long)

    df.Positions = 1(df.Short .> df.Long)
    df.Positions = coalesce.(df.Positions, 0.0)
    position = find_first_long_crossing(df)
    remove_signals!(df, position)
    df.Signals = deepcopy(df.Positions)
    df.Signals[2:end] = diff(df.Signals)
end

function macd_long_strategy!(df; alpha::Float64=0.3, beta::Float64=0.07)
    df.Short = ema(df.Close, alpha)
    df.Long = ema(df.Close, beta)

    df.Positions = 1(df.Short .> df.Long)
    df.Positions = coalesce.(df.Positions, 0.0)
    position = find_first_long_crossing(df)
    remove_signals!(df, position)
    df.Signals = deepcopy(df.Positions)
    df.Signals[2:end] = diff(df.Signals)
end

function macd_long_short_strategy!(df; short=6, long=26)
    df.Short = ema(df.Close, short)
    df.Long = ema(df.Close, long)

    df.Positions = 1(df.Short .> df.Long) + -1(df.Short .< df.Long)
    df.Positions = coalesce.(df.Positions, 0.0)
    position = find_first_long_crossing(df)
    remove_signals!(df, position)
    df.Signals = deepcopy(df.Positions)
    df.Signals[2:end] = diff(df.Signals)
end

function portfolio!(df; initial_capital=1000, quantity=1)
    positions = quantity * df.Positions
    positions_diff = quantity * df.Signals

    df.Holdings = positions .* df.Close
    df.Cash = initial_capital .- cumsum(positions_diff .* df.Close)
    df.Total = df.Holdings .+ df.Cash
    df.Returns = cumprod([1.0; df.Total[2:end] ./ df.Total[1:end-1]]) * 100 .- 100
end

function dynamic_portfolio!(df; initial_capital=1000)
    df.Holdings = zeros(length(df.Positions))
    df.Cash = zeros(length(df.Positions))
    df.Cash[1] = initial_capital
    df.Quantity = zeros(length(df.Positions))
    current_position = 0

    for i in 2:size(df,1)
        quantity = abs(current_position)
        df.Holdings[i] = current_position * df.Close[i] 
        df.Cash[i] = df.Cash[i-1]

        if df.Signals[i] > 0
            quantity = floor((df.Cash[i] + df.Holdings[i]) / df.Close[i] + quantity) / abs(df.Signals[i])
        end

        df.Quantity[i] = quantity * abs(df.Signals[i])

        position = ((df.Signals[i] > 0) ? floor((df.Cash[i] + df.Holdings[i]) / df.Close[i]) : quantity) * df.Positions[i]
        positions_diff = quantity * df.Signals[i]

        df.Holdings[i] = position * df.Close[i] 
        df.Cash[i] = df.Cash[i] - positions_diff * df.Close[i]

        if df.Signals[i] != 0
            current_position = current_position + positions_diff 
        end
    end

    df.Total = df.Holdings .+ df.Cash
    df.Returns = (cumprod([1.0; df.Total[2:end] ./ df.Total[1:end-1]]) .- 1) * 100

    return df.Returns[end]
end

function plot_strategy(df)
    long_signals = df[(df.Signals .> 0), :]
    short_signals = df[(df.Signals .< 0), :]

    stock = layer(df, x=:Date, y=:Close, Geom.line)
    short = layer(df, x=:Date, y=:Short, Geom.line, Theme(default_color="grey"))
    long = layer(df, x=:Date, y=:Long, Geom.line, Theme(default_color="black"))
    long_signals_layer = layer(x=long_signals.Date, y=long_signals.Close, Geom.point, shape=[Shape.xcross], Theme(default_color="green", point_size=2mm))
    short_signals_layer = layer(x=short_signals.Date, y=short_signals.Close, Geom.point, shape=[Shape.xcross], Theme(default_color="red", point_size=2mm))

    stock_p = plot(long_signals_layer, short_signals_layer, long, short, stock, Theme(key_position=:none), Guide.xlabel("Time"), Guide.ylabel("Value"), Guide.title("OMXS30 - MACD Strategy"))
    stock_p |> SVG("plots/OMXS30.svg", 15inch, 8inch)
end

function plot_perfomance(df)
    long_signals = df[(df.Signals .> 0), :]
    short_signals = df[(df.Signals .< 0), :]

    strategy = layer(df, x=:Date, y=:Returns, Geom.line)
    long_signals_strategy = layer(x=long_signals.Date, y=long_signals.Returns, Geom.point, shape=[Shape.xcross], Theme(default_color="green", point_size=2mm))
    short_signals_strategy = layer(x=short_signals.Date, y=short_signals.Returns, Geom.point, shape=[Shape.xcross], Theme(default_color="red", point_size=2mm))

    strategy_p = plot(long_signals_strategy, short_signals_strategy, strategy, Theme(key_position=:none), Guide.xlabel("Time"), Guide.ylabel("Return (%)"), Guide.title("OMXS30 - MACD Perfomance"))
    strategy_p |> SVG("plots/OMXS30_Strategy.svg", 15inch, 8inch)
end

function print_log(df)
    for row in eachrow(df)
        if row.Signals > 0
            println(row.Date, ": Long ", row.Quantity)
        elseif row.Signals < 0
            println(row.Date, ": Short ", row.Quantity)
        end
    end
end

function backtest(short::Int64, long::Int64)
    if short >= long || short <= 0 || long <= 0
        return 0.0
    end

    df = get_dataframe(path = "csv/", filename = "OMXS30.csv")
    macd_long_strategy!(df, short=short, long=long)
    dynamic_portfolio!(df, initial_capital=2000)
end

function backtest(x)
    alpha = x[1]
    beta = x[2]
    df = get_dataframe(path = "csv/", filename = "OMXS30.csv")
    macd_long_strategy!(df, alpha=alpha, beta=beta)
    -dynamic_portfolio!(df, initial_capital=2000)
end

df = get_dataframe(path = "csv/", filename = "OMXS30.csv")
# macd_long_strategy!(df, alpha=0.04, beta=0.02)
macd_long_strategy!(df, short=50, long=100)
plot_strategy(df)

println(dynamic_portfolio!(df, initial_capital=2000))
plot_perfomance(df)

print_log(df)

end