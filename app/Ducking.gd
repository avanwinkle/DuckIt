extends Control

var config = {
    "source_folder": null,
    "data_file": null,
    "music_folder": null,
    "resource_folder": null,
    "project_folder": null,
    "hide_finished": false,
    "output_format": 0
}

var data = {}
var is_dirty = false
var autosave = true
var existing_files = []

const max_folder_chars = 64
const default_settings = {
  "track": "voice",
  "volume": 1.0,
  "ducking": {
    "delay": 0.0,
    "attack": 0.5,
    "attenuation": 8.5,
    "release_point": 0.5,
    "release": 0.5
}}

enum SelectType {
  DATA_FILE,
  MUSIC_FOLDER,
  SOURCE_FOLDER,
  RESOURCE_FOLDER,
  PROJECT_FOLDER
}

enum OutputFormat {
  MPF_YAML,
  GODOT_RESOURCE,
  GODOT_TRES
}

func _ready():
    get_tree().set_auto_accept_quit(false)
    $Files/SourceFolder.pressed.connect(self.set_source_folder)
    $Files/MusicFolder.pressed.connect(self.set_music_folder)
    $Files/ResourceFolder.pressed.connect(self.set_resource_folder)
    $Files/ProjectFolder.pressed.connect(self.set_project_folder)
    $Files/DataFile.pressed.connect(self.set_data_file)
    $SoundList.item_selected.connect(self.select_sound)
    $SoundList.empty_clicked.connect(self.deselect_sound)
    $MusicList.item_selected.connect(self.play_music)
    $MusicList.empty_clicked.connect(self.stop_music)
    $Settings/Play.disabled = true
    $Settings/Save.disabled = true
    $Files/Write.disabled = true
    $Settings.visible = false
    $Settings/Play.pressed.connect(self.play_sound)
    $Settings/Save.pressed.connect(self.save_sound)
    $Files/Write.pressed.connect(self.write_data_file)
    $HideFinished.toggled.connect(self.toggle_hiding)
    $Filter.text_changed.connect(self.filter_sounds)
    $Settings/track.selected = 1
    $Settings/sample_rate.selected = 2
    $Settings/sample_rate.item_selected.connect(self.set_sample_rate)
    $Files/OutputOption.item_selected.connect(self.set_output_format)

    for c in $Settings.get_children():
        if "-" in c.name:
            c.pressed.connect(self.callv.bind("adjust_level", c.name.split("-")))

    initialize()

func initialize(_idx=-1):
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

    $HideFinished.button_pressed = config.hide_finished
    $Files/OutputOption.selected = config.output_format

    # Godot TRES always saves individual files
    if $Files/OutputOption.selected == OutputFormat.GODOT_TRES:
      $Files/DataFile.visible = false
      $Files/DataLabel.visible = false
      $Files/Write.visible = false
      $Files/WriteSpacer.visible = false
      $Files/ResourceFolder.visible = true
      $Files/ResourceLabel.visible = true
      $Files/ProjectFolder.visible = true
      $Files/ProjectLabel.visible = true
    # MPF Yaml and Godot Resource save a single file
    else:
      $Files/ResourceFolder.visible = false
      $Files/ResourceLabel.visible = false
      $Files/ProjectFolder.visible = false
      $Files/ProjectLabel.visible = false
      $Files/DataFile.visible = true
      $Files/DataLabel.visible = true
      $Files/Write.visible = true
      $Files/WriteSpacer.visible = true

    if config.get("data_file") and $Files/OutputOption.selected != OutputFormat.GODOT_TRES:
        self.set_data_file(config.data_file)
        self.read_data_file()
    if config.get("resource_folder") and $Files/OutputOption.selected == OutputFormat.GODOT_TRES:
        self.set_resource_folder(config.resource_folder)
    if config.get("project_folder"):
        self.set_project_folder(config.project_folder)
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
    $Settings/Play.disabled = false
    $Settings/Save.disabled = false
    var filename = $SoundList.get_item_text(index)
    var settings = data.get(filename, default_settings)
    $Settings/track.selected = 1 if settings.track == "callout" else 0
    $Settings/volume.text = str(settings.volume)
    $Settings/delay.text = str(settings.ducking.delay)
    $Settings/attack.text = str(settings.ducking.attack)
    $Settings/attenuation.text = str(settings.ducking.attenuation)
    $Settings/release_point.text = str(settings.ducking.release_point)
    $Settings/release.text = str(settings.ducking.release)
    $Settings.visible = true

