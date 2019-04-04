require("vec2")
require("collision")

local ui_font = nil
local core = nil
local game_state = "RUN"
local game_width = 1366
local game_height = 768
local game_objects = {}
local game_objects_buffer = {}
local game_object_pool = {}
local game_object_id_stack = {}
local n_back_queue = {}
local n_back_num = 2
local n_back_range = 5
local n_back_timer = 90
local n_back_timer_base = 45
local n_back_result_timer = 0
local n_back_result_timer_base = 25
local n_back_font = nil
local n_back_font_outline = nil
local n_back_color = 1
local n_back_sounds = nil
local n_back_claimed = false
local n_back_fail_count = 0
local n_back_result = "NONE"
local mouse_beam = nil
local beams = {}
local DEBUG_MODE = false
local frame_time = 0
local mouse_position = vec2_new(love.mouse.getX(), love.mouse.getY())
local baddie_spawn_timer = 0
local baddie_spawn_timer_base = 25
local baddie_spawn_max_size = 7
local baddie_spawn_min_size = 4
local baddie_spawn_offset = 100
local baddie_max = 60
local baddie_count = 0
local next_object_id = 1
local score = 0
local highscore = 0
local new_highscore = false
local score_font = nil
local images = {}
local sounds = {}
local explosion_sounds = {}
local shoot_sounds = {}
local beam_hit_sounds = {}
local camera_shake_timer = 0
local transition = nil

function set_color(r, g, b, a)
	-- note(ryan): LOVE started using normalized color values some version ago so
	-- this wrapper function converts from the old code to new versions of LOVE
	-- (tested on LOVE 11.2)
	if a == nil then a = 255 end
	love.graphics.setColor(r / 255, g / 255, b / 255, a / 255)
end

function set_background_color(r, g, b, a)
	-- see set_color
	if a == nil then a = 255 end
	love.graphics.setBackgroundColor(r / 255, g / 255, b / 255, a / 255)
end

function save_game()
	if love.filesystem.exists("nback.save") then
		love.filesystem.remove("nback.save")
	end
	local f, err = love.filesystem.newFile("nback.save")
	if err then
		print(err)
	else
		f:open("w")
		love.filesystem.append("nback.save", tostring(highscore))
		f:close()
	end
end

function load_game()
	if love.filesystem.exists("nback.save") then
		for line in love.filesystem.lines("nback.save") do
			highscore = tonumber(line)
		end
	end
end

function game_over()
	play_sound("GAME_OVER")
	if score > highscore then
		highscore = score
		new_highscore = true
	end
	change_scene("GAME_OVER", false)
end

function change_scene(scene_name, use_transition)
	next_scene = scene_name
	if use_transition then
		for i = 1, #game_objects do
			game_objects[i].is_active = false
		end
		local transition = new_object("TRANSITION", -game_width, 0)
		transition.state = "END"
	else
		new_scene(next_scene, false)
	end
end

function new_scene(scene_name, use_transition)
	for i = 1, #game_objects do
		free_object(game_objects[i])
	end
	camera_shake_timer = 0
	clear_table(beams)
	clear_table(game_objects)
	local scene = {}
	scene.scene_name = scene_name
	if scene_name == "MENU" then
		local play_button = new_object("BUTTON", game_width / 2, game_height / 2)
		play_button.text = "PLAY"
		for i = 1, 100 do
			new_object("STAR", math.random(0, game_width), math.random(0, game_height))
		end
		core = new_object("CORE", game_width / 2, game_height / 2)
	elseif scene_name == "GAME" then
		clear_table(n_back_queue)
		new_highscore = false
		n_back_timer = 90
		n_back_result_timer = 0
		n_back_claimed = false
		n_back_fail_count = 0
		n_back_result = "NONE"
		baddie_count = 0
		score = 0
		baddie_spawn_timer = 0
		baddie_spawn_timer_base = 25
		core = new_object("CORE", game_width / 2, game_height / 2)
		for i = 1, 3 do
			local light = new_object("DISCO_LIGHT", game_width / 2, game_height / 2)
			rotate_object(light, (i - 1) * (360 / 3))
		end
		for i = 1, 3 do
			local light = new_object("DISCO_LIGHT", game_width / 2, game_height / 2)
			light.is_visible = false
			light.color = 3
			rotate_object(light, 60 + (i - 1) * (360 / 3))
		end
		for i = 1, 100 do
			new_object("STAR", math.random(0, game_width), math.random(0, game_height))
		end
		local beam = new_object("BEAM", game_width / 2, game_height / 2)
		mouse_beam = beam
		table.insert(beams, beam)
		sounds.LASER:setVolume(0)
		sounds.LASER:setLooping(true)
		sounds.LASER:play()
		beam_base = new_object("BEAM_BASE", game_width / 2, game_height / 2)
		for i = 1, 3 do
			local light = new_object("N_BACK_LIGHT", game_width / 2, game_height / 2)
			rotate_object(light, (i - 1) * 120)
			local beam = new_object("BEAM", game_width / 2, game_height / 2)
			rotate_object(beam, (i - 1) * 120)
			table.insert(beams, beam)
			beam.is_hot = false
			beam.is_visible = false
			beam.rotation_speed = 1
			beam.color.r = 0
			beam.color.g = 255
			beam.color.b = 0
		end
	elseif scene_name == "GAME_OVER" then
		local retry_button = new_object("BUTTON", game_width / 2, game_height / 2)
		retry_button.text = "RETRY"
		local play_button = new_object("BUTTON", game_width / 2, retry_button.y + retry_button.height + 25)
		play_button.text = "MENU"
		for i = 1, 100 do
			new_object("STAR", math.random(0, game_width), math.random(0, game_height))
		end
	end
	if use_transition then
		for i = 1, #game_objects do
			game_objects[i].is_active = false
		end
		local transition = new_object("TRANSITION", 0, 0)
		transition.state = "START"
	end
	active_scene = scene
	return scene
