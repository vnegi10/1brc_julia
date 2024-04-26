### A Pluto.jl notebook ###
# v0.19.36

using Markdown
using InteractiveUtils

# ╔═╡ be669e6e-cc33-46f4-b7f0-93fdf9ec217a
using Statistics, ThreadsX, CSV, DataFrames, BenchmarkTools, ProgressMeter

# ╔═╡ 91c47eca-ffc5-11ee-2558-b3f40cc93e49
md"
## Input data
Generated via the Python script from this [link](https://github.com/gunnarmorling/1brc/blob/main/src/main/python/create_measurements.py)

```
python3 create_measurements.py 1000000000
```
"

# ╔═╡ 48d6ae88-fafe-4f37-ba3d-34be727b19c2
versioninfo()

# ╔═╡ 5148881a-1edc-4073-94e3-e56f7fff605f
md"
## Using the standard library
"

# ╔═╡ d8e57b27-1e78-4aa9-9117-07c0bdce17ca
md"
#### Create a dict with all stations mapped to their temps
"

# ╔═╡ 4c7d5d3e-fa39-4df3-8f98-d9c990c71f10
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

# ╔═╡ 626bafd1-7b38-4bc3-867a-2714cff2fbf6
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

# ╔═╡ 0a46b87b-364d-4807-bce9-feb3d89d1bfa
function get_stations_v2(fname::String)
	
	stations = String[]
	temps = Vector{Float64}[]
	
	for line in eachline(fname)
		line_parts = split(line, ";")
		station, temp = line_parts[1], parse(Float64, line_parts[2])		
		
		if station ∉ stations
			push!(stations, station)
			push!(temps, [temp])
		else
			find_idx = ThreadsX.findfirst(x -> x == station, stations)
			push!(temps[find_idx], temp)
		end	
	end

	return stations, temps

end

# ╔═╡ 8eee43c2-fd05-4583-8f2d-717233973c23
function get_stations_dict_v3(fname::String)
	
	stations = Dict{String, Vector{Float64}}()

	# Use of eachline requires Julia 1.8	
	for row in CSV.Rows(fname; 
	                    delim = ';',
	                    header = ["station", "temp"],
	                    types = Dict(2 => Float64))
				
		if row.station in keys(stations)
			push!(stations[row.station], row.temp)
		else
			stations[row.station] = [row.temp]
		end	
	end

	return stations
end

# ╔═╡ 2497157a-b02e-4ad6-8795-598adc28ddb5
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

# ╔═╡ be339d68-fc78-4d2a-a5e0-628305f55a75
function get_stations_df_v5(fname::String, num_chunks::Int)
	
	df_all_group = DataFrame()

	for chunk in CSV.Chunks(fname; 
	                        delim = ';',
	                        header = ["station", "temp"],
	                        types = [Symbol, Float32],
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

# ╔═╡ 2ea501bc-743f-4b90-83af-fa56723d7025
function groupby_stations(chunk)

	stations = chunk.station |> unique
	t_min, t_mean, t_max = [Vector{Float32}(undef, length(stations)) for i = 1:3]

	for i in eachindex(stations)
		chunk_filter = filter(row -> row.station == stations[i], chunk)
		
		# Pre-allocate for better performance
		temps = Vector{Float32}(undef, length(chunk_filter))
        for j in eachindex(chunk_filter)
			@inbounds temps[j] = chunk_filter[j].temp
		end
						
		t_min[i] = minimum(temps)
		t_mean[i] = mean(temps)
		t_max[i] = maximum(temps)
	end

	df_group = DataFrame(station = stations,
	                     temp_min = t_min,
	                     temp_mean = t_mean,
	                     temp_max = t_max)

	return df_group
end

# ╔═╡ 6c5c59fe-e1c7-452a-873a-4e03e2a18b01
function get_stations_df_v6(fname::String, num_chunks::Int)
	
	df_all_group = DataFrame()

	for chunk in CSV.Chunks(fname; 
	                        delim = ';',
	                        header = ["station", "temp"],
	                        types = [Symbol, Float32],
	                        strict = true,
	                        ntasks = num_chunks,
		                    pool = true
	                        )

		df_group = groupby_stations(chunk)

		# Vertically concatenate all DataFrames
		df_all_group = vcat(df_all_group, df_group)		
		
	end

	df_output = combine(groupby(df_all_group, :station, sort = true),
                            :temp_min  => minimum => :t_min,
                            :temp_mean => mean => :t_mean,
                            :temp_max  => maximum => :t_max
		               )

	df_output[!, :t_mean] = map(x -> round(x; digits = 1), 
		                        df_output[!, :t_mean])

	return df_output
end

# ╔═╡ 7c3c70ee-8c6c-4127-babe-ae78814156c0
md"
###### Using multi-threaded map function i.s.o. a for loop
"

# ╔═╡ 62c525b0-5e68-48a6-a4c0-23eae0824f22
function get_stations_df_v7(fname::String, num_chunks::Int)

	df_all = Vector{DataFrame}(undef, num_chunks)
	
	chunks = CSV.Chunks(fname; 
	                    delim = ';',
	                    header = ["station", "temp"],
	                    types = Dict("temp" => Float32),
	                    strict = true,
	                    ntasks = num_chunks,
		                pool = true
	                    )

	#df_all = ThreadsX.map(x -> groupby_stations(x), chunks)
	chunks_file = collect(chunks)
	
	# Execute in parallel on all available threads
	Threads.@threads for i in eachindex(chunks_file)
	    df_all[i] = groupby_stations(chunks_file[i])		
	end

	df_all_group = vcat(df_all...)

	df_output = combine(groupby(df_all_group, :station, sort = true),
                            :temp_min  => minimum => :t_min,
                            :temp_mean => mean => :t_mean,
                            :temp_max  => maximum => :t_max
		               )

	df_output[!, :t_mean] = map(x -> round(x; digits = 1), 
		                        df_output[!, :t_mean])

	return df_output
end

# ╔═╡ c2946753-d770-45c9-b5fe-96a992c8ebd8
function groupby_df(chunk)

	df_chunk = chunk |> DataFrame

	# Group stations from each chunk		
	df_group = combine(groupby(df_chunk, :station, sort = true),
						   :temp => minimum,
						   :temp => mean,
						   :temp => maximum
					  )

	return df_group

end

# ╔═╡ 33d75bbe-04f0-433e-a9cd-f7d7fee92e5f
function get_stations_df_v8(fname::String, num_chunks::Int)
	
	chunks = CSV.Chunks(fname; 
	                    delim = ';',
	                    header = ["station", "temp"],
	                    types = Dict("temp" => Float32),
	                    strict = true,
	                    ntasks = num_chunks,
		                pool = true
	                    )

	# Execute in parallel on available threads
	df_all = ThreadsX.map(x -> groupby_df(x), chunks, basesize = 2)

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

# ╔═╡ 2ce9cff2-f742-44e2-82e0-7d1f1bc0e747
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

# ╔═╡ fab88fa3-5211-44b5-8eff-203335123841
chunks = CSV.Chunks("measurements_test_10k.txt"; 
	                    delim = ';',
	                    header = ["station", "temp"],
	                    types = Dict("temp" => Float32),
	                    strict = true,
	                    ntasks = 8,
		                pool = true
	                    )

# ╔═╡ fe275494-b2bf-4f43-8346-53d283ea01b6
A = collect(chunks);

# ╔═╡ 88ff15ee-0c10-4044-9f96-e1a8e9ae9656
typeof(A)

# ╔═╡ 62e31e63-5239-4ebb-a4c1-d3d25731a765
#@btime get_stations_df_v7("measurements_test_10k.txt", 192);

# ╔═╡ b52e7336-5cbc-43a2-b6b7-f253bb4eb85c
#@btime get_stations_df_v8("measurements_test_10k.txt", 24);

# ╔═╡ b87395ee-6c9a-4b68-b17a-5e06cd13b4c3
#@btime get_stations_df_v5("measurements_test_10k.txt", 24);

# ╔═╡ b5b9a46d-3b36-41a4-b71a-0e442dace56d
#@btime get_stations_df_v6("measurements_test_10k.txt", 768);
# 0.811578 seconds (33.88 M allocations: 807.563 MiB, 3.42% gc time)
# 0.046259 seconds (275.29 k allocations: 34.608 MiB, 9.28% gc time)

# ╔═╡ cf2b20ac-7340-48f8-9c6d-7de921cd8dbf
#@btime get_stations_df_v5("measurements_test_10k.txt", 192);

# ╔═╡ 1b3276b8-d856-4008-b073-c99ce69fe032
#@btime get_stations_df_v7("measurements_test_20k.txt", 768);
# 23.754 ms (462150 allocations: 34.59 MiB) (chunks = 192, threads = 24)
# 35.614 ms (751157 allocations: 57.24 MiB) (using ThreadsX for unique, minimum and maximum)
# 19.977 ms (303553 allocations: 32.04 MiB) (using eachindex i.s.o. enumerate)
# 46.303 ms (379984 allocations: 23.85 MiB) (threads = 1)

# ╔═╡ 6220e7f1-887b-4467-b8b0-44435997ccf9
#@btime get_stations_df_v4("measurements_test_20k.txt", 48);

# ╔═╡ e48fc6e3-745e-4b90-92ff-84132c7f023f
#@btime get_stations_df_v8("measurements_test_20k.txt", 48);
# 16.300 ms (218759 allocations: 9.22 MiB) (with station type as Symbol)
# 7.832 ms (100228 allocations: 7.43 MiB) (with station type as fixed string)
# 12.932 ms (99964 allocations: 7.41 MiB) (threads = 1)

# ╔═╡ d27c89f1-4216-4808-9c2b-3099d843f6eb
#@btime get_stations_df_v9("measurements_test_20k.txt", 48);
# 8.048 ms (99576 allocations: 7.40 MiB) (chunks = 48, threads = 12)
# 12.763 ms (99521 allocations: 7.39 MiB) (chunks = 48, threads = 1)

# ╔═╡ e4f96a79-d637-4e0c-8352-ab1088b198a5
#@btime get_stations_df_v7("measurements_test_100k.txt", 6144);
# 467.136 ms (1426197 allocations: 279.57 MiB) (chunks = 384, threads = 2)
# 271.230 ms (1488292 allocations: 174.21 MiB) (chunks = 768, threads = 2)
# 186.510 ms (1605858 allocations: 136.65 MiB) (chunks = 1536, threads = 2)
# 175.875 ms (1813216 allocations: 116.24 MiB) (chunks = 3072, threads = 2)
# 115.407 ms (1813226 allocations: 116.24 MiB) (chunks = 3072, threads = 4)
# 107.787 ms (1813246 allocations: 116.24 MiB) (chunks = 3072, threads = 8)
# 132.456 ms (2244369 allocations: 133.85 MiB) (chunks = 6144, threads = 8)

# ╔═╡ d630d70c-1cbe-4f34-aff4-f3b1bacd7ccb
3072 / 8

# ╔═╡ cc624265-270a-4a4d-ac31-354d0ccb333f
384 * 12

# ╔═╡ 8a47b260-6bb0-46f1-a0be-93b07b398958
#@btime get_stations_df_v8("measurements_test_100k.txt", 96);
# 29.537 ms (382427 allocations: 26.72 MiB) (threads = 6, chunks = 48)
# 31.728 ms (425430 allocations: 32.37 MiB) (threads = 6, chunks = 96)
# 48.863 ms (425344 allocations: 32.36 MiB) (threads = 1, chunks = 96)
# 43.791 ms (425358 allocations: 32.36 MiB) (threads = 2, chunks = 96)

# ╔═╡ 06ba670e-c792-414d-b2bb-ca9dcec997be
get_stations_df_v9("measurements_test_100k.txt", 96);
# 31.901 ms (338701 allocations: 32.30 MiB) (threads = 6, chunks = 24)
# 28.562 ms (381928 allocations: 26.69 MiB) (threads = 6, chunks = 48)
# 32.837 ms (424494 allocations: 32.33 MiB) (threads = 6, chunks = 96)
# 48.448 ms (424469 allocations: 32.32 MiB) (threads = 1, chunks = 96)
# 41.469 ms (424474 allocations: 32.32 MiB) (threads = 2, chunks = 96)

# ╔═╡ 90b29c2f-d43a-4ec7-82e2-74437f56e06d
#@time get_stations_df_v5("measurements.txt", 192);
# 790.440265 seconds (9.89 G allocations: 244.658 GiB, 4.67% gc time, 0.07% compilation time)

# ╔═╡ 8c5bb36e-64b5-40dd-821a-b84ecf427c42
#@time get_stations_df_v4("measurements.txt", 192);
# 164.952828 seconds (1.01 G allocations: 61.211 GiB, 5.33% gc time, 1.08% compilation time: 23% of which was recompilation)
# 170.691496 seconds (1.01 G allocations: 61.157 GiB, 4.99% gc time) (threads = 24)

# ╔═╡ f19784e9-2b50-4722-a642-25254e864f57
# @time get_stations_df_v7("measurements.txt", 3072);
# > 8000 seconds 

# ╔═╡ a645592e-e9f1-4b27-9d36-351c6d6ae3f5
#@time get_stations_df_v8("measurements.txt", 192);
# 180.007490 seconds (1.01 G allocations: 58.085 GiB, 13.72% gc time, 0.39% compilation time) (threads = 6, basesize = 2)
# 174.764410 seconds (1.01 G allocations: 58.083 GiB, 11.29% gc time)
# 187.163915 seconds (1.01 G allocations: 58.083 GiB, 18.04% gc time) (chunks = 192)
# 212.453533 seconds (1.08 G allocations: 63.380 GiB, 23.02% gc time, 0.04% compilation time) (chunks = 3072, basesize = 2)
# 209.305900 seconds (1.08 G allocations: 63.376 GiB, 23.67% gc time, 0.06% compilation time) (chunks = 3072, basesize = 4)
# 216.378178 seconds (1.08 G allocations: 63.376 GiB, 24.20% gc time, 0.02% compilation time) (chunks = 3072, basesize = 16)
# 207.664344 seconds (1.08 G allocations: 63.418 GiB, 20.03% gc time, 2.46% compilation time) (chunks = 3072, basesize = 8, threads = 24)
# 352.883428 seconds (1.32 G allocations: 80.138 GiB, 50.40% gc time, 0.31% compilation time) (chunks = 12288)
# 188.490987 seconds (1.01 G allocations: 58.200 GiB, 9.62% gc time, 4.02% compilation time) (default basesize, chunks = 192)
# 242.397831 seconds (2.01 G allocations: 117.850 GiB, 12.03% gc time, 0.09% compilation time) (chunks = 96)
# 181.048599 seconds (1.01 G allocations: 58.106 GiB, 8.73% gc time, 0.24% compilation time)

# ╔═╡ 7b87fec1-5125-4dd7-8b08-9d885c7a6316
#@time get_stations_df_v9("measurements.txt", 192);
# 206.178802 seconds (1.00 G allocations: 87.856 GiB, 15.66% gc time) (threads = 6, chunks = 96)
# 179.361948 seconds (1.01 G allocations: 58.072 GiB, 13.93% gc time) (threads = 6, chunks = 192)
# 184.213278 seconds (1.01 G allocations: 58.436 GiB, 18.58% gc time, 0.04% compilation time) (threads = 6, chunks = 384)
# 189.941818 seconds (1.01 G allocations: 58.067 GiB, 16.45% gc time, 0.03% compilation time) (threads = 1, chunks = 192)
# 199.398815 seconds (1.01 G allocations: 58.069 GiB, 20.17% gc time, 0.12% compilation time) (threads = 2, chunks = 192)

# ╔═╡ 3f290913-2779-4eb2-b019-48cae14c06ec
192 * 4 * 2 * 2

# ╔═╡ 457fbe9e-f0aa-477a-9b16-7888a5c30909


# ╔═╡ e75cd6d1-b02a-4101-9359-3d556e539ba2
md"
###### Test implementation
"

# ╔═╡ 94c4e745-8ed0-4a5d-a261-0f92d5a8be07
@assert size(get_stations_df_v7("measurements_test_10k.txt", 4)) == size(get_stations_df_v8("measurements_test_10k.txt", 4)) "Output df sizes do not match"

# ╔═╡ c875320f-8e07-4fb3-8a03-7eb3ba3cdcc8
md"
#### Create a new dict with stations mapped to required output
"

# ╔═╡ c4b006ff-7d4e-4ed4-bdb3-6ac0c63d8b48
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

# ╔═╡ 3cd10b97-8c42-4d47-806f-bd2b957c9930
function calculate_output_v2(all_temps)

	output_temps = Vector{Float64}[]

	for temps in all_temps
		output_temp = [round(ThreadsX.minimum(temps); digits = 1), 
		               round(mean(temps); digits = 1), 
		               round(ThreadsX.maximum(temps); digits = 1)]
		push!(output_temps, output_temp)
	end

	return output_temps

end

# ╔═╡ 52e8e916-d448-4767-9b9d-4dcee95a275a
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

# ╔═╡ f0fa9a13-b01b-4402-80b3-92e3d2218989
md"
#### Print output
"

# ╔═╡ 34ff5bf7-014e-4185-8592-9305d3429e54
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

# ╔═╡ af10aa57-e2be-421e-9650-37be9c1f5aad
function print_output_v2(stations, output_temps)
	
	print("{")
	sorted_stations = sort(stations)
	
	# Output style: Abha=5.0/18.0/27.4
	for station in sorted_stations
		# Need to find the correct temp. array from original sequence
		find_idx = ThreadsX.findfirst(x -> x == station, stations)
		temps = output_temps[find_idx]
		print("$(station)=$(temps[1])/$(temps[2])/$(temps[3]), ")
	end

	print("}")

	return nothing

end

# ╔═╡ a7b474fe-e10d-433b-97d9-19dc9fbcf38e
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

# ╔═╡ c001a291-aed6-483f-ba16-71bb4971f1a6
md" 
#### Time full sequence
"

# ╔═╡ 1f0f558e-60fe-4c48-bac6-d140dd530841
function execute_challenge_v1(fname::String)

	get_stations_dict_v1(fname) |> calculate_output_v1 |> print_output_v1

end

# ╔═╡ 5581a801-213b-4266-98f2-ff515a731a75
# @time execute_challenge_v1("measurements.txt")
# 349.618470 seconds (3.00 G allocations: 303.705 GiB, 7.32% gc time)
# 371.050525 seconds (3.00 G allocations: 303.735 GiB, 6.65% gc time)

# ╔═╡ 71cd8cac-d124-403b-836a-8c7ab1633e61
function execute_challenge_v1_1(fname::String)

	get_stations_dict_v2(fname) |> calculate_output_v3 |> print_output_v1

end

# ╔═╡ 2f1afcf8-5827-4fb8-aef1-df2c6cc85a81
# @time execute_challenge_v1_1("measurements.txt")
# 528.758262 seconds (3.00 G allocations: 303.735 GiB, 4.59% gc time)

# ╔═╡ 63046959-e63c-425e-bc9e-487dcf2f9639
function execute_challenge_v2(fname::String)

	stations, all_temps = get_stations_v2(fname)
	output_temps = calculate_output_v2(all_temps)
	print_output_v2(stations, output_temps)

end

# ╔═╡ caf8a733-ad05-489f-b5a9-223b5cccc321
#@time execute_challenge_v2("measurements.txt")
# Process interrupted when time > 1800 seconds

# ╔═╡ 918e2fb0-a521-4c14-9b07-b6db8adda03f
function execute_challenge_v3(fname::String)

	get_stations_dict_v3(fname) |> calculate_output_v1 |> print_output_v1

end

# ╔═╡ e9d9c5f5-554a-4ea4-be6d-0bcdaae73cb0
#@time execute_challenge_v3("measurements.txt")
# > 800 seconds

# ╔═╡ ba23eb53-f6fd-4924-a7a0-f70fc981be33
function execute_challenge_v4(fname::String, num_chunks::Int)

	get_stations_df_v4(fname, num_chunks) |> print_output_v4

end

# ╔═╡ 059d50ae-1c56-429c-8b51-c8636be65c3e
function execute_challenge_v5(fname::String, num_chunks::Int)

	get_stations_df_v5(fname, num_chunks) |> print_output_v4

end

# ╔═╡ 2c924a23-a694-4ed3-b449-9cc55dc2b9b9
#@time execute_challenge_v4("measurements.txt", 48)
# 414.318812 seconds (3.88 G allocations: 162.503 GiB, 42.25% gc time, 0.03% compilation time)
# 409.120363 seconds (3.88 G allocations: 162.502 GiB, 41.48% gc time)

# ╔═╡ d2d7ba25-b41b-4675-ab30-6ff611f70276
# @time execute_challenge_v4("measurements.txt", 24)
# 593.550114 seconds (3.88 G allocations: 162.229 GiB, 61.22% gc time)

# ╔═╡ 5a40851a-7679-4656-b89d-c09905488b7f
# @time execute_challenge_v4("measurements.txt", 96)
# 319.955607 seconds (3.88 G allocations: 163.512 GiB, 26.39% gc time)
# 183.303949 seconds (1.00 G allocations: 89.484 GiB, 7.04% gc time, 0.03% compilation time) (with pool = true, using fixed-width string type and Float32 for temp)

# ╔═╡ 05d39f62-0490-483e-9d2b-abb2c62a861a
#@time execute_challenge_v4("measurements.txt", 192)
# 264.546108 seconds (3.89 G allocations: 137.408 GiB, 20.19% gc time)
# 160.090199 seconds (1.01 G allocations: 61.996 GiB, 5.24% gc time) (with pool = true, using fixed-width string type and Float32 for temp)

# ╔═╡ 5db68425-6076-4511-8183-626737b146cc
#@time execute_challenge_v4("measurements.txt", 768)
# 257.606806 seconds (3.90 G allocations: 212.066 GiB, 15.96% gc time)
# 187.627493 seconds (1.02 G allocations: 146.107 GiB, 7.28% gc time, 0.32% compilation time) (with pool = 0.4)
# 250.394454 seconds (3.90 G allocations: 212.066 GiB, 13.82% gc time)
# 189.346376 seconds (1.02 G allocations: 146.079 GiB, 9.16% gc time) (with pool = 0.4)
# 192.084528 seconds (1.02 G allocations: 146.079 GiB, 7.56% gc time, 0.00% compilation time) (with pool = true and using fixed-width string type)
# 176.931510 seconds (1.02 G allocations: 109.176 GiB, 7.12% gc time, 1.44% compilation time: 17% of which was recompilation) (with pool = true, using fixed-width string type and Float32 for temp)

# ╔═╡ ae3d5525-e2a5-4e7b-9e0e-9c39f0b759b3
#@time execute_challenge_v4("measurements.txt", 3072)
# 1023.051909 seconds (1.08 G allocations: 848.873 GiB, 42.83% gc time, 0.00% compilation time)

# ╔═╡ ee3a65bb-7a4a-45bd-bead-448178421bcd
#@time execute_challenge_v5("measurements.txt", 96)
# > 500 seconds

# ╔═╡ 2c683710-43bd-4c82-9687-10ad802e1069
#@time execute_challenge_v4("measurements_test.txt", 2)

# ╔═╡ ba9dfbf8-74aa-417c-8f07-3682e15ded00
function execute_challenge_v6(fname::String, num_chunks::Int)

	get_stations_df_v6(fname, num_chunks) |> print_output_v4

end

# ╔═╡ 1fdb4af8-a93f-4772-8ec1-68076824afbc
#@time execute_challenge_v6("measurements.txt", 24)
# > 900 seconds for chunks = 24
# > 900 seconds for chunks = 192
# > 500 seconds for chunks = 192_00000
# > 500 seconds for chunks = 192_000
# > 1000 seconds for chunks = 1920
# > 2500 seconds for chunks = 3072

# ╔═╡ 3fdbb273-d1ea-4ede-8d56-5d5a13504a80
md"
###### Using multi-threading via ThreadsX.map
"

# ╔═╡ 037eb961-cd13-41e0-9ec4-052d84114813
function execute_challenge_v7(fname::String, num_chunks::Int)

	get_stations_df_v7(fname, num_chunks) |> print_output_v4

end

# ╔═╡ a05a779d-0e7e-48c0-a3af-0cc1d7c94a2e
#@time execute_challenge_v7("measurements.txt", 3072)
# > 300 seconds for chunks = 3072

# ╔═╡ 15aee5e0-e783-4ad9-9e8f-5a1fd02dce53
function execute_challenge_v8(fname::String, num_chunks::Int)

	get_stations_df_v8(fname, num_chunks) |> print_output_v4

end

# ╔═╡ e91246d1-4557-455b-a2e4-27ef50a85aab
#@time execute_challenge_v8("measurements.txt", 96)
# Out of memory for chunks = 24
# 706.389460 seconds (9.88 G allocations: 242.306 GiB, 5.34% gc time, 0.80% compilation time) for chunks = 96
# 682.845490 seconds (9.88 G allocations: 242.272 GiB, 5.16% gc time) for chunks = 96, basesize = 1

# ╔═╡ 091e28d3-c216-4178-845f-844da6a99e11
Threads.nthreads()

# ╔═╡ 728a5b9c-39df-4a53-bf09-7c780f6bde15
(768 * 4)

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
BenchmarkTools = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
ProgressMeter = "92933f4c-e287-5a05-a399-4b506db050ca"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
ThreadsX = "ac1d9e8a-700a-412c-b207-f0111f4b6c0d"

[compat]
BenchmarkTools = "~1.4.0"
CSV = "~0.10.12"
DataFrames = "~1.6.1"
ProgressMeter = "~1.9.0"
ThreadsX = "~0.1.12"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.10.2"
manifest_format = "2.0"
project_hash = "0ee0dc20ddb723768e27bb53a825ac2ea6cb7e06"

[[deps.Accessors]]
deps = ["CompositionsBase", "ConstructionBase", "Dates", "InverseFunctions", "LinearAlgebra", "MacroTools", "Test"]
git-tree-sha1 = "cb96992f1bec110ad211b7e410e57ddf7944c16f"
uuid = "7d9f7c33-5ae7-4f3b-8dc6-eff91059b697"
version = "0.1.35"

    [deps.Accessors.extensions]
    AccessorsAxisKeysExt = "AxisKeys"
    AccessorsIntervalSetsExt = "IntervalSets"
    AccessorsStaticArraysExt = "StaticArrays"
    AccessorsStructArraysExt = "StructArrays"

    [deps.Accessors.weakdeps]
    AxisKeys = "94b1ba4f-4ee9-5380-92f1-94cde586c3c5"
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"
    Requires = "ae029012-a4dd-5104-9daa-d747884805df"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"
    StructArrays = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"

[[deps.Adapt]]
deps = ["LinearAlgebra", "Requires"]
git-tree-sha1 = "0fb305e0253fd4e833d486914367a2ee2c2e78d0"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "4.0.1"

    [deps.Adapt.extensions]
    AdaptStaticArraysExt = "StaticArrays"

    [deps.Adapt.weakdeps]
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.ArgCheck]]
git-tree-sha1 = "a3a402a35a2f7e0b87828ccabbd5ebfbebe356b4"
uuid = "dce04be8-c92d-5529-be00-80e4d2c0e197"
version = "2.3.0"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.BangBang]]
deps = ["Accessors", "Compat", "ConstructionBase", "InitialValues", "LinearAlgebra", "Requires"]
git-tree-sha1 = "ffe3b6222215a9cf7ce449ad0b91274787a801c3"
uuid = "198e06fe-97b7-11e9-32a5-e1d131e6ad66"
version = "0.4.0"

    [deps.BangBang.extensions]
    BangBangChainRulesCoreExt = "ChainRulesCore"
    BangBangDataFramesExt = "DataFrames"
    BangBangStaticArraysExt = "StaticArrays"
    BangBangStructArraysExt = "StructArrays"
    BangBangTablesExt = "Tables"
    BangBangTypedTablesExt = "TypedTables"

    [deps.BangBang.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"
    StructArrays = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
    Tables = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
    TypedTables = "9d95f2ec-7b3d-5a63-8d20-e2491e220bb9"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.Baselet]]
