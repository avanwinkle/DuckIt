extends Node2D

const CHANGE_DB = -8.5

# Called when the node enters the scene tree for the first time.
func _ready():
    var player = AudioStreamPlayer.new()
    player.stream = load("res://assets/music/main/bells-loop.ogg")
    self.add_child(player)
    player.play()
    self._replay_duck()
    
func _replay_duck():
    var duck = get_tree().create_tween()
    var current_volume = AudioServer.get_bus_volume_db(0)
    var new_volume = CHANGE_DB  if current_volume == 0.0 else 0.0
    duck.tween_method(self._duck_music, current_volume, new_volume, 0.5).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
    duck.finished.connect(self._replay_duck)

func _duck_music(value: float):
    print("Setting music to %0.2f" % value)
    AudioServer.set_bus_volume_db(0, value)
    
