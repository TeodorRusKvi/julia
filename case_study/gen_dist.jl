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
function init_servers(num_servers::Int, max_server_capacity::Int, max_queue_length::Int)
    return [Server(
        i, 
        0, 
        0, 
        max_server_capacity, 
        max_queue_length
        ) for i in 1:num_servers]
end

# Initialize queue state
function init_queue_state(num_servers::Int, max_server_capacity::Int, max_queue_length::Int)
    servers = init_servers(num_servers, max_server_capacity, max_queue_length)
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

function log_deviations(deviations::Vector{Float64})
    println("<br />Deviations:")
    for deviation in enumerate(deviations)
        #if i <= length(event_ids)
        println("Deviation: $deviation")
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


############################### EVENT GENERATING ################################

# Event generator function with random distributions using Channel
function event_generator(arrival_mean::Float64, service_mean::Float64, num_servers::Int)
    Channel{Event}(128) do channel  # Define a channel with buffer size 128
        last_departure_times = zeros(Float64, num_servers)
        event_id_counter = 1
        current_time = 0.0  # Start time for event generation

        while true
            # Generate random arrival and service times
            arrival_time, service_time = generate_distributions(arrival_mean, service_mean)

            # Update the current time to simulate arrival
            current_time += arrival_time
            server_id = rand(1:num_servers)
            customer_id = event_id_counter

            # Generate and send arrival event
            put!(channel, Event(current_time, true, server_id, event_id_counter, customer_id))
            event_id_counter += 1

            # Calculate departure time
            departure_time = max(current_time, last_departure_times[server_id]) + service_time
            last_departure_times[server_id] = departure_time

            # Generate and send departure event
            put!(channel, Event(departure_time, false, server_id, event_id_counter, customer_id))
            event_id_counter += 1
        end
    end
end


############################## CONTINUOUS QUEUE SYSTEM ##########################

function simulate_queue_system!(
    arrival_mean::Float64, 
    service_mean::Float64, 
    num_servers::Int, 
    max_server_capacity::Int, 
    max_queue_length::Int, 
    max_customers::Int,
    threshold::Float64=0.1, 
    verbose::Bool=false
)
    # Initialize the queue state
    queue_state = init_queue_state(num_servers, max_server_capacity, max_queue_length)

    # Create the event generator
    event_channel = event_generator(arrival_mean, service_mean, num_servers)
    
    current_time = 0.0  # Start simulation time
    processed_customers = 0  # Track the number of processed customers
    steady_state_reached = false
    avg_queue_lengths = []  # Track average queue lengths over time

    while !steady_state_reached && processed_customers < max_customers
        for event in event_channel
            # Update the simulation time to the current event's time
            current_time = event.time

            # Process arrival or departure
            server = queue_state.servers[event.server_id]
            if event.is_arrival
                handle_arrival!(queue_state, server)
                if verbose
                    println("Arrival: Customer $(event.customer_id) at Server $(server.id) at time $current_time")
                end
            else
                handle_departure!(server)
                if verbose
                    println("Departure: Customer $(event.customer_id) from Server $(server.id) at time $current_time")
                end
                processed_customers += 1  # Increment processed customers
            end

            # Update the average queue lengths
            current_avg_queue_length = sum(server.in_queue for server in queue_state.servers) / num_servers
            push!(avg_queue_lengths, current_avg_queue_length)

            # Check for steady state every few events
            if length(avg_queue_lengths) >= 5
                deviations, steady_state_time = calculate_steady_state(
                    avg_queue_lengths, 
                    current_avg_queue_length, 
                    current_time; 
                    threshold=threshold
                )

                if verbose && !isempty(deviations)
                    log_deviations(deviations)
                end

                if steady_state_time !== nothing
                    steady_state_reached = true
                    println("Steady state reached at time: $steady_state_time")
                    return queue_state
                end
            end
        end
    end

    println("Simulation ended after processing $processed_customers customers without reaching a steady state.")
    return queue_state
end


########################### GENERATOR FOR DISTRIBUTIONS #############################

arrival_mean = 0.833
service_mean_a = 0.8
service_mean_b = 1.2048
num_customers = 10000

##################### GENERATE DISTRIBUTIONS #####################

# Function to generate random distributions
function generate_distributions(arrival_mean::Float64, service_mean::Float64)
    # Generate random arrival times using an exponential distribution
    arrival_time = rand(Exponential(arrival_mean))
    
    # Generate random service times using an exponential distribution
    service_time = rand(Exponential(service_mean))
    
    return arrival_time, service_time
end


########################### PARAMETERS #################################

num_servers_a = 3
num_servers_b = 2
max_server_capacity = 1
max_queue_length = 10000
time_limit = 100.0
verbose=true
max_customers = 1

########################## SIMULATION #################################

simulate_queue_system!(
    arrival_mean, 
    service_mean, 
    num_servers, 
    max_server_capacity, 
    max_queue_length, 
    max_customers,
    threshold=0.05, 
    verbose=true
)