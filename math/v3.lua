--- 3D vector
local v3

local sqrt = math.sqrt

-- v3 methods
-- Unless specified otherwise, all operations are done in place and do not create a new vector.
local v3_mt = {
	-- Clone the vector. Returns a new vector.
	clone = function(self)
		return v3(self[1], self[2], self[3])
	end,

	-- Set vector
	set = function(self, other)
		self[1], self[2], self[3] = other[1], other[2], other[3]
		return self
	end,

	-- Retrieve coordinates
	unpack = function(self)
		return self[1], self[2], self[3]
	end,

	-- Normalize
	normalize = function(self)
		local x, y, z = self[1], self[2], self[3]
		local l = sqrt(x*x + y*y + z*z)
		self[1], self[2], self[3] = x/l, y/l, z/l
		return self
	end,

	-- Vector product. Returns a new vector.
	cross = function(self, other)
		local x1, y1, z1 = self[1], self[2], self[3]
		local x2, y2, z2 = other[1], other[2], other[3]
		return v3(
			y1*z2 - z1*y2,
			z1*x2 - x1*z2,
			x1*y2 - y1*x2
		)
	end,
	dot = function(self, other)
		return self[1] * other[1] + self[2] * other[2] + self[3] * other[3]
	end,

	-- Transform by a mat4
	transform = function(self, matrix)
		local x, y, z = self[1], self[2], self[3]
		-- Transform matrix * Homogeneous coordinates
		local mx = matrix[1]  * x + matrix[2]  * y + matrix[3]  * z + matrix[4]
		local my = matrix[5]  * x + matrix[6]  * y + matrix[7]  * z + matrix[8]
		local mz = matrix[9]  * x + matrix[10] * y + matrix[11] * z + matrix[12]
		local mw = matrix[13] * x + matrix[14] * y + matrix[15] * z + matrix[16]
		-- Go back to euclidian coordinates
		self[1], self[2], self[3] = mx/mw, my/mw, mz/mw
		return self
	end,

	-- Length
	len2 = function(self)
		local x, y, z = self[1], self[2], self[3]
		return x*x + y*y + z*z
	end,
	len = function(self)
		local x, y, z = self[1], self[2], self[3]
		return sqrt(x*x + y*y + z*z)
	end,

	-- Distance
	distance = function(self, other)
		return (self - other):len()
	end,
	distance2 = function(self, other)
		return (self - other):len2()
	end,

	-- Common operations. Returns a new vector.
	__sub = function(self, other)
		return v3(self[1] - other[1], self[2] - other[2], self[3] - other[3])
	end,
	__add = function(self, other)
		return v3(self[1] + other[1], self[2] + other[2], self[3] + other[3])
	end,
	__unm = function(self)
		return v3(-self[1], -self[2], -self[3])
	end,
	__div = function(self, other)
		return v3(self[1] / other, self[2] / other, self[3] / other)
	end,
	__mul = function(self, other)
		return v3(self[1] * other, self[2] * other, self[3] * other)
	end,

	__eq = function(self, other)
		return self[1] == other[1] and self[2] == other[2] and self[3] == other[3]
	end,

	__tostring = function(self)
		return ("v3(%s,%s,%s)"):format(self[1], self[2], self[3])
	end
}
v3_mt.__index = v3_mt

-- If x is a table, will reuse it without copying.
v3 = function(x, y, z)
	if type(x) == "number" then
		return setmetatable({ x, y, z }, v3_mt)
	else
		return setmetatable(x, v3_mt)
	end
end

return v3