extends GutTest

## Songs crossfade: the new one fades in while the old one fades out, then stops.

const LEVEL := preload("res://scenes/levels/hadeda_park/hadeda_park.tscn")


func test_songs_crossfade() -> void:
	GameManager.reset()
	var root := Node3D.new()
	get_tree().root.add_child(root)
	get_tree().current_scene = root
	var level: Node3D = LEVEL.instantiate()
	level.race_seconds = 9999.0
	root.add_child(level)
	level.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	await wait_physics_frames(2)
	var race: AudioStreamPlayer = level._music
	assert_lt(race.volume_linear, 0.5, "the first song fades in from silence")
	await wait_seconds(level.MUSIC_FADE + 0.2)
	assert_almost_eq(race.volume_linear, 1.0, 0.01, "then plays at full volume")
	level._play_music(level.BOSS_MUSIC)
	var boss: AudioStreamPlayer = level._music
	assert_ne(boss, race, "the new song gets the other player")
	await wait_seconds(level.MUSIC_FADE * 0.5)
	assert_true(race.playing and boss.playing, "both play mid-fade")
	assert_between(race.volume_linear, 0.05, 0.95, "the old one is fading out")
	assert_between(boss.volume_linear, 0.05, 0.95, "the new one is fading in")
	await wait_seconds(level.MUSIC_FADE * 0.5 + 0.3)
	assert_false(race.playing, "the old song stops once faded")
	assert_almost_eq(boss.volume_linear, 1.0, 0.01, "the new song is at full volume")
	root.queue_free()