git-tree-sha1 = "aebf55e6d7795e02ca500a689d326ac979aaf89e"
uuid = "9718e550-a3fa-408a-8086-8db961cd8217"
version = "0.1.1"

[[deps.BenchmarkTools]]
deps = ["JSON", "Logging", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "f1f03a9fa24271160ed7e73051fba3c1a759b53f"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.4.0"

[[deps.CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "InlineStrings", "Mmap", "Parsers", "PooledArrays", "PrecompileTools", "SentinelArrays", "Tables", "Unicode", "WeakRefStrings", "WorkerUtilities"]
git-tree-sha1 = "679e69c611fff422038e9e21e270c4197d49d918"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.10.12"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "59939d8a997469ee05c4b4944560a820f9ba0d73"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.4"

[[deps.Compat]]
deps = ["TOML", "UUIDs"]
git-tree-sha1 = "75bd5b6fc5089df449b5d35fa501c846c9b6549b"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.12.0"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.1.0+0"

[[deps.CompositionsBase]]
git-tree-sha1 = "802bb88cd69dfd1509f6670416bd4434015693ad"
uuid = "a33af91c-f02d-484b-be07-31d278c5ca2b"
version = "0.1.2"
weakdeps = ["InverseFunctions"]

    [deps.CompositionsBase.extensions]
    CompositionsBaseInverseFunctionsExt = "InverseFunctions"

[[deps.ConstructionBase]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "c53fc348ca4d40d7b371e71fd52251839080cbc9"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.5.4"

    [deps.ConstructionBase.extensions]
    ConstructionBaseIntervalSetsExt = "IntervalSets"
    ConstructionBaseStaticArraysExt = "StaticArrays"

    [deps.ConstructionBase.weakdeps]
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.DataAPI]]
git-tree-sha1 = "abe83f3a2f1b857aac70ef8b269080af17764bbe"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.16.0"

[[deps.DataFrames]]
deps = ["Compat", "DataAPI", "DataStructures", "Future", "InlineStrings", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrecompileTools", "PrettyTables", "Printf", "REPL", "Random", "Reexport", "SentinelArrays", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "04c738083f29f86e62c8afc341f0967d8717bdb8"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.6.1"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "ac67408d9ddf207de5cfa9a97e114352430f01ed"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.16"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.DefineSingletons]]
git-tree-sha1 = "0fba8b706d0178b4dc7fd44a96a92382c9065c2c"
uuid = "244e2a9f-e319-4986-a169-4d1fe445cd52"
version = "0.1.2"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.FilePathsBase]]
deps = ["Compat", "Dates", "Mmap", "Printf", "Test", "UUIDs"]
git-tree-sha1 = "9f00e42f8d99fdde64d40c8ea5d14269a2e2c1aa"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.21"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.InitialValues]]
git-tree-sha1 = "4da0f88e9a39111c2fa3add390ab15f3a44f3ca3"
uuid = "22cec73e-a1b8-11e9-2c92-598750a2cf9c"
version = "0.3.1"

