M = 10000000
dist1 = [0.6, 0.3, 0.5, 0.2, 0.7, 0.3, 0.4] # Distribution of arrival times
dist2 = [0.6, 0.8, 1.2, 0.6, 1.1, 0.6, 0.5] # Distribution of service times
queue = 0

# Function to cycle through distributions instead of using a random generator
function get_next_time(times, index)
    if index > length(times)
        return nothing, index # No more arrivals or service times
    else
        return times[index], index + 1
    end
end

function simulate_system(dist1, dist2, queue)
    nextcustime_index = 1  # Tracks next customer arrival
    service_index = 1      # Tracks next service time

    # Get the time of the first customer arrival
    nextcustime, nextcustime_index = get_next_time(dist1, nextcustime_index)
    
    server1_idle = true  # Server1 starts idle
    server1_time = 0     # Time when Server1 will finish serving

    # Metrics
    total_service_time = 0
    total_queue_time = 0
    total_time = 0
    
    # List to store departure times
    departure_times = Float64[]  # Array to hold departure times
    # List to store the number of customers in the system at each time step
    customers_in_system = Int[]  # Array to hold the number of customers in the system

    # Dictionary to track time spent in each state of the queue
    max_customers = max(length(dist1), length(dist2))  # Maximum number of customers based on distributions
    time_in_state = Dict{Int, Float64}()  # Key: number of customers in system, Value: time spent in that state

    # Initialize the time spent in each state to 0
    for i in 0:max_customers  # Initialize for 0 to max_customers
        time_in_state[i] = 0.0
    end

    # Continue until all elements in dist1 (arrival times) and dist2 (service times) are processed
    while nextcustime_index <= length(dist1) || queue > 0 || !server1_idle
        
        # Check the current number of customers in the system
        current_customers = queue + (server1_idle ? 0 : 1)
        
        # Update the time spent in the current state
        time_in_state[current_customers] += 1.0  # Increment time spent in the current state

        # Check if a customer has arrived (next customer based on dist1)
        if nextcustime <= server1_time || server1_idle
            println("Customer arrived at time $nextcustime")

            if server1_idle
                # Server1 is idle, start serving the new customer
                service_time, service_index = get_next_time(dist2, service_index)
                if service_time !== nothing
                    server1_time = nextcustime + service_time
                    server1_idle = false
                    total_service_time += service_time
                    println("Started serving a customer. Service will end at $server1_time")
                end
            else
                # Server is busy, add to the queue
                queue += 1
                println("Server busy. Added customer to the queue. Queue size: $queue")
            end
            
            # Get the next customer arrival time
            nextcustime, nextcustime_index = get_next_time(dist1, nextcustime_index)
            if isnothing(nextcustime)
                nextcustime = M  # No more customers, set it to a large number
            end
        end

        # Check if server finished serving and there are customers waiting in queue
        if !server1_idle && server1_time <= nextcustime
            println("Server finished serving at time $server1_time")
            
            # Record the departure time
            push!(departure_times, server1_time)

            if queue > 0
                queue -= 1
                service_time, service_index = get_next_time(dist2, service_index)
                if service_time !== nothing
                    server1_time += service_time
                    total_service_time += service_time
                    println("Serving next customer from queue. Service will end at $server1_time")
                end
            else
                server1_idle = true
                println("Server is now idle.")
            end
        end

        # Update total time and queue time
        total_time += 1
        total_queue_time += queue
    end

    average_queue_size = total_queue_time / total_time

    println("Simulation finished")
    println("Total service time: $total_service_time")
    println("Average queue size: $average_queue_size")
    println("Departure times: $departure_times")  # Print departure times
    println("Customers in system at each time step: $customers_in_system")  # Print customers in system
    println("Time spent in each state of the queue: $time_in_state")  # Print time spent in each state
    return server1_time, queue
end

simulate_system(dist1, dist2, queue)