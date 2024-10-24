# Event Struct to store arrivals and departures
struct Event
    time::Float64  # Time of event (arrival or departure)
    is_arrival::Bool  # True if it's an arrival, False for a departure
end

# Define a mutable struct for QueueState with state logging
mutable struct QueueState
    queue_length::Int  # Current queue length (waiting customers)
    in_service::Int    # Number of customers currently being served
    last_event_time::Float64  # Last event time
    total_queue_time::Float64
    total_time::Float64  # Total simulation time
    state_times::Dict{Int, Float64}  # Time spent in each state
    state_log::Vector{Tuple{Float64, Int, Int}}  # Log of state changes (time, queue length, in service)
end

# Initialize queue state
function initialize_queue_state()
    return QueueState(0, 0, 0.0, 0.0, 0.0, Dict{Int, Float64}(), Vector{Tuple{Float64, Int, Int}}())
end

function handle_event!(queue_state::QueueState, event::Event, max_service_capacity::Int, verbose::Bool=false)
    current_time = event.time

    # Calculate time delta since the last event
    time_in_queue = current_time - queue_state.last_event_time

    # Update total queue time
    queue_state.total_queue_time += queue_state.queue_length * time_in_queue

    # Update time spent in the current state
    if haskey(queue_state.state_times, queue_state.queue_length)
        queue_state.state_times[queue_state.queue_length] += time_in_queue
    else
        queue_state.state_times[queue_state.queue_length] = time_in_queue
    end

    # Log the state before processing the event
    if verbose
        println("Before event: time=$current_time, queue_length=$(queue_state.queue_length), in_service=$(queue_state.in_service)")
    end

    # Update queue length and in service count based on the event
    if event.is_arrival
        if queue_state.in_service < max_service_capacity
            queue_state.in_service += 1
        else
            queue_state.queue_length += 1
        end
    else
        if queue_state.queue_length > 0
            queue_state.queue_length -= 1
            # in_service remains the same because a customer from the queue is now being served
        else
            queue_state.in_service -= 1
        end
    end

    # Log the state after processing the event
    if verbose
        println("After event: time=$current_time, queue_length=$(queue_state.queue_length), in_service=$(queue_state.in_service)")
    end

    # Log the current state and time (queue length, in service)
    push!(queue_state.state_log, (current_time, queue_state.queue_length, queue_state.in_service))

    # Update last event time
    queue_state.last_event_time = current_time

    # Update total simulation time
    queue_state.total_time = current_time
end

# Function to simulate the queue system with verbosity option
function simulate_queue(arrivals::Vector{Float64}, service_times::Vector{Float64}, max_service_capacity::Int, verbose::Bool=false)
    queue_state = initialize_queue_state()
    events = Vector{Event}()

    # Generate arrival events
    for i in 1:length(arrivals)
        arrival_time = sum(arrivals[1:i])
        push!(events, Event(arrival_time, true))  # Arrival event
    end

    # Process each arrival to generate corresponding departure events
    current_time = 0.0
    for i in 1:length(arrivals)
        arrival_time = sum(arrivals[1:i])
        if i == 1
            departure_time = arrival_time + service_times[i]
        else
            last_departure_time = events[end].time
            departure_time = max(arrival_time, last_departure_time) + service_times[i]
        end
        push!(events, Event(departure_time, false))  # Departure event
    end

    # Sort events by time
    sort!(events, by = e -> e.time)


    departure_count = 0
    total_queue_time_until_fifth = 0.0
    time_at_fifth_departure = 0.0

    for event in events
        handle_event!(queue_state, event, max_service_capacity, verbose)

        if !event.is_arrival
            departure_count += 1
            if departure_count == 5
                # Capture the state at the fifth departure
                total_queue_time_until_fifth = queue_state.total_queue_time
                time_at_fifth_departure = queue_state.total_time
            end
        end
    end

    # Calculate average queue length until the fifth customer
    average_queue_length_until_fifth = total_queue_time_until_fifth / time_at_fifth_departure
    println("Average queue length until the fifth customer: ", average_queue_length_until_fifth)

    # Final calculation: average queue length
    average_queue_length = queue_state.total_queue_time / queue_state.total_time
    println("Average queue length: ", average_queue_length)

    # Output time spent in each state
    println("Time spent in each state:")
    for (state, time) in queue_state.state_times
        println("State $state: $time")
    end

    # Output the state log
    println("State log (time, in the system, queue length):")
    for log_entry in queue_state.state_log
        println(log_entry)
    end

    return queue_state, average_queue_length, average_queue_length_until_fifth
end

# Example usage with verbose output
dist1 = [0.6, 0.3, 0.5, 0.2, 0.7, 0.3, 0.4] # Distribution of arrival times
dist2 = [0.6, 0.8, 1.2, 0.6, 1.1, 0.6, 0.5] # Distribution of service times
max_service_capacity = 1  # Assuming a single server
queue_state, average_queue_length, average_queue_length_until_fifth = simulate_queue(dist1, dist2, max_service_capacity, true)