func deselect_sound(_position, _idx):
    $Settings.visible = false
    $SoundList.deselect_all()

func filter_sounds(_text):
    self.set_source_folder(config.source_folder)

func play_music(name):
    var idx = $MusicList.get_selected_items()[0]
    var path = $MusicList.get_item_metadata(idx)
    print("Playing music at path %s" % path)
    SoundPlayer.play(path, "music",
        { "fade_in": 0.5, "fade_out": 1, "loop": true }, true)

func stop_music(_position, _idx):
    $MusicList.deselect_all()
    SoundPlayer.stop_all(0.1)

func play_sound():
    var idx = $SoundList.get_selected_items()[0]
    var path = $SoundList.get_item_metadata(idx)
    print("Playing sound at %s" % path)

    SoundPlayer.play("%s" % path, "voice", self.generate_sound_config(), true)

func save_sound():
    var idx = $SoundList.get_selected_items()[0]
    var filename = $SoundList.get_item_text(idx)
    data[filename] = self.generate_sound_config()
    is_dirty = true
    $Files/Write.disabled = false

    if autosave:
      write_data_file()

    if config.hide_finished:
      $SoundList.remove_item(idx)
      if idx == $SoundList.item_count:
        idx = idx - 1
      $SoundList.select(idx)

func generate_sound_config():
    return {
      "track": $Settings/track.get_item_text($Settings/track.selected),
      "volume": float($Settings/volume.text),
      "ducking": {
        "delay": float($Settings/delay.text),
        "attack": float($Settings/attack.text),
        "attenuation": float($Settings/attenuation.text),
        "release_point": float($Settings/release_point.text),
        "release": float($Settings/release.text)
    }}

func prompt_for_folder(title: String, select_type: SelectType):
    var dialog = FileDialog.new()
    dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE if select_type == SelectType.DATA_FILE else FileDialog.FILE_MODE_OPEN_DIR
    dialog.access = FileDialog.ACCESS_FILESYSTEM
    dialog.mode_overrides_title = true
    dialog.min_size = Vector2i(640, 480)
    dialog.title = "Select %s" % title
    if select_type == SelectType.DATA_FILE:
      if config.data_file:
        dialog.current_path = config.data_file
      dialog.file_selected.connect(self.set_data_file)
    elif select_type == SelectType.MUSIC_FOLDER:
      if config.music_folder:
        dialog.current_dir = config.music_folder
      dialog.dir_selected.connect(self.set_music_folder)
    elif select_type == SelectType.SOURCE_FOLDER:
      if config.source_folder:
        dialog.current_dir = config.source_folder
      dialog.dir_selected.connect(self.set_source_folder)
    elif select_type == SelectType.RESOURCE_FOLDER:
      if config.resource_folder:
        dialog.current_dir = config.resource_folder
      dialog.dir_selected.connect(self.set_resource_folder)
    elif select_type == SelectType.PROJECT_FOLDER:
      if config.project_folder:
        dialog.current_dir = config.project_folder
      dialog.dir_selected.connect(self.set_project_folder)
    else:
      push_warning("Unknown select type %s for FileDialog" % select_type)
      return
    self.add_child(dialog)
    dialog.popup_centered()

func set_source_folder(path=""):
    if path == "":
        prompt_for_folder("Source Folder", SelectType.SOURCE_FOLDER)
        return
    elif path != config.source_folder:
        config.source_folder = path
        self.save_config()
    if config.source_folder:
      $SoundList.clear()
      self.parse_directory(path, $SoundList)
      $Files/SourceFolder.text = self.clip_source_path(path)

