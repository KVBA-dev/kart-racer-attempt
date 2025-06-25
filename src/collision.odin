package main

import "core:fmt"
import "core:math"
import la "core:math/linalg"
import "core:slice"
import rl "vendor:raylib"

// Collision data structure
Collision :: struct {
	direction:     rl.Vector3,
	contact_point: rl.Vector3,
	distance:      f32,
}

// Triangle structure for mesh faces
MeshCollider :: struct {
	mesh: ^Octree,
}

// Sphere collider structure
SphereCollider :: struct {
	center: rl.Vector3,
	radius: f32,
}

Collider :: union {
	MeshCollider,
	SphereCollider,
}

StaticColliders: [dynamic]MeshCollider

Rigidbody :: struct {
	centerOfMass: rl.Vector3,
	linAccel:     rl.Vector3,
	linVel:       rl.Vector3,
	mass:         f32,
}

init_collision :: proc() {
	StaticColliders = make([dynamic]MeshCollider)
	collisions = make([dynamic]Collision)
}

rigidbody_update :: proc(using rb: ^Rigidbody, dt: f32) {
	linVel += linAccel * dt
}

rigidbody_update_position :: proc(using rb: ^Rigidbody, pos: ^rl.Vector3, dt: f32) {
	pos^ = pos^ + linVel * dt
}

rigidbody_end_timestep :: proc(using rb: ^Rigidbody) {
	linAccel = {0, 0, 0}
}

add_force :: proc(using rb: ^Rigidbody, force: rl.Vector3) {
	linAccel += force / mass
}

add_acceleration :: proc(using rb: ^Rigidbody, accel: rl.Vector3) {
	linAccel += accel
}

destroy_collision :: proc() {
	for mc in StaticColliders {
		delete_octree(mc.mesh)
	}
	delete(StaticColliders)
	delete(collisions)
}

add_mesh_collider :: proc(mesh: rl.Mesh, collection: ^[dynamic]MeshCollider) {
	oct := from_mesh(mesh)
	append(collection, MeshCollider{oct})
}

// WARN: do not use this in separate threads
collisions: [dynamic]Collision

OctreeIndex :: enum u8 {
	BOTTOM_LEFT_BACK,
	BOTTOM_RIGHT_BACK,
	TOP_LEFT_BACK,
	TOP_RIGHT_BACK,
	BOTTOM_LEFT_FRONT,
	BOTTOM_RIGHT_FRONT,
	TOP_LEFT_FRONT,
	TOP_RIGHT_FRONT,
}

MAX_TRIS :: 128

Triangle :: struct {
	verts:  [3]rl.Vector3,
	normal: rl.Vector3,
}

Octree :: struct {
	box:      rl.BoundingBox,
	nodes:    [8]^Octree,
	tris:     [dynamic]Triangle,
	triCount: int,
	isLeaf:   bool,
}

make_octree :: proc(box: rl.BoundingBox) -> ^Octree {
	octree := new(Octree)
	octree.box = box
	octree.tris = make([dynamic]Triangle)
	octree.isLeaf = true

	return octree
}

triangle_bounds :: proc(tri: Triangle) -> rl.BoundingBox {
	return rl.BoundingBox {
		min = rl.Vector3Min(rl.Vector3Min(tri.verts[0], tri.verts[1]), tri.verts[2]),
		max = rl.Vector3Max(rl.Vector3Max(tri.verts[0], tri.verts[1]), tri.verts[2]),
	}
}

insert_triangle :: proc(octree: ^Octree, tri: Triangle, depth: uint) {
	if !rl.CheckCollisionBoxes(octree.box, triangle_bounds(tri)) {
		return
	}

	if depth == 0 {
		return
	}

	if octree.isLeaf {
		triCount := len(octree.tris)
		if triCount < MAX_TRIS {
			append(&octree.tris, tri)
			return
		}
		split(octree)
		for t in octree.tris {
			for i in 0 ..< 8 {
				if rl.CheckCollisionBoxes(octree.nodes[i].box, triangle_bounds(t)) {
					insert_triangle(octree.nodes[i], t, depth - 1)
				}
			}
		}
		octree.isLeaf = false
		clear(&octree.tris)
	}

	for i in 0 ..< 8 {
		if rl.CheckCollisionBoxes(octree.nodes[i].box, triangle_bounds(tri)) {
			insert_triangle(octree.nodes[i], tri, depth - 1)
		}
	}
}