[[deps.InlineStrings]]
deps = ["Parsers"]
git-tree-sha1 = "9cc2baf75c6d09f9da536ddf58eb2f29dedaf461"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.4.0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.InverseFunctions]]
deps = ["Test"]
git-tree-sha1 = "68772f49f54b479fa88ace904f6127f0a3bb2e46"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.12"

[[deps.InvertedIndices]]
git-tree-sha1 = "0dc7b50b8d436461be01300fd8cd45aa0274b038"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.3.0"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.LaTeXStrings]]
git-tree-sha1 = "50901ebc375ed41dbf8058da26f9de442febbbec"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.1"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "2fa9ee3e63fd3a4f7a9a4f4744a52f4856de82df"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.13"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MicroCollections]]
deps = ["Accessors", "BangBang", "InitialValues"]
git-tree-sha1 = "44d32db644e84c75dab479f1bc15ee76a1a3618f"
uuid = "128add7d-3638-4c79-886c-908ea0c25c34"
version = "0.2.0"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "f66bdc5de519e8f8ae43bdc598782d35a25b1272"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.1.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.23+4"

[[deps.OrderedCollections]]
git-tree-sha1 = "dfdf5519f235516220579f949664f1bf44e741c5"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.6.3"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "8489905bcdbcfac64d1daa51ca07c0d8f0283821"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.1"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "36d8b4b899628fb92c2749eb488d884a926614d3"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.3"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "03b4c25b43cb84cee5c90aa9b5ea0a78fd848d2f"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.2.0"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "00805cd429dcb4870060ff49ef443486c262e38e"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.4.1"

