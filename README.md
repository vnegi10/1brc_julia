# One Billion Row Challenge in Julia

This repository contains scripts where I have made an attempt to tackle Gunnar's
popular [One Billion Row Challenge.](https://www.morling.dev/blog/one-billion-row-challenge/)

Though originally intended for the Java community, the challenge has since then been
addressed in [many other](https://1brc.dev/#the-challenge) languages. I am sure the
performance in Julia can be much better than what I have been able to achieve.

## How to run?

- Dependencies can be installed using the `Project.toml` file. Execute the following
code in the Julia REPL from the root of this repository.

```julia
using Pkg
Pkg.activate(pwd())
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

## Benchmark system (Ryzen 9 5900X, 32 GB RAM, NVMe SSD)

```julia
julia> versioninfo()
Julia Version 1.10.2
Commit bd47eca2c8a (2024-03-01 10:14 UTC)
Build Info:
  Official https://julialang.org/ release
Platform Info:
  OS: Linux (x86_64-linux-gnu)
  CPU: 24 × AMD Ryzen 9 5900X 12-Core Processor
  WORD_SIZE: 64
  LIBM: libopenlibm
  LLVM: libLLVM-15.0.7 (ORCJIT, znver3)
Threads: 12 default, 0 interactive, 6 GC (on 24 virtual cores)
Environment:
  JULIA_EDITOR = code
  JULIA_NUM_THREADS = 12
  JULIA_PKG_USE_CLI_GIT = true
```

## Best results

#### Using external dependencies (CSV.jl, DataFrames.jl)

```julia
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

#### Using only base Julia

```julia
julia> ARGS = ["measurements.txt", "384"]
julia> include("execute_base_v1_4.jl")
< printed output is omitted for clarity >
Range (min … max):  71.958 s …   74.295 s  ┊ GC (min … max): 39.73% … 38.84%
 Time  (median):     72.886 s               ┊ GC (median):    39.44%
 Time  (mean ± σ):   72.889 s ± 705.485 ms  ┊ GC (mean ± σ):  39.44% ±  0.31%

  ▁    ▁     ▁   ▁      ▁ █▁                   ▁            ▁  
  █▁▁▁▁█▁▁▁▁▁█▁▁▁█▁▁▁▁▁▁█▁██▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁█▁▁▁▁▁▁▁▁▁▁▁▁█ ▁
  72 s            Histogram: frequency by time         74.3 s <

 Memory estimate: 157.38 GiB, allocs estimate: 2010613120.
```

```julia
julia> ARGS = ["measurements.txt", "24"]
julia> include("execute_base_v1_5.jl")
< printed output is omitted for clarity >
 Range (min … max):  64.612 s …   66.248 s  ┊ GC (min … max): 35.02% … 34.99%
 Time  (median):     65.529 s               ┊ GC (median):    34.63%
 Time  (mean ± σ):   65.438 s ± 604.725 ms  ┊ GC (mean ± σ):  34.81% ±  0.41%

  █            █                 ▁   ▁      ▁    ▁      ▁   ▁  
  █▁▁▁▁▁▁▁▁▁▁▁▁█▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁█▁▁▁█▁▁▁▁▁▁█▁▁▁▁█▁▁▁▁▁▁█▁▁▁█ ▁
  64.6 s          Histogram: frequency by time         66.2 s <

 Memory estimate: 156.46 GiB, allocs estimate: 2000885392.
```