from_mesh :: proc(mesh: rl.Mesh, maxDepth: uint = 5) -> ^Octree {
	box := rl.GetMeshBoundingBox(mesh)
	octree := make_octree(box)

	tris_temp := make([dynamic]Triangle)
	defer delete(tris_temp)


	for i in 0 ..< mesh.triangleCount {
		tri := Triangle {
			verts  = [3]rl.Vector3 {
				rl.Vector3 {
					mesh.vertices[i * 9],
					mesh.vertices[i * 9 + 1],
					mesh.vertices[i * 9 + 2],
				},
				rl.Vector3 {
					mesh.vertices[i * 9 + 3],
					mesh.vertices[i * 9 + 4],
					mesh.vertices[i * 9 + 5],
				},
				rl.Vector3 {
					mesh.vertices[i * 9 + 6],
					mesh.vertices[i * 9 + 7],
					mesh.vertices[i * 9 + 8],
				},
			},
			normal = rl.Vector3Normalize(
				rl.Vector3{mesh.normals[i * 9], mesh.normals[i * 9 + 1], mesh.normals[i * 9 + 2]} +
				rl.Vector3 {
						mesh.normals[i * 9 + 3],
						mesh.normals[i * 9 + 4],
						mesh.normals[i * 9 + 5],
					} +
				rl.Vector3 {
						mesh.normals[i * 9 + 6],
						mesh.normals[i * 9 + 7],
						mesh.normals[i * 9 + 8],
					},
			),
		}
		append(&tris_temp, tri)
	}

	for t in tris_temp {
		insert_triangle(octree, t, maxDepth)
	}

	return octree
}

split :: proc(octree: ^Octree, maxVerts: uint = 10) {
	min := octree.box.min
	max := octree.box.max
	mid := (min + max) * 0.5

	for i in 0 ..< 8 {
		childMin := rl.Vector3 {
			(i & 1 == 0) ? min.x : mid.x, // left-right
			(i & 2 == 0) ? min.y : mid.y, // up-down
			(i & 4 == 0) ? min.z : mid.z, // back-front
		}
		childMax := rl.Vector3 {
			(i & 1 == 0) ? mid.x : max.x, // left-right
			(i & 2 == 0) ? mid.y : max.y, // up-down
			(i & 4 == 0) ? mid.z : max.z, // back-front
		}
		childBox := rl.BoundingBox {
			min = childMin,
			max = childMax,
		}
		octree.nodes[i] = make_octree(childBox)
	}
	octree.isLeaf = false
}

delete_octree :: proc(octree: ^Octree) {
	if octree == nil {
		return
	}
	for n in octree.nodes {
		delete_octree(n)
	}
	delete(octree.tris)
	free(octree)
}

point_in_tri :: proc(point: rl.Vector3, tri: Triangle) -> bool {
	a := tri.verts[0] - point
	b := tri.verts[1] - point
	c := tri.verts[2] - point

	u := rl.Vector3CrossProduct(c, b)
	v := rl.Vector3CrossProduct(a, c)
	w := rl.Vector3CrossProduct(b, a)

	return rl.Vector3DotProduct(u, v) > 0 && rl.Vector3DotProduct(u, w) > 0
}

closest_point_on_line :: proc(point, a, b: rl.Vector3) -> rl.Vector3 {
	ba := b - a
	t := rl.Vector3DotProduct(point - a, ba) / rl.Vector3LengthSqr(ba)
	return a + rl.Clamp(t, 0, 1) * (b - a)
}

