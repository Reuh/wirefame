--- Quaternion
local qt

local sin, cos = math.sin, math.cos
local m4 = require((...):match("^(.*)qt$").."m4")

-- qt methods
-- Unless specified otherwise, all operations are done in place and do not create a new quaternion.
local qt_mt = {
	-- Clone the quaternion. Returns a new quaternion.
	clone = function(self)
		return qt(self[1], self[2], self[3], self[4])
	end,

	-- Set quaternion
	set = function(self, other)
		self[1], self[2], self[3], self[4] = other[1], other[2], other[3], other[4]
		return self
	end,

	-- Retrieve coordinates
	unpack = function(self)
		return self[1], self[2], self[3], self[4]
	end,

	-- Convert to m4 rotation matrix. Returns a new 4x4 matrix.
	toM4 = function(self)
		local x, y, z, w = self[1], self[2], self[3], self[4]
		local xx, yy, zz = x*x, y*y, z*z
		local xw, xy, xz = x*w, x*y, x*z
		local yw, yz = y*w, y*z
		local zw = z*w
		return m4{
			1-2*(yy+zz), 2*(xy-zw),   2*(xz+yw),   0,
			2*(xy+zw),   1-2*(xx+zz), 2*(yz-xw),   0,
			2*(xz-yw),   2*(yz+xw),   1-2*(xx+yy), 0,
			0,           0,           0,           1
		}
	end,

	-- Common operations. Returns a new quaternion.
	__sub = function(self, other)
		return qt(self[1] - other[1], self[2] - other[2], self[3] - other[3], self[4] - other[4])
	end,
	__add = function(self, other)
		return qt(self[1] + other[1], self[2] + other[2], self[3] + other[3], self[4] - other[4])
	end,
	__unm = function(self)
		return qt(-self[1], -self[2], -self[3], -self[4])
	end,
	__mul = function(self, other)
		local sx, sy, sz, sw = self[1], self[2], self[3], self[4]
		local ox, oy, oz, ow = other[1], other[2], other[3], other[4]
		return qt(sw * ow - sx * ox - sy * oy - sz * oz, sx * ow + sw * ox + sy * oz - sz * oy, sy * ow + sw * oy + sz * ox - sx * oz, sz * ow + sw * oz + sx * oy - sy * ox)
	end,

	__eq = function(self, other)
		return self[1] == other[1] and self[2] == other[2] and self[3] == other[3] and self[4] == other[4]
	end,

	__tostring = function(self)
		return ("qt(%s,%s,%s,%s)"):format(self[1], self[2], self[3], self[4])
	end
}
qt_mt.__index = qt_mt

qt = setmetatable({
	--- Create a new identity quaternion
	identity = function()
		return qt(0, 0, 0, 1)
	end,

	--- Create a new quaternion from a rotation
	fromAngleAxis = function(angle, axis)
		local halfAngle = angle / 2
		local s = sin(halfAngle)
		return qt(axis[1] * s, axis[2] * s, axis[3] * s, cos(halfAngle))
	end,
}, {
	-- If x is a table, will reuse it without copying.
	__call = function(self, x, y, z, w)
		if type(x) == "number" then
			return setmetatable({ x, y, z, w }, qt_mt)
		else
			return setmetatable(x, qt_mt)
		end
	end
})

return qt