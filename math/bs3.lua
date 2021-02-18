--- 3D bounding sphere
local bs3

local v3 = require((...):match("^(.*)bs3$").."v3")

-- bs3 methods
-- Unless specified otherwise, all operations are done in place and do not create a bounding sphere.
local bs3_mt = {
	-- Clone the bounding sphere. Returns a new bounding sphere.
	clone = function(self)
		return bs3(self.center:clone(), self.radius)
	end,

	-- Set bounding sphere
	set = function(self, center, radius)
		self.center:set(center)
		self.radius = radius
		return self
	end,

	-- Retrieve center vectors and radius
	unpack = function(self)
		return self.center, self.radius
	end,

	-- Test if the bounding sphere collide with another bounding sphere, bounding box or point
	collide = function(self, other)
		if other.radius then -- bs3
			return (self.center[1] - other.center[1]) * (self.center[1] - other.center[1]) +
			       (self.center[2] - other.center[2]) * (self.center[2] - other.center[2]) +
			       (self.center[3] - other.center[3]) * (self.center[3] - other.center[3])
			       <= (self.radius + other.radius) * (self.radius + other.radius)
		elseif other.min then -- bb3
			local x = math.max(other.min[1], math.min(self.center[1], other.max[1]))
			local y = math.max(other.min[2], math.min(self.center[2], other.max[2]))
			local z = math.max(other.min[3], math.min(self.center[3], other.max[3]))
			return (self.center[1] - x) * (self.center[1] - x) +
			       (self.center[2] - y) * (self.center[2] - y) +
			       (self.center[3] - z) * (self.center[3] - z)
			       <= self.radius * self.radius
		else -- v3
			return (self.center[1] - other[1]) * (self.center[1] - other[1]) +
			       (self.center[2] - other[2]) * (self.center[2] - other[2]) +
			       (self.center[3] - other[3]) * (self.center[3] - other[3])
			       <= self.radius * self.radius
		end
	end,

	-- Extend the bounding sphere by v (number)
	extend = function(self, v)
		self.radius = self.radius + v
		return self
	end,

	-- Modify the bounding sphere so that it include v (v3 or bs3)
	include = function(self, v)
		if v.min then -- bounding sphere
			self.radius = (self.center:distance(v.center) + self.radius + v.radius) / 2
			self.center = v.center + (self.center - v.center):normalize() * (self.radius - v.radius)
		else -- vector
			self.radius = (self.center:distance(v) + self.radius) / 2
			self.center = v + (self.center - v):normalize() * self.radius
		end
		return self
	end,

	-- Common operations with vectors. Returns a new bounding box.
	__sub = function(self, other)
		return bs3(self.center - other, self.radius)
	end,
	__add = function(self, other)
		return bs3(self.center + other, self.radius)
	end,
	__unm = function(self)
		return bs3(-self.center, self.radius)
	end,
	__div = function(self, other)
		return bs3(self.center, self.radius / other)
	end,
	__mul = function(self, other)
		return bs3(self.center, self.radius * other)
	end,

	__tostring = function(self)
		return ("bs3(%s,%s)"):format(self.center, self.radius)
	end
}
bs3_mt.__index = bs3_mt

bs3 = setmetatable({
	-- Calculate the mesh's bounding sphere. Returns a new bounding sphere.
	fromMesh = function(mesh, tr)
		local bs

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
			bs = bs3(v:clone(),0)
			for i=min+1, max do
				v = v3(mesh:getVertexAttribute(vmap[i], iposition))
				if tr then v:transform(tr) end
				bs:include(v)
			end
		else
			local min, max = mesh:getDrawRange()
			if not min then
				min, max = 1, mesh:getVertexCount()
			end
			local v = v3(mesh:getVertexAttribute(min, iposition))
			if tr then v:transform(tr) end
			bs = bs3(v:clone(),0)
			for i=min+1, max do
				v = v3(mesh:getVertexAttribute(i, iposition))
				if tr then v:transform(tr) end
				bs:include(v)
			end
		end

		return bs
	end
}, {
	-- center will not be copied.
	__call = function(self, center, radius)
		return setmetatable({ center = v3(center), radius = radius }, bs3_mt)
	end
})

return bs3