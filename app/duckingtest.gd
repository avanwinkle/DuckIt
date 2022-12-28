extends Control

const sounds = [
    "lionman_challenge_me.wav",
    "lionman_free_the_titans.wav",
    "lionman_laugh.wav",
    "lionman_lionman.wav",
    "lionman_roar.wav",
    "lionman_take_ogres_alley.wav"
]

func _ready():
    for b in $MusicButtons.get_children():
        b.pressed.connect(self.play_music.bind(b.name))

    $Files/SourceFolder.pressed.connect(self.set_source_folder)
    $Files/DataFile.pressed.connect(self.set_data_file)
    $SoundList.item_selected.connect(self.enable_playback)
    $Play.disabled = true
    $Play.pressed.connect(self.play_sound)
    
    self.set_source_folder()

func enable_playback(index=-1):
    print("ENabling playback!")
    $Play.disabled = false
    $SoundList.item_selected.disconnect(self.enable_playback)

func play_music(name):
    var quest = name.split("-")
    print("Playing music %s over base %s" % [name, quest[1]])
    SoundPlayer.play("main/main-%s.ogg" % quest[1], "music", { "fade_in": 0.5, "fade_out": 1, "loop_signal": true})
    SoundPlayer.set_quest(quest[0], int(quest[1]))
    #SoundPlayer.play("main/%s.ogg" % name, "overlay", { "overlay": "quest1"})
    # SoundPlayer.get_child_by_name("Overlays").get_child_by_name("quest1").stream = load("res://assets/music/main/%s.ogg" % name)

func play_sound():
    var idx = $SoundList.get_selected_items()[0]
    var path = $SoundList.get_item_metadata(idx)
    print("Playing sound at %s" % path)
  
    
    SoundPlayer.play("%s" % path, "voice", { "ducking": {
        "delay": float($Settings/delay.text),
        "attack": float($Settings/attack.text),
        "attenuation": float($Settings/attenuation.text),
        "release_point": float($Settings/release_point.text),
        "release": float($Settings/release.text)
    }}, true)

func set_source_folder():
    print("Set source folder")
    #var dialog = FileDialog.new()
    #dialog.mode = 2
    #dialog.access = 2
    #self.add_child(dialog)
    #dialog.popup_centered()
    var path = "/Users/Anthony/git/swords-of-vengeance/godot-mc/assets/voice"
    var assets = []
    var dir = DirAccess.open(path)
    if not dir:
      print("Unable to open path")
      return
    dir.list_dir_begin()
    var file_name = dir.get_next()
    while file_name != "":
      print("Found file %s" % file_name)
      if file_name.ends_with(".wav"):
        assets.push_back({"name": file_name.split(".", 1)[0], "path": "%s/%s" % [path, file_name]})
      file_name = dir.get_next()
    for asset in assets:
      print("Adding asset '%s'" % asset.name)
      #b.pressed.connect(self.play_sound.bind(asset.path))
      var idx = $SoundList.add_item(asset.name)
      $SoundList.set_item_metadata(idx, asset.path)

func set_data_file():
    print("Set data file")
