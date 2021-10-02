extends Node

class_name Cell

var index : int
var player := '' setget set_player
var building := ''
var polygon : PoolVector2Array
var seed_point : Vector2
var centroid : Vector2
var area : float

func set_player(v : String) -> void:
	player = v
	
func is_free() -> bool:
	return player == ''
	
func get_color() -> Color:
	if player == 'red':
		return Color(1.0, 0.3, 0.3, 1)
	elif player == 'blue':
		return Color(0.1, 0.3, 1.0, 1)
	else:
		return Color(0.8, 0.8, 0.3, 1)
		
func get_light_color() -> Color:
	var color = self.get_color()
	color.a = 0.5
	return color

func build_city() -> void:
	building = 'city'
	
func build_town() -> void:
	building = 'town'
	
func set_polygon(p : PoolVector2Array, region : PoolVector2Array) -> void:
	polygon = Geometry.intersect_polygons_2d(p, region)[0]
	
	var c := Vector2()
	for point in polygon:
		c += point
	c /= polygon.size()
	centroid = c
	
	compute_area()

func compute_area():
	var pp = Array(polygon) + [polygon[0]]
	var rsum := 0.0
	var lsum := 0.0
	for i in pp.size()-1:
		lsum += pp[i].x*pp[i+1].y
		rsum += pp[i].y*pp[i+1].x
	area = (lsum-rsum)/2