func toggle_hiding(is_down):
    $SoundList.clear()
    self.parse_directory(config.source_folder, $SoundList)
    config.hide_finished = is_down
    self.save_config()

func set_music_folder(path=""):
    if path == "":
        prompt_for_folder("Music Folder", SelectType.MUSIC_FOLDER)
        return
    elif path != config.music_folder:
        print("Got new music path: '%s'" % path)
        config.music_folder = path
        self.save_config()
    if config.music_folder:
        $MusicList.clear()
        self.parse_directory(path, $MusicList)
        $Files/MusicFolder.text = self.clip_source_path(path)

func set_resource_folder(path=""):
  if path == "":
      prompt_for_folder("Resource Folder", SelectType.RESOURCE_FOLDER)
      return
  elif path != config.resource_folder:
      print("Got resource folder: '%s'" % path)
      config.resource_folder = path
      self.save_config()
  if config.resource_folder:
      self.parse_directory(path, null, existing_files)
      $Files/ResourceFolder.text = self.clip_source_path(path)

func set_project_folder(path=""):
  if path == "":
      prompt_for_folder("Project Root", SelectType.PROJECT_FOLDER)
      return
  elif path != config.project_folder:
      print("Got resource folder: '%s'" % path)
      config.project_folder = path
      self.save_config()
  if config.project_folder:
      # TODO: assemble the data from the files here
      # $MusicList.clear()
      # self.parse_directory(path, $MusicList)
      $Files/ProjectFolder.text = self.clip_source_path(path)

func set_data_file(path=""):
    if path == "":
        prompt_for_folder("Data File", SelectType.DATA_FILE)
        return
    elif path != config.data_file:
      config.data_file = path
      self.save_config()
    if config.data_file:
      $Files/DataFile.text = self.clip_source_path(path)

func parse_directory(path: String, target, accum = null):
    var assets = []
    var hide_existing = target and target == $SoundList and $HideFinished.button_pressed
    #print("Parsing director with path %s, hide_existing is %s" % [path, hide_existing])
    var dir = DirAccess.open(path)
    if not dir:
      print("Unable to open path '%s'" % path)
      return
    dir.list_dir_begin()
    var file_name = dir.get_next()
    while file_name != "":
      if dir.current_is_dir():
        parse_directory("%s/%s" % [path, file_name], target, accum)
      else:
        if file_name.get_extension() in ["wav", "ogg", "mp3"]:
          if hide_existing and not autosave and data.has(file_name):
            pass
          elif hide_existing and autosave and file_name in existing_files:
            pass
          else:
            if target == $SoundList and $Filter.text != "" and not file_name.contains($Filter.text):
              pass
            else:
              assets.push_back({"name": file_name, "path": "%s/%s" % [path, file_name]})
        elif file_name.get_extension() == "tres" and accum != null:
          accum.append(file_name.replace(".tres", ".wav"))
      file_name = dir.get_next()
    for asset in assets:
      if target:
        #print("Adding asset '%s'" % asset.name)
        var idx = target.add_item(asset.name)
        target.set_item_metadata(idx, asset.path)

func adjust_level(target, direction):
    var n = $Settings.get_node(target)
    var adjustment = 0.01 if Input.is_key_pressed(KEY_SHIFT) else 0.1
    if direction == "down":
        adjustment = adjustment * -1
    n.text = str(float(n.text) + adjustment)

func read_data_file():
    print("Loading data file '%s'..." % config.data_file)
    if not FileAccess.file_exists(config.data_file):
      push_error("Unable to load data file %s." % config.data_file)
      config.data_file = null
      self.save_config()
      return
    var data_file = load(config.data_file)
    if data_file:
      for p in data_file.SoundSettings.keys():
        data[p] = data_file.SoundSettings.get(p)

func write_data_file():
  var output_format = $Files/OutputOption.selected
  if output_format == OutputFormat.MPF_YAML:
    _write_mpf_yaml_file()
  elif output_format == OutputFormat.GODOT_RESOURCE:
    _write_godot_resource_file()
  elif output_format == OutputFormat.GODOT_TRES:
    _write_godot_tres()
  else:
    push_error("Unknown output format selection %d" % output_format)
    return
  is_dirty = false

