# Copyright 2021 Paradigm Tilt

extends Node

@onready var _callout_1: AudioStreamPlayer = $Channels/Callout1
@onready var _voice_1: AudioStreamPlayer = $Channels/Voice1
@onready var _music_1: AudioStreamPlayer = $Channels/Music1
@onready var _music_2: AudioStreamPlayer = $Channels/Music2
@onready var _sfx_1: AudioStreamPlayer = $Channels/SFX1
@onready var _sfx_2: AudioStreamPlayer = $Channels/SFX2
@onready var _sfx_3: AudioStreamPlayer = $Channels/SFX3
@onready var MusicDuck: Tween

@onready var SFX_TRACKS: = [_sfx_1, _sfx_2, _sfx_3]
@onready var MUSIC_TRACKS: = [_music_1, _music_2]
@onready var VOICE_TRACKS: = [_voice_1]
@onready var CALLOUT_TRACKS: = [_callout_1]

var queued_voice: Array = []
var queued_callout: Array = []
var queued_music: Array = []
var _music_interrupt_channel: AudioStreamPlayer
var _music_interrupt_time: float
var _music_loop_channel: AudioStreamPlayer

# Counter for the current loop number of the music (zero-indexed)
var _music_loops: int = 0
# Counter for what the next loop number will be
var _music_loop_pending: int = 0

var duck_attenuation := 8
var duck_attack := 0.5
var duck_release := 0.5
var duck_settings
var unduck_level: int = AudioServer.get_bus_volume_db(1)

const default_duck = {
  "delay": 0.0,
  "attack": 0.4,
  "attenuation": 8,
  "release_point": 0.3,
  "release": 0.6
}

func _ready() -> void:
  
  # Godot4 doesn't support direct tweens, so create one manually
  _voice_1.connect("finished", self._on_queue_track_finished)
  _callout_1.connect("finished", self._on_queue_track_finished)
  _music_1.connect("finished", self._on_music_finished.bind(_music_1))
  _music_2.connect("finished", self._on_music_finished.bind(_music_2))
  $DuckAttack.connect("timeout", self._duck_attack)
  $DuckRelease.connect("timeout", self._duck_release)
  set_process(false)

func _process(_delta) -> void:
  var current_time: float
  if _music_interrupt_channel:
    current_time = _music_interrupt_channel.get_playback_position()
    var offset = fmod(current_time, _music_interrupt_time)
    # Floats will never exactly match, so what's our margin of error? 2/100ths?
    if offset < 0.015:
      # If the interrupt channel came to it's natural end, it will be stopped and the "finished"
      # callback has already been sent. If we are interrupting mid-stream, we need to stop the
      # channel and force the next channel to play *immediately* -- otherwise there will be a gap
      if _music_interrupt_channel.playing:
        _music_interrupt_channel.stop()
        # Force the next channel to play but pass is_forced=true so we know there will be
        # a subsequent "finished" event when the above stop() call is processed.
        self._on_music_finished(_music_interrupt_channel, true)
      _music_interrupt_channel = null
      _music_interrupt_time = 0.0
      if not _music_loop_channel:
        set_process(false)

  # Check if we looped
  if _music_loop_channel:
    current_time = _music_loop_channel.get_playback_position()
    # If we're less than a second in and haven't updated the loop, do so now
    if current_time < 1.0 and _music_loop_pending != _music_loops:
      _music_loops += 1
      #self.logger.debug("Music loop channel (%s) is at the beginning with pending loop %s", [_music_loop_channel, _music_loop_pending])
      #self.logger.debug(" - Incremented music loops to iteration %s", _music_loops)
      # Play some quest music
      var in_channel: AudioStreamPlayer
      var out_channel: AudioStreamPlayer
      if _music_loops == 1 and $Overlays/quest1.stream:
          in_channel = $Overlays/quest1
      elif _music_loops == 2 and $Overlays/quest2.stream:
        out_channel = $Overlays/quest1
        in_channel = $Overlays/quest2
      elif _music_loops == 3 and $Overlays/quest3.stream:
        out_channel = $Overlays/quest2
        in_channel = $Overlays/quest3
      # Cross out the layer 2 and layer 3
      elif _music_loops > 4 and $Overlays/quest3.stream:
        if _music_loops % 2 == 0:
          in_channel = $Overlays/quest3
          out_channel = $Overlays/quest2
        else:
          in_channel = $Overlays/quest2
          out_channel = $Overlays/quest3
      if in_channel:
        self._play(in_channel, { "start_at": current_time, "track": "music", "fade_in": 0.25 if out_channel else 1.0 })
        # Fade the main loop down
        var main_reduced_db: float
        if in_channel == $Overlays/quest1:
          main_reduced_db = -0.5
        elif in_channel == $Overlays/quest2:
          main_reduced_db = -1.0
        elif in_channel == $Overlays/quest3:
          main_reduced_db = -1.8
        if main_reduced_db:
          var tween = get_tree().create_tween()
          tween.finished.connect(self._on_fade_complete.bind(_music_loop_channel, null, tween, "play"))
          tween.tween_property(_music_loop_channel, "volume_db", main_reduced_db, 3.0).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
          #$Tweens.add_child(tween)
          tween.play()
          _music_loop_channel.set_meta("tween", tween)
      if out_channel:
        self._stop(out_channel, { "fade_out": 0.5 })
    # We have a 1s buffer, then advance the pending count to the next loop number
    elif current_time > 1.0 and _music_loop_pending == _music_loops:
      _music_loop_pending += 1

