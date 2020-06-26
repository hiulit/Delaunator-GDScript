extends Node2D

const Delaunator = preload("res://Delaunator.gd")

export var random_points = false
export var debug_mode = false

var points
var delaunay
var coordinates = []
var size

var draw = false

var explosion_delay_timer = 0
var explosion_delay_timer_limit = 0

var moving = false

func _ready():
#	randomize()
	size = get_viewport().size
	points = PoolVector2Array([ 
		Vector2(0, 0),
		Vector2(get_viewport().size.x, 0),
		Vector2(get_viewport().size.x, get_viewport().size.y),
		Vector2(0, get_viewport().size.y)
	])

	if random_points:
		points = get_random_points(10)

#	if debug_mode: print("points:", points)

	delaunay = Delaunator.new(points)

#	if debug_mode: print("delaunay.triangles: ", delaunay.triangles)
#	if debug_mode: print("delaunay.halfedges: ", delaunay.halfedges)
#	if debug_mode: print("delaunay.hull: ", delaunay.hull)
#	if debug_mode: print("delaunay.coords: ", delaunay.coords)

	var triangles = delaunay.triangles
	for i in range(0, triangles.size(), 3):
		coordinates.append([
			points[triangles[i]],
			points[triangles[i + 1]],
			points[triangles[i + 2]]
		])
#	if debug_mode: print("coordinates: ", coordinates)
#
#
#	points.append(Vector2(432, 72))
#	if debug_mode: print("points:", points)
#
##	var temp_points = []
##	temp_points.resize(points.size() * 2)
##	for i in points.size():
##		temp_points[i] = points[i].x
##		temp_points[i] = points[i].y
#
#
#	var temp_points = []
#	temp_points.resize(points.size() * 2)
#
#	for i in range(0, points.size()):
#		var p = points[i]
#		temp_points[2 * i] = (p[0])
#		temp_points[2 * i + 1] = (p[1])


#	print_debug("temp_points: ", temp_points)
#	delaunay.update(temp_points);

#	call_deferred("for_each_voronoi_cell", points, delaunay)
#	call_deferred("for_each_voronoi_cell2", points, delaunay)


func _input(event):
	if event is InputEventMouseMotion:
		moving = true
	# Mouse in viewport coordinates
#	if event is InputEventMouseButton:
#		print("Mouse Click/Unclick at: ", event.position)
#		points.append(event.position)
#		delaunay = Delaunator.new(points)
#		update()
#	if event is InputEventMouseMotion:
#		print("Mouse Motion at: ", event.position)
##		print("Mouse Click/Unclick at: ", event.position)
#		points.append(event.position)
##		delaunay = Delaunator.new(points)
#		explosion_delay_timer_limit = 0.5
#		explosion_delay_timer += 0.1
#		if explosion_delay_timer > explosion_delay_timer_limit:
#			explosion_delay_timer -= explosion_delay_timer_limit
#			update()

	pass


func _process(_delta):
	if moving:
		if get_global_mouse_position().x >= 0 and get_global_mouse_position().y >= 0:
			explosion_delay_timer_limit = 0.5
			explosion_delay_timer += 0.1
			if explosion_delay_timer > explosion_delay_timer_limit:
				explosion_delay_timer -= explosion_delay_timer_limit
#				print(get_global_mouse_position())
				points.append(get_global_mouse_position())
				delaunay = Delaunator.new(points)
#				print(points.size())
				update()
			moving = false
	pass


func _draw():
#	print(points.size())
#	var start = OS.get_ticks_msec()
#	delaunay = Delaunator.new(points)
#	var elapsed = OS.get_ticks_msec() - start
#	print(elapsed)

	# Draw triangles.
#	for_each_triangle(points, delaunay)

#	if draw: for_each_voronoi_cell(points, delaunay)
#	for_each_voronoi_cell(points, delaunay)

#	if draw: for_each_voronoi_cell2(points, delaunay)
#	for_each_voronoi_cell2(points, delaunay)

	# Draw voronoi cells.
	for_each_voronoi_edge(points, delaunay)

	# Draw triangle edges.
	for e in delaunay.triangles.size():
		if e > delaunay.halfedges[e]:
			var p = points[delaunay.triangles[e]]
			var q = points[delaunay.triangles[next_half_edge(e)]]
			draw_line(p, q, Color.black, 1)

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
#			), 4, Color.blue)

	pass