[[deps.PrettyTables]]
deps = ["Crayons", "LaTeXStrings", "Markdown", "PrecompileTools", "Printf", "Reexport", "StringManipulation", "Tables"]
git-tree-sha1 = "88b895d13d53b5577fd53379d913b9ab9ac82660"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "2.3.1"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.Profile]]
deps = ["Printf"]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"

[[deps.ProgressMeter]]
deps = ["Distributed", "Printf"]
git-tree-sha1 = "00099623ffee15972c16111bcf84c58a0051257c"
uuid = "92933f4c-e287-5a05-a399-4b506db050ca"
version = "1.9.0"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.Referenceables]]
deps = ["Adapt"]
git-tree-sha1 = "02d31ad62838181c1a3a5fd23a1ce5914a643601"
uuid = "42d2dcc6-99eb-4e98-b66c-637b7d73030e"
version = "0.1.3"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "0e7508ff27ba32f26cd459474ca2ede1bc10991f"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.4.1"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "StaticArraysCore"]
git-tree-sha1 = "e2cc6d8c88613c05e1defb55170bf5ff211fbeac"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "1.1.1"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "66e0a8e672a0bdfca2c3f5937efb8538b9ddc085"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.2.1"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.10.0"

[[deps.SplittablesBase]]
deps = ["Setfield", "Test"]
git-tree-sha1 = "e08a62abc517eb79667d0a29dc08a3b589516bb5"
uuid = "171d559e-b47b-412a-8079-5efa626c420e"
version = "0.1.15"

