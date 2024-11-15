############################## IMPORT ###################################

using Random
using Distributions


############################## STRUCTS ##################################

# Event Struct to store arrivals and departures
struct Event
    time::Float64  # Time of event (arrival or departure)
    is_arrival::Bool  # True if it's an arrival, False for a departure
    server_id::Int
    event_id::Int
    customer_id::Int
end

mutable struct Server
    id::Int
    in_service::Int
    in_queue::Int
    max_capacity::Int
    max_queue_length::Int
end

# Define a mutable struct for QueueState with state logging and tracking different types of departures
mutable struct QueueState
    servers::Vector{Server}  # List of servers
    last_event_time::Float64  # Last event time
    total_queue_time::Float64
    total_time::Float64  # Total simulation time
    lost_customers::Int  # Number of customers who left due to full queues
    state_times::Dict{Int, Float64}  # Time spent in each state
    avg_queue_lengths::Vector{Float64}
end

########################### STATE INITIALIZING #############################

# Initialize servers
function init_servers(num_servers::Int, max_capacity::Int, max_queue_length::Int)
    return [Server(
        i, 
        0, 
        0, 
        max_capacity, 
        max_queue_length
        ) for i in 1:num_servers]
end

# Initialize queue state
function init_queue_state(num_servers::Int, max_capacity::Int, max_queue_length::Int)
    servers = init_servers(num_servers, max_capacity, max_queue_length)
    return QueueState(
        servers, 
        0.0, 
        0.0, 
        0.0, 
        0, 
        Dict{Int, Float64}(), 
        zeros(Float64, num_servers))
end


################################ LOGGING ######################################

# Log the state before processing an event
function log_event_before(event::Event, current_time::Float64, queue_state::QueueState)
    println("<br />########### Event: $(event.event_id) ###########")
    println("Customer ID: $(event.customer_id)")
    println("Current time: $current_time")
    if event.is_arrival
        println("Customer $(event.customer_id) is arriving at server $(event.server_id).")
    else
        println("Customer $(event.customer_id) is leaving from server $(event.server_id).")
    end
    println("System state before event:")
    for server in queue_state.servers
        println("  Server $(server.id): In Service = $(server.in_service), Queue Length = $(server.in_queue)")
    end
    println("Total lost customers so far: $(queue_state.lost_customers)")
end


# Log the state after processing an event
function log_event_after(current_time::Float64, queue_state::QueueState, average_queue_length::Float64)
    println("System state after event:")
    println("Current time: $current_time")
    for server in queue_state.servers
        println("  Server $(server.id): In Service = $(server.in_service), Queue Length = $(server.in_queue)")
    end
    println("Total lost customers: $(queue_state.lost_customers)")
    println("Total waiting time in queue: $(queue_state.total_queue_time)")
    println("Total simulation time: $(queue_state.total_time)")
    println("Average queue length: $average_queue_length")

    # Sort and print state times
    sorted_state_times = sort(collect(queue_state.state_times), by = x -> x[1])
    println("Sorted state times (State -> Time Spent):")
    for (state, time_spent) in sorted_state_times
        println("  State $state: $time_spent")
    end
    println("")
end


###################### UPDATE STATE TIMES ########################

function update_state_times!(queue_state::QueueState, time_in_queue::Float64)
    # Update state times
    current_state = sum(server.in_queue for server in queue_state.servers)
    if haskey(queue_state.state_times, current_state)
        queue_state.state_times[current_state] += time_in_queue
    else
        queue_state.state_times[current_state] = time_in_queue
    end
end


##################### GENERATE DISTRIBUTIONS #####################

# Function to generate random distributions
function generate_distributions(num_customers::Int, arrival_mean::Float64, service_mean::Float64)
    # Generate random arrival times using an exponential distribution
    arrival_times = rand(Exponential(arrival_mean), num_customers)
    
    # Generate random service times using an exponential distribution
    service_times = rand(Exponential(service_mean), num_customers)
    
    return arrival_times, service_times
end


######################### CALCULATE STEADY STATE ##########################

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

function log_deviations(event_ids::Vector{Int}, deviations::Vector{Float64})
    println("<br />Deviations:")
    for deviation in enumerate(deviations)
        #if i <= length(event_ids)
        println("Event ID: $(event_ids[i]), Deviation: $deviation")
    end
end

############################ SERVER ALLOCATION ############################

function assign_least_loaded_server(queue_state::QueueState, num_servers::Int)
    min_load = Inf
    selected_server = 1
    for i in 1:num_servers
        load = queue_state.in_service[i] + queue_state.queue_lengths[i]
        if load < min_load
            min_load = load
            selected_server = i
        end
    end
    println("Selected server: $selected_server with load: $min_load")  # Debug statement
    return selected_server
end


################ EVENT HANDLING #################################