func get_random_points(seed_points = 100):
#	randomize()
	var new_points = []
	new_points.resize(points.size() + seed_points)

	for i in range(new_points.size()):
		if i >= points.size():
			var new_point = Vector2(randi() % int(size.x), randi() % int(size.y))
#			new_point *= -1 if randf() > 0.5 else 1
#			new_point *= 1.15 if randf() > 0.5 else 1
			new_point.x = int(new_point.x)
			new_point.y = int(new_point.y)
			new_points[i] = new_point
		else:
			new_points[i] = points[i]

	return new_points


func triangle_id_to_edge_id(t):
	return [3 * t, 3 * t + 1, 3 * t + 2]


func next_half_edge(e):
	return e - 2 if e % 3 == 2 else e + 1


func prev_half_edge(e):
	return e + 2 if e % 3 == 0 else e -1


func points_of_triangle(points, delaunay, triangle_id):
	var new_array = []
	for e in triangle_id_to_edge_id(triangle_id):
		new_array.append(points[delaunay.triangles[e]])
	return new_array


func for_each_triangle(points, delaunay):
	for i in delaunay.triangles.size() / 3:
#		randomize()
		var r = randf()
		var g = randf()
		var b = randf()
		var color = Color(r, g, b, 1)
		var triangle_id = i
#		var t = triangle_id
#		print(points_of_triangle(points, delaunay, triangle_id))
		draw_polygon(points_of_triangle(points, delaunay, triangle_id), PoolColorArray([color]))
#		print(trianglesAdjacentToTriangle(delaunay, triangle_id))
#		draw_circle(
#			Vector2(
#				triangle_center(points, delaunay, t)[0],
#				triangle_center(points, delaunay, t)[1]),
#			2, Color.blue)


func for_each_voronoi_edge(points, delaunay):
	for e in delaunay.triangles.size():
		if (e < delaunay.halfedges[e]):
			var p = triangle_center(points, delaunay, edge_id_to_triangle_id(e));
			var q = triangle_center(points, delaunay, edge_id_to_triangle_id(delaunay.halfedges[e]));
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


func for_each_voronoi_cell(points, delaunay):
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
#			randomize()
			var color = Color(randf(), randf(), randf(), 1)
			var voronoi_cell = PoolVector2Array()
			for vertice in vertices:
				voronoi_cell.append(Vector2(vertice[0], vertice[1]))
			var new_polygon = Polygon2D.new()
			new_polygon.polygon = voronoi_cell
			new_polygon.color = color
			get_parent().add_child(new_polygon, true)
#			draw_polygon(voronoi_cell, PoolColorArray([color]))


func for_each_voronoi_cell2(points, delaunay):
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
#			randomize()
			var color = Color(randf(), randf(), randf(), 1)
			var voronoi_cell = PoolVector2Array()
			for vertice in vertices:
				voronoi_cell.append(Vector2(vertice[0], vertice[1]))
#			print(voronoi_cell)
			var new_polygon = Polygon2D.new()
			new_polygon.polygon = voronoi_cell
			new_polygon.color = color
#			get_parent().add_child(new_polygon, true)
			draw_polygon(voronoi_cell, PoolColorArray([color]))


func edge_id_to_triangle_id(e):
	return floor(e / 3)


# Returns an array of triangle ids.
func trianglesAdjacentToTriangle(delaunay, t):
	var adjacentTriangles = []
	for e in triangle_id_to_edge_id(t):
		var opposite = delaunay.halfedges[e]
		if (opposite >= 0):
			adjacentTriangles.append(edge_id_to_triangle_id(opposite))

	return adjacentTriangles;


func triangle_center(points, delaunay, t, center = "circumcenter"):
	var vertices = points_of_triangle(points, delaunay, t)
	match center:
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


func _on_start_delaunator_pressed():
#	points.resize(0)
#	points = get_random_points(100)
	var start = OS.get_ticks_msec()
	var delaunay = Delaunator.new(points)
#	print(delaunay.triangles)
#	draw = true
#	if draw: update()
	var elapsed = OS.get_ticks_msec() - start
	print(elapsed)
