using DataFrames, CSV, ProgressMeter, Statistics

include("print_output.jl")

function get_stations_df_v4(fname::String, num_chunks::Int)
    
    df_all_group = DataFrame()

    chunks = CSV.Chunks(fname;
                        delim = ';',
                        header = ["station", "temp"],
                        types = Dict("temp" => Float32),
                        strict = true,
                        ntasks = num_chunks,
                        pool = true
                        )

    p = Progress(length(chunks); dt = 0.5,
                                 barglyphs = BarGlyphs("[=> ]"),
                                 barlen = 50,
                                 color = :yellow)

    for chunk in chunks

        df_chunk = chunk |> DataFrame

        # Group stations from each chunk
        df_group = combine(groupby(df_chunk, :station, sort = true),
                               :temp => minimum,
                               :temp => mean,
                               :temp => maximum
                          )

        # Vertically concatenate all DataFrames
        df_all_group = vcat(df_all_group, df_group)
        next!(p)
        
    end

    finish!(p)

    df_output = combine(groupby(df_all_group, :station, sort = true),
                            :temp_minimum => minimum => :t_min,
                            :temp_mean => mean => :t_mean,
                            :temp_maximum => maximum => :t_max
                       )

    df_output[!, :t_mean] = map(x -> round(x; digits = 1), 
                                df_output[!, :t_mean])

    return df_output
end

function main(ARGS)

    fname = ARGS[1]
    num_chunks = parse(Int, ARGS[2])

    @time get_stations_df_v4(fname, num_chunks) |> print_output_v4

end

# Execute main function, ARGS can be passed via the REPL as:
# julia> ARGS = ["measurements.txt", "96"]
# julia> include("execute_df_v4.jl")
main(ARGS)