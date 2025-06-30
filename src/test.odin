package main

import "core:testing"
import rl "vendor:raylib"


@(test)
raycast_test :: proc(t: ^testing.T) {
	rl.InitWindow(1, 1, "test")
	defer rl.CloseWindow()
	mesh := rl.GenMeshCube(1, 1, 1)
	octree := from_mesh(mesh)
	defer delete_octree(octree)

	test_ray_hit(t, mesh, octree, rl.Ray{{0, 2, 0}, {0, -1, 0}})
	test_ray_hit(t, mesh, octree, rl.Ray{{0, -2, 0}, {0, 1, 0}})
	test_ray_no_hit(t, mesh, octree, rl.Ray{{2, 2, 0}, {1, 0, 0}})
	test_ray_hit(t, mesh, octree, rl.Ray{{.49, 1, 0}, {0, -1, 0}})
	/*test_ray_hit(
		t,
		mesh,
		octree,
		rl.Ray{{3, 3, 3}, {-0.57735026919, -0.57735026919, -0.57735026919}},
	)
	*/
}

test_ray_hit :: proc(t: ^testing.T, mesh: rl.Mesh, octree: ^Octree, ray: rl.Ray) {
	rl_hit := rl.GetRayCollisionMesh(ray, mesh, rl.Matrix(1))
	oc_hit := CheckCollisionMeshRay(octree, ray)

	testing.expect(t, rl_hit.hit, "wrong setup")
	testing.expect(t, oc_hit.hit, "no hits detected")

	testing.expect_value(t, oc_hit.normal, rl_hit.normal)
	testing.expect_value(t, oc_hit.point, rl_hit.point)
	testing.expect_value(t, oc_hit.distance, rl_hit.distance)
}

test_ray_no_hit :: proc(t: ^testing.T, mesh: rl.Mesh, octree: ^Octree, ray: rl.Ray) {
	rl_hit := rl.GetRayCollisionMesh(ray, mesh, rl.Matrix(1))
	oc_hit := CheckCollisionMeshRay(octree, ray)

	testing.expect(t, !rl_hit.hit, "wrong setup")
	testing.expect(t, !oc_hit.hit, "no hits detected")
}