end

function on_select()

end

function save_score()

end

function free_object(object)
	if object == mouse_beam then
		sounds.LASER:setVolume(0)
	end
	stack_push(game_object_id_stack, object.id)
	clear_table(object)
end

function love.load()
	print("starting game.")
	math.randomseed(os.clock())
	-- load the highscore
	load_game()
	-- object pool
	for i = 1, 1200 do
		stack_push(game_object_id_stack, i)
		game_object_pool[i] = {}
	end
	ui_font = love.graphics.newFont(14)
	credit_font = love.graphics.newFont("fonts/coaster.ttf", 32)
	score_font = love.graphics.newFont("fonts/coaster.ttf", 50)
	n_back_font = love.graphics.newFont("fonts/coaster.ttf", 196)
	love.window.setMode(game_width, game_height, {vsync = true})
	love.window.setTitle("ERF: The Planet of Party")
	love.mouse.setVisible(false)
	-- load images
	images.PLANET = love.graphics.newImage("images/planet.png")
	images.PLANET_CLOUDS = love.graphics.newImage("images/planet_clouds.png")
	images.SKULL = love.graphics.newImage("images/skull.png")
	images.CROSS = love.graphics.newImage("images/cross.png")
	-- load sounds
	local snd = love.audio.newSource("sounds/laser.wav", "static")
	sounds.LASER = snd
	local snd = love.audio.newSource("sounds/explode.wav", "static")
	sounds.EXPLODE = snd
	snd:setVolume(0.1)
	for i = 1, 8 do
		explosion_sounds[i] = snd:clone()
	end
	local snd = love.audio.newSource("sounds/shoot.wav", "static")
	sounds.SHOOT = snd
	snd:setVolume(0.1)
	for i = 1, 8 do
		shoot_sounds[i] = snd:clone()
	end
	local snd = love.audio.newSource("sounds/n_back_fail.wav", "static")
	sounds.N_BACK_FAIL = snd
	snd:setVolume(0.15)
	local snd = love.audio.newSource("sounds/n_back_success.wav", "static")
	sounds.N_BACK_SUCCESS = snd
	snd:setVolume(0.6)
	local snd = love.audio.newSource("sounds/one.wav", "static")
	sounds.ONE = snd
	snd:setVolume(1)
	local snd = love.audio.newSource("sounds/two.wav", "static")
	sounds.TWO = snd
	snd:setVolume(1)
	local snd = love.audio.newSource("sounds/three.wav", "static")
	sounds.THREE = snd
	snd:setVolume(1)
	local snd = love.audio.newSource("sounds/four.wav", "static")
	sounds.FOUR = snd
	snd:setVolume(1)
	local snd = love.audio.newSource("sounds/five.wav", "static")
	sounds.FIVE = snd
	snd:setVolume(1)
	local snd = love.audio.newSource("sounds/ready.wav", "static")
	sounds.READY = snd
	snd:setVolume(1)
	local snd = love.audio.newSource("sounds/begin.wav", "static")
	sounds.BEGIN = snd
	snd:setVolume(1)
	local snd = love.audio.newSource("sounds/button.wav", "static")
	sounds.BUTTON = snd
	snd:setVolume(0.25)
	local snd = love.audio.newSource("sounds/firefly.mp3", "static")
	sounds.BG_MUSIC = snd
	snd:setVolume(0.3)
	snd:setLooping(true)
	snd:play()
	n_back_sounds = {
		sounds.ONE,
		sounds.TWO,
		sounds.THREE,
		sounds.FOUR,
		sounds.FIVE,
	}
	local snd = love.audio.newSource("sounds/game_over.wav", "static")
	snd:setVolume(1)
	sounds.GAME_OVER = snd
	new_scene("MENU")
end

