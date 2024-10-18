
mutable struct Customer
    id::Int
    X::Float64
    Y::Float64
    Served::Bool
    Vehicle::Int
end

struct Depot
    X::Float64 
    Y::Float64
end

function serve_customers(customers::Vector{Customer}, maxD::Float64, vehicleid::Int64, depots::Vector{Depot})
    servedids = Int[]
    for depot in depots
        for customer in customers
            distance = sqrt((customer.X - depot.X)^2 + (customer.Y - depot.Y)^2)
            if distance <= maxD
                if customer.Vehicle == vehicleid
                    customer.Served = true
                    push!(servedids, deepcopy(customer.id))
                end
            end
        end
    end

    return servedids
end

customers = [
    Customer(1, 2.0, 3.0, false, 0),
    Customer(2, 4.0, 3.5, false, 3),
    Customer(3, 0.5, 0.4, false, 1),
    Customer(4, 0.3, 4.4, false, 2)
]

max_distance = 4
vehicle_id = 1

depots = [
    Depot(0.3, 3.1)
]

served_ids = serve_customers(customers, max_distance, vehicle_id, depots)
println("Served Customer IDs: ", served_ids)