func _write_mpf_yaml_file():
  var file = FileAccess.open(config.data_file, FileAccess.WRITE)
  var ts = Time.get_datetime_dict_from_system()
  for line in [
      "#config_version=5",
      "# Auto-generated sound file config from Duck It! %s:%s:%s %s/%s/%s" % [ts.hour, ts.minute, ts.second, ts.month, ts.day, ts.year],
      "\nsounds:",
  ]:
      file.store_line(line)
  for k in data.keys():
    for line in [
      "  %s:" % k.get_basename(),
      "    file: %s" % k,
      "    track: %s" % data[k].track,
      "    volume: %0.2f" % data[k].volume,
      "    ducking:",
      "      target: music",
    ]:
      file.store_line(line)
    for d in data[k].ducking.keys():
      file.store_line("      %s: %0.2f" % [d, data[k].ducking[d]])
  file.store_line("\n")
  $Files/Write.disabled = true

func _write_godot_resource_file():
    var file = FileAccess.open(config.data_file, FileAccess.WRITE)
    var ts = Time.get_datetime_dict_from_system()
    for line in [
        "# Auto-generated sound file config from Duck It! %s:%s:%s %s/%s/%s" % [ts.hour, ts.minute, ts.second, ts.month, ts.day, ts.year],
        "\nextends Resource\n",
        "const SoundSettings = {"
    ]:
        file.store_line(line)
    for k in data.keys():
      file.store_line('  "%s": %s,' % [k, data[k]])
    file.store_line("}\n")
    $Files/Write.disabled = true

func _write_godot_tres():
  var idx = $SoundList.get_selected_items()[0]
  var filename = $SoundList.get_item_text(idx)
  data[filename] = self.generate_sound_config()

  var path = $SoundList.get_item_metadata(idx)
  var target_path = path.replace(config.source_folder, config.resource_folder).replace(".wav", ".tres")
  print("Autosaving resource for %s at target path %s" % [filename, target_path])

  if not DirAccess.dir_exists_absolute(target_path.get_base_dir()):
    DirAccess.make_dir_recursive_absolute(target_path.get_base_dir())
  var file = FileAccess.open(target_path, FileAccess.WRITE)

  for line in [
      #"# Auto-generated resource from Duck It! %s:%s:%s %s/%s/%s" % [ts.hour, ts.minute, ts.second, ts.month, ts.day, ts.year],
      '[gd_resource type="Resource" load_steps=3 format=2]\n',
      '[ext_resource path="res://resources/AudioStreamCallout.gd" type="Script" id=1]',
      '[ext_resource path="%s" type="AudioStream" id=2]\n' % path.replace(config.project_folder, "res:/"),
      '[resource]',
      'script = ExtResource( 1 )',
      'sound_file = ExtResource( 2 )',
      'track = "%s"' % data[filename].track,
      'gain = %s' % data[filename].volume
  ]:
      file.store_line(line)
  for k in data[filename].ducking.keys():
    file.store_line('%s = %s' % [k, data[filename].ducking[k]])
  file.store_line("\n")


func _notification(what):
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
      if is_dirty:
        print("changes are dirty, not quitting")
        var dialog = ConfirmationDialog.new()
        dialog.title = "Quit Without Saving?"
        dialog.dialog_text = "\nYou have unsaved changes. Exiting now will lose them forever.\n"
        dialog.ok_button_text = "Quit Without Saving"
        dialog.get_ok_button().pressed.connect(get_tree().quit)
        dialog.min_size = Vector2i(400, 200)
        self.add_child(dialog)
        dialog.popup_centered()
      else:
        get_tree().quit() # default behavior

func clip_source_path(path):
  if path.length() <= max_folder_chars:
    return path
  return "...%s" % path.right(max_folder_chars)

func set_sample_rate(idx):
  SoundPlayer.mix_rate = int($Settings/sample_rate.get_item_text(idx))

func set_output_format(idx):
  config.output_format = idx
  save_config()
  initialize()
