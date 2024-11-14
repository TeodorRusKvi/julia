# Define a mutable struct for QueueState with state logging and tracking different types of departures
mutable struct QueueState
    queue_lengths::Vector{Int}  # Current queue length (waiting customers)
    avg_queue_lengths::Vector{Float64}
    in_service::Vector{Int}    # Number of customers currently being served
    last_event_time::Float64  # Last event time
    total_queue_time::Float64
    total_time::Float64  # Total simulation time
    state_times::Dict{Int, Float64}  # Time spent in each state
    departures::Vector{Int}  # Number of customers who left due to full queues, with different types
end

# Initialize queue state
function init_queue_state(num_servers::Int)
    return QueueState(
        zeros(Int, num_servers), 
        zeros(Float64, num_servers), 
        zeros(Float64, num_servers), 
        0.0, 
        0.0, 
        0.0, 
        Dict{Int, Float64}(),
        [0, 0]  # Initialize departures vector with two types: [without service, after service]
    )
end

# Handle arrival with multiple queues and track departures
function handle_arrival!(queue_state::QueueState, server_id::Int, max_service_capacity::Int, max_queue_length::Int)
    if queue_state.in_service[server_id] < max_service_capacity
        queue_state.in_service[server_id] += 1
    else
        if queue_state.queue_lengths[server_id] < max_queue_length
            queue_state.queue_lengths[server_id] += 1
        else
            # Try other queues
            customer_placed = false
            for i in 1:length(queue_state.queue_lengths)
                if i != server_id && queue_state.queue_lengths[i] < max_queue_length
                    queue_state.queue_lengths[i] += 1
                    customer_placed = true
                    break
                end
            end
            # If no queue has space, the customer leaves without service
            if !customer_placed
                queue_state.departures[1] += 1  # Departure without service
            end
        end
    end
end

# Handle departure
function handle_departure!(queue_state::QueueState, server_id::Int)
    if queue_state.queue_lengths[server_id] > 0
        queue_state.queue_lengths[server_id] -= 1
    else
        queue_state.in_service[server_id] -= 1
        queue_state.departures[2] += 1  # Departure after service
    end
end

# Example usage
num_servers = 3
max_service_capacity = 1
max_queue_length = 5

queue_state = init_queue_state(num_servers)

# Simulate some arrivals and departures
handle_arrival!(queue_state, 1, max_service_capacity, max_queue_length)
handle_arrival!(queue_state, 2, max_service_capacity, max_queue_length)
handle_arrival!(queue_state, 3, max_service_capacity, max_queue_length)
handle_departure!(queue_state, 1)

println("Queue lengths: ", queue_state.queue_lengths)
println("In service: ", queue_state.in_service)
println("Departures without service: ", queue_state.departures[1])
println("Departures after service: ", queue_state.departures[2])