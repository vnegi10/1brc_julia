using Statistics

include("print_output.jl")

function get_stations_dict_v1(fname::String)
    
    stations = Dict{String, Vector{Float64}}()

    # Use of eachline requires Julia 1.8
    for line in eachline(fname)
        line_parts = split(line, ";")
        station, temp = line_parts[1], parse(Float64, line_parts[2])
        if station in keys(stations)
            push!(stations[station], temp)
        else
            stations[station] = [temp]
        end
    end

    return stations
end

function calculate_output_v1(stations_dict::Dict)

    output = Dict{String, Vector{Float64}}()
    station_names = collect(keys(stations_dict))

    for station in station_names
        temps = stations_dict[station]
        output[station] = [round(minimum(temps); digits = 1),
                           round(mean(temps); digits = 1),
                           round(maximum(temps); digits = 1)]
    end

    return output

end

# For testing, use one of the following files:
# measurements_test_10k.txt, measurements_test_20k.txt, measurements_test_100k.txt

@time get_stations_dict_v1("measurements_test_10k.txt") |> calculate_output_v1 |> print_output_v1