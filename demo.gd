extends Node2D

const Delaunator = preload("res://Delaunator.gd")

export var random_points = true
export var use_mouse = false
export var draw = false
export var create_polygons = false
export var debug_mode = false

onready var input_points = $input_points

var default_seed_points = 10
var initial_points
var points
var delaunay
var coordinates = []
var size

var delay_timer = 0
var delay_timer_limit = 0.5

var moving = false

func _ready():
	input_points.text = str(default_seed_points)

	size = get_viewport().size

	initial_points = PoolVector2Array([ 
		Vector2(0, 0),
		Vector2(size.x, 0),
		Vector2(size.x, size.y),
		Vector2(0, size.y)
	])
	
#	initial_points = PoolVector2Array([ 
#		Vector2(168, 180),
#		Vector2(168, 178),
#		Vector2(168, 179),
#		Vector2(168, 181),
#		Vector2(168, 183)
#	])

	if random_points:
		points = get_random_points(int(input_points.text))
	else:
		points = initial_points

	if debug_mode: print("points:", points)

	delaunay = Delaunator.new(points)

	if debug_mode: print("delaunay.triangles: ", delaunay.triangles)
	if debug_mode: print("delaunay.halfedges: ", delaunay.halfedges)
	if debug_mode: print("delaunay.hull: ", delaunay.hull)
	if debug_mode: print("delaunay.coords: ", delaunay.coords)

	for i in range(0, delaunay.triangles.size(), 3):
		coordinates.append([
			points[delaunay.triangles[i]],
			points[delaunay.triangles[i + 1]],
			points[delaunay.triangles[i + 2]]
		])
	if debug_mode: print("coordinates: ", coordinates)

#	call_deferred("for_each_voronoi_cell", points, delaunay)
#	call_deferred("for_each_voronoi_cell_convex_hull", points, delaunay)


func _input(event):
	if use_mouse and event is InputEventMouseMotion:
		moving = true


func _process(_delta):
	if moving:
		if get_global_mouse_position().x >= 0 and get_global_mouse_position().y >= 0:
			delay_timer += 0.1
			if delay_timer > delay_timer_limit:
				delay_timer -= delay_timer_limit
				points.append(get_global_mouse_position())
				delaunay = Delaunator.new(points)
				update()
			moving = false


func _draw():
	# Draw triangles.
#	draw_each_triangle(points, delaunay)

	draw_each_voronoi_cell(points, delaunay)

#	draw_each_voronoi_cell_convex_hull(points, delaunay)

#	draw_each_voronoi_edge(points, delaunay)

#	draw_triangles_edges(points, delaunay)

	# Draw points (triangle vertices).
#	for point in points:
#		draw_circle(point, 5, Color("#bf4040"))

#	# Draw triangle vertices.
#	for coord in coordinates:
#		for point in coord:
#			draw_circle(point, 5, Color("#bf4040"))

#	# Draw triangle centers.
#	for t in delaunay.triangles.size() / 3:
#		draw_circle(
#			Vector2(
#				triangle_center(points, delaunay, t)[0],
#				triangle_center(points, delaunay, t)[1]
#			), 5, Color.white)
#		draw_circle(
#			Vector2(
#				triangle_center(points, delaunay, t)[0],
#				triangle_center(points, delaunay, t)[1]
#			), 4, Color("#4040bf"))
	pass


func get_random_points(seed_points = default_seed_points):
	var new_points = []
	new_points.resize(initial_points.size() + seed_points)

	for i in range(new_points.size()):
		if i >= initial_points.size():
			var new_point = Vector2(randi() % int(size.x), randi() % int(size.y))
			# Uncomment these lines if you need points outside the boundaries.
#			new_point *= -1 if randf() > 0.5 else 1
#			new_point *= 1.15 if randf() > 0.5 else 1
			new_point.x = int(new_point.x)
			new_point.y = int(new_point.y)
			new_points[i] = new_point
		else:
			new_points[i] = initial_points[i]

	return new_points


func triangle_id_to_edge_id(t):
	return [3 * t, 3 * t + 1, 3 * t + 2]


func next_half_edge(e):
	return e - 2 if e % 3 == 2 else e + 1


