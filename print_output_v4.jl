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