func on_sounds_play(s: Dictionary) -> void:
  assert(typeof(s) == TYPE_DICTIONARY, "Sound player called with non-dict value: %s" % s)
  for asset in s.keys():
    var settings = s[asset]
    var track: String = settings.get("track", "sfx")
    var file: String = settings.get("file", asset)
    var action: String = settings.get("action", "play")

    # Special case: synced sfx track
    if track == "sfx_sync":
      track = "sfx"
      # Super secret value -1.0 means sync with music
      settings["start_at"] = -1.0 if _music_loop_channel else 0.0

    if action == "stop" or action == "loop_stop":
      self.stop(file, track, settings)
      return
    self.play(file, track, settings)

func play(filename: String, track: String, settings: Dictionary = {}, is_absolute_path = false) -> void:
  #self.logger.debug("play called for %s on %s with settings %s" % [filename, track, settings])
  var filepath = filename if is_absolute_path else "res://assets/%s/%s" % ["voice" if track == "callout" else track, filename]
  var available_channel: AudioStreamPlayer
  var do_queue_music := false
  settings["track"] = track

  # Callouts supercede voice tracks. If there is a callout, stop voices
  if track == "callout" and _voice_1.playing and settings.get("block_voice", true):
    self._stop(_voice_1, { "fade_out": 0.5 })
    # Clear out any other queued voices
    queued_voice = []

  # Music overlays are targeted at explicit channels
  if settings.get("overlay"):
    available_channel = $Overlays.get_node(settings.overlay)

  # Check our channels to see if (1) one is empty or (2) one already has this
  for channel in self._get_channels(track):
    if channel.stream and channel.stream.resource_path == filepath:
      # If this file is *already* playing, keep playing
      if channel.playing:
        # If this channel has a tween, override it
        if channel.has_meta("tween") and is_instance_valid(channel.get_meta("tween")):
          # Stop the tween
          var tween = channel.get_meta("tween")
          tween.stop()
          self._on_fade_complete(channel, null, tween,  "cancel")
        # If the channel does not have a tween, let it continue playing
        else:
          # If there is an explicit start time, jump there
          if settings.get("start_at") != null:
            channel.seek(settings["start_at"])
          return
      #self.logger.debug("Channel %s already has resource %s, playing from memory", [channel, filepath])
      available_channel = channel
    elif not available_channel:
      if not channel.stream:
        #self.logger.debug("Channel %s has no stream, making it the available channel" % channel)
        available_channel = channel
      elif not channel.playing:
        # Don't take a channel that's queued
        if track == "music" and self.queued_music.size() and channel == self.queued_music[0]["channel"]:
          #self.logger.debug("Channel %s is queued up with music, not making it available")
          pass
        else:
          #self.logger.debug("Channel %s has a stream %s but it's not playing, making it available" % [channel, channel.stream])
          available_channel = channel
          available_channel.stream = null
    # Music only allows one channel at a time, so stop any other channels
    if channel.playing and channel != available_channel and track == "music":
      # We can queue this track to play at the end of the current track's loop
      if settings.get("queue", false):
        do_queue_music = true
        # Stop looping the playing channel
        # There is a bug(?) in Godot where setting loop = false
        # immediately stops the track. Instead, use the set_loop() method
        channel.stream.set_loop(false)
        # Is there an interrupt? Track the channel we want to interrupt
        if settings.get("interrupt"):
          self._music_interrupt_channel = channel
          self._music_interrupt_time = settings['interrupt']
          set_process(true)
        # Don't stop this channel, but keep looking for an available music channel
        # to preload the queued track
        continue
      # Always do a cross-fade on music
      if not settings.get("fade_out"):
        settings["fade_out"] = 1
      # If we want to sync the incoming music, get the play position
      if settings.get("sync", false):
        settings["start_at"] = channel.get_playback_position()
      # Unless this is an overlay, stop the underlying channel
      if not settings.get("overlay"):
        self._stop(channel, settings)

  if do_queue_music:
    # If the channel is available, preload the file
    if available_channel:
      available_channel.stream = load(filepath)
    self.queued_music.push_back({
      "channel": available_channel,
      "filepath": filepath,
      "forced": false,
      "settings": settings
    })
    return

  if not available_channel:
    # Queue the filename if it's a voice or callout track
    var target_queue = queued_callout if track == "callout" else queued_voice if track == "voice" else null
    if target_queue:
      # By default, max queue time is one minute (tracked in milliseconds)
      var max_queue_time: int = settings.get("max_queue_time", 60000)
      if max_queue_time != 0:
        target_queue.append(self._generate_queue_item(filename, max_queue_time, settings))
    return
  if not available_channel.stream:
    if not is_absolute_path:
      available_channel.stream = load(filepath)
    else:
      if FileAccess.file_exists(filepath):
          var file = FileAccess.open(filepath, FileAccess.READ)
          var buffer = file.get_buffer(file.get_length())
          var stream
          if filepath.ends_with(".wav"):
            stream = AudioStreamWAV.new()
            stream.data = buffer
            stream.format = 1 # 16 bit
            stream.mix_rate = 48000
            stream.stereo = false
          elif filepath.ends_with(".ogg"):
            stream = AudioStreamOggVorbis.new()
            var data = OggPacketSequence.new()
            data.packet_data = buffer
            stream.packet_sequence = data
          elif filepath.ends_with(".mp3"):
            stream = AudioStreamMP3.new()
          else:
            print("Error opening file '%s': unknown audio type" % filepath)
          #for i in 200:
          #    buffer.remove(buffer.size()-1) # removes pop sound at the end
          #    buffer.remove(0)

          available_channel.stream = stream  
      else:
          print("Unable to open file at path %s" % filename)
  self._play(available_channel, settings)

