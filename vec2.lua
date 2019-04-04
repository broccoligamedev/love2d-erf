function vec2_add(v1, v2)
	return vec2_new(v1.x + v2.x, v1.y + v2.y)
end

function vec2_sub(v1, v2)
	return vec2_new(v1.x - v2.x, v1.y - v2.y)
end

function vec2_dot(v1, v2)
	return (v1.x * v2.x) + (v1.y * v2.y)
end

function vec2_cross(v1, v2)
	return (v1.x * v2.y) - (v1.y * v2.x)
end

function vec2_scale(v1, s)
	return vec2_new(v1.x * s, v1.y * s)
end

function vec2_normals(v1)
	local normals = {}
	local norm1 = vec2_normalize(vec2_new(v1.y, -v1.x))
	local norm2 = vec2_normalize(vec2_new(-v1.y, v1.x))
	table.insert(normals, norm1)
	table.insert(normals, norm2)
	return normals
end

function vec2_clone(v1)
	return vec2_new(v1.x, v1.y)
end

function vec2_get_normals(v1)
	local norm1 = vec2_normalize(vec2_new(v1.y, -v1.x))
	local norm2 = vec2_normalize(vec2_new(-v1.y, v1.x))
	return norm1, norm2
end

function vec2_normalize(v1)
	local mag = vec2_length(v1)
	if mag > 0 then
		return vec2_new(v1.x / mag, v1.y / mag)
	end
	return vec2_new(0, 0)
end

function vec2_length(v1)
	return math.sqrt((v1.x * v1.x) + (v1.y * v1.y))
end

function vec2_new(x, y)
	return {x = x, y = y}
end

function vec2_zero()
	return vec2_new(0, 0)
end

function vec2_flatten(vec_list)
	local flat_list = {}
	for i = 1, #vec_list do
		local v = vec_list[i]
		table.insert(flat_list, v.x)
		table.insert(flat_list, v.y)
	end
	return flat_list
end

function vec2_rotate(v1, deg)
	local precision = 5
	local rad = math.rad(deg)
	local new_x = (v1.x * math.cos(rad)) - (v1.y * math.sin(rad))
	new_x = math.floor(new_x * (10 ^ precision)) / (10 ^ precision)
	local new_y = (v1.x * math.sin(rad)) + (v1.y * math.cos(rad))
	new_y = math.floor(new_y * (10 ^ precision)) / (10 ^ precision)
	return vec2_new(new_x, new_y)
end

function vec2_rotate_around(v1, deg, origin_x, origin_y)
	local new_vec = vec2_new(v1.x - origin_x, v1.y - origin_y)
	new_vec = vec2_rotate(new_vec, deg)
	new_vec.x = new_vec.x + origin_x
	new_vec.y = new_vec.y + origin_y
	return new_vec
end

function vec2_absolute_angle(v1)
    return math.deg(math.atan2(v1.y, v1.x))
end

function vec2_angle_between(v1, v2)
    local theta = math.atan2(v2.y, v2.x) - math.atan2(v1.y, v1.x)
    return math.deg(theta)
end