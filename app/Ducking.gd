extends Control

var config = {
    "source_folder": null,
    "data_file": null,
    "music_folder": null
}

var data = {
    "__default__": { "track": "voice", "volume": 1.0, "ducking": {
        "delay": 0.5,
        "attack": 1.0,
        "attenuation": 8.5,
        "release_point": 0.5,
        "release": 0.5
    }}
}

func _ready():
    $Files/SourceFolder.pressed.connect(self.set_source_folder)
    $Files/MusicFolder.pressed.connect(self.set_music_folder)
    $Files/DataFile.pressed.connect(self.set_data_file)
    $SoundList.item_selected.connect(self.select_sound)
    $MusicList.item_selected.connect(self.play_music)
    $Play.disabled = true
    $Save.disabled = true
    $HideFinished.button_pressed = true
    $Play.pressed.connect(self.play_sound)
    $Save.pressed.connect(self.save_sound)
    $Write.pressed.connect(self.write_data_file)
    $HideFinished.toggled.connect(self.toggle_hiding)

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
    config.data_file = "/Users/anthony/git/swords-of-vengeance/godot-mc/autoloads/sounds.gd"
    if config.get("data_file"):
        self.set_data_file(config.data_file)
        self.read_data_file()
    if config.get("source_folder"):
        self.set_source_folder(config.source_folder)
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

func select_sound(index=-1):
    $Play.disabled = false
    $Save.disabled = false
    var filename = $SoundList.get_item_text(index)
    print("Looking for filename %s in settings? %s" % [filename, data.has(filename)])
    var settings = data.get(filename, data["__default__"])
    $Settings/track.text = settings.track
    $Settings/volume.text = str(settings.volume)
    $Settings/delay.text = str(settings.ducking.delay)
    $Settings/attack.text = str(settings.ducking.attack)
    $Settings/attenuation.text = str(settings.ducking.attenuation)
    $Settings/release_point.text = str(settings.ducking.release_point)
    $Settings/release.text = str(settings.ducking.release)

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

    SoundPlayer.play("%s" % path, "voice", self.generate_sound_config(), true)

func save_sound():
    var idx = $SoundList.get_selected_items()[0]
    var filename = $SoundList.get_item_text(idx)
    data[filename] = self.generate_sound_config()

func generate_sound_config():
    return {
      "track": $Settings/track.text,
      "volume": float($Settings/volume.text),
      "ducking": {
        "delay": float($Settings/delay.text),
        "attack": float($Settings/attack.text),
        "attenuation": float($Settings/attenuation.text),
        "release_point": float($Settings/release_point.text),
        "release": float($Settings/release.text)
    }}

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

func toggle_hiding(_down):
    $SoundList.clear()
    self.parse_directory(config.source_folder, $SoundList)

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
    if path == "":
        config["data_file"] = prompt_for_folder()
    if path != "":
      config.data_file = path
      self.save_config()
      $Files/DataFile.text = path

func parse_directory(path: String, target: ItemList):
    var assets = []
    var hide_existing = target == $SoundList and $HideFinished.button_pressed
    print("Parsing director with path %s, hide_existing is %s" % [path, hide_existing])
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
          if hide_existing and data.has(file_name):
            pass
          else:
            assets.push_back({"name": file_name, "path": "%s/%s" % [path, file_name]})
      file_name = dir.get_next()
    for asset in assets:
      #print("Adding asset '%s'" % asset.name)
      var idx = target.add_item(asset.name)
      target.set_item_metadata(idx, asset.path)

func read_data_file():
    var data_file = ResourceLoader.load(config.data_file)
    data = data_file.SoundFiles

func write_data_file():
    var file = FileAccess.open(config.data_file, FileAccess.WRITE)
    for line in [
        "# Auto-generated sound file config",
        "extends Node",
        "const SoundFiles = {",
    ]:
        file.store_line(line)
    for k in data.keys():
        if k != "__default__":
            file.store_line('    "%s": %s,' % [k, data[k]])
    file.store_line("}")
