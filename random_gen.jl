using Random

# With a seed
Random.seed!(1234)  # Set the seed for reproducibility
println("Random numbers with seed:")
for i in 1:5
    println(rand())
end

# Without a seed
println("<br />Random numbers without seed:")
for i in 1:5
    println(rand())
end