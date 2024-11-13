# Event Struct to store arrivals and departures
struct Event
    time::Float64  # Time of event (arrival or departure)
    is_arrival::Bool  # True if it's an arrival, False for a departure
    server_id::Int
    event_id::Int
    customer_id::Int
end

# Define a mutable struct for QueueState with state logging
mutable struct QueueState
    queue_lengths::Vector{Int}  # Current queue length (waiting customers)
    avg_queue_lengths::Vector{Float64}
    in_service::Vector{Int}    # Number of customers currently being served
    last_event_time::Float64  # Last event time
    total_queue_time::Float64
    total_time::Float64  # Total simulation time
    state_times::Dict{Int, Float64}  # Time spent in each state
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
    Dict{Int, Float64}())
end


function handle_event!(queue_state::QueueState, event::Event, max_service_capacity::Int, max_queue_length::Int, verbose::Bool=false)
    current_time = event.time
    server_id = event.server_id

    # Calculate time delta since the last event
    time_in_queue = current_time - queue_state.last_event_time

    # Update queue state
    update_queue_time!(queue_state, time_in_queue)
    update_state_times!(queue_state, time_in_queue)

    # Log the state before processing the event
    if verbose
        log_event_before(event, current_time, queue_state)
    end

    # Process the event
    if event.is_arrival
        handle_arrival!(queue_state, server_id, max_service_capacity, max_queue_length)
    else
        handle_departure!(queue_state, server_id)
    end

    # Update times
    queue_state.last_event_time = current_time
    queue_state.total_time = current_time

    # Calculate average queue length
    current_avg_queue_length = queue_state.total_queue_time / queue_state.total_time
    push!(queue_state.avg_queue_lengths, current_avg_queue_length)

    # Calculate deviations and check for steady state
    deviations, steady_state_time = calculate_steady_state(queue_state.avg_queue_lengths, current_avg_queue_length, current_time)

    # Log the state after processing the event
    if verbose
        log_event_after(current_time, queue_state, current_avg_queue_length, deviations, steady_state_time)
    end
end


function print_queue_lengths(queue_state::QueueState)
    println("Current queue lengths:")
    for i in 1:length(queue_state.queue_lengths)
        println("Server $(i): Queue length = $(queue_state.queue_lengths[i])")
    end
end


function calculate_steady_state(avg_queue_lengths::Vector{Float64}, current_avg_queue_length::Float64, current_time::Float64; threshold::Float64=0.1)
    if length(avg_queue_lengths) < 5
        return (Float64[], nothing)
    end

    recent_avg_lengths = avg_queue_lengths[end-4:end]
    deviations = [abs(current_avg_queue_length - avg) / avg for avg in recent_avg_lengths]

    steady_state_time = if all(dev -> dev < threshold, deviations)
        current_time
    else
        nothing
    end

    return (deviations, steady_state_time)
end


function update_queue_time!(queue_state::QueueState, time_in_queue::Float64)
    for i in 1:length(queue_state.queue_lengths)
        queue_state.total_queue_time += queue_state.queue_lengths[i] * time_in_queue
    end
end

function update_state_times!(queue_state::QueueState, time_in_queue::Float64)
    state_key = sum(queue_state.queue_lengths)
    if haskey(queue_state.state_times, state_key)
        queue_state.state_times[state_key] += time_in_queue
    else
        queue_state.state_times[state_key] = time_in_queue
    end
end

function handle_arrival!(queue_state::QueueState, server_id::Int, max_service_capacity::Int, max_queue_length::Int)
    if queue_state.in_service[server_id] < max_service_capacity
        queue_state.in_service[server_id] += 1
    else
        if queue_state.queue_lengths[server_id] < max_queue_length
            queue_state.queue_lengths[server_id] += 1
        else
            for i in 1:length(queue_state.queue_lengths)
                if i != server_id && queue_state.queue_lengths[i] < max_queue_length
                    queue_state.queue_lengths[i] += 1
                    break
                end
            end
        end
    end
end

function handle_departure!(queue_state::QueueState, server_id::Int)
    if queue_state.queue_lengths[server_id] > 0
        queue_state.queue_lengths[server_id] -= 1
    else
        queue_state.in_service[server_id] -= 1
    end
end

function log_event_before(event::Event, current_time::Float64, queue_state::QueueState)
    println("")
    println("########### Event: $(event.event_id) ###########")
    println("Customer ID: $(event.customer_id)")
    if event.is_arrival
        println("Customer $(event.customer_id) is arriving.")
    else
        println("Customer $(event.customer_id) is leaving.")
    end
    println("")
    println("Before event: time=$current_time, queue_length=$(queue_state.queue_lengths), in_service=$(queue_state.in_service)")
end


function log_event_after(current_time::Float64, queue_state::QueueState, current_avg_queue_length::Float64, deviations::Vector{Float64}, steady_state_time::Union{Nothing, Float64})
    println("After event: time=$current_time, queue_length=$(queue_state.queue_lengths), in_service=$(queue_state.in_service)")
    println("")
    sorted_state_times = sort(collect(queue_state.state_times), by = x -> x[1])
    println("Sorted state times: $sorted_state_times")
    println("")
    print_queue_lengths(queue_state)
    println("Current average queue length: $current_avg_queue_length")
    println("Total waiting time in queue: $(queue_state.total_queue_time)")
    println("Last deviations: $deviations")
    if steady_state_time !== nothing
        println("Steady state reached at time: $steady_state_time")
    end
end


function simulate_queue(
    arrivals::Vector{Float64}, 
    service_times::Vector{Float64}, 
    max_service_capacity::Int, 
    num_servers::Int, 
    max_queue_length::Int, 
    time_limit::Float64, 
    threshold::Float64=0.1, 
    verbose::Bool=true
)
    queue_state = init_queue_state(num_servers)
    events = Vector{Event}()
    event_id_counter = 1
    # Track the last departure time for each server
    last_departure_times = zeros(Float64, num_servers)

    # Generate arrival events
    for i in 1:length(arrivals)
        arrival_time = sum(arrivals[1:i])
        server_id = rand(1:num_servers)  # Randomly assign a server
        customer_id = i  # Assign a unique customer ID
        push!(events, Event(arrival_time, true, server_id, event_id_counter, customer_id))  # Arrival event
        event_id_counter += 1

        # Calculate departure time for this arrival
        departure_time = max(arrival_time, last_departure_times[server_id]) + service_times[i]
        last_departure_times[server_id] = departure_time
        push!(events, Event(departure_time, false, server_id, event_id_counter, customer_id))  # Departure event
        event_id_counter += 1
    end

    # Sort events by time
    sort!(events, by = e -> e.time)

    # Reassign event IDs based on sorted order
    sorted_events = [Event(event.time, event.is_arrival, event.server_id, index, event.customer_id) for (index, event) in enumerate(events)]

    for event in sorted_events
        handle_event!(queue_state, event, max_service_capacity, max_queue_length, verbose)
    end
end


# Example usage with verbose output
dist1 = [0.6, 0.3, 0.5, 0.2, 0.7, 0.3, 0.4] # Distribution of arrival times
dist2 = [0.6, 0.8, 1.2, 0.6, 1.1, 0.6, 0.5] # Distribution of service times
num_servers = 1
max_service_capacity = 1
max_queue_length = 10000
time_limit=20.0
threshold=0.1


simulate_queue_and_steady_state(
    dist1, 
    dist2, 
    num_servers, 
    max_service_capacity, 
    max_queue_length, 
    time_limit, 
    threshold, 
    true
)
