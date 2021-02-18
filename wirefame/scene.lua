local wirefame = require((...):match("^(.*)%.wirefame%.scene$"))
local group_mt = require((...):match("^(.*)scene$").."group")
local m4, v3 = wirefame.m4, wirefame.v3
local lg = love.graphics

-- Global shaders
local pickShader = lg.newShader(wirefame.shader.pick)

--- Scene methods
local scene_mt = {
	--- Set the projection matrix.
	setPerspective = function(self, fovy, ratio, near, far)
		return self:setTransform(3, m4.perspective(fovy, ratio, near, far))
	end,

	--- Sets the view and projection matrix.
	lookAt = function(self, eye, center, up)
		self.camera = v3(eye)
		return self:setTransform(2, m4.lookAt(eye, center, up))
	end,

	--- Rebuild the shader
	rebuildShader = function(self)
		if self.shader.changed then
			if self.shader.shader then self.shader.shader:release() end
			local s = ""
			for var, val in pairs(self.shader.define) do
				s = s .. ("# define %s %s"):format(var, val) .. "\n"
			end
			s = s .. wirefame.shader.render
			self.shader.shader = lg.newShader(s)
			self.shader.shader:send("scene_transform", m4.identity())
			self.shader.shader:send("model_transform", m4.identity())
			for _, model in ipairs(self) do model:initShader(self.shader.shader) end
			self.shader.changed = false
		end
		return self.shader.shader
	end,

	--- Draw the scene.
	draw = function(self)
		-- Init shader
		local shader = self:rebuildShader()

		-- Calculate transformation matrix
		shader:send("scene_transform", self:updateFinalTransform())

		-- Draw models
		lg.setShader(shader)
		for _, model in ipairs(self) do
			model:draw(shader, false) -- draw opaque models
		end
		for _, model in ipairs(self) do
			model:draw(shader, true) -- draw transparent models
		end
		lg.setShader()
	end,

	--- Returns the object visible at x, y on the screen.
	pick = function(self, x, y)
		local canvas = lg.newCanvas()

		-- Calculate transformation matrix
		pickShader:send("scene_transform", m4.scale{1, -1, 1} * self:updateFinalTransform())

		-- Draw models
		lg.setCanvas{canvas, depth = true}
		lg.setShader(pickShader)
		local r, g, b = 0, 0, 0
		for _, model in ipairs(self) do
			if r < 255 then
				r = r+1
			elseif g < 255 then
				g = g+1
			elseif b < 255 then
				b = b+1
			else
				error("too many object to pick from")
			end
			pickShader:send("pick_color", {r/255, g/255, b/255})
			model:draw(pickShader, false)
		end
		r, g, b = 0, 0, 0
		for _, model in ipairs(self) do
			if r < 255 then
				r = r+1
			elseif g < 255 then
				g = g+1
			elseif b < 255 then
				b = b+1
			end
			pickShader:send("pick_color", {r/255, g/255, b/255})
			model:draw(pickShader, true)
		end
		lg.setShader()
		love.graphics.setCanvas()

		-- Pick object
		r, g, b = canvas:newImageData():getPixel(x, y)
		local i = math.floor(r*255) + math.floor(g*255)*255 + math.floor(b*255)*255*255
		return self[i]
	end,

	-- Redefine some group methods (main change is not passing scene transform to children)
	add = function(self, ...)
		for _, m in ipairs({...}) do
			self.n = self.n + 1
			table.insert(self, m)
			if m.parent == nil then
				m.parent = self
				if self.scene then
					m:onAddToScene(self.scene)
				end
			end
		end
		return self
	end,
	sendFinalTransform = function(self, tr)
		-- scene final transform is applied in shader
	end,
	__tostring = function(self)
		local mt = getmetatable(self)
		setmetatable(self, nil)
		local str = "scene: "..(tostring(self):gsub("^table: ", ""))
		setmetatable(self, mt)
		return str
	end

	-- And every group method
}
for k, v in pairs(group_mt) do
	if scene_mt[k] == nil then
		scene_mt[k] = v
	end
end
scene_mt.__index = scene_mt

--- Create a scene.
wirefame.scene = function()
	local scene = {
		-- Other scene variables
		camera = v3(0, 0, 0), -- camera position
		shader = {
			changed = true, -- rebuild shader
			define = {}, -- map of variables to define in the shader
			shader = nil, -- the shader
			lights = {} -- list of used lights slots, see light_mt
		},

		-- Size
		n = 0,

		-- Tags
		tags = {},

		-- Scene transformation matrices
		transformStack = {
			n = 4,
			changed = true,
			names = {},
			[0] = m4.identity(),
			m4.identity(), -- Custom: user-defined transformation to the models world coordinates in the scene (excluding camera)
			m4.identity(), -- View: world coordinates -> camera coordinates
			m4.identity(), -- Projection: camera coordinates -> perspective camera coordinates
			m4.identity(), -- Viewport: perspective camera coordinates -> screen coordinates
		},
		finalTransform = nil,

		-- Group color
		color = { wirefame.defaultColor[1], wirefame.defaultColor[2], wirefame.defaultColor[3], wirefame.defaultColor[4] },

		-- Hierarchy
		parent = nil,
		scene = nil
	}
	scene.scene = scene

	-- enable depth buffer (lequal instead of less in order to allow regular 2D drawing (constant depth value))
	lg.setDepthMode("lequal", true)

	-- enable back face culling
	lg.setFrontFaceWinding("ccw")
	lg.setMeshCullMode("back")

	-- Create & return object
	return setmetatable(scene, scene_mt)
end

return scene_mt
