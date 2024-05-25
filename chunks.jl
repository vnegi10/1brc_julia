using Mmap, Statistics

function get_chunks(fname::String, num_chunks::Int64)
    
    # Use memory mapping to read large file
    fopen = open(fname, "r")
    fmmap = Mmap.mmap(fopen)

    # Find suitable range for reading each chunk
    i_max = length(fmmap)
    chunk_size = round(Int, (i_max / num_chunks))
    i_start = 1
    i_end = chunk_size

    all_start, all_end = [Int64[] for i = 1:2]
    all_chunks = Vector{UInt8}[]

    # Find indexes for start and end of each chunk
    while i_end ≤ i_max

        # Exit after processing last chunk
        if i_end == i_max
            break
        end
        
        # Check if we end at byte representation of new-line character
        while fmmap[i_end] != 0x0a
            i_end += 1
        end

        push!(all_start, i_start)
        push!(all_end, i_end)

        # Move to next chunk
        i_start = i_end + 1
        i_end = i_start + chunk_size

        if i_end > i_max
            i_end = i_max
            push!(all_start, i_start)
            push!(all_end, i_end)
        end

    end

    @assert length(all_start) == length(all_end) "Length of index vectors doesn't match"

    for i in eachindex(all_start)
        push!(all_chunks, fmmap[all_start[i]:all_end[i]])
    end

    close(fopen)

    return all_chunks
    
end

function process_chunk_v1(chunk)
    stations = Dict{String, Vector{Float32}}()
    io_stream = IOBuffer(chunk)
    
    # Use of eachline requires Julia 1.8
    for line in eachline(io_stream)
        line_parts = split(line, ";")
        station, temp = line_parts[1], parse(Float32, line_parts[2])
        if haskey(stations, station)
            push!(stations[station], temp)
        else
            stations[station] = [temp]
        end
    end

    return stations
end

function process_chunk_v2(chunk)
    stations = Dict{String, Vector{Float32}}()
    io_stream = IOBuffer(chunk)
    
    # Use of eachline requires Julia 1.8
    for line in eachline(io_stream)
        line_parts = split(line, ";")
        station, temp = line_parts[1], parse(Float32, line_parts[2])
        if haskey(stations, station)
            # Find min and max
            if temp ≤ stations[station][1]
                # Replace when a new minimum is found
                stations[station][1] = temp
            else
                # Replace when a new maximum is found
                if temp ≥ stations[station][3]
                    stations[station][3] = temp
                end
            end        

            # Mean
            stations[station][2] += temp
            stations[station][4] += 1.0
            
        else
            # min, sum, max, counter
            stations[station] = [temp, temp, temp, 1.0]
        end
    end

    return stations
end

function process_chunk_v3(chunk)
    stations = Dict{String, Vector{Float32}}()
    io_stream = IOBuffer(chunk)
    
    # Use of eachline requires Julia 1.8
    for line in eachline(io_stream)
        pos = findfirst(';', line)
        station = @view(line[1:prevind(line, pos)])
        temp = parse(Float32, @view(line[pos+1:end]))
        if haskey(stations, station)
            # Find min and max
            if temp ≤ stations[station][1]
                # Replace when a new minimum is found
                stations[station][1] = temp
            else
                # Replace when a new maximum is found
                if temp ≥ stations[station][3]
                    stations[station][3] = temp
                end
            end

            # Mean
            stations[station][2] += temp
            stations[station][4] += 1.0
            
        else
            # min, sum, max, counter
            stations[station] = [temp, temp, temp, 1.0]
        end
    end

    return stations
end

function process_chunk_v4(chunk)
    stations = Dict{String, Vector{Float32}}()
    io_stream = IOBuffer(chunk)
    
    # Use of eachline requires Julia 1.8
    while !eof(io_stream)
        line = readline(io_stream)
        pos = findfirst(';', line)
        station = @view(line[1:prevind(line, pos)])
        temp = parse(Float32, @view(line[pos+1:end]))
        if haskey(stations, station)
            stations[station][1] = min(temp, stations[station][1])
            # Mean = Total temp / Number of times a match is found
            stations[station][2] += temp
            stations[station][3] = max(temp, stations[station][3])
            stations[station][4] += 1.0
        else
            # min, sum, max, counter
            stations[station] = [temp, temp, temp, 1.0]
        end
    end

    return stations
end

function combine_chunks_v1(all_stations)

    list_stations = Vector{Vector{String}}()

    for stations in all_stations
        list_station = collect(keys(stations))
        push!(list_stations, list_station)
    end

    # Concatenate into a single vector and remove duplicates
    list_stations = vcat(list_stations...)
    list_stations = unique(list_stations)

    combined_stations = Dict{String, Vector{Float32}}()

    # Collect data for every station
    for station in list_stations
        temps = Vector{Vector{Float32}}()
        
        for stations in all_stations
            if haskey(stations, station)
                push!(temps, stations[station])
            end
        end

        # Concatenate into a single vector of temperatures
        temps = vcat(temps...)
        
        combined_stations[station] = [round(minimum(temps); digits = 1),
                                      round(mean(temps); digits = 1),
                                      round(maximum(temps); digits = 1)]

    end

    return combined_stations

end

function combine_chunks_v2(all_stations)

    list_stations = Vector{Vector{String}}()

    for stations in all_stations
        list_station = collect(keys(stations))
        push!(list_stations, list_station)
    end

    # Concatenate into a single vector and remove duplicates
    list_stations = vcat(list_stations...)
    list_stations = unique(list_stations)

    combined_stations = Dict{String, Vector{Float32}}()

    # Collect data for every station
    for station in list_stations
        mins, sums, maxs, counters = [Float32[] for i = 1:4]
        
        for stations in all_stations
            if haskey(stations, station)
                push!(mins, stations[station][1])
                push!(sums, stations[station][2])
                push!(maxs, stations[station][3])
                push!(counters, stations[station][4])
            end
        end

        combined_stations[station] = [round(minimum(mins); digits = 1),
                                      round((sum(sums) / sum(counters));digits = 1),
                                      round(maximum(maxs); digits = 1)]

    end

    return combined_stations

end