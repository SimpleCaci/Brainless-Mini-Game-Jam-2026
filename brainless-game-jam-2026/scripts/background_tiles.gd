extends TileMapLayer

@export var width := 400
@export var height := 400

# Set these to your actual TileSet atlas coords for the two tiles.
# If you used two separate tiles in an atlas, these are (x,y) positions in the atlas grid.
@export var tile_a := Vector2i(0, 0)  # dark
@export var tile_b := Vector2i(0, 1)  # light

@export var source_id := 0            # usually 0 unless you added multiple sources

func _ready():
	draw_background()
	

func draw_background():
	clear()
	for y in range(height):
		for x in range(width):
			var atlas := tile_a if ((x + y ) % 2 == 0) else tile_b
			set_cell(Vector2i(x, y), source_id, atlas, 0 )