function love.update()
	mouse_position = vec2_new(love.mouse.getX(), love.mouse.getY())
	if game_state == "RUN" then
		local frame_start_time = os.clock()
		if camera_shake_timer > 0 then
			camera_shake_timer = camera_shake_timer - 1
		end
		if active_scene.scene_name == "GAME" then
			if mouse_beam then
				local vec_to_mouse = vec2_new(mouse_position.x - mouse_beam.x, mouse_position.y - mouse_beam.y)
				local theta = vec2_absolute_angle(vec_to_mouse) - mouse_beam.rotation
				rotate_object(mouse_beam, theta + 90)
				local current_volume = sounds.LASER:getVolume()
				if love.mouse.isDown(1) then
					sounds.LASER:setVolume(interpolate(current_volume, 0, 1, 0.10))
					mouse_beam.is_hot = true
					mouse_beam.is_visible = true
				else
					sounds.LASER:setVolume(interpolate(current_volume, 0, 1, -0.10))
					mouse_beam.is_hot = false
					mouse_beam.is_visible = false
				end
			end
			n_back_result_timer = n_back_result_timer - 1
			if n_back_result_timer <= 0 then
				n_back_result = "NONE"
			end
			n_back_timer = n_back_timer - 1
			if n_back_timer <= 0 then
				n_back_timer = n_back_timer_base
				if #n_back_queue == n_back_num + 1 and not n_back_claimed and n_back_queue[1] == n_back_queue[n_back_num + 1] then
					n_back_fail()
				end
				push_num()
			end
			baddie_spawn_timer = baddie_spawn_timer - 1
			if baddie_spawn_timer <= 0 and baddie_count < baddie_max then
				local swarm_size = math.random(baddie_spawn_min_size, baddie_spawn_max_size)
				local position = vec2_new((game_width / 2) + 1000, 0)
				position = vec2_rotate(position, math.random(1, 360))
				for i = 1, swarm_size do
					baddie_spawn_timer = baddie_spawn_timer_base
					local relative_position = vec2_new(position.x + math.random(-baddie_spawn_offset, baddie_spawn_offset), position.y + math.random(-baddie_spawn_offset, baddie_spawn_offset))
					local baddie = new_object("BADDIE", relative_position.x, relative_position.y)
					local velocity = vec2_new((game_width / 2) - baddie.x, (game_height / 2) - baddie.y)
					velocity = vec2_normalize(velocity)
					velocity = vec2_scale(velocity, baddie.speed)
					baddie.velocity = velocity
					baddie.goal_distance = core.shield_radius + math.random(50, 150)
					baddie_count = baddie_count + 1
					if baddie_count >= baddie_max then
						break
					end
				end
			end
		end
		for i = 1, #game_objects do
			local object = game_objects[i]
			local object_type = object.object_type
			if object.is_active then
				if object_type == "CORE" then
					object.rotation = object.rotation + 0.25
					object.cloud_rotation = object.cloud_rotation - 0.15
					object.is_hit = false
					if object.bounce_multiplier > 1 then
						object.bounce_multiplier = object.bounce_multiplier - 0.01
					end
					object.bounce_timer = object.bounce_timer - 1
					if object.bounce_timer <= 0 then
						object.bounce_timer = object.bounce_timer_base
						object.bounce_multiplier = 1.05
					end
					object.flash_timer = object.flash_timer - 1
					if object.flash_timer <= 0 then
						object.is_flashing = false
					end
					if object.hp <= 0 then
						game_over()
						break
					end
				elseif object_type == "MISSILE" then
					apply_velocity(object)
					if out_of_bounds(object) then
						object.is_alive = false
					end
				elseif object_type == "BADDIE" then
					-- do rude dude stuff here!!!
					if object.is_hurt then
						object.is_hurt = false
					end
					object.attack_timer = object.attack_timer - 1
					if object.attack_timer <= 0 then
						object.attack_timer = object.attack_timer_base
						object.can_attack = true
					end
					local position_delta = vec2_new(object.x - game_width / 2, object.y - game_height / 2)
					local theta = vec2_absolute_angle(object.velocity) - object.rotation
					rotate_object(object, theta + 90)
					if core and vec2_length(position_delta) > object.goal_distance then
						apply_velocity(object)
					elseif core and object.can_attack then
						object.can_attack = false
						local center = find_center(object.vertices)
						local missile = new_object("MISSILE", center.x, center.y)
						local velocity = vec2_new(core.x - missile.x, core.y - missile.y)
						velocity = vec2_normalize(velocity)
						velocity = vec2_scale(velocity, missile.speed)
						missile.velocity = velocity
						play_sound("SHOOT")
					end
				elseif object_type == "DEBRIS" then
					rotate_object(object, object.rotation_speed)
					apply_velocity(object)
					object.alpha = object.alpha - object.fade_speed
					if object.alpha <= 0 then
						object.is_alive = false
					end
				elseif object_type == "DISCO_LIGHT" then
					object.color_timer = object.color_timer - 1
					if object.color_timer <= 0 then
						object.color_timer = object.color_timer_base
						object.color = (object.color % 4) + 1
					end
					object.hide_timer = object.hide_timer - 1
					if object.hide_timer <= 0 then
						object.hide_timer = object.hide_timer_base
						object.is_visible = not object.is_visible
					end
					rotate_object(object, object.rotation_speed)
				elseif object_type == "STAR" then
					object.x = object.x - object.speed
					if object.x < 0 then
						object.x = game_width
					end
				elseif object_type == "PARTICLE" then
					apply_velocity(object)
					if object.style == "NORMAL" then
						if object.color.a > 0 then
							object.color.a = object.color.a - object.fade_speed
						else
							object.is_alive = false
						end
					elseif object.style == "EXPLOSION" then
						if object.radius < object.max_radius then
							object.radius = object.radius + object.growth_rate
						else
							object.style = "NORMAL"
						end
					end
				elseif object_type == "EXPLOSION" then
					object.explosion_timer = object.explosion_timer - 1
					if object.explosion_timer <= 0 then
						object.explosion_timer = object.explosion_timer_base
						object.explosion_count = object.explosion_count - 1
						local position = vec2_new(
							object.x + math.random(-object.explosion_spread, object.explosion_spread),
							object.y + math.random(-object.explosion_spread, object.explosion_spread)
						)
						local particle = new_object("PARTICLE", position.x, position.y)
						particle.shape = "CIRCLE"
						particle.style = "EXPLOSION"
						particle.color.r = 255
						particle.color.g = math.random(100, 255)
						particle.color.b = 20
						particle.z = math.random(1, 5)
						particle.max_radius = math.random(32, 48)
						particle.radius = math.random(16, 24)
						particle.growth_rate = 2
						particle.fade_speed = 16
						if object.explosion_count <= 0 then
							object.is_alive = false
						end
					end
				elseif object_type == "BEAM" then
					rotate_object(object, object.rotation_speed)
					if object.active_timer > 0 then
						object.active_timer = object.active_timer - 1
						if object.active_timer <= 0 then
							object.is_hot = false
							object.is_visible = false
						end
					end
				elseif object_type == "BEAM_BASE" then
					local vec_to_mouse = vec2_new(mouse_position.x - object.x, mouse_position.y - object.y)
					local theta = vec2_absolute_angle(vec_to_mouse) - object.rotation
					rotate_object(object, theta + 90)
				elseif object_type == "N_BACK_LIGHT" then
					rotate_object(object, 1)
				elseif object_type == "BUTTON" then
					if not (
						mouse_position.x < (object.x - object.width / 2) or 
						mouse_position.x > (object.x + object.width / 2) or
						mouse_position.y < (object.y - object.height / 2) or
						mouse_position.y > (object.y + object.height / 2)
					) then
						if love.mouse.isDown(1) then
							object.cursor_state = "SELECTED"
						else
							object.cursor_state = "HOVER"
						end
					else
						object.cursor_state = "NONE"
					end
				elseif object_type == "TRANSITION" then
					object.x = object.x + object.speed
					if object.state == "END" then
						if object.x >= 0 then
							transition = nil
							object.is_alive = false
							new_scene(next_scene, true)
						end
						break
					elseif object.state == "START" then
						if object.x >= game_width then
							transition = nil
							object.is_alive = false
							for i = 1, #game_objects do
								game_objects[i].is_active = true
							end
						end
						break
					end
				end
			end
		end
		handle_collisions()
		clean_up_dead_objects()
		frame_time = os.clock() - frame_start_time
	end
