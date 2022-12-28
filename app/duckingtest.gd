extends Control

var config = {
    "source_folder": null,
    "data_file": null,
    "music_folder": null
}

func _ready():
    $Files/SourceFolder.pressed.connect(self.set_source_folder)
    $Files/MusicFolder.pressed.connect(self.set_music_folder)
    $Files/DataFile.pressed.connect(self.set_data_file)
    $SoundList.item_selected.connect(self.enable_playback)
    $MusicList.item_selected.connect(self.play_music)
    $Play.disabled = true
    $Play.pressed.connect(self.play_sound)
    
    self.load_config()
    
func load_config():
    var config_file = ConfigFile.new()

    # Load data from a file.
    var err = config_file.load("user://config.cfg")

    # If the file didn't load, ignore it.
    if err != OK:
        return
        
    if config_file.has_section("config"):
        for k in config.keys():
            if config_file.has_section_key("config", k):
                config[k] = config_file.get_value("config", k)
    config.music_folder = "/Users/anthony/git/swords-of-vengeance/godot-mc/assets/music"
    if config.get("source_folder"):    
        self.set_source_folder(config.source_folder)
    if config.get("data_file"):
        self.set_data_file(config.data_file)
    if config.get("music_folder"):
        self.set_music_folder(config.music_folder)
    print("Setup with config: %s" % config)

func save_config():
    var config_file = ConfigFile.new()
    for k in config.keys():
        config_file.set_value("config", k, config[k])
    var err = config_file.save("user://config.cfg")
    if err != OK:
        print("Unable to save config file:", err)

func enable_playback(index=-1):
    $Play.disabled = false
    $SoundList.item_selected.disconnect(self.enable_playback)

func play_music(name):
    var idx = $MusicList.get_selected_items()[0]
    var path = $MusicList.get_item_metadata(idx)
    print("Playing music at path %s" % path)
    SoundPlayer.play(path, "music", 
        { "fade_in": 0.5, "fade_out": 1, "loop": true }, true)
    #var quest = name.split("-")
    #print("Playing music %s over base %s" % [name, quest[1]])
    #SoundPlayer.play("main/main-%s.ogg" % quest[1], "music", { "fade_in": 0.5, "fade_out": 1, "loop_signal": true})
    #SoundPlayer.set_quest(quest[0], int(quest[1]))
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

func prompt_for_folder():
    var dialog = FileDialog.new()
    dialog.mode = 2
    dialog.access = 2
    self.add_child(dialog)
    dialog.popup_centered()
    var path = "/Users/anthony/git/swords-of-vengeance/godot-mc/assets/voice"
    return path
    
func set_source_folder(path=""):
    print("Set source folder")
    if path == "":
        config["source_folder"] = prompt_for_folder()
        self.save_config()
    if path != "":
        self.parse_directory(path, $SoundList)
        $Files/SourceFolder.text = path
        
func set_music_folder(path=""):
    print("Set music folder")
    if path == "":
        config["music_folder"] = prompt_for_folder()
        self.save_config()
    if path != "":
        self.parse_directory(path, $MusicList)
        $Files/MusicFolder.text = path
        
func set_data_file(path):
    print("Set data file")
    config.data_file = path
    self.save_config()

func parse_directory(path: String, target: ItemList):
    var assets = []
    var dir = DirAccess.open(path)
    if not dir:
      print("Unable to open path '%s'" % path)
      return
    dir.list_dir_begin()
    var file_name = dir.get_next()
    while file_name != "":
      if dir.current_is_dir():
        print("Found subfolder %s" % file_name)
        parse_directory("%s/%s" % [path, file_name], target)
      else:
        var suffix = file_name.split(".")[-1]
        if suffix in ["wav", "ogg", "mp3"]:
          print("Found file %s" % file_name)
          assets.push_back({"name": file_name.split(".", 1)[0], "path": "%s/%s" % [path, file_name]})
      file_name = dir.get_next()
    for asset in assets:
      print("Adding asset '%s'" % asset.name)
      #b.pressed.connect(self.play_sound.bind(asset.path))
      var idx = target.add_item(asset.name)
      target.set_item_metadata(idx, asset.path)
