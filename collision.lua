require("vec2")

function collides_with(verts1, verts2)
	-- find the axes
	local axes = {}
	local verts1_normals = find_normals(verts1)
	local verts2_normals = find_normals(verts2)
	for i = 1, #verts1_normals do
		local normal = verts1_normals[i]
		table.insert(axes, normal)
	end
	for i = 1, #verts2_normals do
		local normal = verts2_normals[i]
		table.insert(axes, normal)
	end
	-- project the shapes
	for i = 1, #axes do
		local projection1 = project(verts1, axes[i])
		local projection2 = project(verts2, axes[i])
		if not projection_overlap(projection1, projection2) then
			return false
		end
	end
	return true
end

function find_normals(verts)
	local num_of_verts = #verts
	local normals = {}
	for i = 1, num_of_verts do
		local v1 = verts[i]
		local v2 = (verts[(i % num_of_verts) + 1])
		local edge = vec2_sub(v1, v2)
		local normal = vec2_normals(edge)[1]
		table.insert(normals, normal)
	end
	return normals
end

function project(verts, axis)
	local min, max = nil, nil
	for i = 1, #verts do
		local v = verts[i]
		local dot = vec2_dot(v, axis)
		if (not min) or (dot < min) then
			min = dot
		end
		if (not max) or (dot > max) then
			max = dot
		end
	end
	return {min = min, max = max}
end

function projection_overlap(p1, p2)
	if ((p1.max > p2.min) and (p1.min < p2.max)) then
		return true
	end
	return false
end

function raycast(origin, dest, edges)
	-- (a, b), (c, d) are points defining two line segments
	-- r, s are direction vectors
	-- t, u are scalar values
	-- vec2 cross product is defined as (ax * by) - (ay * bx)
	local shortest_dist = nil
	local a = origin
	local b = dest
	local r = vec2_sub(b, a)
	for i = 1, #edges do
		local vertices = edges[i]
		for k = 1, #vertices do
			local c = vertices[k]
			local d = vertices[(k % #vertices) + 1]
			local s = vec2_sub(d, c)
			local cross_rs = vec2_cross(r, s)
			local cross_sr = vec2_cross(s, r)
			local t = nil
			local u = nil
			if (cross_rs ~= 0) and (cross_sr ~= 0) then
				t = vec2_cross(vec2_sub(c, a), s) / cross_rs
				u = vec2_cross(vec2_sub(a, c), r) / cross_sr
				if (t >= 0 and t <= 1) and (u >= 0 and u <= 1) then
					if not shortest_dist or t < shortest_dist then
						shortest_dist = t
					end
				end
			end
		end
	end
	if shortest_dist then
		r = vec2_scale(r, shortest_dist)
		return r
	end
	return nil
end