func _play(channel: AudioStreamPlayer, settings: Dictionary) -> void:
  print("Playing %s on %s with settings %s" % [channel.stream.resource_path, channel, settings])
  var start_at: float = settings.get("start_at", 0.0)
  var fade_in: float = settings.get("fade_in", 0.0)
  # Music is OGG, which doesn't support loop begin/end
  if settings.get("track") == "music":
    # By default, loop the music, but allow an override
    channel.stream.loop = settings.get("loop", true)
    # Check if we need to track looping
    if channel.stream.loop and settings.get("loop_signal", false):
      #self.logger.debug("Setting loop signal for stream %s on channel %s", [channel.stream.resource_path, channel])
      _music_loop_channel = channel
      _music_loops = 0
      _music_loop_pending = 0
      set_process(true)
  elif start_at == -1.0:
    # Map the sound start position relative to the music position
    start_at = fmod(_music_loop_channel.get_playback_position(), channel.stream.get_length())
  elif settings.get("loop_end"):
    # TODO: Manage an explicit number of loops?
    channel.stream.loop_mode = 1  # LoopMode.LOOP_FORWARD
    # A loop_end of -1 will loop the entire file
    channel.stream.loop_end = (channel.stream.get_length() * channel.stream.mix_rate) if settings["loop_end"] == -1 else settings["loop_end"]
    if settings.get("loop_begin"):
      channel.stream.loop_begin = settings["loop_begin"]

  # If this is a voice or callout, duck the music
  if settings.get("track") == "voice" or settings.get("ducking"):
    duck_settings = settings.get("ducking", default_duck)
    duck_settings.release_timestamp = channel.stream.get_length() - duck_settings.get("release_point", default_duck.release_point)
    if duck_settings.get("delay"):
      $DuckAttack.start(duck_settings.delay)
    else:
      self._duck_attack()

  # If the current volume is less than the target volume, e.g. this was fading out
  # but was re-played, force a quick fade to avoid jumping back to full
  if not fade_in and channel.playing and channel.volume_db < 0:
    fade_in = 0.5
  if not fade_in:
    # Ensure full volume in case it was tweened out previously
    channel.volume_db = settings.get("volume", 0.0)
    channel.play(start_at)
    return
  # Set the channel volume and begin playing
  if not channel.playing:
    channel.volume_db = -80.0
    channel.play(start_at)
  var tween = get_tree().create_tween()
  tween.tween_property(channel, "volume_db", 0.0, fade_in).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
  tween.finished.connect(self._on_fade_complete.bind(channel, null, tween, "play"))
  tween.play()
  channel.set_meta("tween", tween)

