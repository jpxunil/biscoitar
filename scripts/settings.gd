class_name Settings
## Configurações do jogador: volume e atalhos. Ficam num arquivo próprio (user://settings.cfg),
## separado do progresso, e valem na hora: nada aqui precisa reiniciar o jogo.
##
## Áudio: cada canal é um bus de verdade do AudioServer (default_bus_layout.tres). Só entra em
## CHANNELS o canal que o jogo realmente toca. Pra criar música, voz etc.: adicione o bus no
## layout, toque os sons nele e ponha uma linha aqui; o slider aparece sozinho na tela de opções.

const PATH := "user://settings.cfg"
const CHANNELS := [
	{"bus": &"Master", "name": "Volume geral"},
	{"bus": &"SFX", "name": "Efeitos sonoros"},
]

## bus -> 0..1
static var volume: Dictionary = {}
static var mute_all := false
static var _booted := false


## Carrega do disco na primeira chamada e aplica. Com Knowledge.persist desligado (testes) fica no padrão.
static func boot() -> void:
	if _booted:
		return
	_booted = true
	Binds.boot()
	_defaults()
	if Knowledge.persist:
		read(PATH)
	apply_audio()


static func _defaults() -> void:
	mute_all = false
	for c in CHANNELS:
		volume[c["bus"]] = 1.0


static func set_volume(bus: StringName, v: float) -> void:
	volume[bus] = clampf(v, 0.0, 1.0)
	apply_audio()


static func set_mute_all(on: bool) -> void:
	mute_all = on
	apply_audio()


static func reset_audio() -> void:
	_defaults()
	apply_audio()


static func apply_audio() -> void:
	for c in CHANNELS:
		var i := AudioServer.get_bus_index(c["bus"])
		if i < 0:
			push_error("Settings: o bus de áudio %s não existe no layout" % c["bus"])
			continue
		var v: float = volume.get(c["bus"], 1.0)
		# em zero o bus fica mudo em vez de ir pra -inf dB
		var off: bool = v <= 0.0 or (mute_all and c["bus"] == &"Master")
		AudioServer.set_bus_mute(i, off)
		if v > 0.0:
			AudioServer.set_bus_volume_linear(i, v)


static func save() -> void:
	if Knowledge.persist:
		write(PATH)


static func write(path: String) -> Error:
	var cfg := ConfigFile.new()
	for c in CHANNELS:
		cfg.set_value("audio", String(c["bus"]), volume.get(c["bus"], 1.0))
	cfg.set_value("audio", "mute_all", mute_all)
	var b := Binds.to_dict()
	for id in b:
		cfg.set_value("binds", id, b[id])
	return cfg.save(path)


static func read(path: String) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	for c in CHANNELS:
		volume[c["bus"]] = clampf(float(cfg.get_value("audio", String(c["bus"]), 1.0)), 0.0, 1.0)
	mute_all = bool(cfg.get_value("audio", "mute_all", false))
	var b := {}
	if cfg.has_section("binds"):
		for id in cfg.get_section_keys("binds"):
			b[id] = cfg.get_value("binds", id)
	Binds.from_dict(b)
