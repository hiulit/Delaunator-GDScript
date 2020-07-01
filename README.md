# Delaunator GDScript ![Godot v3.2](https://img.shields.io/badge/Godot-v3.2-%23478cbf?logo=godot-engine&logoColor=white)

A GDScript port of Delaunator: A fast library for [Delaunay triangulation](https://en.wikipedia.org/wiki/Delaunay_triangulation) of 2D points.

The original code is from [Mapbox's Delaunator](https://github.com/mapbox/delaunator). Some reference code is from [Delaunator-Python](https://github.com/HakanSeven12/Delaunator-Python).

**Note**: It seems like GDScript is not that *fast* (in reference of the slogan above, taken from the original library). See the [performance benchmarks](#performance).

![Delaunay triangulation](/examples/00-a-delaunay-triangulation.png)
*Delaunay triangulation*

![Voronoi cells](/examples/00-b-voronoi-cells.png)
*Voronoi cells*

## Usage

```gdscript
const Delaunator = preload("res://Delaunator.gd")

var points = PoolVector2Array([
  Vector2(0, 0), Vector2(1024, 0), Vector2(1024, 600), Vector2(0, 600), Vector2(29, 390), Vector2(859, 300), Vector2(65, 342), Vector2(86, 333), Vector2(962, 212), Vector2(211, 351), Vector2(3, 594), Vector2(421, 278), Vector2(608, 271), Vector2(230, 538), Vector2(870, 454), Vector2(850, 351), Vector2(583, 385), Vector2(907, 480), Vector2(749, 533), Vector2(877, 232), Vector2(720, 546), Vector2(1003, 541), Vector2(696, 594), Vector2(102, 306)
])

var delaunay = Delaunator.new(points)

print(delaunay.triangles)
# >> [11, 16, 12, 11, 13, 16, 22, 20, 16, 16, 15, 12, 20, 18, 16, 13, 22, 16, 20, 22, 18, 18, 15, 16, 15, 5, 12, 9, 13, 11, 8, 19, 5, 5, 19, 12, 12, 0, 11, 18, 14, 15, 15, 8, 5, 17, 14, 18, 0, 23, 11, 11, 23, 9, 9, 4, 13, 14, 17, 15, 21, 17, 2, 23, 7, 9, 23, 6, 7, 7, 4, 9, 17, 8, 15, 19, 1, 12, 6, 4, 7, 2, 17, 18, 17, 21, 8, 22, 2, 18, 21, 1, 8, 4, 10, 13, 13, 3, 22, 22, 3, 2, 4, 3, 10, 10, 3, 13, 2, 1, 21, 8, 1, 19, 1, 0, 12, 23, 0, 6, 6, 0, 4, 4, 0, 3]

print(delaunay.halfedges)
# >> [5, 11, 38, 28, 17, 0, 18, 14, 16, 22, 26, 1, 20, 23, 7, 98, 8, 4, 6, 89, 12, 41, 9, 13, 44, 35, 10, 56, 3, 53, 113, 33, 43, 31, 77, 25, 115, 50, 2, 46, 59, 21, 73, 32, 24, 57, 39, 82, 117, 51, 37, 49, 65, 29, 70, 95, 27, 45, 74, 40, 84, 81, 110, 68, 71, 52, 119, 80, 63, 79, 54, 64, 86, 42, 58, 112, 116, 34, 122, 69, 67, 61, 47, 88, 60, 92, 72, 101, 83, 19, 109, 111, 85, 104, 107, 55, 106, 99, 15, 97, -1, 87, 125, 105, 93, 103, 96, 94, -1, 90, 62, 91, 75, 30, -1, 36, 76, 48, 120, 66, 118, 123, 78, 121, -1, 102]

print(delaunay.hull)
# >> [1, 0, 3, 2]

print(delaunay.coords)
# >> [0, 0, 1024, 0, 1024, 600, 0, 600, 29, 390, 859, 300, 65, 342, 86, 333, 962, 212, 211, 351, 3, 594, 421, 278, 608, 271, 230, 538, 870, 454, 850, 351, 583, 385, 907, 480, 749, 533, 877, 232, 720, 546, 1003, 541, 696, 594, 102, 306]

```

## API Reference

### Delaunator.new(points)

Constructs a Delaunay triangulation object given an array of points (`Vector2(x, y)`). Duplicate points are skipped.

### Delaunator.new(points).triangles

An array of triangle vertex indices (each group of three numbers forms a triangle). All triangles are directed counterclockwise.

To get the coordinates of all triangles, use:

```gdscript
var coordinates = []

for i in range(0, triangles.size(), 3):
  coordinates.append([
    points[triangles[i]],
    points[triangles[i + 1]],
    points[triangles[i + 2]]
  ])
```

### Delaunator.new(points).halfedges

An array of triangle half-edge indices that allows you to traverse the triangulation.
`i`-th half-edge in the array corresponds to vertex `triangles[i]` the half-edge is coming from.
`halfedges[i]` is the index of a twin half-edge in an adjacent triangle (or `-1` for outer half-edges on the convex hull).

The flat array-based data structures might be counterintuitive, but they're one of the key reasons this library is fast.

### Delaunator.new(points).hull

An array of indices that reference points on the convex hull of the input data, counter-clockwise.

### Delaunator.new(points).coords

An array of input coordinates in the form `[x0, y0, x1, y1, ...]`, of the type provided in the constructor.

### Delaunator.new(points).update()

Updates the triangulation if you modified `Delaunator.new(points).coords` values in place, avoiding expensive memory allocations. Useful for iterative relaxation algorithms such as [Lloyd's](https://en.wikipedia.org/wiki/Lloyd%27s_algorithm).

## Performance

Benchmark results performed on a Macbook Pro Retina 15" 2015 with Godot v3.2 and using this method:

```gdscript
var start = OS.get_ticks_msec()
var delaunay = Delaunator.new(points)
var elapsed = OS.get_ticks_msec() - start
print(elapsed)
```

| 10 points | 100 points | 1.000 points | 10.000 points | 100.000 points |
| --: | --: | --: | --: | --: |
| ~1ms | ~6ms | ~67ms | ~760ms | ~9.4s|

## Changelog

See [CHANGELOG](/CHANGELOG.md).

## Authors

* Me 😛 [hiulit](https://github.com/hiulit).

## Credits

Thanks to:

* [Vladimir Agafonkin](https://github.com/mourner) - for creating [Delaunator](https://github.com/mapbox/delaunator).
* [Amit Patel](https://github.com/redblobgames) - For the [Delaunator guide](https://mapbox.github.io/delaunator/).

## License

See [LICENSE](/LICENSE).
