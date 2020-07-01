# Delaunator-GDScript guide

**Disclaimer**: This guide is a copy of the [original "Delaunator guide"](https://mapbox.github.io/delaunator/). The only changes are the pictures, created with Godot 3.2, and the code, transcoded from JavaScript to GDScript.

**Note**: The sample code on this page is written for readability, not performance.

Delaunator is a fast library for Delaunay triangulation. It takes as input a set of points:

![Delaunator input](/examples/01-points.png)
*Delaunator input*

and produces as output a triangulation:

![Delaunator output](/examples/02-triangles-vertices.png)
*Delaunator output*

The triangulation is represented as compact arrays of integers. It's less convenient than other representations but is the reason the library is fast.

## Delaunay triangles

After constructing a `var delaunay = Delaunator.new(points)` object, it will have a `triangles` array and a `halfedges` array, both indexed by half-edge id.

What's a half-edge?

A triangle edge may be shared with another triangle. Instead of thinking about each edge A↔︎B, we will use two *half-edges*   A→B and B→A. Having two half-edges is the key to everything this library provides.

Half-edges `e` are the indices into both of Delaunator's outputs:

* `delaunay.triangles[e]` returns the point id where the half-edge starts.
* `delaunay.halfedges[e]` returns the opposite half-edge in the adjacent triangle, or -1 if there is no adjacent triangle.

Triangle ids and half-edge ids are related.

* The half-edges of triangle `t` are `3 * t`, `3 * t + 1`, and `3 * t + 2`.
* The triangle of half-edge id `e` is `floor(e / 3)`.

Let's use some helper functions for these:

```gdscript
func edges_of_triangle(t):
  return [3 * t, 3 * t + 1, 3 * t + 2]

func triangle_of_edge(e):
  return floor(e / 3)
```

It will also be useful to have some helper functions to go from one half-edge to the next and previous half-edges in the same triangle:

```gdscript
func next_half_edge(e):
  return e - 2 if e % 3 == 2 else e + 1

func prev_half_edge(e):
  return e + 2 if e % 3 == 0 else e -1
```

### Delaunay edges

We can draw all the triangle edges without constructing the triangles themselves. Each edge is two half-edges. A half-edge `e` starts at `points[delaunay.triangles[e]]`. Its opposite `delaunay.halfedges[e]` starts at the other end, so that tells us the two endpoints of the edge. However, the half-edges along the convex hull won't have an opposite, so `delaunay.halfedges[e]` will be `-1`, and `points[delaunay.halfedges[e]]` will fail. To reliably find the other end of the edge, we need to instead use `points[next_half_edge(e)]`. We can loop through the half-edges and pick half of them to draw:

```gdscript
func draw_triangles_edges(points, delaunay):
  for e in delaunay.triangles.size():
    if e > delaunay.halfedges[e]:
      var p = points[delaunay.triangles[e]]
      var q = points[delaunay.triangles[next_half_edge(e)]]
      draw_line(p, q, Color.black)
```

![Drawing triangle edges](/examples/03-triangles-edges.png)
*Drawing triangle edges*

### Constructing triangles

A triangle is formed from three consecutive half-edges, `3 * t`, `3 * t + 1` and `3 * t + 2`. Each half-edge `e` starts at `points[e]`, so we can connect those three points into a triangle.

```gdscript
func edges_of_triangle(t):
  return [3 * t, 3 * t + 1, 3 * t + 2]

func points_of_triangle(points, delaunay, t):
  var points_of_triangle = []
  for e in edges_of_triangle(t):
    points_of_triangle.append(points[delaunay.triangles[e]])
  return points_of_triangle

func draw_triangles(points, delaunay):
  for t in delaunay.triangles.size() / 3:
    var color = Color(randf(), randf(), randf(), 1)
    draw_polygon(points_of_triangle(points, delaunay, t), PoolColorArray([color]))
```

![Drawing triangles](/examples/04-triangles-polygons.png)
*Drawing triangles*

### Adjacent triangles

We can also use the half-edges of a triangle to find the adjacent triangles. Each half-edge's opposite will be in an adjacent triangle, and the `triangle_of_edge(t)` helper function will tell us which triangle a half-edge is in:

```gdscript
func edges_of_triangle(t):
  return [3 * t, 3 * t + 1, 3 * t + 2]

func triangle_of_edge(e):
  return floor(e / 3)

func triangles_adjacent_to_triangle(delaunay, t):
  var adjacent_triangles = []
  for e in edges_of_triangle(t):
    var opposite = delaunay.halfedges[e]
    if opposite >= 0:
      adjacent_triangles.append(triangle_of_edge(opposite))
  return adjacent_triangles;
```

## Voronoi cells

A [Voronoi diagram](https://en.wikipedia.org/wiki/Voronoi_diagram) is built by connecting the Delaunay triangle circumcenters together using the dual of the Delaunay graph.

* Calculate the circumcenters of each triangle.
* Construct the Voronoi edges from two circumcenters.
* Connect the edges into Voronoi cells.

### Triangle circumcenters

The formula for circumcenters can be found [on Wikipedia](https://en.wikipedia.org/wiki/Circumscribed_circle#Circumcenter_coordinates). The circumcenter is often but not always inside the triangle.

```gdscript
func circumcenter(a, b, c):
  var ad = a[0] _ a[0] + a[1] _ a[1]
  var bd = b[0] _ b[0] + b[1] _ b[1]
  var cd = c[0] _ c[0] + c[1] _ c[1]
  var D = 2 _ (a[0] _ (b[1] - c[1]) + b[0] _ (c[1] - a[1]) + c[0] _ (a[1] - b[1]))

  return [
    1 / D * (ad * (b[1] - c[1]) + bd * (c[1] - a[1]) + cd * (a[1] - b[1])),
    1 / D * (ad * (c[0] - b[0]) + bd * (a[0] - c[0]) + cd * (b[0] - a[0]))
  ]
```

![Circumcenters of the triangles](/examples/05-circumcenters.png)
*Circumcenters of the triangles*

You can also use other triangle centers to create variations of the Voronoi diagram. The [centroid](https://en.wikipedia.org/wiki/Centroid) or the [incenter](https://en.wikipedia.org/wiki/Incenter), for example:

```gdscript
func centroid(a, b, c):
  var c_x = (a[0] + b[0] + c[0]) / 3
  var c_y = (a[1] + b[1] + c[1]) / 3

  return [c_x, c_y]

func incenter(a, b, c):
  var ab = sqrt(pow(a[0] - b[0], 2) + pow(b[1] - a[1], 2))
  var bc = sqrt(pow(b[0] - c[0], 2) + pow(c[1] - b[1], 2))
  var ac = sqrt(pow(a[0] - c[0], 2) + pow(c[1] - a[1], 2))
  var c_x = (ab _ a[0] + bc _ b[0] + ac _ c[0]) / (ab + bc + ac)
  var c_y = (ab _ a[1] + bc _ b[1] + ac _ c[1]) / (ab + bc + ac)

  return [c_x, c_y]
```

This convenience function will go from triangle id to circumcenter (or centroid or incenter):

```gdscript
func triangle_center(points, delaunay, t, center = "circumcenter"):
  var vertices = points_of_triangle(points, delaunay, t)
  match center:
    "circumcenter":
      return circumcenter(vertices[0], vertices[1], vertices[2])
    "centroid":
      return centroid(vertices[0], vertices[1], vertices[2])
    "incenter":
      return incenter(vertices[0], vertices[1], vertices[2])
```

### Voronoi edges

With the circumcenters we can draw the Voronoi edges without constructing the polygons. Each Delaunay triangle half-edge corresponds to one Voronoi polygon half-edge. The Delaunay half-edge connects two points, `delaunay.triangles[e]` and `delaunay.triangles[next_half_edge(e)]`. The Voronoi half-edge connects the circumcenters of two triangles, `triangle_of_edge(e)` and `triangle_of_edge(delaunay.halfedges[e])`. We can iterate over the half-edges and construct the line segments:

```gdscript
func draw_voronoi_edges(points, delaunay):
  for e in delaunay.triangles.size():
    if (e < delaunay.halfedges[e]):
      var p = triangle_center(points, delaunay, triangle_of_edge(e));
      var q = triangle_center(points, delaunay, triangle_of_edge(delaunay.halfedges[e]));
      draw_line(Vector2(p[0], p[1]), Vector2(q[0], q[1]), Color.black)
```

![Drawing Voronoi edges](/examples/06-voronoi-edges.png)
*Drawing Voronoi edges*

### Constructing Voronoi cells

To build the polygons, we need to find the triangles touching a point. The half-edge structures can give us what we need. Let's assume we have a starting half-edge that leads into the point. We can alternate two steps to loop around:

* Use `next_half_edge(e)` to go to the next outgoing half-edge in the current triangle.
* Use `delaunay.halfedges[e]` to go to the incoming half-edge in the adjacent triangle.

```gdscript
func edges_around_point(delaunay, start):
  var result = []
  var incoming = start
  while true:
    result.append(incoming);
    var outgoing = next_half_edge(incoming)
    incoming = delaunay.halfedges[outgoing];
    if not (incoming != -1 and incoming != start): break
  return result
```

Note that this requires any incoming half-edge that leads to the point. If you need a quick way to find such a half-edge given a point, it can be useful to build an index of these half-edges. For an example, see the modified version of `draw_voronoi_cells` at the [end of the page](#convex-hull).


### Drawing Voronoi cells

To draw the Voronoi cells, we can turn a point's incoming half-edges into triangles, and then find their circumcenters. We can iterate over half-edges, but since many half-edges lead to a point, we need to keep track of which points have already been visited.

```gdscript
func draw_voronoi_cells(points, delaunay):
  var seen = []
  for e in delaunay.triangles.size():
    var triangles = []
    var vertices = []
    var p = delaunay.triangles[next_half_edge(e)]
    if not seen.has(p):
      seen.append(p)
      var edges = edges_around_point(delaunay, e)
      for edge in edges:
        triangles.append(triangle_of_edge(edge))
      for t in triangles:
        vertices.append(triangle_center(points, delaunay, t))

  if triangles.size() > 2:
    var color = Color(randf(), randf(), randf(), 1)
    var voronoi_cell = PoolVector2Array()
    for vertice in vertices:
      voronoi_cell.append(Vector2(vertice[0], vertice[1]))
    draw_polygon(voronoi_cell, PoolColorArray([color]))
```

![Drawing Voronoi cells](/examples/07-voronoi-polygons.png)
*Drawing Voronoi cells*

### Convex hull

There's a problem with the `edges_around_point` loop above. Points on the convex hull won't be completely surrounded by triangles, and the loop will stop partway through, when it hits -1. There are three approaches to this:

1. Ignore it. Make sure never to circulate around points on the convex hull.
2. Change the code.
    * Check for -1 in all code that looks at `halfedges`.
    * Change the `edges_around_point` loop to start at the "leftmost" half-edge so that by the time it reaches -1, it has gone through all the triangles.
3. Change the data. Remove the convex hull by wrapping the mesh around the "back". There will no longer be any -1 halfedges.
    * Add "ghost" half-edges that pair up with the ones that point to -1.
    * Add a single ghost point at "infinity" that represents the "back side" of the triangulation.
    * Add ghost triangles to connect these ghost half-edges to the ghost point.

Here's an example of how to find the "leftmost" half-edge:

```gdscript
func draw_voronoi_cells_convex_hull(points, delaunay):
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
        triangles.append(triangle_of_edge(e))

    for t in triangles:
      vertices.append(triangle_center(points, delaunay, t))

    if triangles.size() > 2:
      var color = Color(randf(), randf(), randf(), 1)
      var voronoi_cell = PoolVector2Array()
      for vertice in vertices:
        voronoi_cell.append(Vector2(vertice[0], vertice[1]))
      draw_polygon(voronoi_cell, PoolColorArray([color]))
```