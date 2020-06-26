class_name Delaunator

const EPSILON = pow(2, -52)
const EDGE_STACK = []

var coords: Array # PoolRealArray.
var halfedges: Array # PoolIntArray.
var hull: Array # PoolIntArray.
var triangles: Array # PoolIntArray.
var triangles_len
var _cx
var _cy
var _dists: Array # PoolRealArray.
var _halfedges: Array # This array should be a PoolIntArray but we need to use the .slice() function on it.
var _hash_size
var _hull_hash: Array # PoolIntArray.
var _hull_next: Array # PoolIntArray.
var _hull_prev: Array # PoolIntArray.
var _hull_start
var _hull_tri: Array # PoolIntArray.
var _ids: Array # PoolIntArray.
var _triangles: Array  # This array should be a PoolIntArray but we need to use the .slice() function on it.


func _init(points):
	EDGE_STACK.resize(512)

	var n = points.size()

	if points.size() < 3:
		push_error("Delaunator needs at least 3 points.")
		return

	self.coords.resize(n * 2)

	for i in range(0, n):
		var p = points[i]
		self.coords[2 * i] = p[0]
		self.coords[2 * i + 1] = p[1]

	return self._constructor()


func _constructor():
	var n = self.coords.size() >> 1

	# Arrays that will store the triangulation graph.
	var max_triangles = max(2 * n - 5, 0)
	self._triangles.resize(max_triangles * 3)
	self._halfedges.resize(max_triangles * 3)

	# Temporary arrays for tracking the edges of the advancing convex hull.
	self._hash_size = ceil(sqrt(n))
	self._hull_prev.resize(n) # Edge to prev edge.
	self._hull_next.resize(n) # Edge to next edge.
	self._hull_tri.resize(n) # Edge to adjacent triangle.

	self._hull_hash.resize(self._hash_size)
	for i in self._hash_size:
		self._hull_hash[i] = -1 # angular edge hash

	# Temporary arrays for sorting points.
	self._ids.resize(n)
	self._dists.resize(n)

	return self.update()


func update():
	var n = self.coords.size() >> 1

	# Populate an array of point indices; calculate input data bbox.
	var min_x = INF
	var min_y = INF
	var max_x = -INF
	var max_y = -INF

	for i in range(0, n):
		var x = self.coords[2 * i]
		var y = self.coords[2 * i + 1]
		if x < min_x: min_x = x
		if y < min_y: min_y = y
		if x > max_x: max_x = x
		if y > max_y: max_y = y
		self._ids[i] = i

	var cx = (min_x + max_x) / 2
	var cy = (min_y + max_y) / 2

	var min_dist = INF
	var i0 = 0
	var i1 = 0
	var i2 = 0

	# Pick a seed point close to the center.
	for i in range(0, n):
		var d = self.dist(cx, cy, self.coords[2 * i], self.coords[2 * i + 1])
		if (d < min_dist):
			i0 = i
			min_dist = d
	var i0x = self.coords[2 * i0]
	var i0y = self.coords[2 * i0 + 1]

	min_dist = INF

	# Find the point closest to the seed.
	for i in range(0, n):
		if i == i0: continue
		var d = self.dist(i0x, i0y, self.coords[2 * i], self.coords[2 * i + 1])
		if (d < min_dist and d > 0):
			i1 = i
			min_dist = d
	var i1x = self.coords[2 * i1]
	var i1y = self.coords[2 * i1 + 1]

	var min_radius = INF

	# Find the third point which forms the smallest circumcircle with the first two.
	for i in range(0, n):
		if i == i0 or i == i1: continue
		var r = self.circumradius(i0x, i0y, i1x, i1y, self.coords[2 * i], self.coords[2 * i + 1])
		if r < min_radius:
			i2 = i
			min_radius = r
	var i2x = self.coords[2 * i2]
	var i2y = self.coords[2 * i2 + 1]

	if min_radius == INF:
		# Order collinear points by dx (or dy if all x are identical)
		# and return the list as a hull.
		for i in range(0, n):
			var _dist_temp
			if self.coords[2 * i] - self.coords[0]:
				_dist_temp = self.coords[2 * i] - self.coords[0]
			elif self.coords[2 * i + 1] - self.coords[1]:
				_dist_temp = self.coords[2 * i + 1] - self.coords[1]
			self._dists[i] = _dist_temp

		self.quicksort(self._ids, self._dists, 0, n - 1)
		var hull = []
		hull.resize(n)
		var j = 0
		var d0 = -INF

		for i in range(0, n):
			var id = self._ids[i]
			if self._dists[id] > d0:
				hull[j] = id
				j += 1
				d0 = self._dists[id]
		self.hull = hull.slice(0, j - 1)
		self.triangles = []
		self.halfedges = []

	# Swap the order of the seed points for counter-clockwise orientation.
	if self.orient(i0x, i0y, i1x, i1y, i2x, i2y):
		var i = i1
		var x = i1x
		var y = i1y
		i1 = i2
		i1x = i2x
		i1y = i2y
		i2 = i
		i2x = x
		i2y = y

	var center = self.circumcenter(i0x, i0y, i1x, i1y, i2x, i2y)
	self._cx = center[0]
	self._cy = center[1]

	for i in range(0, n):
		self._dists[i] = self.dist(self.coords[2 * i], self.coords[2 * i + 1], center[0], center[1])

	# Sort the points by distance from the seed triangle circumcenter.
	self.quicksort(self._ids, self._dists, 0, n - 1)

	# Set up the seed triangle as the starting hull.
	self._hull_start = i0
	var hull_size = 3

	self._hull_next[i0] = i1
	self._hull_prev[i2] = i1
	self._hull_next[i1] = i2
	self._hull_prev[i0] = i2
	self._hull_next[i2] = i0
	self._hull_prev[i1] = i0

	self._hull_tri[i0] = 0
	self._hull_tri[i1] = 1
	self._hull_tri[i2] = 2