[[deps.StaticArraysCore]]
git-tree-sha1 = "36b3d696ce6366023a0ea192b4cd442268995a0d"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.2"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.10.0"

[[deps.StringManipulation]]
deps = ["PrecompileTools"]
git-tree-sha1 = "a04cabe79c5f01f4d723cc6704070ada0b9d46d5"
uuid = "892a3eda-7b42-436c-8928-eab12a02cf0e"
version = "0.3.4"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.2.1+1"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "TableTraits"]
git-tree-sha1 = "cb76cf677714c095e535e3501ac7954732aeea2d"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.11.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.ThreadsX]]
deps = ["Accessors", "ArgCheck", "BangBang", "ConstructionBase", "InitialValues", "MicroCollections", "Referenceables", "SplittablesBase", "Transducers"]
git-tree-sha1 = "70bd8244f4834d46c3d68bd09e7792d8f571ef04"
uuid = "ac1d9e8a-700a-412c-b207-f0111f4b6c0d"
version = "0.1.12"

[[deps.TranscodingStreams]]
git-tree-sha1 = "54194d92959d8ebaa8e26227dbe3cdefcdcd594f"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.10.3"
weakdeps = ["Random", "Test"]

    [deps.TranscodingStreams.extensions]
    TestExt = ["Test", "Random"]

