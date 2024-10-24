M = 10000000
dist1 = [0.6, 0.3, 0.5, 0.2, 0.7]#, 0.3, 0.4]  # Distribution of arrival times
dist2 = [0.6, 0.8, 1.2, 0.6, 1.1]#, 0.6, 0.5]  # Distribution of service times
queue = 0

# Event Struct to store arrivals and departures
struct Event
    time::Float64  # Time of event (arrival or departure)
    is_arrival::Bool  # True if it's an arrival, False for a departure
end

# Define a mutable struct for QueueState
mutable struct QueueState
    queue_length::Int  # Current queue length
    last_event_time::Float64  # Last event time
    total_queue_time::Float64  # Accumulated queue length * time period
    state_times::Dict{Int, Float64}  # Accumulated time per queue state (key=queue_length)
end

# Initialize queue state with time logging for each state
function initialize_queue_state(max_queue_length::Int)
    return QueueState(0, 0.0, 0.0, Dict(i => 0.0 for i in 0:max_queue_length))
end

# Function to handle an event and log the time spent in the current state
function handle_event!(queue_state::QueueState, event::Event)
    current_time = event.time
        if event.is_arrival
            println("Current time of arrival: ", current_time)
        else 
            println("Current time of de: ", current_time)
        end
    # Calculate how much time has passed since the last event
    time_in_current_state = current_time - queue_state.last_event_time

    # Log the time spent in the current queue state
    queue_state.state_times[queue_state.queue_length] += time_in_current_state

    # Update queue length based on the event
    if event.is_arrival
        queue_state.queue_length += 1
    else
        queue_state.queue_length -= 1
    end

    # Update the last event time
    queue_state.last_event_time = current_time
end

# Function to simulate the queue system
function simulate_queue(arrivals::Vector{Float64}, service_times::Vector{Float64}, max_queue_length::Int)
    queue_state = initialize_queue_state(max_queue_length)
    departure_times = Vector{Float64}(undef, length(arrivals))  # Store departure times

    events = Vector{Event}()

    # Generate arrival events
    for arrival_time in arrivals
        push!(events, Event(arrival_time, true))
    end

    # Generate departure events
    for i in 1:length(arrivals)
        if i == 1
            departure_times[i] = arrivals[i] + service_times[i]
        else
            departure_times[i] = departure_times[i-1] + service_times[i]
        end
        push!(events, Event(departure_times[i], false))
    end

    # Sort events by time (arrival and departure times on the same timeline)
    sort!(events, by = x -> x.time)

    # Process each event
    for event in events
        handle_event!(queue_state, event)
    end

    # After all events, accumulate any remaining time in the last state
    total_time = events[end].time  # The time of the last event
    queue_state.state_times[queue_state.queue_length] += total_time - queue_state.last_event_time

    return queue_state
end

# Function to compute the average queue length
function calculate_average_queue_length(queue_state::QueueState)
    total_time = sum(queue_state.state_times)  # Total time spent in all states
    weighted_sum = 0.0

    for (queue_length, time_in_state) in queue_state.state_times
        weighted_sum += queue_length * time_in_state
    end

    return weighted_sum / total_time
end

average_queue_length = simulate_queue(dist1, dist2, 5)