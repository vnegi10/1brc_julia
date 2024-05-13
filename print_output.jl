function print_output_v1(output_dict::Dict)
    
    print("{")
    station_names = collect(keys(output_dict)) |> sort

    # Output style: Abha=5.0/18.0/27.4
    for station in station_names
        temps = output_dict[station]
        print("$(station)=$(temps[1])/$(temps[2])/$(temps[3]), ")
    end

    print("}")

    return nothing

end

function print_output_v4(df_output::DataFrame)

    print("{")
    rows, cols = size(df_output)
    
    # Output style: Abha=5.0/18.0/27.4
    for (i, station) in enumerate(df_output[!, :station])
        print("$(station)=$(df_output[!, 2][i])/$(df_output[!, 3][i])/$(df_output[!, 4][i]), ")
    end

    print("}")

    return nothing

end