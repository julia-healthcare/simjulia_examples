using DataStructures
using StatsBase
using PyPlot
using ResumableFunctions
using SimJulia
using Random, Distributions

# Simulation run time and warm-up
sim_duration = 5000
warm_up = 1000

# Average time between patients arriving
inter_arrival_time = 10

# Number of doctors in ED
number_of_docs = 2

# Time between audits
audit_interval = 100

# Average time patients spends being *treated* in ED
appointment_time_mean = 18
appointment_time_sd = 18


# Priority queue for waiting patients
patient_queue = PriorityQueue()

# Vectors used to store audit results
audit_time = []
audit_patients_in_ED = []
audit_patients_waiting = []
audit_patients_waiting_p1 = []
audit_patients_waiting_p2 = []
audit_patients_waiting_p3 = []
audit_reources_used = []

# Proportion of patients in priorities 1,2,3
priority_dist = [0.3, 0.3, 0.4]

# Set up counter for number of a ptients entering simulation
patient_count = 0

# Set up running counts of patients waiting (total and by priority)
patients_waiting = 0
patients_waiting_by_priority = [0, 0, 0]

# Set up patient type

mutable struct Patient
    #=
    Patient type
    =#
    
    uid # Unique patient ID 
    priority # Priority 1-3 (1=highest)
    consulation_time # Time needed with doc
    queuing_time # Record time spent queing
    time_in # Record time arrival
    time_see_doc # Record time see doc
    time_out # Record exit time
end

function patient_init(env)
    #=
    Create new patient.
    =#
    
    # Set references to global parameters
    global patient_count
    global priority_dist
    global appointment_time_mean
    global appointment_time_sd
    
    # Increment patient count
    patient_count += 1
    uid = patient_count
    
    # Sample priority

    cum_probs = cumsum(priority_dist)
    rand_num = rand()
    if rand_num <= cum_probs[1]
        p_priority = 1
    elseif rand_num <= cum_probs[2]
        p_priority = 2
    else
        p_priority = 3
    end
    
    #= Sample Sample time (assume log normal distribution). Note: log parameters
    are estimates from mean and sd. In a real sim fit σ & μ directly to data =#
    m = appointment_time_mean
    s = appointment_time_sd
    
    σ_log = s/m * 0.85
    μ_log = log(m) - σ_log^2/2
    d = LogNormal(μ_log, σ_log)
    consult_time = rand(d)
    
    # Set inital times (these will be updated in sim)
    queuing_time = 0 
    time_in = now(env)
    time_see_doc = 0
    time_out = 0    
    
    patient = Patient(uid, p_priority, consult_time, queuing_time, time_in,
        time_see_doc, time_out)
    
    return patient

end

# Generate new arrivals

@resumable function new_admission(env::Environment)
    
    #=
    Continuous loop of new arrivals:
    1) Sample interval until next arrival from exponential distribution
    2) Wait for required interval
    3) Call a new patient process
    =#
    
    x = 0
    # Set references to global parameters
    global inter_arrival_time

    while true
        # Get time to next patient arrival from exponential distribution
        next_p = rand(Exponential(inter_arrival_time))
        # Wait for next patient arrival
        @yield timeout(env, next_p)
        # Generate patient
        patient = patient_init(env)
        x += 1
        println(x)
        # Call patient pathway process
        # p = @process patient_pathway(env, patient)
    end
end

# Main

# Set up simulation environment
sim = Simulation()
# Set up starting processes (pass environment to process)
@process new_admission(sim)
# Run simulation (pass simulation time)
run(sim, warm_up + sim_duration)

println("end")