[[deps.Transducers]]
deps = ["Accessors", "Adapt", "ArgCheck", "BangBang", "Baselet", "CompositionsBase", "ConstructionBase", "DefineSingletons", "Distributed", "InitialValues", "Logging", "Markdown", "MicroCollections", "Requires", "SplittablesBase", "Tables"]
git-tree-sha1 = "47e516e2eabd0cf1304cd67839d9a85d52dd659d"
uuid = "28d57a85-8fef-5791-bfe6-a80928e7c999"
version = "0.4.81"

    [deps.Transducers.extensions]
    TransducersBlockArraysExt = "BlockArrays"
    TransducersDataFramesExt = "DataFrames"
    TransducersLazyArraysExt = "LazyArrays"
    TransducersOnlineStatsBaseExt = "OnlineStatsBase"
    TransducersReferenceablesExt = "Referenceables"

    [deps.Transducers.weakdeps]
    BlockArrays = "8e7c35d0-a365-5155-bbbb-fb81a777f24e"
    DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
    LazyArrays = "5078a376-72f3-5289-bfd5-ec5146d43c02"
    OnlineStatsBase = "925886fa-5bf2-5e8e-b522-a9147a512338"
    Referenceables = "42d2dcc6-99eb-4e98-b66c-637b7d73030e"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.WeakRefStrings]]
