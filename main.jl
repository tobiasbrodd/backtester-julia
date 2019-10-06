include("./backtester.jl")

using DataFrames, Gadfly, .Backtester

nx = 300
ny = 300
dx = 5
dy = 5
res = zeros(Int(ny/dy), Int(nx/dx))

res_vec = []

global i = 1
for short in dy:dy:ny
    global j = i
    for long in (short+dx):dx:nx
        res[i, j] = backtest(short, long)
        # println("Short: ", short, " Long: ", long, " Return: ", res[i, j])
        push!(res_vec, (res[i, j], short, long))
        global j = j + 1
    end
    println(i)
    global i = i + 1
end

res_spy = spy(res)
res_spy |> SVG("plots/res.svg", 15inch, 8inch)

sort!(res_vec, by = x -> x[1])

x = []
y = []
z = []
for r in res_vec
    println(r)
    push!(x, r[2])
    push!(y, r[3])
    push!(z, r[1])
end

res_vec_plot_x = plot(x=x, y=z, Geom.boxplot)
res_vec_plot_x |> SVG("plots/res_vec_short.svg", 15inch, 8inch)

res_vec_plot_y = plot(x=y, y=z, Geom.boxplot)
res_vec_plot_y |> SVG("plots/res_vec_long.svg", 15inch, 8inch)

# println(backtest(5, 10))