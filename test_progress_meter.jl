using ProgressMeter
p = Progress(10)
Threads.@threads for i in 1:10
    sleep(2*rand())
    next!(p)
end
finish!(p)