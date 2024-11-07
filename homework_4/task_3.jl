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
    in_service::Vector{Int}    # Number of customers currently being served
    last_event_time::Float64  # Last event time
    total_queue_time::Float64
    total_time::Float64  # Total simulation time
    state_times::Dict{Int, Float64}  # Time spent in each state
end


# Initialize queue state
function init_queue_state(num_servers::Int)
    return QueueState(zeros(Int, num_servers), zeros(Int, num_servers), 0.0, 0.0, 0.0, Dict{Int, Float64}())
end


function handle_event!(queue_state::QueueState, event::Event, max_service_capacity::Int, max_queue_length::Int, verbose::Bool=false)
    current_time = event.time
    server_id = event.server_id

    # Calculate time delta since the last event
    time_in_queue = current_time - queue_state.last_event_time

    # Update total queue time
    for i in 1:length(queue_state.queue_lengths)
        queue_state.total_queue_time += queue_state.queue_lengths[i] * time_in_queue
    end

    state_key = sum(queue_state.queue_lengths)
    # Update time spent in the current state
    if haskey(queue_state.state_times, state_key)
        queue_state.state_times[state_key] += time_in_queue
    else
        queue_state.state_times[state_key] = time_in_queue
    end

    # Log the state before processing the event
    if verbose
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

    # Update queue length and in service count based on the event
    if event.is_arrival
        if queue_state.in_service[server_id] < max_service_capacity
            queue_state.in_service[server_id] += 1
        else
            if queue_state.queue_lengths[server_id] < max_queue_length
                queue_state.queue_lengths[server_id] += 1
            else 
                #Find another server with space in the queue
                for i in 1:length(queue_state.queue_lengths)
                    if i != server_id && queue_state.queue_lengths[i] < max_queue_length
                        queue_state.queue_lengths[i] += 1
                        break
                    end
                end
            end
        end
    else #is departure
        if queue_state.queue_lengths[server_id] > 0
            queue_state.queue_lengths[server_id] -= 1
            # in_service remains the same because a customer from the queue is now being served
        else
            queue_state.in_service[server_id] -= 1
        end
    end

    # Update last event time
    queue_state.last_event_time = current_time

    # Update total simulation time
    queue_state.total_time = current_time

    total_waiting_time = queue_state.total_queue_time
    average_queue_length = total_waiting_time / queue_state.total_time

    if verbose
        println("After event: time=$current_time, queue_length=$(queue_state.queue_lengths), in_service=$(queue_state.in_service)")
        println("")
        sorted_state_times = sort(collect(queue_state.state_times), by = x -> x[1])
        println("Sorted state times: $sorted_state_times")
        println("")
        println("Total waiting time in queue: $total_waiting_time")
        println("Average queue length: $average_queue_length")
    end
end

# Function to simulate the queue system with verbosity option
function simulate_queue(arrivals::Vector{Float64}, service_times::Vector{Float64}, max_service_capacity::Int, num_servers::Int, max_queue_length::Int, verbose::Bool=false)
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
simulate_queue(dist1, dist2, num_servers, max_service_capacity, max_queue_length, true)