#	for i in self._hull_hash.size():
#		self._hull_hash[i] = -1
#	print(self._hull_hash)
	self._hull_hash[self._hash_key(i0x, i0y)] = i0
	self._hull_hash[self._hash_key(i1x, i1y)] = i1
	self._hull_hash[self._hash_key(i2x, i2y)] = i2

	self.triangles_len = 0
	self._add_triangle(i0, i1, i2, -1, -1, -1)

	var xp = 0
	var yp = 0

	for k in range(0, self._ids.size()):
		var i = self._ids[k]
		var x = self.coords[2 * i]
		var y = self.coords[2 * i + 1]

		# Skip near-duplicate points.
		if k > 0 and abs(x - xp) <= EPSILON and abs(y - yp) <= EPSILON: continue

		xp = x
		yp = y

		# Skip seed triangle points.
		if i == i0 or i == i1 or i == i2: continue

		# Find a visible edge on the convex hull using edge hash.
		var start = 0
		var key = self._hash_key(x, y)

		for j in range(0, self._hash_size):
#				start = self._hull_hash[(key + j) % self._hash_size]
			start = self._hull_hash[fmod((key + j), self._hash_size)]
			if (start != -1 and start != self._hull_next[start]): break

		start = self._hull_prev[start]
		var e = start

		while true:
			var q = self._hull_next[e]
			if self.orient(x, y, self.coords[2 * e], self.coords[2 * e + 1], self.coords[2 * q], self.coords[2 * q + 1]): break
			e = q
			
			if (e == start):
				e = -1
				break

		if (e == -1): continue # Likely a near-duplicate point; Skip it.

		# Add the first triangle from the point.
		var t = self._add_triangle(e, i, self._hull_next[e], -1, -1, self._hull_tri[e])
		# Recursively flip triangles from the point until they satisfy the Delaunay condition.
		self._hull_tri[i] = self._legalize(t + 2)
		self._hull_tri[e] = t # Keep track of boundary triangles on the hull.
		hull_size += 1

		# Walk forward through the hull, adding more triangles and flipping recursively.
		n = self._hull_next[e]

		while true:
			var q = self._hull_next[n]
			if not self.orient(x, y, self.coords[2 * n], self.coords[2 * n + 1], self.coords[2 * q], self.coords[2 * q + 1]): break
			t = self._add_triangle(n, i, q, self._hull_tri[i], -1, self._hull_tri[n])
			self._hull_tri[i] = self._legalize(t + 2)
			self._hull_next[n] = n # Mark as removed.
			hull_size -= 1
			n = q

		# Walk backward from the other side, adding more triangles and flipping.
		if (e == start):
			while true:
				var q = self._hull_prev[e]
				if not orient(x, y, self.coords[2 * q], self.coords[2 * q + 1], self.coords[2 * e], self.coords[2 * e + 1]): break
				t = self._add_triangle(q, i, e, -1, self._hull_tri[e], self._hull_tri[q])
				self._legalize(t + 2)
				self._hull_tri[q] = t
				self._hull_next[e] = e # Mark as removed.
				hull_size -= 1
				e = q

		# Update the hull indices.
		self._hull_start = e
		self._hull_prev[i] = e
		self._hull_next[e] = i
		self._hull_prev[n] = i
		self._hull_next[i] = n

		# Save the two new edges in the hash table.
		self._hull_hash[self._hash_key(x, y)] = i
		self._hull_hash[self._hash_key(self.coords[2 * e], self.coords[2 * e + 1])] = e

	self.hull.resize(hull_size)
	var e = self._hull_start
	for i in range(0, hull_size):
		self.hull[i] = e
		e = self._hull_next[e]

	# Trim typed triangle mesh arrays.
	self.triangles = self._triangles.slice(0, self.triangles_len - 1)
	self.halfedges = self._halfedges.slice(0, self.triangles_len - 1)

