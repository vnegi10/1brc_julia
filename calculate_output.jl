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

function calculate_output_v3(stations_dict::Dict)

    output = Dict{Symbol, Vector{Float64}}()
    station_names = collect(keys(stations_dict))

    for station in station_names
        temps = stations_dict[station]
        output[station] = [round(minimum(temps); digits = 1),
                           round(mean(temps); digits = 1),
                           round(maximum(temps); digits = 1)]
    end

    return output

end