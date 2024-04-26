using DataFrames, CSV

include("print_output_v4.jl")

function get_stations_df_v4(fname::String, num_chunks::Int)
	
	df_all_group = DataFrame()

	for chunk in CSV.Chunks(fname; 
	                        delim = ';',
	                        header = ["station", "temp"],
	                        types = Dict("temp" => Float32),
	                        strict = true,
	                        ntasks = num_chunks,
		                    pool = true
	                        )

		df_chunk = chunk |> DataFrame

		# Group stations from each chunk		
		df_group = combine(groupby(df_chunk, :station, sort = true),
                               :temp => minimum,
                               :temp => mean,
                               :temp => maximum
		                  )

		# Vertically concatenate all DataFrames
		df_all_group = vcat(df_all_group, df_group)		
		
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

    @time get_stations_df_v4(fname, num_chunks) |> print_output_v4

end

main(ARGS)