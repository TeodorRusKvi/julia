M = 10000000 # very large number
dist1 = [0.6, 0.3, 0.5, 0.2, 0.7, 0.3, 0.4] # Distribution of arrival times
dist2 = [0.6, 0.8, 1.2, 0.6, 1.1, 0.6, 0.5] # Distribution of service times
queue = 0
rng = rand
nextcustime = rng(dist1)
server1_time = M
server2_time = M


function simulate_system(M, dist1, dist2, queue, rng, nextcustime, server1_time, server2_time)
    iteration = nextcustime

    while iteration < 50000
        #events are either 1) serv1 finished 2)
        # 2) serv2 finished 3) new customer arrival
        if iteration == server1_time
            if queue == 0
                server1_time = M # Server not busy
            else # there is queue
                queue -= 1
                server1_time = iteration + rng(dist2)
            end   
        elseif iteration == server2_time
            if queue == 0 
                server2_time = M
            else # there is queue
                queue -= 1
                server2_time = iteration + rng(dist2)
            end
        
        elseif iteration == nextcustime #customer arrives
            
            nextcustime = iteration + rng(dist1)
            if server1_time == M #server idle    
                server1_time = iteration +  rng(dist2)
                iteration = minimum([nextcustime, server1_time, server2_time])
                continue # skip to next event
            elseif server2_time == M
                server2_time = iteration  + rng(dist2)
                iteration = minimum([nextcustime, server1_time, server2_time])
                continue  # Skip to next event
            
            else 
                queue += 1 #all servers busy
                
            end
        end
        iteration = minimum([nextcustime, server1_time, server2_time])
        #Skip to the next earliest event

    end
     # Return the final values of the variables
     return server1_time, server2_time, queue, nextcustime, iteration
end


server1_time, server2_time, queue, nextcustime, iteration = simulate_system(M, dist1, dist2, queue, rng, nextcustime, server1_time, server2_time)


# Display the final states
println("Server 1 Time: $server1_time")
println("Server 2 Time: $server2_time")
println("Queue Size: $queue")
println("Next Customer Time: $nextcustime")
println("Final Iteration Time: $iteration")