local wirefame = require((...):match("^(.*)%.wirefame%.group$"))
local model_mt = require((...):match("^(.*)group$").."model")
local m4, v3, bb3, bs3 = wirefame.m4, wirefame.v3, wirefame.bb3, wirefame.bs3
local unpack = table.unpack or unpack

--- Group methods.
local group_mt = {
	--- Add a model to the node.
	add = function(self, ...)
		assert(not self.filtered, "can't add to a filtered group")
		for _, m in ipairs({...}) do
			self.n = self.n + 1
			table.insert(self, m)
			if m.parent == nil then
				m.parent = self
				if self.scene then
					m:onAddToScene(self.scene)
				end
				m:setTransform(0, self:updateFinalTransform())
			end
		end
		return self
	end,

	--- Remove a model from the node.
	remove = function(self, ...)
		assert(not self.filtered, "can't remove from a filtered group")
		for _, m in ipairs({...}) do
			for i=1, self.n do
				if self[i] == m then
					self.n = self.n - 1
					table.remove(self, i)
					m.parent = nil
					if m.scene then
						m:onRemoveFromScene(m.scene)
					end
					return self
				end
			end
		end
		error("can't find model to remove")
	end,

	--- All these methods and properties of model are present, but operate on the whole group.

	-- Overwrite some model methods:
	onAddToScene = function(self, scene)
		self.scene = scene
		for i=1, self.n do
			self[i]:onAddToScene(scene)
		end
	end,
	onRemoveFromScene = function(self, scene)
		self.scene = nil
		for i=1, self.n do
			self[i]:onRemoveFromScene(scene)
		end
	end,
	get = function(self, ...)
		local l = {}
		for i=1, self.n do
			local il = self[i]:get(...)
			if #il > 0 then
				table.insert(l, il)
			end
		end
		l.n = #l
		l.filtered = true
		return setmetatable(l, {__index = self, __tostring = self.__tostring})
	end,
	boundingBox = function(self)
		if #self > 0 then
			self:updateFinalTransform()
			local r = self[1]:boundingBox()
			for i=2, self.n do
				r:include(self[i]:boundingBox())
			end
			return r
		else
			return bb3(v3(0,0,0), v3(0,0,0))
		end
	end,
	boundingSphere = function(self)
		if #self > 0 then
			self:updateFinalTransform()
			local r = self[1]:boundingSphere()
			for i=2, self.n do
				r:include(self[i]:boundingSphere())
			end
			return r
		else
			return bs3(v3(0,0,0), 0)
		end
	end,
	initShader = function(self, shader)
		for i=1, self.n do
			self[i]:initShader(shader)
		end
	end,
	sendFinalTransform = function(self, tr)
		if self.filtered then self = getmetatable(self).__index end
		for i=1, self.n do
			self[i]:setTransform(0, tr)
		end
	end,
	setColor = function(self, r, g, b, a) -- apply color to all children
		self.color[1], self.color[2], self.color[3], self.color[4] = r, g, b, a or 1
		for i=1, self.n do
			self[i]:setColor(r, g, b, a)
		end
		return self
	end,
	draw = function(self, shader, transp)
		-- Transparency sort
		if transp then
			if self.color[4] >= 1 then return end
		else
			if self.color[4] < 1 then return end
		end

		-- Transformation matrix
		self:updateFinalTransform()

		-- Draw
		for i=1, self.n do
			self[i]:draw(shader, transp)
		end
	end,

	__tostring = function(self)
		local mt = getmetatable(self)
		setmetatable(self, nil)
		local str = "group: "..(tostring(self):gsub("^table: ", ""))
		setmetatable(self, mt)
		return str
	end
}
for k, v in pairs(model_mt) do
	if group_mt[k] == nil then
		group_mt[k] = v
	end
end
group_mt.__index = group_mt

--- Create a group of models.
function wirefame.group(t)
	local group = {
		-- Size
		n = 0,

		-- Tags
		tags = {},

		-- Group transformation matrices
		transformStack = { n = 1, changed = true, names = {}, [0] = m4.identity(), m4.identity() },
		finalTransform = nil,

		-- Group color
		color = { wirefame.defaultColor[1], wirefame.defaultColor[2], wirefame.defaultColor[3], wirefame.defaultColor[4] },

		-- Hierarchy
		parent = nil,
		scene = nil
	}

	-- Create & return object
	return setmetatable(group, group_mt):add(unpack(t))
end

return group_mt