deps = ["DataAPI", "InlineStrings", "Parsers"]
git-tree-sha1 = "b1be2855ed9ed8eac54e5caff2afcdb442d52c23"
uuid = "ea10d353-3f73-51f8-a26c-33c1cb351aa5"
version = "1.4.2"

[[deps.WorkerUtilities]]
git-tree-sha1 = "cd1659ba0d57b71a464a29e64dbc67cfe83d54e7"
uuid = "76eceee3-57b5-4d4a-8e66-0e911cebbf60"
version = "1.6.1"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+1"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.8.0+1"
"""

# ╔═╡ Cell order:
# ╟─91c47eca-ffc5-11ee-2558-b3f40cc93e49
# ╠═48d6ae88-fafe-4f37-ba3d-34be727b19c2
# ╟─5148881a-1edc-4073-94e3-e56f7fff605f
# ╟─d8e57b27-1e78-4aa9-9117-07c0bdce17ca
# ╠═be669e6e-cc33-46f4-b7f0-93fdf9ec217a
# ╟─4c7d5d3e-fa39-4df3-8f98-d9c990c71f10
# ╟─626bafd1-7b38-4bc3-867a-2714cff2fbf6
# ╟─0a46b87b-364d-4807-bce9-feb3d89d1bfa
# ╟─8eee43c2-fd05-4583-8f2d-717233973c23
# ╟─2497157a-b02e-4ad6-8795-598adc28ddb5
# ╟─be339d68-fc78-4d2a-a5e0-628305f55a75
# ╟─2ea501bc-743f-4b90-83af-fa56723d7025
# ╟─6c5c59fe-e1c7-452a-873a-4e03e2a18b01
# ╟─7c3c70ee-8c6c-4127-babe-ae78814156c0
# ╟─62c525b0-5e68-48a6-a4c0-23eae0824f22
# ╟─c2946753-d770-45c9-b5fe-96a992c8ebd8
# ╟─33d75bbe-04f0-433e-a9cd-f7d7fee92e5f
# ╟─2ce9cff2-f742-44e2-82e0-7d1f1bc0e747
# ╠═fab88fa3-5211-44b5-8eff-203335123841
# ╠═fe275494-b2bf-4f43-8346-53d283ea01b6
# ╠═88ff15ee-0c10-4044-9f96-e1a8e9ae9656
# ╠═62e31e63-5239-4ebb-a4c1-d3d25731a765
# ╠═b52e7336-5cbc-43a2-b6b7-f253bb4eb85c
# ╠═b87395ee-6c9a-4b68-b17a-5e06cd13b4c3
# ╠═b5b9a46d-3b36-41a4-b71a-0e442dace56d
# ╠═cf2b20ac-7340-48f8-9c6d-7de921cd8dbf
# ╠═1b3276b8-d856-4008-b073-c99ce69fe032
# ╠═6220e7f1-887b-4467-b8b0-44435997ccf9
# ╠═e48fc6e3-745e-4b90-92ff-84132c7f023f
# ╠═d27c89f1-4216-4808-9c2b-3099d843f6eb
# ╠═e4f96a79-d637-4e0c-8352-ab1088b198a5
# ╠═d630d70c-1cbe-4f34-aff4-f3b1bacd7ccb
# ╠═cc624265-270a-4a4d-ac31-354d0ccb333f
# ╠═8a47b260-6bb0-46f1-a0be-93b07b398958
# ╠═06ba670e-c792-414d-b2bb-ca9dcec997be
# ╠═90b29c2f-d43a-4ec7-82e2-74437f56e06d
# ╠═8c5bb36e-64b5-40dd-821a-b84ecf427c42
# ╠═f19784e9-2b50-4722-a642-25254e864f57
# ╠═a645592e-e9f1-4b27-9d36-351c6d6ae3f5
# ╠═7b87fec1-5125-4dd7-8b08-9d885c7a6316
# ╠═3f290913-2779-4eb2-b019-48cae14c06ec
# ╠═457fbe9e-f0aa-477a-9b16-7888a5c30909
# ╟─e75cd6d1-b02a-4101-9359-3d556e539ba2
# ╠═94c4e745-8ed0-4a5d-a261-0f92d5a8be07
# ╟─c875320f-8e07-4fb3-8a03-7eb3ba3cdcc8
# ╟─c4b006ff-7d4e-4ed4-bdb3-6ac0c63d8b48
# ╟─3cd10b97-8c42-4d47-806f-bd2b957c9930
# ╟─52e8e916-d448-4767-9b9d-4dcee95a275a
# ╟─f0fa9a13-b01b-4402-80b3-92e3d2218989
# ╟─34ff5bf7-014e-4185-8592-9305d3429e54
# ╟─af10aa57-e2be-421e-9650-37be9c1f5aad
# ╟─a7b474fe-e10d-433b-97d9-19dc9fbcf38e
# ╟─c001a291-aed6-483f-ba16-71bb4971f1a6
# ╟─1f0f558e-60fe-4c48-bac6-d140dd530841
# ╠═5581a801-213b-4266-98f2-ff515a731a75
# ╟─71cd8cac-d124-403b-836a-8c7ab1633e61
# ╠═2f1afcf8-5827-4fb8-aef1-df2c6cc85a81
# ╟─63046959-e63c-425e-bc9e-487dcf2f9639
# ╠═caf8a733-ad05-489f-b5a9-223b5cccc321
# ╟─918e2fb0-a521-4c14-9b07-b6db8adda03f
# ╠═e9d9c5f5-554a-4ea4-be6d-0bcdaae73cb0
# ╠═ba23eb53-f6fd-4924-a7a0-f70fc981be33
# ╟─059d50ae-1c56-429c-8b51-c8636be65c3e
# ╠═2c924a23-a694-4ed3-b449-9cc55dc2b9b9
# ╠═d2d7ba25-b41b-4675-ab30-6ff611f70276
# ╠═5a40851a-7679-4656-b89d-c09905488b7f
# ╠═05d39f62-0490-483e-9d2b-abb2c62a861a
# ╠═5db68425-6076-4511-8183-626737b146cc
# ╠═ae3d5525-e2a5-4e7b-9e0e-9c39f0b759b3
# ╠═ee3a65bb-7a4a-45bd-bead-448178421bcd
# ╠═2c683710-43bd-4c82-9687-10ad802e1069
# ╟─ba9dfbf8-74aa-417c-8f07-3682e15ded00
# ╠═1fdb4af8-a93f-4772-8ec1-68076824afbc
# ╟─3fdbb273-d1ea-4ede-8d56-5d5a13504a80
# ╟─037eb961-cd13-41e0-9ec4-052d84114813
# ╠═a05a779d-0e7e-48c0-a3af-0cc1d7c94a2e
# ╟─15aee5e0-e783-4ad9-9e8f-5a1fd02dce53
# ╠═e91246d1-4557-455b-a2e4-27ef50a85aab
# ╠═091e28d3-c216-4178-845f-844da6a99e11
# ╠═728a5b9c-39df-4a53-bf09-7c780f6bde15
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002