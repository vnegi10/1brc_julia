using Statistics

include("calculate_output.jl")
include("print_output.jl")

function get_stations_dict_v2(fname::String)
    
    stations = Dict{Symbol, Vector{Float64}}()

    # Use of eachline requires Julia 1.8
    for line in eachline(fname)
        line_parts = split(line, ";")
        station, temp = Symbol(line_parts[1]), parse(Float64, line_parts[2])
        if station in keys(stations)
            push!(stations[station], temp)
        else
            stations[station] = [temp]
        end
    end

    return stations
end

# For testing, use one of the following files:
# measurements_test_10k.txt, measurements_test_20k.txt, measurements_test_100k.txt
@time get_stations_dict_v2("measurements_test_10k.txt") |> calculate_output_v3 |> print_output_v1