# Handle an arrival event
function handle_arrival!(queue_state::QueueState, server::Server)
    if server.in_service < server.max_capacity
        server.in_service += 1
    elseif server.in_queue < server.max_queue_length
        server.in_queue += 1
    else
        # Check if any other server has space in the queue
        placed_in_queue = false
        for other_server in queue_state.servers
            if other_server.id != server.id && other_server.in_queue < other_server.max_queue_length
                other_server.in_queue += 1
                placed_in_queue = true
                break
            end
        end
        # If no space was found in any queue, increment lost customers
        # The lost customer is never assigned to a server
        if !placed_in_queue
            queue_state.lost_customers += 1
        end
    end
end


# Handle a departure event
function handle_departure!(server::Server)
    if server.in_queue > 0 #If there are someone in the queue
        server.in_queue -= 1 # subtracts one from the queue
    else #If there are no one in the queue
        server.in_service -= 1 #We subtract one from the service
    end
end


############################### SIMULATION ################################

# Simulate the queue system
function simulate_queue(arrival_times::Vector{Float64}, service_times::Vector{Float64}, num_servers::Int, max_capacity::Int, max_queue_length::Int, time_limit::Float64, verbose::Bool=false)
    queue_state = init_queue_state(num_servers, max_capacity, max_queue_length)
    events = Vector{Event}()
    event_id_counter = 1
    last_departure_times = zeros(Float64, num_servers)
    # Start time of the while loop
    current_time = 0.0
    customer_id = 1
    max_departure_time = 0.0

    # Continue generating events until the time limit is reached
    while current_time < time_limit
        # Randomly select an arrival time from the generated arrival_times vector
        arrival_time = rand(arrival_times)
        
        # Randomly select a service time from the generated service_times vector
        service_time = rand(service_times)
        
        # Update the current time with the randomly selected arrival time
        current_time += arrival_time
        
        # Break the loop if the current time exceeds the time limit
        if current_time > time_limit
            println("Time limit reached: $time_limit")
            break
        end
        
        # Randomly assign a server
        server_id = rand(1:num_servers)
        
        
        # Create an arrival event
        push!(events, Event(current_time, true, server_id, event_id_counter, customer_id))
        event_id_counter += 1

        # Calculate departure time for this arrival
        departure_time = max(current_time, last_departure_times[server_id]) + service_time
        last_departure_times[server_id] = departure_time

        # Update the max departure time
        max_departure_time = max(max_departure_time, departure_time)
        
        # Create a departure event
        push!(events, Event(departure_time, false, server_id, event_id_counter, customer_id))
        event_id_counter += 1

        customer_id += 1

    end

    # Sort events by time
    sort!(events, by = e -> e.time)

    sorted_events = [Event(event.time, event.is_arrival, event.server_id, index, event.customer_id) for (index, event) in enumerate(events)]
    steady_state_time = nothing
    # Process events
    for event in sorted_events
        current_time = event.time

        server = queue_state.servers[event.server_id]

        # Calculate time delta since the last event
        time_in_queue = current_time - queue_state.last_event_time

        # Update total queue time
        queue_state.total_queue_time += sum(server.in_queue for server in queue_state.servers) * time_in_queue
        
        # Update state times
        update_state_times!(queue_state, time_in_queue)

        # Log the state before processing the event
        if verbose
            log_event_before(event, current_time, queue_state)
        end

        # Handle the event
        if event.is_arrival
            handle_arrival!(queue_state, server)
        else
            handle_departure!(server)
        end

        # Update last event time
        queue_state.last_event_time = current_time

        # Update total simulation time
        queue_state.total_time = current_time

        # Calculate the current average queue length
        current_avg_queue_length = queue_state.total_queue_time / queue_state.total_time
        
        # Store the current average queue length
        push!(queue_state.avg_queue_lengths, current_avg_queue_length)

        # Check for steady state
        deviations, steady_state_time = calculate_steady_state(queue_state.avg_queue_lengths, current_avg_queue_length, current_time)
        if verbose
            log_deviations(event.event_id, deviations)
        end
        if steady_state_time !== nothing
            println("<br />Steady state reached at time: $steady_state_time")
            break
        end
        # Log the state after processing the event
        if verbose
            log_event_after(current_time, queue_state, current_avg_queue_length)
        end
    end
    # Return the total planned simulation time
    return max_departure_time
end

########################### PARAMETERS #################################

# Example usage with verbose output
dist1 = [0.6, 0.3, 0.5, 0.2, 0.7, 0.3, 0.4] # Distribution of arrival times
dist2 = [0.6, 0.8, 1.2, 0.6, 1.1, 0.6, 0.5] # Distribution of service times

num_servers = 1
max_service_capacity = 1
max_queue_length = 10000
time_limit = 30.0

num_customers = 20
arrival_mean = 0.1  # Faster arrival rate
service_mean = 1.0  # Slower service rate

arrival_times, service_times = generate_distributions(
    num_customers, 
    arrival_mean, 
    service_mean
    )

#println("Generated Arrival Times: ", arrival_times)
#println("Generated Service Times: ", service_times)


########################## SIMULATION #################################

total_planned_time = simulate_queue(
dist1, 
dist2, 
num_servers, 
max_service_capacity, 
max_queue_length,
time_limit,
true,
)

print("\n")
println("Total planned simulation time: ", total_planned_time)