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

    for s in sounds:
        var b = Button.new()
        b.name = s
        b.text = s
        b.pressed.connect(self.play_sound.bind(s))
        $SoundList.add_child(b)

    $Files/SourceFolder.pressed.connect(self.set_source_folder)
    $Files/DataFile.pressed.connect(self.set_data_file)

func play_music(name):
    var quest = name.split("-")
    print("Playing music %s over base %s" % [name, quest[1]])
    SoundPlayer.play("main/main-%s.ogg" % quest[1], "music", { "fade_in": 0.5, "fade_out": 1, "loop_signal": true})
    SoundPlayer.set_quest(quest[0], int(quest[1]))
    #SoundPlayer.play("main/%s.ogg" % name, "overlay", { "overlay": "quest1"})
    # SoundPlayer.get_child_by_name("Overlays").get_child_by_name("quest1").stream = load("res://assets/music/main/%s.ogg" % name)

func play_sound(name):
    SoundPlayer.play("%s" % name, "voice", { "ducking": {
        "delay": float($Settings/delay.text),
        "attack": float($Settings/attack.text),
        "attenuation": float($Settings/attenuation.text),
        "release_point": float($Settings/release_point.text),
        "release": float($Settings/release.text)
    }})

func set_source_folder():
    print("Set source folder")

func set_data_file():
    print("Set data file")
