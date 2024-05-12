using DataFrames, CSV, Mmap, BenchmarkTools

include("groupby_df.jl")
include("print_output_v4.jl")

function get_stations_df_v11(fname::String,
                             num_chunks::Int64,
                             num_tasks::Int64=Threads.nthreads())
    
    # Use memory mapping to read large file
    fopen = open(fname, "r")
    fmmap = Mmap.mmap(fopen)

    # Find suitable range for reading each chunk
    i_max = length(fmmap)
    chunk_size = round(Int, (i_max / num_chunks))
    i_start = 1
    i_end = chunk_size

    df_all_group = DataFrame()

    while i_end ≤ i_max
        # Check if we end at byte representation of new-line character
        while fmmap[i_end] != 0x0a
            i_end += 1
        end

        df_chunk = CSV.read(fmmap[i_start:i_end], DataFrame;
                            delim = ';',
                            header = ["station", "temp"],
                            types = Dict("temp" => Float32),
                            strict = true,
                            ntasks = num_tasks,
                            pool = true,
                            buffer_in_memory = true
                            );

        # Group stations from each chunk
        df_group = combine(groupby(df_chunk, :station, sort = true),
                               :temp => minimum,
                               :temp => mean,
                               :temp => maximum
                          )

        # Vertically concatenate all DataFrames
        df_all_group = vcat(df_all_group, df_group)

        # Exit after processing last chunk
        if i_end == i_max
            break
        end

        # Move to next chunk
        i_start = i_end + 1
        i_end = i_start + chunk_size

        if i_end > i_max
            i_end = i_max
        end

    end

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
    
    @time get_stations_df_v11(fname, num_chunks) |> print_output_v4

end

# Execute main function, ARGS can be passed via the REPL as:
# julia> ARGS = ["measurements.txt", "24"]
# julia> include("execute_df_v11.jl")
# main(ARGS)

# Run benchmark for 10 samples with a maximum duration of 20 minutes
b = @benchmarkable main(ARGS) samples = 10 seconds = 1200
run(b)