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

    # Continue until all elements in dist1 (arrival times) and dist2 (service times) are processed
    while nextcustime_index <= length(dist1) || queue > 0 || !server1_idle
        
        # Check if a customer has arrived (next customer based on dist1)
        if nextcustime <= server1_time || server1_idle
            println("Customer arrived at time $nextcustime")
            
            if server1_idle
                # Server1 is idle, start serving the new customer
                service_time, service_index = get_next_time(dist2, service_index)
                if service_time !== nothing
                    server1_time = nextcustime + service_time
                    server1_idle = false
                    println("Started serving a customer. Service will end at $server1_time")
                end
            else
                # Server is busy, add to the queue
                queue += 1
                println("Server busy. Added customer to the queue. Queue size: $queue")
            end
            
            # Get the next customer arrival time
            nextcustime, nextcustime_index = get_next_time(dist1, nextcustime_index)
            if nextcustime === nothing
                nextcustime = M  # No more customers, set it to a large number
            end
        end

        # Check if server finished serving and there are customers waiting in queue
        if !server1_idle && server1_time <= nextcustime
            println("Server finished serving at time $server1_time")
            
            if queue > 0
                queue -= 1
                service_time, service_index = get_next_time(dist2, service_index)
                if !isnothing(service_time)
                    server1_time += service_time
                    println("Serving next customer from queue. Service will end at $server1_time")
                end
            else
                server1_idle = true
                println("Server is now idle.")
            end
        end
    end

    println("Simulation finished")
    return server1_time, queue
end

simulate_system(dist1, dist2, queue)
