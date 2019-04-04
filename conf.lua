function love.conf(t)
	-- enable the console (Windows)
	t.console = true
end

function love.run()
	if love.math then
		love.math.setRandomSeed(os.time())
	end

	if love.load then
		love.load(arg)
	end

	if love.timer then
		love.timer.step()
	end

	local dt = 0
	local time_accumulator = 0
	local tickrate = 30

	while true do
		if love.event then
			love.event.pump()
			for name, a,b,c,d,e,f in love.event.poll() do
				if name == "quit" then
					if not love.quit or not love.quit() then
						return a
					end
				end
				love.handlers[name](a,b,c,d,e,f)
			end
		end

		if love.timer then
			love.timer.step()
			dt = love.timer.getDelta()
		end

		time_accumulator = time_accumulator + dt

	    while time_accumulator >= 1 / tickrate do
	        time_accumulator = time_accumulator - (1 / tickrate)
			if love.update then
				love.update(1 / tickrate)
			end
	    end

		if love.graphics and love.graphics.isActive() then
			love.graphics.clear(love.graphics.getBackgroundColor())
			love.graphics.origin()
			if love.draw then
				love.draw()
			end
			love.graphics.present()
		end

		if love.timer then
			love.timer.sleep(0.001)
		end
	end
end