func stop(filename: String, track: String, settings: Dictionary) -> void:
  var filepath: String = "res://assets/%s/%s" % [track, filename]
  # Find the channel playing this file
  for channel in self._get_channels(track):
    if channel.stream and channel.stream.resource_path == filepath:
      self._stop(channel, settings)
      return
  # It's possible that the stop was called just for safety.
  # If no channel is found with this file, that's okay.

func stop_overlay(overlay_name: String, settings: Dictionary) -> void:
  if overlay_name == "__all__":
    for n in $Overlays.get_children():
      self._stop(n, settings, "clear")
  else:
    self._stop($Overlays.get_node(overlay_name), settings, "clear")

func _stop(channel: AudioStreamPlayer, settings: Dictionary, action: String = "stop") -> void:
  if channel == _music_loop_channel:
    _music_loop_channel = null
    if not _music_interrupt_channel:
      set_process(false)
  elif channel == _music_interrupt_channel:
    _music_interrupt_channel = null
    if not _music_loop_channel:
      set_process(false)
  if settings.get("action") == "loop_stop":
    # The position is reset when the loop mode changes, so store it first
    var pos: float = channel.get_playback_position()
    channel.stream.loop_mode = 0
    # Play the track to the end of the file
    channel.play(pos)
    return
  if not settings.get("fade_out"):
    channel.stop()
    return
  var tween = get_tree().create_tween()
  tween.tween_property(channel, "volume_db", -80.0, settings["fade_out"]).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
  tween.finished.connect(self._on_fade_complete.bind(channel, null, tween, action))
  tween.play()
  channel.set_meta("tween", tween)

func stop_all(fade_out: float = 1.0) -> void:
  duck_settings = null
  # Clear any queued tracks as well, lest they be triggered after the stop
  for track in ["music", "voice", "callout"]:
    self.clear_queue(track)
  var tween = get_tree().create_tween() if fade_out > 0 else null
  for channel in $Channels.get_children() + $Overlays.get_children():
    if channel.playing:
      if tween:
        tween.tween_property(channel, "volume_db", -80.0, fade_out).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
      else:
        channel.stop()
  if tween:
    tween.finished.connect(self._on_fade_complete.bind(null, null, tween, "stop_all"))
    tween.play()
  else:
    for t in $Tweens.get_children():
      $Tweens.remove_child(t)
      t.remove_all()
      t.queue_free()
    set_process(false)

func clear_queue(track: String) -> void:
  match track:
    "music":
      self.queued_music = []
    "voice":
      self.queued_voice = []
    "callout":
      self.queued_callout = []
    _:
      print("Unknown track '%s' to clear queue.", track)

func _on_fade_complete(channel, _nodePath, tween, action) -> void:
  #$Tweens.remove_child(tween)
  # Presumably the signal will disconnect when the tween is removed
  #tween.remove_all()
  #tween.queue_free()
  # If this is a stop action, stop the channel as well
  if action == "stop" or action == "clear":
    #self.logger.debug("Fade out complete on channel %s" % channel)
    channel.stop()
  # If this is a stop_all action, stop all the channels
  elif action == "stop_all":
    for c in $Channels.get_children():
      if c.stream and c.stream.resource_path != "res://assets/sfx/stinger.wav":
        c.stop()
    set_process(false)
  elif action == "play":
    #self.logger.debug("Fade in to %0.2f complete on channel %s", [channel.volume_db, channel])
    pass
  if action == "clear":
    channel.stream = null

func _get_channels(track: String):
  match track:
    "sfx":
      return SFX_TRACKS
    "music":
      return MUSIC_TRACKS
    "voice":
      return VOICE_TRACKS
    "callout":
      return CALLOUT_TRACKS
  print("Invalid track %s requested", track)

