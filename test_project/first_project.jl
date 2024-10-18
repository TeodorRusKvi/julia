a = 3;
b = 4;
c = a + 4

function myfunc(a, b, c)
    d = a+b*c
    return d
end

function greet(name)
    return "Hello, " * name * "!"
end

vector = [1,2,3,4,5]

push!(vector, 6)

new_vector = vector .+1

println(vector[end]+= 1)



println(new_vector)

conv_vec = vcat(vector, new_vector)
println(conv_vec)

deleteat!(vector, 6)

insert!(vector, 3, 10)

using PrettyTables

M = rand(4, 4)

with_terminal() do pretty_table(M) end

