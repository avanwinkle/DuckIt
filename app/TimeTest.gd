extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
    
    var test = "loc_cav_p_intro_1.wav"
    var start = Time.get_ticks_usec()
    for i in range(0,1000):
        test[5] = "a"
        test[6] = "s"
        test[8] = "k"
    var end = Time.get_ticks_usec()
    var worker_time = (end-start)
    
    test = "loc_cav_player_intro_1.wav"
    start = Time.get_ticks_usec()
    for i in range(0,1000):
        test.replace("player", "asrak")
    end = Time.get_ticks_usec()
    var replace_time = (end-start)
    
    test = "loc_cav_intro_1.wav"
    start = Time.get_ticks_usec()
    for i in range(0,1000):
        test.insert(6, "_ask")
    end = Time.get_ticks_usec()
    var insert_time = (end-start)
    
    # Measuring the time spent running a calculation over each element of an array
    test = "loc_cav_{player}_intro_1.wav"
    start = Time.get_ticks_usec()
    for i in range(0, 1000):
        test.format(["asrak"])
    end = Time.get_ticks_usec()
    var loop_time = (end-start)

    print("Index time: %sns\nReplace time: %sns\nInsert Time: %sns\nFormat time: %sns" % [worker_time, replace_time, insert_time, loop_time])
    