#	return self.triangles


func _hash_key(x, y):
	return fmod(floor(pseudo_angle(x - self._cx, y - self._cy) * self._hash_size), self._hash_size)


func _legalize(a):
	var i = 0
	var ar = 0

	# Recursion eliminated with a fixed-size stack.
	while true:
		var b = self._halfedges[a]

#		If the pair of triangles doesn't satisfy the Delaunay condition
#		(p1 is inside the circumcircle of [p0, pl, pr]), flip them,
#		then do the same check/flip recursively for the new pair of triangles
#
#				   pl                    pl
#				  /||\                  /  \
#			   al/ || \bl            al/    \a
#				/  ||  \              /      \
#			   /  a||b  \    flip    /___ar___\
#			 p0\   ||   /p1   =>   p0\---bl---/p1
#				\  ||  /              \      /
#			   ar\ || /br             b\    /br
#				  \||/                  \  /
#				   pr                    pr

		var a0 = a - a % 3
		ar = a0 + (a + 2) % 3

		if b == -1: # Convex hull edge.
			if i == 0: break
			i -= 1
			a = EDGE_STACK[i]
			continue

		var b0 = b - b % 3
		var al = a0 + (a + 1) % 3
		var bl = b0 + (b + 2) % 3

		var p0 = self._triangles[ar]
		var pr = self._triangles[a]
		var pl = self._triangles[al]
		var p1 = self._triangles[bl]

		var illegal = self.in_circle(
			self.coords[2 * p0], self.coords[2 * p0 + 1],
			self.coords[2 * pr], self.coords[2 * pr + 1],
			self.coords[2 * pl], self.coords[2 * pl + 1],
			self.coords[2 * p1], self.coords[2 * p1 + 1]
		)

		if illegal:
			self._triangles[a] = p1
			self._triangles[b] = p0

			var hbl = self._halfedges[bl]

			# Edge swapped on the other side of the hull (rare); Fix the halfedge reference.
			if (hbl == -1):
				var e = self._hull_start
				while true:
					if self._hull_tri[e] == bl:
						self._hull_tri[e] = a
						break

					e = self._hull_prev[e]
					if e == self._hull_start: break

			self._link(a, hbl)
			self._link(b, self._halfedges[ar])
			self._link(ar, bl)

			var br = b0 + (b + 1) % 3

			# Don't worry about hitting the cap: it can only happen on extremely degenerate input.
			if i < EDGE_STACK.size():
				EDGE_STACK[i] = br
				i += 1
		else:
			if i == 0: break
			i -= 1
			a = EDGE_STACK[i]

	return ar


func _link(a, b):
	self._halfedges[a] = b
	if (b != -1):
		self._halfedges[b] = a


# Add a new triangle given vertex indices and adjacent half-edge ids.
func _add_triangle(i0, i1, i2, a, b, c):
	var t = self.triangles_len

	self._triangles[t] = i0
	self._triangles[t + 1] = i1
	self._triangles[t + 2] = i2

	self._link(t, a)
	self._link(t + 1, b)
	self._link(t + 2, c)

	self.triangles_len += 3

	return t


# Monotonically increases with real angle, but doesn't need expensive trigonometry.
func pseudo_angle(dx, dy):
	var p = dx / (abs(dx) + abs(dy))

	if (dy > 0):
		return (3 - p) / 4 # [0..1]
	else:
		return (1 + p) / 4 # [0..1]


func dist(ax, ay, bx, by):
	var dx = ax - bx
	var dy = ay - by
	return dx * dx + dy * dy


