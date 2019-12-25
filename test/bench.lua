local t = require("socket").gettime

--
local wirefame = require("wirefame")

function wirefame.drawLine(x0, y0, x1, y1)
	love.graphics.line(x0, y0, x1, y1)
end

local model = wirefame.open("metaknight.obj")

--
local s = t()

for _=1,100 do
	model:draw(0, 0, 1000, 1000, 255)
end

local e = t()

--
print(e-s)
