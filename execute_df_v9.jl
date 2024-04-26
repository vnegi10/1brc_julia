using DataFrames, CSV, ProgressMeter

include("groupby_df.jl")
include("print_output_v4.jl")

function get_stations_df_v9(fname::String, num_chunks::Int)
	
	df_all = Vector{DataFrame}(undef, num_chunks)
		
	chunks = CSV.Chunks(fname;
	                    delim = ';',
	                    header = ["station", "temp"],
	                    types = Dict("temp" => Float32),
	                    strict = true,
	                    ntasks = num_chunks,
		                pool = true
	                    )

	# This will likely cause memory issues when loading the full dataset
	chunks_file = collect(chunks)
	p = Progress(length(chunks_file); dt = 0.5, 
	                                  barglyphs = BarGlyphs("[=> ]"),
	                                  barlen = 50,
	                                  color = :yellow)
	
	# Execute in parallel on all available threads
	Threads.@threads for i in eachindex(chunks_file)
	    df_all[i] = groupby_df(chunks_file[i])
		next!(p)
	end

	finish!(p)

	# Concatenate into a single DataFrame
	df_all_group = vcat(df_all...)

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
    
    @time get_stations_df_v9(fname, num_chunks) |> print_output_v4

end

main(ARGS)