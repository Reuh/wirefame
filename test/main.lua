require("candran").setup()
local wirefame = require("wirefame")

love.graphics.setLineStyle("rough")

love.window.setMode(1000, 1000, { vsync = false })

wirefame.defaultColor = { 1, 0, 0, 1 }

local model = wirefame.model("test/Duck.gltf")
	:setColor(1, 1, 1)

local img = wirefame.model(love.graphics.newImage("hyke.png")):scale{1/100, 1/100, 1/100}

-- local model = wirefame.model("test/metaknight.obj")
-- 	:scale{1/15, 1/15, 1/15}
-- 	:translate{0, -0.7, 0}

local scene = wirefame.scene()
	:setPerspective(math.rad(60), 1, .1, 100)
	:lookAt({0,0,3}, {0,0,0}, {0,1,0})
	:add(model, img)

function love.update(dt)
	scene:rotate(dt/2, {0, 1, 0})
end

function love.draw()
	love.graphics.setColor(1, 1, 1)
	love.graphics.print(love.timer.getFPS(), 5, 5)
	scene:draw()
end