func prev_half_edge(e):
	return e + 2 if e % 3 == 0 else e - 1


func points_of_triangle(points, delaunay, t):
	var points_of_triangle = []
	for e in triangle_id_to_edge_id(t):
		points_of_triangle.append(points[delaunay.triangles[e]])
	return points_of_triangle


func draw_each_triangle(points, delaunay):
	for t in delaunay.triangles.size() / 3:
		var color = Color(randf(), randf(), randf(), 1)
#		draw_polyline(points_of_triangle(points, delaunay, t), Color.black)
		draw_polygon(points_of_triangle(points, delaunay, t), PoolColorArray([color]))


func draw_triangles_edges(points, delaunay):
	for e in delaunay.triangles.size():
		if e > delaunay.halfedges[e]:
			var p = points[delaunay.triangles[e]]
			var q = points[delaunay.triangles[next_half_edge(e)]]
			draw_line(p, q, Color.black)


func draw_each_voronoi_edge(points, d):
	for e in d.triangles.size():
		if (e < d.halfedges[e]):
			var p = triangle_center(points, d, edge_id_to_triangle_id(e));
			var q = triangle_center(points, d, edge_id_to_triangle_id(d.halfedges[e]));
			draw_line(
				Vector2(p[0], p[1]),
				Vector2(q[0], q[1]),
				Color.white)


func cell_edge_ids(delaunay, start):
	var result = []
	var incoming = start
	while true:
		result.append(incoming);
		var outgoing = next_half_edge(incoming)
		incoming = delaunay.halfedges[outgoing];
		if not (incoming != -1 and incoming != start): break
	return result


func draw_each_voronoi_cell(points, delaunay):
	var seen = []
	for e in delaunay.triangles.size():
		var triangles = []
		var vertices = []
		var p = delaunay.triangles[next_half_edge(e)]
		if not seen.has(p):
			seen.append(p)
			var edges = cell_edge_ids(delaunay, e)
			for edge in edges:
				triangles.append(edge_id_to_triangle_id(edge))
			for t in triangles:
				vertices.append(triangle_center(points, delaunay, t))

		if triangles.size() > 2:
			var color = Color(randf(), randf(), randf(), 1)
			var voronoi_cell = PoolVector2Array()
			for vertice in vertices:
				voronoi_cell.append(Vector2(vertice[0], vertice[1]))
			if create_polygons:
				var new_polygon = Polygon2D.new()
				new_polygon.polygon = voronoi_cell
				new_polygon.color = color
				get_parent().add_child(new_polygon, true)
			else:
				draw_polygon(voronoi_cell, PoolColorArray([color]))


func draw_each_voronoi_cell_convex_hull(points, delaunay):
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
			var edges = cell_edge_ids(delaunay, incoming)
			for e in edges:
				triangles.append(edge_id_to_triangle_id(e))

		for t in triangles:
			vertices.append(triangle_center(points, delaunay, t))

		if triangles.size() > 2:
			var color = Color(randf(), randf(), randf(), 1)
			var voronoi_cell = PoolVector2Array()
			for vertice in vertices:
				voronoi_cell.append(Vector2(vertice[0], vertice[1]))
			if create_polygons:
				var new_polygon = Polygon2D.new()
				new_polygon.polygon = voronoi_cell
				new_polygon.color = color
				get_parent().add_child(new_polygon, true)
			else:
				draw_polygon(voronoi_cell, PoolColorArray([color]))


func edge_id_to_triangle_id(e):
	return floor(e / 3)


# Returns an array of triangle ids.
func triangles_adjacent_to_triangle(delaunay, t):
	var adjacent_triangles = []
	for e in triangle_id_to_edge_id(t):
		var opposite = delaunay.halfedges[e]
		if opposite >= 0:
			adjacent_triangles.append(edge_id_to_triangle_id(opposite))

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


func _on_get_random_points_pressed():
	points = initial_points
	randomize()
	points = get_random_points(int(input_points.text))
	var start = OS.get_ticks_msec()
	delaunay = Delaunator.new(points)
#	draw = true
	if draw: update()
	var elapsed = OS.get_ticks_msec() - start
	print(ProjectSettings.get_setting("application/config/name"), " execution time: ", elapsed,  "ms")
