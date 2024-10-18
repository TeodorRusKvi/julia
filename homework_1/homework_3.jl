# Define the Fruit struct
struct Fruit
    name::String
    weight::Float64
    cut::Bool
end

# Initialize an array of fruit names
fruit_names = ["Apple", "Banana", "Orange"]
weights = [150.0, 120.0, 180.0]  # Corresponding weights of the fruits

# Initialize an empty array for already cut fruits
alreadycutfruits = Vector{Fruit}()

# Initialize an array to track cutting status (0 = not cut, 1 = cut)
cuttingarray = zeros(Int, length(fruit_names))

# While not all fruits are cut
while !all(x -> x > 0, cuttingarray)
    # Find the index of the first uncut fruit
    idx = findfirst(x -> x == 0, cuttingarray)
    
    if idx !== nothing
        # Check if the fruit is already cut
        fruit_name = fruit_names[idx]
        
        if any(fruit -> fruit.name == fruit_name, alreadycutfruits)
            println("$fruit_name is already cut.")
        else
            # Create the fruit struct for the uncut fruit
            thisfruit = Fruit(fruit_names[idx], weights[idx], true)
            
            # Add the fruit to alreadycutfruits array
            push!(alreadycutfruits, thisfruit)
            
            # Mark the fruit as cut in the cuttingarray
            cuttingarray[idx] = 1
            
            println("Cutting and adding $fruit_name.")
        end
    end
end

# Output the already cut fruits
println("\nAlready cut fruits:")
for cut_fruit in alreadycutfruits
    println(cut_fruit)
end