# Return 2d orientation sign if we're confident in it through J. Shewchuk's error bound check.
func orient_if_sure(px, py, rx, ry, qx, qy):
	var l = (ry - py) * (qx - px)
	var r = (rx - px) * (qy - py)

	if (abs(l - r) >= 0.00000000000000033306690738754716 * abs(l + r)):
		return l - r
	else:
		return 0


# A more robust orientation test that's stable in a given triangle (to fix robustness issues).
func orient(rx, ry, qx, qy, px, py):
	var _sign

	if self.orient_if_sure(px, py, rx, ry, qx, qy):
		_sign = self.orient_if_sure(px, py, rx, ry, qx, qy)
	elif self.orient_if_sure(rx, ry, qx, qy, px, py):
		_sign = self.orient_if_sure(rx, ry, qx, qy, px, py)
	elif self.orient_if_sure(qx, qy, px, py, rx, ry):
		_sign = self.orient_if_sure(qx, qy, px, py, rx, ry)

	return false if _sign == null else _sign < 0


func in_circle(ax, ay, bx, by, cx, cy, px, py):
	var dx = ax - px
	var dy = ay - py
	var ex = bx - px
	var ey = by - py
	var fx = cx - px
	var fy = cy - py

	var ap = dx * dx + dy * dy
	var bp = ex * ex + ey * ey
	var cp = fx * fx + fy * fy

	return dx * (ey * cp - bp * fy) -\
		dy * (ex * cp - bp * fx) +\
		ap * (ex * fy - ey * fx) < 0


func circumradius(ax, ay, bx, by, cx, cy):
	var dx = bx - ax
	var dy = by - ay
	var ex = cx - ax
	var ey = cy - ay

	var bl = dx * dx + dy * dy
	var cl = ex * ex + ey * ey

	# When you divide by 0 in Godot you get an error.
	# It should return INF (positive or negative).
	var d
	if (dx * ey - dy * ex) == 0:
		d = INF
	elif (dx * ey - dy * ex) == 0:
		d = -INF
	else:
		d = 0.5 / (dx * ey - dy * ex)

	var x = (ey * bl - dy * cl) * d
	var y = (dx * cl - ex * bl) * d

	return x * x + y * y


func circumcenter(ax, ay, bx, by, cx, cy):
	var dx = bx - ax
	var dy = by - ay
	var ex = cx - ax
	var ey = cy - ay

	var bl = dx * dx + dy * dy
	var cl = ex * ex + ey * ey

	# When you divide by 0 in Godot you get an error.
	# It should return INF (positive or negative).
	var d
	if (dx * ey - dy * ex) == 0:
		d = INF
	elif (dx * ey - dy * ex) == 0:
		d = -INF
	else:
		d = 0.5 / (dx * ey - dy * ex)

	var x = ax + (ey * bl - dy * cl) * d
	var y = ay + (dx * cl - ex * bl) * d

	return [x, y]


func quicksort(ids, dists, left, right):
	if right - left <= 20:
		for i in range(left + 1, right + 1):
			var temp = ids[i]
			var temp_dist = dists[temp]
			var j = i - 1
			while j >= left and dists[ids[j]] > temp_dist:
				ids[j + 1] = ids[j]
				j -= 1
			ids[j + 1] = temp
	else:
		var median = (left + right) >> 1
		var i = left + 1
		var j = right
		self.swap(ids, median, i)

		if (dists[ids[left]] > dists[ids[right]]):
			self.swap(ids, left, right)

		if (dists[ids[i]] > dists[ids[right]]):
			self.swap(ids, i, right)

		if (dists[ids[left]] > dists[ids[i]]):
			self.swap(ids, left, i)

		var temp = ids[i]
		var temp_dist = dists[temp]

		while true:
			while true:
				i += 1
				if dists[ids[i]] >= temp_dist: break

			while true:
				j -= 1
				if dists[ids[j]] <= temp_dist: break

			if j < i: break
			self.swap(ids, i, j)

		ids[left + 1] = ids[j]
		ids[j] = temp

		if right - i + 1 >= j - left:
			self.quicksort(ids, dists, i, right)
			self.quicksort(ids, dists, left, j - 1)
		else:
			self.quicksort(ids, dists, left, j - 1)
			self.quicksort(ids, dists, i, right)


func swap(arr, i, j):
	var tmp = arr[i]
	arr[i] = arr[j]
	arr[j] = tmp
