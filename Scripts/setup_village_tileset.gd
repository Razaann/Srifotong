extends EditorScript
## Sekali-jalan: mengisi Data/village_tileset.tres dari Tiles.png.
## Cara pakai: buka file ini di Script editor -> klik tombol Run.
## Hasil: tile per sel tak-transparan + fisika kotak penuh untuk sel padat
## (kecuali baris dekorasi 4 & 9) + terrain set Rumput/Gua/Batu.

const TILESET_PATH := "res://Data/village_tileset.tres"
const TILES_PNG := "res://Asset/Pixel art Platformer/Pixel art Platformer/Tilesets/Tiles.png"
const COLS := 20
const ROWS := 14
const DECOR_ROWS := [4, 9]
# Peta sel isi dari scan alpha Tiles.png ("#" = ada gambar).
const OCC: Array[String] = [
	"######.######.######",
	"######.######.######",
	"######.######.######",
	"######.######.##....",
	"....##........##....",
	"############........",
	"############........",
	"############........",
	"####..##............",
	"......##............",
	"###############.....",
	"################....",
	"####..#########.....",
	"####..#########.....",
]
const SQUARE := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://Data")
	var tex := load(TILES_PNG) as Texture2D
	if tex == null:
		push_error("Tiles.png tidak ketemu: " + TILES_PNG)
		return
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_physics_layer(0)
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(16, 16)
	ts.add_source(src, 0)
	# Terrain set agar brush terrain langsung nyambung untuk area datar.
	ts.add_terrain_set()
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	var names: Array[String] = ["Rumput", "Gua", "Batu"]
	var cols: Array[Color] = [Color(0.35, 0.8, 0.3), Color(0.3, 0.35, 0.7), Color(0.6, 0.6, 0.65)]
	for i in names.size():
		var t := ts.add_terrain(0)
		ts.set_terrain_name(0, t, names[i])
		ts.set_terrain_color(0, t, cols[i])
	var made := 0
	var phys := 0
	for y in ROWS:
		for x in COLS:
			if OCC[y].substr(x, 1) != "#":
				continue
			var c := Vector2i(x, y)
			src.create_tile(c)
			made += 1
			var td := src.get_tile_data(c, 0)
			var fam := 0
			if y >= 10:
				fam = 2
			elif y >= 5:
				fam = 1
			td.terrain_set = 0
			for b in 16:
				td.set_terrain_peering_bit(b, fam)
			if not (y in DECOR_ROWS):
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, SQUARE)
				phys += 1
	var err := ResourceSaver.save(ts, TILESET_PATH)
	if err != OK:
		push_error("Gagal simpan tileset: %s" % err)
		return
	print("Tileset OK: %d tile, %d fisika -> %s" % [made, phys, TILESET_PATH])
