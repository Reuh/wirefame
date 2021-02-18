local wirefame = require((...):match("^(.*)%.wirefame%.light$"))
local model_mt = require((...):match("^(.*)light$").."model")
local m4, v3 = wirefame.m4, wirefame.v3

--- Light methods.
local lightType = {
	none = 0,
	ambient = 1,
	directional = 2,
	point = 3
}
local light_mt = {
	-- Rewrite model methods
	initShader = function(self, shader)
		shader:send("lights["..(self.index-1).."].type", self.type)
		shader:send("lights["..(self.index-1).."].position", self.position)
		shader:send("lights["..(self.index-1).."].color", self.color)
	end,
	onAddToScene = function(self, scene)
		self.scene = scene
		-- create array if needed
		if not scene.shader.define.LIGHT_COUNT then
			scene.shader.define.LIGHT_COUNT = 0
			scene.shader.lights = {}
		end
		-- find free spot
		self.index = nil
		for i=1, scene.shader.define.LIGHT_COUNT, 1 do
			if not scene.shader.lights[i] then
				self.index = i
				self:initShader() -- update already existing array in shader
				break
			end
		end
		if not self.index then -- create new spot
			scene.shader.define.LIGHT_COUNT = scene.shader.define.LIGHT_COUNT + 1
			self.index = scene.shader.define.LIGHT_COUNT
			scene.shader.changed = true
		end
		-- register oneself
		scene.shader.lights[self.index] = true
	end,
	onRemoveFromScene = function(self, scene)
		self.scene = nil
		-- unregister oneself
		scene.shader.lights[self.index] = nil
		-- recalculate minimal array size
		for i=scene.shader.define.LIGHT_COUNT, 1, -1 do
			if scene.shader.lights[i] then
				break
			else
				scene.shader.define.LIGHT_COUNT = scene.shader.define.LIGHT_COUNT - 1 -- will update on next recompile, nothing is urgent
			end
		end
		-- update oneself in shader
		scene.shader.shader:send("lights["..(self.index-1).."].type", lightType.none)
	end,
	sendFinalTransform = function(self, tr)
		self.position = v3(0,0,0):transform(tr)
	end,
	draw = function(self, shader, transp)
		-- Draw
		if shader:hasUniform("lights["..(self.index-1).."].position") then
			self:updateFinalTransform()
			shader:send("lights["..(self.index-1).."].position", self.position)
			shader:send("lights["..(self.index-1).."].color", self.color)
		end
	end,
	__tostring = function(self)
		local mt = getmetatable(self)
		setmetatable(self, nil)
		local str = "light: "..(tostring(self):gsub("^table: ", ""))
		setmetatable(self, mt)
		return str
	end
}
for k, v in pairs(model_mt) do
	if light_mt[k] == nil then
		light_mt[k] = v
	end
end
light_mt.__index = light_mt

--- Create a light object
function wirefame.light(type)
	local light = {
		-- Light
		type = lightType[type],
		position = v3(0, 0, 0),

		-- Color
		color = { wirefame.defaultColor[1], wirefame.defaultColor[2], wirefame.defaultColor[3], wirefame.defaultColor[4] },

		-- Size
		n = 1,
		true,

		-- Tags
		tags = {},

		-- Group transformation matrices
		transformStack = { n = 1, changed = true, names = {}, [0] = m4.identity(), m4.identity() },
		finalTransform = nil,

		-- Empty model object
		object = {},

		-- Hierarchy
		parent = nil,
		scene = nil
	}

	-- Create & return object
	return setmetatable(light, light_mt)
end

return light_mt
