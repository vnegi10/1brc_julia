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