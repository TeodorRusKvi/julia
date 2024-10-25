import Random

function random_integer()
    return rand(1:100)
end

rant = random_integer()
println("My random number is: $rant")
# Everyting between 1 and 100

Random.seed!(42)
function nth_random_integer()
    return rand(1:100)
end


nth_ri = nth_random_integer()
for rant in nth_ri
    println("My n-th random integer is: $rant, and the second is: $rant")
end 
#Usually 63