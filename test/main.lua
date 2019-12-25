local wirefame = require("wirefame")

love.graphics.setLineStyle("rough")

love.window.setMode(1000, 1000, { vsync = false })

wirefame.defaultColor = { 1, 0, 0, 1 }

local camera = { 0, 1, 3 }

local frame = wirefame.model("frame.obj")
	:setColor(1, 1, 1)

local model = wirefame.model("metaknight.obj")
	:scale(1/15, 1/15, 1/15)
	:translate(0, -0.7, 0)

local scene = wirefame.scene()
	:setViewport(0, 0, 1000, 1000)
	:lookAt(camera, {0,0,0}, {0,1,0})
	:setViewDistance(5)
	:add(frame, model)

function love.update(dt)
	model:rotate(dt/2, {0, 1, 0})
end

function love.draw()
	love.graphics.setColor(1, 1, 1)
	love.graphics.print(love.timer.getFPS(), 5, 5)
	scene:draw()
end
