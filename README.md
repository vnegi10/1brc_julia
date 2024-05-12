# One Billion Row Challenge in Julia

This repository contains scripts where I have made an attempt to tackle Gunnar's
popular [One Billion Row Challenge.](https://www.morling.dev/blog/one-billion-row-challenge/)

Though originally intended for the Java community, the challenge has since then been
addressed in [many other](https://1brc.dev/#the-challenge) languages. I am sure the
performance in Julia can be much better than what I have been able to achieve.

## How to run?

- Dependencies can be installed using the `Project.toml` file

```julia
using Pkg
Pkg.activate()
```

- Input file `measurements.txt` is not added here due to its large size. You can generate
your own file by executing the Python script from [here.](https://github.com/gunnarmorling/1brc/blob/main/src/main/python/create_measurements.py)

```python
python3 create_measurements.py 1000000000
```

- Benchmark can be triggered from the Julia REPL as shown below. This will take about
10-15 minutes to complete.

```julia
julia> ARGS = ["measurements.txt", "24"]
julia> include("execute_df_v11.jl")
```

- `1brc_notebook.jl` is a [Pluto](https://github.com/fonsp/Pluto.jl)
notebook, where all different implementations have been tested. Make sure to first
generate the input data file as described above.

## Strategy
The following strategy has given me the best result so far:

1. Use memory mapping to read the file
2. Generate indexes that will split file into chunks (based on user input)
3. Loop through the chunks, read each chunk (into a DataFrame) in parallel using `CSV.read`
4. Use `groupby` and `combine` on station, get min, max, and mean of all temperatures
5. Vertically concatenate all DataFrames
6. Finally repeat step 4 again to combine data from all chunks
7. Format according to challenge specifications and print output

## Result (Ryzen 9 5900X, 32 GB RAM, NVMe SSD)

```julia
julia> Threads.nthreads()
12

julia> include("execute_df_v11.jl")
< printed output is omitted for clarity >
Range (min … max):  89.459 s … 94.728 s  ┊ GC (min … max): 10.08% … 10.85%
 Time  (median):     90.178 s             ┊ GC (median):    10.54%
 Time  (mean ± σ):   90.765 s ±  1.567 s  ┊ GC (mean ± σ):  10.41% ±  0.41%

  █ ██ ██  █   █     █    █                               █  
  █▁██▁██▁▁█▁▁▁█▁▁▁▁▁█▁▁▁▁█▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁█ ▁
  89.5 s         Histogram: frequency by time        94.7 s <

 Memory estimate: 92.03 GiB, allocs estimate: 1000828591.
```