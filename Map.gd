extends Control

const Delaunator = preload("res://lib/Delaunator.gd")

export var margin := 10
export var seed_points := 256
export var starting_territory_height := 120.0
export var starting_cities := 1
export var starting_towns := 2
export var starting_free_cities := 6
export var starting_free_towns := 12

var points : Array
var cells : Array # of Cell
var delaunay

func _ready():
	randomize()
	
	# initial points
	points = [ 
		Vector2(margin, margin),
		Vector2(rect_size.x-margin, margin),
		Vector2(rect_size.x-margin, rect_size.y-margin),
		Vector2(margin, rect_size.y-margin)
	]
	for i in range(seed_points):
		points.append(Vector2(margin + (rect_size.x-2*margin) * randf(), margin + (rect_size.y-2*margin) * randf()))
	
	delaunay = Delaunator.new(points)
	
	var voronoi_cells = create_voronoi_cells_convex_hull(points, delaunay)
	
	# store infos about each cell
	for p in points.size():
		var cell = Cell.new()
		cell.index = p
		cell.seed_point = points[p]
		cell.set_polygon(voronoi_cells[p], PoolVector2Array([
			Vector2(margin, margin),
			Vector2(rect_size.x-margin, margin),
			Vector2(rect_size.x-margin, rect_size.y-margin),
			Vector2(margin, rect_size.y-margin)
		]))
		
		# assign a cell to a player if near the top or bottom sides
		if points[p].y < starting_territory_height:
			cell.set_player('red')
		elif points[p].y > rect_size.y - starting_territory_height:
			cell.set_player('blue')
		
		cells.append(cell)
	
	# place starting cities and towns in a random cell of the corresponding player
	for player in ['red', 'blue']:
		var player_cells = []
		for cell in cells:
			if cell.player == player:
				player_cells.append(cell)
				
		player_cells.shuffle()
		
		var last_index := 0
		for i in range(starting_cities):
			last_index = i
			player_cells[last_index].build_city()
		for i in range(starting_towns):
			player_cells[last_index+1+i].build_town()
	
	# free cities and towns
	var free_cells = []
	for cell in cells:
		if cell.is_free():
			free_cells.append(cell)
			
	free_cells.shuffle()
	
	var last_index := 0
	for i in range(starting_free_cities):
		last_index = i
		free_cells[last_index].build_city()
	for i in range(starting_free_towns):
		free_cells[last_index+1+i].build_town()
	
	update()
	
func _draw():
	draw_voronoi_edges(points, delaunay)
	draw_cells()
	
func draw_cells():
	for cell in cells:
		draw_colored_polygon(cell.polygon, cell.get_light_color())
		if cell.building:
			var size : Vector2
			if cell.building == 'town':
				size = Vector2(6,6)
			elif cell.building == 'city':
				size = Vector2(12,12)
			draw_rect(Rect2(cell.centroid-size/2, size), cell.get_color())
			draw_rect(Rect2(cell.centroid-size/2, size), Color(0,0,0,1), false)

func draw_voronoi_edges(points, d):
	for e in d.triangles.size():
		if (e < d.halfedges[e]):
			var p = triangle_center(points, d, triangle_of_edge(e));
			var q = triangle_center(points, d, triangle_of_edge(d.halfedges[e]));
			draw_line(
				Vector2(p[0], p[1]),
				Vector2(q[0], q[1]),
				Color(0,0,0,0.2),
				1.0,
				true)
				

func create_voronoi_cells_convex_hull(points, delaunay):
	var result := []
	var index = {}
	
	for e in delaunay.triangles.size():
		var endpoint = delaunay.triangles[next_half_edge(e)]
		if (!index.has(endpoint) or delaunay.halfedges[e] == -1):
			index[endpoint] = e
	
	for p in points.size():
		var triangles = []
		var vertices = []
		var incoming = index.get(p)
	
		if incoming == null:
			triangles.append(0)
		else:
			var edges = edges_around_point(delaunay, incoming)
			for e in edges:
				triangles.append(triangle_of_edge(e))
	
		for t in triangles:
			vertices.append(triangle_center(points, delaunay, t))
	
		if triangles.size() > 2:
			var voronoi_cell = PoolVector2Array()
			for vertice in vertices:
				voronoi_cell.append(Vector2(vertice[0], vertice[1]))
			result.append(voronoi_cell)
			
	return result

func edges_of_triangle(t):
	return [3 * t, 3 * t + 1, 3 * t + 2]


func triangle_of_edge(e):
	return floor(e / 3)


func next_half_edge(e):
	return e - 2 if e % 3 == 2 else e + 1


func prev_half_edge(e):
	return e + 2 if e % 3 == 0 else e - 1


func points_of_triangle(points, delaunay, t):
	var points_of_triangle = []
	for e in edges_of_triangle(t):
		points_of_triangle.append(points[delaunay.triangles[e]])
	return points_of_triangle


func edges_around_point(delaunay, start):
	var result = []
	var incoming = start
	while true:
		result.append(incoming);
		var outgoing = next_half_edge(incoming)
		incoming = delaunay.halfedges[outgoing];
		if not (incoming != -1 and incoming != start): break
	return result


func triangle_adjacent_to_triangle(delaunay, t):
	var adjacent_triangles = []
	for e in edges_of_triangle(t):
		var opposite = delaunay.halfedges[e]
		if opposite >= 0:
			adjacent_triangles.append(triangle_of_edge(opposite))

	return adjacent_triangles;


func triangle_center(p, d, t, c = "circumcenter"):
	var vertices = points_of_triangle(p, d, t)
	match c:
		"circumcenter":
			return circumcenter(vertices[0], vertices[1], vertices[2])
		"centroid":
			return centroid(vertices[0], vertices[1], vertices[2])
		"incenter":
			return incenter(vertices[0], vertices[1], vertices[2])


func circumcenter(a, b, c):
	var ad = a[0] * a[0] + a[1] * a[1]
	var bd = b[0] * b[0] + b[1] * b[1]
	var cd = c[0] * c[0] + c[1] * c[1]
	var D = 2 * (a[0] * (b[1] - c[1]) + b[0] * (c[1] - a[1]) + c[0] * (a[1] - b[1]))

	return [
		1 / D * (ad * (b[1] - c[1]) + bd * (c[1] - a[1]) + cd * (a[1] - b[1])),
		1 / D * (ad * (c[0] - b[0]) + bd * (a[0] - c[0]) + cd * (b[0] - a[0]))
	]


func centroid(a, b, c):
	var c_x = (a[0] + b[0] + c[0]) / 3
	var c_y = (a[1] + b[1] + c[1]) / 3

	return [c_x, c_y]


func incenter(a, b, c):
	var ab = sqrt(pow(a[0] - b[0], 2) + pow(b[1] - a[1], 2))
	var bc = sqrt(pow(b[0] - c[0], 2) + pow(c[1] - b[1], 2))
	var ac = sqrt(pow(a[0] - c[0], 2) + pow(c[1] - a[1], 2))
	var c_x = (ab * a[0] + bc * b[0] + ac * c[0]) / (ab + bc + ac)
	var c_y = (ab * a[1] + bc * b[1] + ac * c[1]) / (ab + bc + ac)

	return [c_x, c_y]
