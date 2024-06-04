using BenchmarkTools

include("chunks.jl")
include("print_output.jl")

function get_stations_dict_v7(fname::String, num_chunks::Int64)

    all_chunks = get_chunks(fname, num_chunks)
    all_stations = [Dict{String, Vector{Float32}}() for _ in 1:num_chunks]

    #t1 = time()

    Threads.@threads for i in eachindex(all_chunks)
        @inbounds all_stations[i] = process_chunk_v4(all_chunks[i])
    end

    #t2 = time()
    #Δt = round(t2 - t1, digits = 2)
    #@info("Time taken to process chunks: $(Δt) s")
    #sleep(5)

    all_chunks = nothing

    return combine_chunks_v2(all_stations)
end

function main(ARGS)

    fname = ARGS[1]
    num_chunks = parse(Int, ARGS[2])
    
    get_stations_dict_v7(fname, num_chunks) |> print_output_v1

end

# Execute main function, ARGS can be passed via the REPL as:
# julia> ARGS = ["measurements.txt", "24"]
# julia> include("execute_df_v11.jl")
# main(ARGS)

# Run benchmark for 10 samples with a maximum duration of 20 minutes, trigger GC
# before each sample run is started.
b = @benchmarkable main(ARGS) samples = 10 seconds = 1200 gcsample = true
run(b)