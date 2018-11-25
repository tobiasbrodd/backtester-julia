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
    delete!(df, :Average)
    delete!(df, :Volume)
    delete!(df, :Turnover)
    delete!(df, :Trades)

    df = df[(df.Close .!= 0), :]

    sort!(df, :Date)

    return df
end

function cross_strategy!(df; short=6, long=26)
    df.Short = ema(df.Close, short)
    df.Long = ema(df.Close, long)

    df.Positions = 1(df.Short .> df.Long)
    df.Positions = coalesce.(df.Positions, 0.0)
    df.Signals = deepcopy(df.Positions)
    df.Signals[2:end] = diff(df.Signals)
end

function macd_strategy!(df; short=6, long=26)
    df.Short = ema(df.Close, short)
    df.Long = ema(df.Close, long)

    df.Positions = 1(df.Short .> df.Long) + -1(df.Short .< df.Long)
    i = 1
    while df.Positions[i] === missing || df.Positions[i] == 0
        df.Positions[i] = 1.0
        i += 1
    end
    df.Positions = coalesce.(df.Positions, 0.0)
    df.Signals = deepcopy(df.Positions)
    df.Signals[2:end] = diff(df.Signals)
end

function portfolio!(df; initial_capital=1000, quantity=1)
    positions = quantity * df.Positions
    positions_diff = quantity * df.Signals

    df.Stock = positions .* df.Close
    df.Holdings = positions .* df.Close
    df.Cash = initial_capital .- cumsum(positions_diff .* df.Close)
    df.Total = df.Holdings .+ df.Cash
    df.Returns = [1.0; df.Total[2:end] ./ df.Total[1:end-1]] .- 1.0
end

function plot_strategy(df)
    long_signals = df[(df.Signals .> 0), :]
    short_signals = df[(df.Signals .< 0), :]

    stock = layer(df, x=:Date, y=:Close, Geom.line)
    short = layer(df, x=:Date, y=:Short, Geom.line, Theme(default_color="grey"))
    long = layer(df, x=:Date, y=:Long, Geom.line, Theme(default_color="black"))
    long_signals_layer = layer(x=long_signals.Date, y=long_signals.Close, Geom.point, shape=[Shape.xcross], Theme(default_color="green", point_size=2mm))
    short_signals_layer = layer(x=short_signals.Date, y=short_signals.Close, Geom.point, shape=[Shape.xcross], Theme(default_color="red", point_size=2mm))

    stock_p = plot(long_signals_layer, short_signals_layer, long, short, stock, Theme(key_position=:none), Guide.xlabel("Time"), Guide.ylabel("SEK"), Guide.title("OMXS30 - MACD Strategy"))
    stock_p |> SVG("plots/OMXS30.svg", 15inch, 8inch)
end

function plot_perfomance(df)
    long_signals = df[(df.Signals .> 0), :]
    short_signals = df[(df.Signals .< 0), :]

    strategy = layer(df, x=:Date, y=:Total, Geom.line)
    long_signals_strategy = layer(x=long_signals.Date, y=long_signals.Total, Geom.point, shape=[Shape.xcross], Theme(default_color="green", point_size=2mm))
    short_signals_strategy = layer(x=short_signals.Date, y=short_signals.Total, Geom.point, shape=[Shape.xcross], Theme(default_color="red", point_size=2mm))

    strategy_p = plot(long_signals_strategy, short_signals_strategy, strategy, Theme(key_position=:none), Guide.xlabel("Time"), Guide.ylabel("SEK"), Guide.title("OMXS30 - MACD Perfomance"))
    strategy_p |> SVG("plots/OMXS30_Strategy.svg", 15inch, 8inch)
end

df = get_dataframe(path = "csv/", filename = "OMXS30.csv")
macd_strategy!(df, short=50, long=100)
plot_strategy(df)

portfolio!(df, initial_capital=1500)
plot_perfomance(df)

end