func _generate_queue_item(filename: String, max_queue_time: int, settings: Dictionary) -> Dictionary:
  return {
    "filename": filename,
    "expiration": Time.get_ticks_msec() + (1000 * max_queue_time),
    "settings": settings
  }

func _on_queue_track_finished() -> void:
  # The two queues hold dictionary objects like this:
  #{ "filename": filename, "expiration": some_time, "settings": settings }
  var now := Time.get_ticks_msec()
  var q: Dictionary
  # First check for a callout that's queued
  while queued_callout:
    q = queued_callout.pop_front()
    if q.expiration > now:
      self.play(q.filename, "callout", q.settings)
      return
  # Now check for voice
  while queued_voice:
    q = queued_voice.pop_front()
    if q.expiration > now:
      self.play(q.filename, "voice", q.settings)
      return

# Special method for transitioning from one music loop to another
func _on_music_finished(channel: AudioStreamPlayer, is_forced: bool = false) -> void:
  if not self.queued_music.size():
    return

  var upnext = self.queued_music[0]
  #self.logger.debug("Music track on channel %s has finished, up next is %s", [channel, upnext])
  # When we force a transition, the original finished event will emit later.
  # If that's now, we can proceed to preload the track (but not play it)
  if not is_forced and upnext["forced"] and upnext["channel"] == channel:
    channel.stream = load(upnext["filepath"])
    # Clear the forced flag to restore proper queue processing
    upnext["forced"] = false
    return

  # Pop the front off the queue
  self.queued_music.pop_front()
  self._play(upnext["channel"], upnext["settings"])

  # If there is another music track in the queue... queued, use the freshly-empty channel
  if self.queued_music:
    # We will use this channel for the next music, regardless
    self.queued_music[0]["channel"] = channel

    # If we are forcing a transition, we don't want to queue the next track
    # Instead, mark it as forced
    if is_forced:
      self.queued_music[0]["forced"] = true
    else:
      channel.stream = load(self.queued_music[0]["filepath"])

func _on_volume(track: String, value: float, _change: float):
  var bus_name: String = track.trim_suffix("_volume")
  # The Master bus is fixed and capitalized
  if bus_name == "master":
    bus_name = "Master"
  AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus_name), linear_to_db(value))

func set_quest(quest_column: String, quest_level: int) -> void:
  # Always set the first quest
  $Overlays/quest1.stream = load("res://assets/music/main/%s-1.ogg" % quest_column)
  $Overlays/quest2.stream = load("res://assets/music/main/%s-2.ogg" % quest_column) if quest_level > 1 else null
  $Overlays/quest3.stream = load("res://assets/music/main/%s-3.ogg" % quest_column) if quest_level > 2 else null

func _duck_music(value: float):
  #print(" - setting music bus volume to %0.2f" % value)
  AudioServer.set_bus_volume_db(1, value)

func _duck_attack() -> void:
  if duck_settings.is_empty():
    return
  # We only have one duck at a time, so store the return values globally
  duck_release = duck_settings.get("release", default_duck.release)
  if MusicDuck:
    print("killing old music duck")
    MusicDuck.kill()
  print("Attack the duck!!")
  MusicDuck = get_tree().create_tween()
  MusicDuck.tween_method(self._duck_music,
                                # Always use the current level in case we're interrupting
                                AudioServer.get_bus_volume_db(1),
                                self.unduck_level - duck_settings.get("attenuation", default_duck.attenuation),
                                duck_settings.get("attack", default_duck.attack)) \
                                .set_trans(Tween.TRANS_LINEAR) \
                                .set_ease(Tween.EASE_IN)
  print("Ducking voice clip down with settings: %s" % duck_settings)
  $DuckRelease.start(duck_settings.release_timestamp)


func _duck_release():
  if duck_settings.is_empty():
    return
  # If the music is ducked, unduck it
  if AudioServer.get_bus_volume_db(1) < self.unduck_level:
    var current_volume = AudioServer.get_bus_volume_db(1)
    var new_volume = float(self.unduck_level)
    print("Unducking voice clip from %0.2f back to %0.2f db over %0.2f seconds" % [AudioServer.get_bus_volume_db(1), new_volume, duck_release])
    if MusicDuck:
      MusicDuck.kill()
    MusicDuck = get_tree().create_tween()
    MusicDuck.tween_method(self._duck_music, current_volume, new_volume, duck_release).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
