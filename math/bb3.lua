--- Axis aligned 3D bounding box
local bb3

local v3 = require((...):match("^(.*)bb3$").."v3")

-- bb3 methods
-- Unless specified otherwise, all operations are done in place and do not create a bounding box.
local bb3_mt = {
	-- Clone the bounding box. Returns a new bounding box.
	clone = function(self)
		return bb3(self.min:clone(), self.max:clone())
	end,

	-- Set bounding box
	set = function(self, min, max)
		self.min, self.max = v3(min), v3(max)
		return self
	end,

	-- Retrieve min and max vectors
	unpack = function(self)
		return self.min, self.max
	end,

	-- Test if the bounding box collide with another bounding box, bounding sphere or point
	collide = function(self, other)
		if other.min then -- bb3
			return self.min[1] <= other.max[1] and self.max[1] >= other.min[1] and
			       self.min[2] <= other.max[2] and self.max[2] >= other.min[2] and
			       self.min[3] <= other.max[3] and self.max[3] >= other.min[3]
		elseif other.radius then -- bs3
			return other:collide(self)
		else -- v3
			return self.min[1] <= other[1] and self.max[1] >= other[1] and
			       self.min[2] <= other[2] and self.max[2] >= other[2] and
			       self.min[3] <= other[3] and self.max[3] >= other[3]
		end
	end,

	-- Extend the bounding box by v:
	-- * number: extend by a certain distance from the center
	-- * v3: extend each axis by the associated vector coordinate
	extend = function(self, v)
		if type(v) == "number" then
			self.min = self.min - { v, v, v }
			self.max = self.max + { v, v, v }
		else
			self.min = self.min - v
			self.max = self.max + v
		end
		return self
	end,

	-- Modify the bounding box so that it include v (v3 or bb3)
	include = function(self, v)
		if v.min then -- bounding box
			self.min[1] = math.min(self.min[1], v.min[1])
			self.min[2] = math.min(self.min[2], v.min[2])
			self.min[3] = math.min(self.min[3], v.min[3])
			self.max[1] = math.max(self.max[1], v.max[1])
			self.max[2] = math.max(self.max[2], v.max[2])
			self.max[3] = math.max(self.max[3], v.max[3])
		else -- vector
			self.min[1] = math.min(self.min[1], v[1])
			self.min[2] = math.min(self.min[2], v[2])
			self.min[3] = math.min(self.min[3], v[3])
			self.max[1] = math.max(self.max[1], v[1])
			self.max[2] = math.max(self.max[2], v[2])
			self.max[3] = math.max(self.max[3], v[3])
		end
		return self
	end,

	-- Common operations with vectors. Returns a new bounding box.
	__sub = function(self, other)
		return bb3(self.min - other, self.max - other)
	end,
	__add = function(self, other)
		return bb3(self.min + other, self.max + other)
	end,
	__unm = function(self)
		return bb3(-self.min, -self.max)
	end,

	__tostring = function(self)
		return ("bb3(%s,%s)"):format(self.min, self.max)
	end
}
bb3_mt.__index = bb3_mt

bb3 = setmetatable({
	-- Calculate the mesh's bounding box. Returns a new bounding box.
	fromMesh = function(mesh, tr)
		local bb

		-- Get VertexPosition attribute index in vertex data
		local iposition
		for i, t in ipairs(mesh:getVertexFormat()) do
			if t[1] == "VertexPosition" then
				if t[3] ~= 3 then error("mesh vertices don't have a 3 dimensional position") end
				iposition = i
				break
			end
		end
		if not iposition then error("mesh doesn't have VertexPosition attributes") end

		-- Retrieve vertices
		local vmap = mesh:getVertexMap()
		if vmap then
			local min, max = mesh:getDrawRange()
			if not min then
				min, max = 1, #vmap
			end
			local v = v3(mesh:getVertexAttribute(vmap[min], iposition))
			if tr then v:transform(tr) end
			bb = bb3(v:clone(),v:clone())
			for i=min+1, max do
				v = v3(mesh:getVertexAttribute(vmap[i], iposition))
				if tr then v:transform(tr) end
				bb:include(v)
			end
		else
			local min, max = mesh:getDrawRange()
			if not min then
				min, max = 1, mesh:getVertexCount()
			end
			local v = v3(mesh:getVertexAttribute(min, iposition))
			if tr then v:transform(tr) end
			bb = bb3(v:clone(),v:clone())
			for i=min+1, max do
				v = v3(mesh:getVertexAttribute(i, iposition))
				if tr then v:transform(tr) end
				bb:include(v)
			end
		end

		return bb
	end
}, {
	-- min and max will not be copied.
	__call = function(self, min, max)
		return setmetatable({ min = v3(min), max = v3(max) }, bb3_mt)
	end
})

return bb3