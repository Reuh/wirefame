--- 4x4 matrix.
-- Reminder: they are represented in row-major order, **unlike** GLM which is column-major.
local m4

local cos, sin, tan = math.cos, math.sin, math.tan
local v3 = require((...):match("^(.*)m4$").."v3")

local tmpv3 = v3(0,0,0) -- temporary vector used in our computations

-- m4 methods
-- Unless specified otherwise, all operations are done in place and do not create a new matrix.
local m4_mt = {
	-- Clone the matrix. Returns a new matrix.
	clone = function(self)
		return m4{
			self[1],  self[2],  self[3],  self[4],
			self[5],  self[6],  self[7],  self[8],
			self[9],  self[10], self[11], self[12],
			self[13], self[14], self[15], self[16]
		}
	end,

	-- Set matrix
	set = function(self, other)
		self[1],  self[2],  self[3],  self[4]  = other[1],  other[2],  other[3],  other[4]
		self[5],  self[6],  self[7],  self[8]  = other[5],  other[6],  other[7],  other[8]
		self[9],  self[10], self[11], self[12] = other[9],  other[10], other[11], other[12]
		self[13], self[14], self[15], self[16] = other[13], other[14], other[15], other[16]
		return self
	end,

	-- Retrieve values
	unpack = function(self)
		return self[1],  self[2],  self[3],  self[4],
			   self[5],  self[6],  self[7],  self[8],
			   self[9],  self[10], self[11], self[12],
			   self[13], self[14], self[15], self[16]
	end,

	-- Apply a transformation matrix to our matrix
	transform = function(self, tr)
		local s1,  s2,  s3,  s4  = self[1],  self[2],  self[3],  self[4]
		local s5,  s6,  s7,  s8  = self[5],  self[6],  self[7],  self[8]
		local s9,  s10, s11, s12 = self[9],  self[10], self[11], self[12]
		local s13, s14, s15, s16 = self[13], self[14], self[15], self[16]

		self[1]  = tr[1]  * s1 + tr[2]  * s5 + tr[3]  * s9  + tr[4]  * s13
		self[2]  = tr[1]  * s2 + tr[2]  * s6 + tr[3]  * s10 + tr[4]  * s14
		self[3]  = tr[1]  * s3 + tr[2]  * s7 + tr[3]  * s11 + tr[4]  * s15
		self[4]  = tr[1]  * s4 + tr[2]  * s8 + tr[3]  * s12 + tr[4]  * s16

		self[5]  = tr[5]  * s1 + tr[6]  * s5 + tr[7]  * s9  + tr[8]  * s13
		self[6]  = tr[5]  * s2 + tr[6]  * s6 + tr[7]  * s10 + tr[8]  * s14
		self[7]  = tr[5]  * s3 + tr[6]  * s7 + tr[7]  * s11 + tr[8]  * s15
		self[8]  = tr[5]  * s4 + tr[6]  * s8 + tr[7]  * s12 + tr[8]  * s16

		self[9]  = tr[9]  * s1 + tr[10] * s5 + tr[11] * s9  + tr[12] * s13
		self[10] = tr[9]  * s2 + tr[10] * s6 + tr[11] * s10 + tr[12] * s14
		self[11] = tr[9]  * s3 + tr[10] * s7 + tr[11] * s11 + tr[12] * s15
		self[12] = tr[9]  * s4 + tr[10] * s8 + tr[11] * s12 + tr[12] * s16

		self[13] = tr[13] * s1 + tr[14] * s5 + tr[15] * s9  + tr[16] * s13
		self[14] = tr[13] * s2 + tr[14] * s6 + tr[15] * s10 + tr[16] * s14
		self[15] = tr[13] * s3 + tr[14] * s7 + tr[15] * s11 + tr[16] * s15
		self[16] = tr[13] * s4 + tr[14] * s8 + tr[15] * s12 + tr[16] * s16

		return self
	end,
	translate = function(self, v)
		return self:transform(m4.translate(v))
	end,
	scale = function(self, v)
		return self:transform(m4.scale(v))
	end,
	rotate = function(self, angle, v)
		return self:transform(m4.rotate(angle, v))
	end,
	shear = function(self, vxy, vyz)
		return self:transform(m4.shear(vxy, vyz))
	end,

	-- Common operations. Returns a new matrix.
	__mul = function(self, other)
		return m4{
			self[1]  * other[1] + self[2]  * other[5] + self[3]  * other[9]  + self[4]  * other[13],
			self[1]  * other[2] + self[2]  * other[6] + self[3]  * other[10] + self[4]  * other[14],
			self[1]  * other[3] + self[2]  * other[7] + self[3]  * other[11] + self[4]  * other[15],
			self[1]  * other[4] + self[2]  * other[8] + self[3]  * other[12] + self[4]  * other[16],

			self[5]  * other[1] + self[6]  * other[5] + self[7]  * other[9]  + self[8]  * other[13],
			self[5]  * other[2] + self[6]  * other[6] + self[7]  * other[10] + self[8]  * other[14],
			self[5]  * other[3] + self[6]  * other[7] + self[7]  * other[11] + self[8]  * other[15],
			self[5]  * other[4] + self[6]  * other[8] + self[7]  * other[12] + self[8]  * other[16],

			self[9]  * other[1] + self[10] * other[5] + self[11] * other[9]  + self[12] * other[13],
			self[9]  * other[2] + self[10] * other[6] + self[11] * other[10] + self[12] * other[14],
			self[9]  * other[3] + self[10] * other[7] + self[11] * other[11] + self[12] * other[15],
			self[9]  * other[4] + self[10] * other[8] + self[11] * other[12] + self[12] * other[16],

			self[13] * other[1] + self[14] * other[5] + self[15] * other[9]  + self[16] * other[13],
			self[13] * other[2] + self[14] * other[6] + self[15] * other[10] + self[16] * other[14],
			self[13] * other[3] + self[14] * other[7] + self[15] * other[11] + self[16] * other[15],
			self[13] * other[4] + self[14] * other[8] + self[15] * other[12] + self[16] * other[16]
		}
	end,
	__add = function(self, other)
		return m4{
			self[1]  + other[1],  self[2]  + other[2],  self[3]  + other[3],  self[4]  + other[4],
			self[5]  + other[5],  self[6]  + other[6],  self[7]  + other[7],  self[8]  + other[8],
			self[9]  + other[9],  self[10] + other[10], self[11] + other[11], self[12] + other[12],
			self[13] + other[13], self[14] + other[14], self[15] + other[15], self[16] + other[16],
		}
	end,
	__sub = function(self, other)
		return m4{
			self[1]  - other[1],  self[2]  - other[2],  self[3]  - other[3],  self[4]  - other[4],
			self[5]  - other[5],  self[6]  - other[6],  self[7]  - other[7],  self[8]  - other[8],
			self[9]  - other[9],  self[10] - other[10], self[11] - other[11], self[12] - other[12],
			self[13] - other[13], self[14] - other[14], self[15] - other[15], self[16] - other[16],
		}
	end,
	__unm = function(self)
		return m4{
			-self[1],  -self[2],  -self[3],  -self[4],
			-self[5],  -self[6],  -self[7],  -self[8],
			-self[9],  -self[10], -self[11], -self[12],
			-self[13], -self[14], -self[15], -self[16]
		}
	end,

	__tostring = function(self)
		local mt = getmetatable(self)
		setmetatable(self, nil)
		local str = "m4: "..(tostring(self):gsub("^table: ", ""))
		setmetatable(self, mt)
		return str
	end
}
m4_mt.__index = m4_mt

