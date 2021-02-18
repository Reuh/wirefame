local wirefame = require((...):match("^(.*)%.wirefame%.model$"))
local m4, v3, bb3, bs3 = wirefame.m4, wirefame.v3, wirefame.bb3, wirefame.bs3
local unpack = table.unpack or unpack
local lg = love.graphics

-- Model methods.
local model_mt = {
	--- Called when the model is added to a scene.
	onAddToScene = function(self, scene)
		self.scene = scene
	end,

	--- Called when the model is removed from a scene.
	onRemoveFromScene = function(self, scene)
		self.scene = nil
	end,

	--- Create a new group containing this entity
	group = function(self)
		return wirefame.group{self}
	end,

	-- Add tags on this model only.
	tag = function(self, ...)
		for _, t in ipairs({...}) do
			self.tags[t] = true
		end
		return self
	end,
	-- Check tags on this model only.
	is = function(self, ...)
		local r = true
		for _, t in ipairs({...}) do
			r = r and self.tags[t]
		end
		return r
	end,
	-- List tags on this model only.
	listTags = function(self)
		local r = {}
		for t, _ in pairs(self.tags) do
			table.insert(r, t)
		end
		return r
	end,

	--- Get a new group of all models recursively contained in this object with these tags.
	get = function(self, ...)
		if self:is(...) then
			return self
		else
			return wirefame.group{}
		end
	end,

	--- Apply a transformation matrix to the model vertices coordinates.
	-- If no i is given, will transform the first matrix.
	transform = function(self, i, tr)
		if not tr then
			i, tr = 1, i
		elseif type(i) == "string" then
			i = self.transformStack.names[i]
		end
		self.transformStack[i]:transform(tr)
		self.transformStack.changed = true
		return self
	end,
	--- Retrieve the ith transformation matrix.
	-- If no i is given, will retrieve the first matrix.
	getTransform = function(self, i)
		if not i then
			i = 1
		elseif type(i) == "string" then
			i = self.transformStack.names[i]
		end
		return self.transformStack[i]
	end,
	--- Set the ith transformation matrix.
	-- If no i is given, will set the first matrix.
	setTransform = function(self, i, tr)
		if not tr then
			i, tr = 1, i
		elseif type(i) == "string" then
			i = self.transformStack.names[i]
		end
		self.transformStack[i] = tr
		self.transformStack.changed = true
		return self
	end,
	--- Reset the ith transformation matrix.
	-- If no i is given, will reset the first matrix.
	resetTransform = function(self, i)
		if not i then
			i = 1
		end
		self.transformStack[i] = m4.identity()
		self.transformStack.changed = true
		return self
	end,

	--- Set the whole transformation stack.
	setTransformStack = function(self, stack)
		self.transformStack = { names = self.transformStack.names, [0] = self.transformStack[0] }
		for i, tr in ipairs(stack) do
			self.transformStack[i] = tr
		end
		self.transformStack.n = #self.transformStack
		self.transformStack.changed = true
		return self
	end,
	--- Retrieve the whole transformation stack.
	getTransformStack = function(self)
		return self.transformStack
	end,
	--- Set the size of the transformation stack, initiatializing new transformations matrices if needed.
	setTransformStackSize = function(self, n)
		self.transformStack.n = n
		for i=1, self.transformStack.n, 1 do
			if self.transformStack[i] == nil then
				self.transformStack[i] = m4.identity()
			end
		end
		self.transformStack.changed = true
		return self
	end,
	--- Assign to each transform in the transformation stack a name and resize the transformation stack to match.
	setTransformNames = function(self, list)
		self:setTransformStackSize(#list)
		local names = {}
		for i, name in ipairs(list) do
			names[name] = i
		end
		self.transformStack.names = names
		return self
	end,
	--- Retrieve the transformation names.
	getTransformNames = function(self, list)
		local names = {}
		for name, i in pairs(self.transformStack.names) do
			names[i] = name
		end
		return names
	end,
	--- Assign a name to the transform i.
	setTransformName = function(self, i, name)
		self.transformStack.names[name] = i
		return self
	end,

	--- Calculate the final transformation matrix if needed, and send it to eventual children (using :sendFinalTransform).
	-- Returns the transform.
	updateFinalTransform = function(self)
		if self.transformStack.changed then
			self.finalTransform = m4.identity()
			for i=1, self.transformStack.n, 1 do
				self.finalTransform:transform(self.transformStack[i])
			end
			self.finalTransform:transform(self.transformStack[0])
			self.transformStack.changed = false
			self:sendFinalTransform(self.finalTransform)
		end
		return self.finalTransform
	end,

	--- Send the final transformation matrix to the eventual children objects.
	sendFinalTransform = function(self, tr)
		if self.object.setTransform then
			self.object:setTransform(tr)
		end
	end,

	--- Common tranforms
	translate = function(self, i, v)
		if v then
			return self:transform(i, m4.translate(v))
		else
			return self:transform(m4.translate(i))
		end
	end,
	scale = function(self, i, v)
		if v then
			return self:transform(i, m4.scale(v))
		else
			return self:transform(m4.scale(i))
		end
	end,
	rotate = function(self, i, a, v)
		if v then
			return self:transform(i, m4.rotate(a, v))
		else
			return self:transform(m4.rotate(i, a))
		end
	end,
	shear = function(self, i, vxy, vyz)
		if vyz then
			return self:transform(i, m4.shear(vxy, vyz))
		else
			return self:transform(m4.shear(i, vxy))
		end
	end,

	--- Returns the minimum bounding box.
	boundingBox = function(self)
		if self.object.boundingBox then
			return self.object:boundingBox(self:updateFinalTransform())
		else
			return bb3(v3(0,0,0), v3(0,0,0))
		end
	end,
	--- Returns the minimum bounding sphere.
	boundingSphere = function(self)
		if self.object.boundingSphere then
			return self.object:boundingSphere(self:updateFinalTransform())
		else
			return bs3(v3(0,0,0), 0)
		end
	end,

	--- Sets the color used to draw the model.
	setColor = function(self, r, g, b, a)
		self.color[1], self.color[2], self.color[3], self.color[4] = r, g, b, a or 1
		return self
	end,
	getColor = function(self)
		return self.color[1], self.color[2], self.color[3], self.color[4]
	end,

	--- Initialize all relevant uniforms in the shader (called after shader rebuild)
	initShader = function(self, shader)
	end,

	-- Draw the model. Shader may be either render or pick.
	draw = function(self, shader, transp)
		if self.object.draw then
			-- Transparency sort
			if transp then
				if self.color[4] >= 1 then return end
			else
				if self.color[4] < 1 then return end
			end

			-- Transformation matrix (will automatically update object that need to know the matrix)
			shader:send("model_transform", self:updateFinalTransform())

			-- Draw
			lg.setColor(self.color)
			self.object:draw(shader)
		end
	end,

	__tostring = function(self)
		local mt = getmetatable(self)
		setmetatable(self, nil)
		local str = "model: "..(tostring(self):gsub("^table: ", ""))
		setmetatable(self, mt)
		return str
	end
}
model_mt.__index = model_mt

--- Loads an .obj/.iqe file, or import a LÖVE drawable, or import a drawing function, or create a empty model.
function wirefame.model(object)
	local model = {
		-- Size
		n = 1,
		true,

		-- Tags
		tags = {},

		-- Model transformation matrices. Matrix 0 is the transform inherited from parent chain.
		transformStack = { n = 1, changed = true, names = {}, [0] = m4.identity(), m4.identity() },
		finalTransform = nil,

		-- Model color
		color = { wirefame.defaultColor[1], wirefame.defaultColor[2], wirefame.defaultColor[3], wirefame.defaultColor[4] },

		-- Model object
		-- object:draw(shader)
		-- object:setTransform(tr)
		-- object:boundingBox(tr)
		-- object:boundingSphere(tr)
		object = nil,

		-- Hierarchy
		parent = nil,
		scene = nil
	}

	-- Empty model
	if object == nil then
		model.object = {}
	-- Load a model file
	elseif type(object) == "string" then
		local ext = object:match("%.(.-)$") or ""
		if wirefame.loader[ext] then
			model.object = wirefame.loader[ext](object)
		else
			error(("unknown model type %s"):format(ext))
		end
	-- Function
	elseif type(object) == "function" then
		model.object = { draw = object }
	-- Convertible to LÖVE meshes.
	elseif type(object) == "userdata" then
		if object:type() == "Image" or object:type() == "Canvas" then
			local t = lg.newMesh({
				{ "VertexPosition", "float", 3 },
				{ "VertexTexCoord", "float", 2 },
				{ "VertexColor",    "byte",  4 },
				{ "VertexNormal",   "float", 3 }
			},
			{
				{
					0, 0, 0,
					0, 1,
					1, 1, 1, 1,
					0, 0, 1
				},
				{
					object:getWidth(), 0, 0,
					1, 1,
					1, 1, 1, 1,
					0, 0, 1
				},
				{
					object:getWidth(), object:getHeight(), 0,
					1, 0,
					1, 1, 1, 1,
					0, 0, 1
				},
				{
					0, object:getHeight(), 0,
					0, 0,
					1, 1, 1, 1,
					0, 0, 1
				}
			}, "fan")
			t:setVertexMap(1, 2, 3, 4)
			t:setTexture(object)
			model.object = {
				draw = function()
					lg.draw(t)
				end,
				boundingBox = function(self, tr)
					return bb3.fromMesh(t, tr)
				end,
				boundingSphere = function(self, tr)
					return bs3.fromMesh(t, tr)
				end
			}
		elseif object:type() == "Mesh" then
			model.object = {
				draw = function()
					lg.draw(object)
				end,
				boundingBox = function(self, tr)
					return bb3.fromMesh(object, tr)
				end,
				boundingSphere = function(self, tr)
					return bs3.fromMesh(t, tr)
				end
			}
		else
			error("unknown userdata")
		end
	else
		model.object = object
	end

	-- Create & return object
	return setmetatable(model, model_mt)
end

return model_mt