end

function love.mousereleased(x, y, button)
	for i = 1, #game_objects do
		local object = game_objects[i]
		local object_type = object.object_type
		if object_type == "BUTTON" and object.cursor_state == "SELECTED" and not transition then
			if object.text == "PLAY" or object.text == "RETRY" then
				change_scene("GAME", true)
			elseif object.text == "MENU" then
				change_scene("MENU", true)
			end
			play_sound("BUTTON")
		end
	end
end

function clean_up_dead_objects()
	for i = 1, #game_objects do
		local object = game_objects[i]
		if object.is_alive then
			table.insert(game_objects_buffer, object)
		else
			free_object(object)
		end
	end
	local temp = game_objects
	clear_table(game_objects)
	game_objects = game_objects_buffer
	game_objects_buffer = temp
end

function stack_push(t, val)
	local size = #t
	t[size + 1] = val
end

function stack_pop(t)
	local size = #t
	local val = t[size]
	t[size] = nil
	return val
end

function clear_table(t)
	for k, _ in pairs(t) do
		t[k] = nil
	end
end

function interpolate(val, min, max, step)
	local new_val = val + step
	if new_val > max then
		return max
	elseif new_val < min then
		return min
	else
		return new_val
	end
end

function love.draw()
	love.graphics.scale(love.graphics.getWidth() / game_width, love.graphics.getHeight() / game_height)
	love.graphics.push()
	love.graphics.translate(
		math.random(-camera_shake_timer, camera_shake_timer),
		math.random(-camera_shake_timer, camera_shake_timer)
	)
	set_background_color(5, 5, 5)
	table.sort(game_objects, z_sort)
	for i = 1, #game_objects do
		local object = game_objects[i]
		local object_type = object.object_type
		if object.is_alive and object.is_visible then
			if object_type == "CORE" then
				set_color(255, 255, 255)
				love.graphics.draw(
					images.PLANET,
					object.x,
					object.y,
					math.rad(object.rotation),
					object.bounce_multiplier,
					object.bounce_multiplier,
					object.radius,
					object.radius
				)
				love.graphics.draw(
					images.PLANET_CLOUDS,
					object.x,
					object.y,
					math.rad(object.cloud_rotation),
					object.bounce_multiplier,
					object.bounce_multiplier,
					object.radius,
					object.radius
				)
				if object.is_shielded then
					set_color(100, 100, 220)
					if object.is_flashing then
						set_color(255, 255, 255)
					end
					love.graphics.setLineWidth(4)
					love.graphics.circle("line", object.x, object.y, object.shield_radius)
				end
				set_color(5, 5, 5)
				love.graphics.circle("fill", object.x, object.y, 112)
				set_color(100, 100, 220)
				love.graphics.setLineWidth(4)
				love.graphics.circle("line", object.x, object.y, 112)
				if #n_back_queue > 0 and active_scene.scene_name == "GAME" then
					local n_back_char = n_back_queue[#n_back_queue]
					if n_back_color == 1 then
						set_color(255, 50, 255, object.alpha)
					elseif n_back_color == 2 then
						set_color(50, 255, 50, object.alpha)
					elseif n_back_color == 3 then
						set_color(255, 255, 50, object.alpha)
					elseif n_back_color == 4 then
						set_color(50, 255, 255, object.alpha)
					end
					love.graphics.setFont(n_back_font)
					local char_width = n_back_font:getWidth(n_back_char)
					local char_height = n_back_font:getHeight(n_back_char)
					love.graphics.print(n_back_char, object.x - (char_width / 2), object.y - (char_height / 2))
				end
			elseif object_type == "MISSILE" then
				set_color(255, 0, 0)
				love.graphics.circle("fill", object.x, object.y, object.radius)
			elseif object_type == "BADDIE" then
				if object.is_hurt then
					set_color(255, 0, 0)
				else
					set_color(240, 240, 240)
				end
				local flat_verts = vec2_flatten(object.vertices)
				love.graphics.polygon("fill", flat_verts)
				set_color(20, 20, 20)
				love.graphics.setLineWidth(4)
				love.graphics.polygon("line", flat_verts)
			elseif object_type == "DEBRIS" then
				local flat_verts = vec2_flatten(object.vertices)
				set_color(240, 240, 240, object.alpha)
				love.graphics.polygon("fill", flat_verts)
			elseif object_type == "DISCO_LIGHT" then
				if object.color == 1 then
					set_color(255, 100, 255, object.alpha)
				elseif object.color == 2 then
					set_color(100, 255, 100, object.alpha)
				elseif object.color == 3 then
					set_color(255, 255, 100, object.alpha)
				elseif object.color == 4 then
					set_color(100, 255, 255, object.alpha)
				end
				love.graphics.polygon("fill", vec2_flatten(object.vertices))
			elseif object_type == "STAR" then
				set_color(255, 255, 255, 200)
				love.graphics.circle("fill", object.x, object.y, 2)
			elseif object_type == "PARTICLE" then
				set_color(object.color.r, object.color.g, object.color.b, object.color.a)
				if object.shape == "CIRCLE" then
					love.graphics.circle("fill", object.x, object.y, object.radius)
				elseif object.shape == "RECT" then
					love.graphics.rectangle("fill", object.x - object.width / 2, object.y - object.height / 2, object.width, object.height)
				end
			elseif object_type == "BEAM" then
				set_color(object.color.r, object.color.g, object.color.b)
				love.graphics.polygon("fill", vec2_flatten(object.vertices))
			elseif object_type == "BEAM_BASE" then
				set_color(20, 20, 20)
				love.graphics.polygon("fill", vec2_flatten(object.vertices))
				love.graphics.setLineWidth(4)
				set_color(100, 100, 220)
				love.graphics.polygon("line", vec2_flatten(object.vertices))
			elseif object_type == "N_BACK_LIGHT" then
				set_color(20, 20, 20)
				love.graphics.polygon("fill", vec2_flatten(object.vertices))
				love.graphics.setLineWidth(4)
				set_color(100, 100, 220)
				love.graphics.polygon("line", vec2_flatten(object.vertices))
				local center = find_center(object.vertices)
				if n_back_result == "NONE" then
					set_color(20, 20, 20)
				elseif n_back_result == "SUCCESS" then
					set_color(0, 255, 0)
				elseif n_back_result == "FAIL" then
					set_color(255, 0, 0)
				end
				love.graphics.circle("fill", center.x, center.y, 12)
				set_color(100, 100, 220)
				love.graphics.circle("line", center.x, center.y, 12)
			elseif object_type == "BUTTON" then
				if object.cursor_state == "NONE" then
					set_color(20, 20, 20)
				else
					set_color(40, 40, 40)
				end
				love.graphics.rectangle("fill", object.x - object.width / 2, object.y - object.height / 2, object.width, object.height)
				love.graphics.setLineWidth(4)
				set_color(100, 100, 220)
				love.graphics.rectangle("line", object.x - object.width / 2, object.y - object.height / 2, object.width, object.height)
				love.graphics.setFont(score_font)
				if object.cursor_state == "SELECTED" then
					set_color(255, 255, 255)
				else
					set_color(100, 100, 220)
				end
				love.graphics.printf(object.text, object.x - object.width / 2, object.y - 32, object.width, "center")
			end
		end
	end
	love.graphics.pop()
	if active_scene.scene_name == "MENU" then
		set_color(255, 255, 255)
		love.graphics.setFont(score_font)
		love.graphics.printf("ERF\nTHE PLANET OF PARTY", game_width / 2 - 250, 15, 500, "center")
		love.graphics.printf("HIGHSCORE: " .. highscore, game_width / 2 - 250, game_height - 110, 500, "center")
		love.graphics.setFont(credit_font)
		local credit_string = "PROGRAMMING\nRyan Hughes\n\nDESIGN\nRyan Hughes\n\nMUSIC\nFirefly - Cybercrunk\n(CC BY-NC-ND 3.0)\n\nVOICE WORK\nSara Heres"
		love.graphics.printf(credit_string, game_width - 475, game_height / 2 - 250, 500, "center")
	elseif active_scene.scene_name == "GAME" then
		-- score
		set_color(255, 255, 255)
		love.graphics.draw(images.SKULL, game_width - 55, game_height - 55)
		love.graphics.setFont(score_font)
		local score_string = tostring(score)
		love.graphics.printf(
			score,
			game_width - 1000,
			game_height - 60,
			940,
			"right"
		)
		set_color(255, 255, 255, 255)
		for i = 1, n_back_fail_count do
			love.graphics.draw(images.CROSS, game_width - 55 - (50 * (i - 1)), game_height - 110)
		end
	elseif active_scene.scene_name == "GAME_OVER" then
		set_color(255, 255, 255)
		love.graphics.draw(images.SKULL, (game_width / 2) - 25, (game_height / 2) - 25 - 150)
		local score_string = tostring(score)
		love.graphics.printf(score_string, (game_width / 2) - 250, (game_height / 2) - 132, 500, "center")
		love.graphics.printf("HIGHSCORE: " .. highscore, game_width / 2 - 250, game_height - 110, 500, "center")
	end
	-- cursor
	set_color(255, 255, 255, 255)
	love.graphics.setLineWidth(2)
	love.graphics.circle("line", mouse_position.x, mouse_position.y, 12)
	love.graphics.line(mouse_position.x, mouse_position.y - 14, mouse_position.x, mouse_position.y + 14)
	love.graphics.line(mouse_position.x - 14, mouse_position.y, mouse_position.x + 14, mouse_position.y)
	-- transition
	if transition then
		set_color(10, 10, 10)
		love.graphics.rectangle("fill", transition.x, transition.y, transition.width, transition.height)
	end
	-- debug
	if DEBUG_MODE then
		set_color(255, 0, 0)
		love.graphics.circle("fill", mouse_position.x, mouse_position.y, 7)
		local debug_text = {}
		table.insert(debug_text, love.timer.getFPS() .. " fps")
		table.insert(debug_text, string.format("%.2f mb", collectgarbage("count") / 1000))
		table.insert(debug_text, string.format("%d ms", frame_time * 1000))
		local queue_size = #n_back_queue
		local queue_string = "["
		for i = 1, queue_size do
			queue_string = queue_string .. n_back_queue[i]
			if i < queue_size then
				queue_string = queue_string .. ", "
			end
		end
		queue_string = queue_string .. "]"
		table.insert(debug_text, queue_string)
		table.insert(debug_text, #game_objects .. " objects")
		if game_state == "PAUSE" then
			table.insert(debug_text, "PAUSE")
		end
		love.graphics.setFont(ui_font)
		set_color(0, 0, 0, 100)
		local debug_box_height = (#debug_text + 2) * ui_font:getHeight()
		love.graphics.rectangle("fill", 0, 0, 400, debug_box_height)
		set_color(255, 255, 255)
		for i = 1, #debug_text do
			love.graphics.print(
				debug_text[i],
				ui_font:getHeight(),
				i * ui_font:getHeight()
			)
		end
	end
end

function love.keypressed(key)
	if key == "`" then
		DEBUG_MODE = not DEBUG_MODE
	elseif key == "p" then
		if game_state == "PAUSE" then
			game_state = "RUN"
		elseif game_state == "RUN" then
			game_state = "PAUSE"
		end
	elseif key == "f" then
		love.window.setFullscreen(not love.window.getFullscreen())
	elseif key == "escape" then
		if active_scene.scene_name == "MENU" then
			love.event.quit()
		elseif active_scene.scene_name == "GAME" then
			change_scene("MENU", true)
		elseif active_scene.scene_name == "GAME_OVER" then
			change_scene("GAME", true)
		end
	elseif key == "space" then
		n_back_key_pressed()
	end
end

function love.quit()
	-- do nothing
end

function shake_screen(strength)
	if camera_shake_timer < strength then
		camera_shake_timer = strength
	end
end

function n_back_key_pressed()
	if not n_back_claimed and #n_back_queue > 0 then
		if n_back_queue[1] == n_back_queue[n_back_num + 1] then
			n_back_success()
		else
			n_back_fail()
		end
		n_back_claimed = true
	end
end

function n_back_fail()
	core.hp = core.hp - 100
	n_back_fail_count = n_back_fail_count + 1
	shake_screen(20)
	play_sound("N_BACK_FAIL")
	n_back_result = "FAIL"
	n_back_result_timer = n_back_result_timer_base
end

function n_back_success()
	play_sound("N_BACK_SUCCESS")
	n_back_result = "SUCCESS"
	n_back_result_timer = n_back_result_timer_base
	for i = 1, 3 do
		local beam = beams[i + 1]
		beam.is_hot = true
		beam.is_visible = true
		beam.active_timer = n_back_result_timer_base
	end
end

function push_num()
	local queue_size = #n_back_queue
	local possible_nums = {}
	for i = 1, n_back_range do
		if i ~= n_back_queue[queue_size] then
			table.insert(possible_nums, i)
		end
	end
	local next_num = possible_nums[math.random(1, #possible_nums)]
	if queue_size < n_back_num + 1 then
		table.insert(n_back_queue, next_num)
	else
		for i = 1, queue_size - 1 do
			n_back_queue[i] = n_back_queue[i + 1]
		end
		n_back_queue[queue_size] = next_num
	end
	n_back_claimed = false
	n_back_color = (n_back_color % 4) + 1
	local snd = n_back_sounds[next_num]:clone()
	snd:setPitch(math.random(98, 100) / 100)
	love.audio.play(snd)
end

function play_sound(sound)
	if sound == "EXPLOSION" then
		for i = 1, #explosion_sounds do
			local snd = explosion_sounds[i]
			if not snd:isPlaying() then
				snd:setPitch(math.random(80, 100) / 100)
				snd:play()
				break
			end
		end
	elseif sound == "SHOOT" then
		for i = 1, #shoot_sounds do
			local snd = shoot_sounds[i]
			if not snd:isPlaying() then
				snd:setPitch(math.random(90, 110) / 100)
				snd:play()
				break
			end
		end
	elseif sound == "N_BACK_SUCCESS" then
		snd = sounds.N_BACK_SUCCESS
		snd:play()
	elseif sound == "N_BACK_FAIL" then
		local snd = sounds.N_BACK_FAIL
		snd:play()
	elseif sound == "GAME_OVER" then
		local snd = sounds.GAME_OVER
		snd:play()
	elseif sound == "BUTTON" then
		local snd = sounds.BUTTON
		snd:play()
	end
end

function handle_collisions()
	for i = 1, #game_objects do
		local object = game_objects[i]
		local object_type = object.object_type
		if object_type == "BADDIE" then
			if object_on_screen(object) then
				for k = 1, #beams do
					local beam = beams[k]
					if beam.is_hot and collides_with(beam.vertices, object.vertices) then
						object.is_hurt = true
						object.hp = object.hp - 1
						if object.hp <= 0 then
							local explosion = new_object("EXPLOSION", object.x, object.y)
							score = score + 1
							baddie_count = baddie_count - 1
							object.is_alive = false
							explosion.explosion_count = 2
							local debris = new_object("DEBRIS", object.x, object.y)
							local velocity = vec2_new(math.random(-3, 3), math.random(-3, 3))
							debris.velocity = velocity
							debris.rotation_speed = math.random(-5, 5)
							local v1 = object.vertices[1]
							local v2 = object.vertices[2]
							local v3 = vec2_new(object.x, object.y)
							table.insert(debris.vertices, v1)
							table.insert(debris.vertices, v2)
							table.insert(debris.vertices, v3)
							local debris = new_object("DEBRIS", object.x, object.y)
							debris.rotation_speed = math.random(-5, 5)
							local velocity = vec2_new(math.random(-3, 3), math.random(-3, 3))
							debris.velocity = velocity
							local v1 = vec2_new(object.x, object.y)
							local v2 = object.vertices[2]
							local v3 = object.vertices[3]
							table.insert(debris.vertices, v1)
							table.insert(debris.vertices, v2)
							table.insert(debris.vertices, v3)
							play_sound("EXPLOSION")
						end
					end
				end
			end
		elseif object_type == "MISSILE" then
			local vec_to_core = vec2_new(core.x - object.x, core.y - object.y)
			local distance_to_core = vec2_length(vec_to_core)
			if distance_to_core <= core.shield_radius then
				local distance_delta = vec2_new()
				object.is_alive = false
				local particle = new_object("PARTICLE", object.x, object.y)
				particle.style = "EXPLOSION"
				local lightness = math.random(-25, 25)
				particle.color.r = 255
				particle.color.g = 0
				particle.color.b = 0
				particle.max_radius = math.random(16, 24)
				particle.radius = math.random(4, 8)
				particle.growth_rate = 1
				particle.fade_speed = 18
				particle.z = 20
				core.is_flashing = true
				core.flash_timer = core.flash_timer_base
				shake_screen(5)
				core.hp = core.hp - 1
			end
		elseif object_type == "BEAM" then
			if object.is_hot then
				local edges = {}
				local v1 = vec2_new(0, 0)
				local v2 = vec2_new(game_width, 0)
				local v3 = vec2_new(game_width, game_height)
				local v4 = vec2_new(0, game_height)
				table.insert(edges, {v1, v2})
				table.insert(edges, {v2, v3})
				table.insert(edges, {v3, v4})
				table.insert(edges, {v4, v1})
				local ray_origin = vec2_new(object.x, object.y)
				local ray_dest = vec2_new(0, 1000)
				ray_dest = vec2_rotate(ray_dest, object.rotation + 180)
				ray_dest.x = ray_dest.x + object.x
				ray_dest.y = ray_dest.y + object.y
				local ray = raycast(ray_origin, ray_dest, edges)
				if ray then
					ray = vec2_new(ray.x + game_width / 2, ray.y + game_height / 2)
					local particle = new_object("PARTICLE", ray.x, ray.y)
					local velocity = vec2_new(math.random(-1, 1) / 2, math.random(-1, 1) / 2)
					particle.velocity = velocity
					particle.style = "EXPLOSION"
					particle.color.r = object.color.r
					particle.color.g = object.color.g
					particle.color.b = object.color.b
					particle.max_radius = math.random(24, 32)
					particle.radius = math.random(8, 16)
					particle.growth_rate = 1
					particle.fade_speed = 18
					particle.z = object.z
				end
			end
		end
	end
end

function vec_to_mouse(x, y)
	return vec2_new(mouse_position.x - x, mouse_position.y - y)
end

function out_of_bounds(object)
	if object.x < -100 or object.x > game_width + 100 or object.y < -100 or object.y > game_height + 100 then
		return true
	end
	return false
end

function new_object(object_type, x, y)
	local next_id = stack_pop(game_object_id_stack)
	local object = game_object_pool[next_id]
	object.id = next_id
	object.x = x
	object.y = y
	object.z = 0
	object.rotation = 0
	object.object_type = object_type
	object.is_visible = true
	object.is_alive = true
	object.is_active = true
	if object_type == "CORE" then
		object.hp = 300
		object.cloud_rotation = 0
		object.radius = 200
		object.shield_radius = 230
		object.is_shielded = true
		object.z = 10
		object.bounce_timer = 10
		object.bounce_timer_base = 10
		object.bounce_multiplier = 1
		object.is_flashing = false
		object.flash_timer = 0
		object.flash_timer_base = 0.05
	elseif object_type == "MISSILE" then
		object.radius = 8
		object.speed = 6
		object.z = 0
	elseif object_type == "BADDIE" then
		object.hp = 2
		object.z = 5
		object.is_hurt = false
		object.speed = 3
		object.can_attack = true
		object.attack_timer = 30
		object.attack_timer_base = math.random(30, 45)
		object.vertices = {}
		local v1 = vec2_new(x - 15, y)
		local v2 = vec2_new(x, y - 30)
		local v3 = vec2_new(x + 15, y)
		table.insert(object.vertices, v1)
		table.insert(object.vertices, v2)
		table.insert(object.vertices, v3)
	elseif object_type == "DEBRIS" then
		object.z = 5
		object.alpha = 255
		object.fade_speed = 5
		object.rotation_speed = 1
		object.vertices = {}
	elseif object_type == "DISCO_LIGHT" then
		object.color = 1
		object.alpha = 255
		object.alpha_min = 200
		object.alpha_max = 255
		object.z = -10
		object.rotation_speed = 0.25
		object.color_timer = 10
		object.color_timer_base = 10
		object.hide_timer = 10
		object.hide_timer_base = 10
		object.vertices = {}
		local v1 = vec2_new(x, y)
		local target = vec2_new(0, -900)
		local v2 = vec2_add(v1, vec2_rotate(target, 10))
		local v3 = vec2_add(v1, vec2_rotate(target, -10))
		table.insert(object.vertices, v1)
		table.insert(object.vertices, v2)
		table.insert(object.vertices, v3)
	elseif object_type == "STAR" then
		object.speed = math.random(15, 20)
		object.z = -20
	elseif object_type == "PARTICLE" then
		object.style = "NORMAL"
		object.z = 2
		object.radius = 8
		object.max_radius = 12
		object.color = {r = 255, g = 255, b = 255, a = 255}
		object.speed = math.random(1, 4)
		object.fade_speed = 5
		object.growth_rate = 1
		object.shape = "CIRCLE"
	elseif object_type == "BEAM" then
		object.active_timer = 0
		object.active_timer_base = 15
		object.color = {}
		object.color.r = 255
		object.color.g = 0
		object.color.b = 0
		object.rotation_speed = 0
		object.is_hot = false
		object.z = 3
		object.vertices = {}
		object.width = 35
		object.height = math.sqrt((game_width / 2) ^ 2 + (game_height / 2) ^ 2)
		local v1 = vec2_new(x - object.width / 2, y)
		local v2 = vec2_new(x - object.width / 2, y - object.height)
		local v3 = vec2_new(x + object.width / 2, y - object.height)
		local v4 = vec2_new(x + object.width / 2, y)
		table.insert(object.vertices, v1)
		table.insert(object.vertices, v2)
		table.insert(object.vertices, v3)
		table.insert(object.vertices, v4)
	elseif object_type == "BEAM_BASE" then
		object.z = 4
		object.vertices = {}
		object.width = 70
		object.height = 60
		local v1 = vec2_new(x - object.width / 2, y - 180)
		local v2 = vec2_new(x - object.width / 2, y - object.height - 180)
		local v3 = vec2_new(x + object.width / 2, y - object.height - 180)
		local v4 = vec2_new(x + object.width / 2, y - 180)
		table.insert(object.vertices, v1)
		table.insert(object.vertices, v2)
		table.insert(object.vertices, v3)
		table.insert(object.vertices, v4)
	elseif object_type == "EXPLOSION" then
		object.explosion_count = 3
		object.explosion_spread = 32
		object.explosion_timer = 0.15
		object.explosion_timer_base = 0.15
	elseif object_type == "N_BACK_LIGHT" then
		object.z = 11
		object.vertices = {}
		object.width = 70
		object.height = 108
		local v1 = vec2_new(x - object.width / 2, y - 100)
		local v2 = vec2_new(x + 10 - object.width / 2, y - object.height - 100)
		local v3 = vec2_new(x - 10 + object.width / 2, y - object.height - 100)
		local v4 = vec2_new(x + object.width / 2, y - 100)
		table.insert(object.vertices, v1)
		table.insert(object.vertices, v2)
		table.insert(object.vertices, v3)
		table.insert(object.vertices, v4)
	elseif object_type == "BUTTON" then
		object.cursor_state = "NONE"
		object.text = "NO_TEXT"
		object.z = 20
		object.width = 300
		object.height = 100
	elseif object_type == "TRANSITION" then
		object.width = game_width
		object.height = game_height
		object.speed = 120
		object.z = 1000
		transition = object
	end
	table.insert(game_objects, object)
	return object
end

function move_object(object, x, y)
	object.x = object.x + x
	object.y = object.y + y
	if object.vertices then
		for i = 1, #object.vertices do
			local v = object.vertices[i]
			v.x = v.x + x
			v.y = v.y + y
		end
	end
end

function rotate_object(object, deg)
	object.rotation = object.rotation + deg
	for i = 1, #object.vertices do
		local v = object.vertices[i]
		local relative_vert = vec2_new(v.x - object.x, v.y - object.y)
		relative_vert = vec2_rotate(relative_vert, deg)
		relative_vert = vec2_new(relative_vert.x + object.x, relative_vert.y + object.y)
		object.vertices[i] = relative_vert
	end
end

function find_center(vertices)
	local x = 0
	local y = 0
	local count = #vertices
	for i = 1, #vertices do
		local v = vertices[i]
		x = x + v.x
		y = y + v.y
	end
	x = x / count
	y = y / count
	return vec2_new(x, y)
end

function love.quit()
	save_game()
end

function apply_velocity(object)
	if object.velocity then
		move_object(object, object.velocity.x, object.velocity.y)
	end
end

function object_on_screen(object)
	for i = 1, #object.vertices do
		local v = object.vertices[i]
		if not (v.x < 0 or v.x > game_width or v.y < 0 or v.y > game_height) then
			return true
		end
	end
	return false
end

function z_sort(a, b)
	if a.z < b.z then
		return true
	elseif a.z > b.z then
		return false
	elseif a.z == b.z then
		return a.id < b.id
	end
end