m4 = setmetatable({
	-- Common transformation to create new matrices from
	identity = function()
		return m4{
			1, 0, 0, 0,
			0, 1, 0, 0,
			0, 0, 1, 0,
			0, 0, 0, 1
		}
	end,
	translate = function(v)
		return m4{
			1, 0, 0, v[1],
			0, 1, 0, v[2],
			0, 0, 1, v[3],
			0, 0, 0, 1
		}
	end,
	scale = function(v)
		return m4{
			v[1], 0,    0,    0,
			0,    v[2], 0,    0,
			0,    0,    v[3], 0,
			0,    0,    0,    1
		}
	end,
	rotate = function(angle, v)
		local c = cos(angle)
		local s = sin(angle)
		local x, y, z = tmpv3:set(v):normalize():unpack()
		local tx, ty, tz = (1 - c) * x, (1 - c) * y, (1 - c) * z
		return m4{
			c + tx * x,      ty * x - s * z,  tz * x + s * y, 0,
			tx * y + s * z,  c + ty * y,      tz * y - s * x, 0,
			tx * z - s * y,  ty * z + s * x,  c + tz * z,     0,
			0,               0,               0,              1
		}
	end,
	-- vxy: shearing vector in the (xy) plane
	-- vyz: shearing vector in the (yz) plane
	shear = function(vxy, vyz)
		return m4{
			1,      vxy[1], vyz[1], 0,
			vxy[2], 1,      vyz[2], 0,
			vxy[3], vyz[3], 1,      0,
			0,      0,      0,      1
		}
	end,

	-- Projection matrix constructor (right-handed).
	perspective = function(fovy, aspect, zNear, zFar) -- If zFar is not specified, will return an infinite perspective matrix.
		local f = 1 / tan(fovy / 2)
		if zFar then
			return m4{
				f / aspect, 0, 0,                               0,
				0,          f, 0,                               0,
				0,          0, (zFar + zNear) / (zNear - zFar), (2 * zFar * zNear) / (zNear - zFar),
				0,          0, -1,                              0
			}
		else
			return m4{
				f / aspect, 0, 0,  0,
				0,          f, 0,  0,
				0,          0, -1, -2 * zNear,
				0,          0, -1, 0
			}
		end
	end,
	orthographic = function(xmag, ymag, znear, zfar)
		return m4{
			1 / xmag, 0,        0,                  0,
			0,        1 / ymag, 0,                  0,
			0,        0,        2 / (znear - zfar), (zfar + znear) / (znear - zfar),
			0,        0,        0,                  1
		}
	end,
	lookAt = function(eye, center, up)
		center, up = v3(center), v3(up)
		local f = (center - eye):normalize()
		local s = f:cross(up):normalize()
		local u = s:cross(f)
		return m4{
			 s[1],  s[2],  s[3], -s:dot(eye),
			 u[1],  u[2],  u[3], -u:dot(eye),
			-f[1], -f[2], -f[3],  f:dot(eye),
			 0,     0,     0,     1
		}
	end,

	-- Create a new matrix from column major list
	fromColumnMajor = function(m)
		return m4{
			m[1], m[5], m[9],  m[13],
			m[2], m[6], m[10], m[14],
			m[3], m[7], m[11], m[15],
			m[4], m[8], m[12], m[16]
		}
	end
}, {
	-- Will not copy the table.
	__call = function(self, t)
		return setmetatable(t, m4_mt)
	end
})

return m4