closest_point_on_tri :: proc(point: rl.Vector3, tri: Triangle) -> rl.Vector3 {
	p0 := point - tri.verts[0]
	e10 := tri.verts[1] - tri.verts[0]
	e21 := tri.verts[2] - tri.verts[1]
	e02 := tri.verts[0] - tri.verts[2]

	proj := point - rl.Vector3DotProduct(p0, tri.normal) * tri.normal

	if point_in_tri(proj, tri) {
		return proj
	}

	closest01 := closest_point_on_line(point, tri.verts[0], tri.verts[1])
	closest12 := closest_point_on_line(point, tri.verts[1], tri.verts[2])
	closest20 := closest_point_on_line(point, tri.verts[2], tri.verts[0])

	closest := closest01
	if rl.Vector3DistanceSqrt(closest, point) > rl.Vector3DistanceSqrt(closest12, point) {
		closest = closest12
	}
	if rl.Vector3DistanceSqrt(closest, point) > rl.Vector3DistanceSqrt(closest20, point) {
		closest = closest20
	}
	return closest

}

CheckCollisionSphereTriangle :: proc(sphere: SphereCollider, tri: Triangle) -> (bool, Collision) {
	closest := closest_point_on_tri(sphere.center, tri)
	dist := rl.Vector3Distance(sphere.center, closest)
	if dist <= sphere.radius {
		hitinfo := Collision {
			contact_point = closest,
			direction     = rl.Vector3Normalize(closest - sphere.center),
			distance      = sphere.radius - dist,
		}
		return true, hitinfo
	}
	return false, {}
}

CheckCollisionMeshSphere :: proc(octree: ^Octree, sphere: SphereCollider) -> []Collision {
	clear(&collisions)
	if !rl.CheckCollisionBoxSphere(octree.box, sphere.center, sphere.radius) {
		return {}
	}
	if octree.isLeaf {
		for t in octree.tris {
			if ok, col := CheckCollisionSphereTriangle(sphere, t); ok {
				append(&collisions, col)
			}
		}
		return collisions[:]
	}

	for n in octree.nodes {
		if n == nil {
			continue
		}
		cols := CheckCollisionMeshSphere(n, sphere)
		if len(cols) > 0 do return cols
	}

	return {}
}


CheckCollisionSpheres :: proc(s1, s2: SphereCollider) -> (bool, Collision) {
	dist := rl.Vector3Distance(s1.center, s2.center)
	radii := s1.radius + s2.radius
	if radii >= rl.Vector3Distance(s1.center, s2.center) {
		normal := rl.Vector3Normalize(s1.center - s2.center)
		col := Collision {
			direction     = normal,
			contact_point = s1.center - normal * s1.radius,
		}
		col.distance = rl.Vector3Distance(col.contact_point, radii - dist)
		return true, col
	}
	return false, {}
}

// HACK: no need to create a new struct or other hacks
currUp: rl.Vector3

sort_collisions_predicate :: proc(a, b: Collision) -> bool {
	return la.dot(a.direction, currUp) < la.dot(b.direction, currUp)
}

sort_collisions_by_grounding :: proc(cols: []Collision, up: rl.Vector3) {
	currUp = up
	slice.sort_by(cols, sort_collisions_predicate)
}

draw_octree :: proc(octree: ^Octree) {
	if octree == nil {
		return
	}

	if octree.isLeaf {
		rl.DrawBoundingBox(octree.box, rl.YELLOW)
		for t in octree.tris {
			rl.DrawLine3D(t.verts[0], t.verts[1], rl.RED)
			rl.DrawLine3D(t.verts[0], t.verts[2], rl.RED)
			rl.DrawLine3D(t.verts[2], t.verts[1], rl.RED)

			rl.DrawTriangle3D(t.verts[0], t.verts[1], t.verts[2], rl.ColorAlpha(rl.RED, 0.5))
		}
		return
	}

	for n in octree.nodes {
		draw_octree(n)
	}
}

draw_collider :: proc(col: Collider) {
	switch c in col {
	case SphereCollider:
		rl.DrawSphereWires(c.center, c.radius, 16, 16, rl.GREEN)
	case MeshCollider:
		draw_octree(c.mesh)
	}
}
