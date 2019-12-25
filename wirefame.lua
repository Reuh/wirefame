--- WireFame v0.4.0 by Reuh: initially a wireframe software rendering engine, now also a 3D framework for Löve (optional).
-- Should be compatible with Lua 5.1 to 5.3. There are 3 functions you will need to implement yourself to make
-- this works with your graphical backend.
-- Name found by Lenade Lamidedi.
-- Thanks to tinyrenderer (https://github.com/ssloy/tinyrenderer/wiki) for explaining how a 3D renderer works.

local wirefame = {
	--- Default drawing color used when creating models.
	defaultColor = { 1, 1, 1, 1 }
}

--------------------------------------
--## LÖVE-specific initialization ##--
--------------------------------------

local lg, lshaderCode
if love then
	-- love.graphics
	lg = love.graphics

	-- shader code
	lshaderCode = [[
	varying vec3 normal_world; // vertex normal in world space
	varying vec4 position_world; // fragment position in world space

	# ifdef VERTEX
	uniform mat4 scene_transform; // world -> view transform
	uniform mat4 model_transform; // model -> world transform

	attribute vec3 VertexNormal;

	vec4 position(mat4 love_transform, vec4 vertex_position) {
		normal_world = (model_transform * vec4(VertexNormal, 0)).xyz;
		position_world = model_transform * vertex_position;
		return scene_transform * position_world;
	}
	# endif

	# ifdef PIXEL
	# if LIGHT_COUNT > 0
		struct Light {
			int type; // 1 for ambient, 2 for directional, 3 for point
			vec3 position; // position for point lights, or direction for directional lights
			vec4 color; // diffuse color for point and directional lights (alpha is intensity), or ambient color for ambient light
		};

		uniform Light[LIGHT_COUNT] lights;
	# endif

	vec4 effect(vec4 color, sampler2D texture, vec2 texture_coords, vec2 screen_coords) {
		// base color
		vec4 material_color = texture2D(texture, texture_coords) * color;
		if (material_color.a == 0) discard;

		# if LIGHT_COUNT > 0
			// shading
			vec4 final_color = vec4(0.0, 0.0, 0.0, 0.0);
			for (int i = 0; i < LIGHT_COUNT; i++) {
				Light light = lights[i];

				// ambient
				if (light.type == 1) {
					final_color += material_color * light.color;

				// directional
				} else if (light.type == 2) {
					// diffuse lighting
					vec3 n = normalize(normal_world);
					vec3 l = normalize(-light.position);
					final_color += material_color * vec4(light.color.rgb * light.color.a * max(dot(n, l), 0.0), 1);

				// point
				} else if (light.type == 3) {
					// diffuse lighting
					vec3 n = normalize(normal_world);
					vec3 l = normalize(light.position - position_world.xyz);
					float distance = length(light.position - position_world.xyz);
					final_color += material_color * vec4(light.color.rgb * light.color.a * max(dot(n, l), 0.0) / (distance * distance), 1);
				}

				// no specular because i'm lazy (TODO)
			}

			// done
			return final_color;
		# else
			return material_color;
		# endif
	}
	# endif
	]]

	-- enable depth buffer
	lg.setDepthMode("lequal", true)

	-- culling
	love.graphics.setFrontFaceWinding("ccw")
	lg.setMeshCullMode("back")
end

------------------------------------------------------------------
--## Functions you need to implement fore wireframe rendering ##--
------------------------------------------------------------------

--- Draws a line from x0,y0 to x1,y1 (px).
-- function wirefame.drawLine(x0, y0, x1, y1)
function wirefame.drawLine(x0, y0, x1, y1)
	lg.line(x0, y0, x1, y1)
end
--- Draws a point at x,y (px).
-- function wirefame.drawPoint(x, y)
function wirefame.drawPoint(x, y)
	lg.setPointSize(2)
	lg.points(x, y)
end
--- Sets the current drawing color (0-1).
-- function wirefame.setColor(r, g, b, a)
function wirefame.setColor(r, g, b, a)
	lg.setColor(r, g, b, a)
end

-------------------------
--## Utility classes ##--
-------------------------

local unpack = table.unpack or unpack
local sqrt, cos, sin, tan, rad = math.sqrt, math.cos, math.sin, math.tan, math.rad
local m4, v3, bb3
local tmpv3 -- temporary vector used in our computations

--- 4x4 matrix. Reminder: they are represented in row-major order, **unlike** GLM which is column-major.
local m4_mt = {
	-- Clone the matrix
	clone = function(self)
		return m4{unpack(self)}
	end,

	-- Set matrix in place
	set = function(self, other)
		self[1],  self[2],  self[3],  self[4]  = other[1],  other[2],  other[3],  other[4]
		self[5],  self[6],  self[7],  self[8]  = other[5],  other[6],  other[7],  other[8]
		self[9],  self[10], self[11], self[12] = other[9],  other[10], other[11], other[12]
		self[13], self[14], self[15], self[16] = other[13], other[14], other[15], other[16]
		return self
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

	-- Common operations
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
	__sub = function(self, other)
		return m4{
			self[1]  + other[1],  self[2]  + other[2],  self[3]  + other[3],  self[4]  + other[4],
			self[5]  + other[5],  self[6]  + other[6],  self[7]  + other[7],  self[8]  + other[8],
			self[9]  + other[9],  self[10] + other[10], self[11] + other[11], self[12] + other[12],
			self[13] + other[13], self[14] + other[14], self[15] + other[15], self[16] + other[16],
		}
	end,
	__add = function(self, other)
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
	-- Common transformation matrices constructors
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
		local x, y, z = tmpv3:set(v):normalizeInPlace():unpack()
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
	gnomonic = function(dist)
		return m4{
			1, 0, 0,      0,
			0, 1, 0,      0,
			0, 0, 1,      0,
			0, 0, 1/dist, 1
		}
	end,
	perspective = function(fovy, aspect, zNear, zFar)
		local f = 1 / tan(rad(fovy) / 2)
		return m4{
			f / aspect, 0, 0,                               0,
			0,          f, 0,                               0,
			0,          0, (zFar + zNear) / (zNear - zFar), (2 * zFar * zNear) / (zNear - zFar),
			0,          0, -1,                              0
		}
	end,
	lookAt = function(eye, center, up)
		center, up = v3(center), v3(up)
		local f = (center - eye):normalizeInPlace()
		local s = f:cross(up):normalizeInPlace()
		local u = s:cross(f)
		return m4{
			 s[1],  s[2],  s[3], -s:dot(eye),
			 u[1],  u[2],  u[3], -u:dot(eye),
			-f[1], -f[2], -f[3],  f:dot(eye),
			 0,     0,     0,     1
		}
	end
}, {
	__call = function(self, t)
		return setmetatable(t, m4_mt)
	end
})
wirefame.m4 = m4

--- 3D vector
local v3_mt = {
	-- Clone the vector
	clone = function(self)
		return v3(self:unpack())
	end,

	-- Set vector in place
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
		return v3(x/l, y/l, z/l)
	end,
	normalizeInPlace = function(self)
		local x, y, z = self[1], self[2], self[3]
		local l = sqrt(x*x + y*y + z*z)
		self[1], self[2], self[3] = x/l, y/l, z/l
		return self
	end,

	-- Vector product
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
		local x, y, z = self:unpack()
		-- Transform matrix * Homogeneous coordinates
		local mx = matrix[1]  * x + matrix[2]  * y + matrix[3]  * z + matrix[4]
		local my = matrix[5]  * x + matrix[6]  * y + matrix[7]  * z + matrix[8]
		local mz = matrix[9]  * x + matrix[10] * y + matrix[11] * z + matrix[12]
		local mw = matrix[13] * x + matrix[14] * y + matrix[15] * z + matrix[16]
		-- Go back to euclidian coordinates
		return v3(mx/mw, my/mw, mz/mw)
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

	-- Common operations
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
		return ("v3(%s,%s,%s)"):format(self:unpack())
	end
}
v3_mt.__index = v3_mt
v3 = function(x, y, z)
	if type(x) == "number" then
		return setmetatable({ x, y, z }, v3_mt)
	else
		return setmetatable(x, v3_mt)
	end
end
wirefame.v3 = v3
tmpv3 = v3(0, 0, 0)

--- 3D bounding box
local bb3_mt = {
	-- Clone the bounding box
	clone = function(self)
		return bb3(self.min:clone(), self.max:clone())
	end,

	-- Set bounding box in place
	set = function(self, min, max)
		self.min, self.max = v3(min), v3(max)
		return self
	end,

	-- Retrieve min and max vectors
	unpack = function(self)
		return self.min, self.max
	end,

	-- Test if the bounding box collide with another bounding box
	collide = function(self, other)
		return self.min[1] < other.max[1] and self.max[1] > other.min[1] and
		       self.min[2] < other.max[2] and self.max[2] > other.min[2] and
			   self.min[3] < other.max[3] and self.max[3] > other.min[3]
	end,

	-- Extend a bounding box by a certain distance
	extend = function(self, d)
		self.min = self.min - { d, d, d }
		self.max = self.max + { d, d, d }
		return self
	end,

	-- Transform by a mat4
	transform = function(self, matrix)
		return bb3(self.min:transform(matrix), self.max:transform(matrix))
	end,

	-- Common operations with vectors
	__sub = function(self, other)
		return bb3(self.min - other, self.max - other)
	end,
	__add = function(self, other)
		return bb3(self.min + other, self.max + other)
	end,
	__unm = function(self)
		return bb3(-self.min, -self.max)
	end,
	__div = function(self, other)
		return bb3(self.min / other, self.max / other)
	end,
	__mul = function(self, other)
		return bb3(self.min * other, self.max * other)
	end,

	__tostring = function(self)
		return ("bb3(%s,%s)"):format(self.min, self.max)
	end
}
bb3_mt.__index = bb3_mt
bb3 = function(min, max)
	return setmetatable({ min = v3(min), max = v3(max) }, bb3_mt)
end
wirefame.bb3 = bb3

----------------------------
--## Wirefame functions ##--
----------------------------

--- Returns a list of vertices and faces from a .obj or .iqe file.
-- Supports geometric vertices (ignores w), point, lines and faces.
-- The parser will ignore textures, normals, free-form geometry, blends, meshes, materials, smoothing, poses, skeletons, animations.
-- Made using http://paulbourke.net/dataformats/obj/ and http://sauerbraten.org/iqm/iqe.txt
-- TODO: animations? Simplify? Rely on iqm-exm? etc
local function parseModel(path, color, args)
	args = args or {}

	local vertices = { n = 0 }
	local faces = { n = 0 }

	for line in io.lines(path) do
		-- .obj --

		-- Variable substitution
		for i, a in ipairs(args) do
			line = line:gsub("$"..tostring(i), tostring(a))
		end

		-- Read another .obj file: call filename arg1...
		if line:match("^call%s") then
			local file = line:match("^call%s+([^%s]+)")
			local nargs = {}
			for narg in (line:match("^call%s+[^%s]+(.*)")):gmatch("([^%s]+)") do
				table.insert(nargs, narg)
			end
			local nvertices, nfaces = parseModel(file, color, nargs)
			for _, v in ipairs(nvertices) do
				table.insert(vertices, v)
			end
			for _, f in ipairs(nfaces) do
				table.insert(faces, f)
			end
		-- Vertex: v x y z w
		-- Ignores w.
		elseif line:match("^v%s") then
			local x, y, z = line:match("^v%s+([-%d.e]+)%s+([-%d.e]+)%s+([-%d.e]+)")
			local vec = v3(tonumber(x), tonumber(y), tonumber(z))
			vec.color = color
			table.insert(vertices, vec)
		-- Point: p v1 v2 v3 ...
		-- Line: l v1/vt1 v2/vt2 v3/vt3 ...
		-- Faces: f v1/vt1/vn1 v2/vt2/vn2 v3/vt3/vn3 ...
		-- Ignores vt* and vn*.
		elseif line:match("^[plf]%s") then
			local face = {}
			for vertex in line:gmatch("([-%d.e/]+)") do
				table.insert(face, tonumber(vertex:match("^([-%d.e]+)"))) -- extract just the vertex number
			end
			face.n = #face
			face.type = line:match("^([plf])%s")
			table.insert(faces, face)

		-- .iqe --

		-- Vertex: vp x y z w
		-- Ignores w.
		elseif line:match("^vp%s") then
			local x, y, z = line:match("^vp%s+([-%d.e]*)%s*([-%d.e]*)%s*([-%d.e]*)")
			local vec = v3(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0)
			vec.color = color
			table.insert(vertices, vec)
		-- Vertex color: vc r g b a
		elseif line:match("^vc%s") then
			local r, g, b, a = line:match("^vc%s+([-%d.e]*)%s*([-%d.e]*)%s*([-%d.e]*)%s*([-%d.e]*)")
			vertices[#vertices].color = { tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0, tonumber(a) or 1 }
		-- Triangles: fa v1 v2 v3...
		elseif line:match("^fa%s") then
			local face = { type = "f" }
			for vertex in line:gmatch("([-%d.e/]+)") do
				table.insert(face, tonumber(vertex:match("^([-%d.e]+)"))) -- extract just the vertex number
			end
			face.n = #face
			table.insert(faces, face)
		end
	end

	-- Some post-processing on the parsed data
	vertices.n = #vertices
	faces.n = #faces
	for i=1, faces.n do
		local face = faces[i]
		for j=1, face.n do
			local vertex = face[j]
			if vertex < 0 then -- Relative vertex number
				face[j] = vertices.n - vertex + 1
			end
		end
	end

	return vertices, faces
end

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

	--- Clone the model.
	clone = function(self)
		return wirefame.model(self.lmesh, self.vertices, self.faces)
			:setTransformStack(self.transformStack)
			:setColor(self.color[1], self.color[2], self.color[3], self.color[4])
			:tag(unpack(self:listTags()))
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

	--- Get a group of all models recursively contained in this object with these tags.
	get = function(self, ...)
		if self:is(...) then
			return wirefame.group{self}
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
		self.transformStack = { names = self.transformStack.names }
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
	end,
	--- Assign a name to the transform i.
	setTransformName = function(self, i, name)
		self.transformStack.names[name] = i
	end,

	--- Calculate the final transformation matrix.
	getFinalTransform = function(self)
		if self.transformStack.changed then
			self.finalTransform = m4.identity()
			for i=1, self.transformStack.n, 1 do
				self.finalTransform:transform(self.transformStack[i])
			end
			self.transformStack.changed = false
		end
		return self.finalTransform
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
	boundingBox = function(self, tr)
		local transform = self:getFinalTransform()
		if tr then
			transform = tr * transform
		end

		-- Create vertices if needed from lmesh
		self:_meshToVertices()

		-- Calculate bounding box
		if self.vertices.n > 0 then
			local v = self.vertices[1]:transform(transform)
			local min, max = v:clone(), v:clone()
			for i=2, self.vertices.n do
				v = self.vertices[i]:transform(transform)
				min[1] = math.min(min[1], v[1])
				min[2] = math.min(min[2], v[2])
				min[3] = math.min(min[3], v[3])
				max[1] = math.max(max[1], v[1])
				max[2] = math.max(max[2], v[2])
				max[3] = math.max(max[3], v[3])
			end
			return bb3(min, max)
		else
			return bb3(v3(0,0,0), v3(0,0,0))
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

	--- Draw the 3D model, applying transformation tr, view distance viewDist and a camera sitting on z = trCamZ in screen coordinates.
	drawWireframe = function(self, tr, viewDist, trCamZ)
		local drawLine, drawPoint = wirefame.drawLine, wirefame.drawPoint
		local setColor = wirefame.setColor

		-- Create vertices if needed from lmesh
		self:_meshToVertices()

		-- Transformation matrix
		local transform = tr * self:getFinalTransform()

		-- Already transformed vertices cache
		local trVertex = {}

		-- Iterate faces and draw them
		for i=1, self.faces.n do
			local face = self.faces[i]

			local n = face.n -- number of vertices in the face
			local nV -- number of vertices to iterate
			local draw -- draw function(v3(n).x, v3(n).y, v3(n+1).x, v3(n+1).y)

			-- Face type
			if face.type == "f" then
				nV = n
				draw = drawLine
			elseif face.type == "l" then
				nV = n -1 -- doesn't iterate on the last vertex, so no line between the last and first vertex
				draw = drawLine
			elseif face.type == "p" then
				nV = n
				draw = drawPoint
			end

			for j=1, nV do
				local vertex1, vertex2 = face[j], face[j%n+1]

				-- Transform
				if trVertex[vertex1] == nil then
					trVertex[vertex1] = self.vertices[vertex1]:transform(transform)
				end
				if trVertex[vertex2] == nil then
					trVertex[vertex2] = self.vertices[vertex2]:transform(transform)
				end

				local tr1, tr2 = trVertex[vertex1], trVertex[vertex2]
				local tr1Z, tr2Z = tr1[3], tr2[3]
				local col = self.vertices[vertex1].color

				-- Ignore if a vertex is behind camera
				if tr1Z < trCamZ and tr2Z < trCamZ then
					-- Distance between camera and middle of the segment
					-- distCam = 0 if the distance is equal to viewDist, becoming closer to viewDist if the object is closer to the camera)
					local distCam = viewDist - (trCamZ - (tr1Z+tr2Z)/2)
					if distCam > 0 then
						setColor(col[1], col[2], col[3], distCam * col[4]/viewDist)
						draw(tr1[1], tr1[2], tr2[1], tr2[2])
					end
				end
			end
		end
	end,

	--- Send all relevant uniforms to the shader
	sendToShader = function(self, lshader)
	end,

	-- Draw the model using LÖVE. Use OpenGL/hardware acceleration, but it's not actually wireframe anymore.
	drawLove = function(self, lshader, transp, tr, col)
		-- Create mesh if needed from .obj data
		self:_verticesToMesh()

		-- Transformation matrix
		if tr then
			lshader:send("model_transform", tr * self:getFinalTransform())
		else
			lshader:send("model_transform", self:getFinalTransform())
		end

		-- Color
		if col then
			col = { self.color[1] * col[1], self.color[2] * col[2], self.color[3] * col[3], self.color[4] * col[4] }
		else
			col = self.color
		end

		-- Transparency sort
		if transp then
			if col[4] >= 1 then return end
		else
			if col[4] < 1 then return end
		end

		-- Draw
		lg.setColor(col)
		if type(self.lmesh) == "function" then
			self.lmesh()
		else
			lg.draw(self.lmesh)
		end
	end,

	--- Private ---
	_meshToVertices = function(self)
		if not self.vertices and not self.faces then
			local lmesh = self.lmesh

			local vertices = { n = 0 }
			local faces = { n = 0 }

			if type(lmesh) == "userdata" and lmesh:type() == "Mesh" then
				-- Get format
				local iposition, icolor
				local i = 1
				for _, t in ipairs(lmesh:getVertexFormat()) do
					if t[1] == "VertexPosition" then
						if t[3] ~= 3 then error("mesh vertices don't have a 3 dimensional position") end
						iposition = i
					elseif t[1] == "VertexColor" then
						if t[3] ~= 4 then error("mesh color doesn't have 4 components") end
						icolor = i
					end
					i = i + t[3]
				end
				if not iposition or not icolor then
					error("mesh doesn't have VertexPosition and/or VertexColor attributes")
				end

				-- Retrieve vertices
				local lmap = lmesh:getVertexMap()
				for i=1, #lmap do
					local attr = { lmesh:getVertex(lmap[i]) }
					local x, y, z, r, g, b, a = attr[iposition], attr[iposition+1], attr[iposition+2], attr[icolor], attr[icolor+1], attr[icolor+2], attr[icolor+3]
					local v = v3(x, y, z)
					v.color = { r, g, b, a }
					table.insert(vertices, v)
				end
				vertices.n = #vertices

				-- Retrieve faces
				if lmesh:getDrawMode() == "triangles" then
					for i=1, #lmap-2, 3 do
						table.insert(faces, { n = 3, type = "f", i, i+1, i+2 })
					end
				elseif lmesh:getDrawMode() == "fan" then
					for i=1, #lmap-1, 2 do
						table.insert(faces, { n = 3, type = "f", 1, i, i+1 })
					end
				else
					error("unsuported mesh drawing mode "..lmesh:getDrawMode())
				end
				faces.n = #faces
			else
				error(("wirefame conversion of a %s is not supported"):format(type(lmesh) == "userdata" and lmesh:type() or tostring(lmesh)))
			end

			self.vertices, self.faces = vertices, faces
		end
	end,
	_verticesToMesh = function(self)
		if not self.lmesh then
			local vertices, faces = self.vertices, self.faces

			-- Get vertices list
			local lvertices = {}
			for i=1, vertices.n do
				local v = vertices[i]
				v.normal = v3(0, 0, 0)
				table.insert(lvertices, { v[1], v[2], v[3], v.color[1], v.color[2], v.color[3] })
			end

			-- Get vertex map
			local lmap = {}
			for i=1, faces.n do
				local f = faces[i]
				if f.type == "f" then
					for j=3, f.n do
						table.insert(lmap, f[1])
						table.insert(lmap, f[j-1])
						table.insert(lmap, f[j])
						-- add triangle normal to vertices
						local triangleNormal = (vertices[f[j-1]]-vertices[f[1]]):cross(vertices[f[j]]-vertices[f[1]]):normalizeInPlace()
						vertices[f[1]].normal = vertices[f[1]].normal + triangleNormal
						vertices[f[j-1]].normal = vertices[f[j-1]].normal + triangleNormal
						vertices[f[j]].normal = vertices[f[j]].normal + triangleNormal
					end
				elseif f.type == "l" then
					for j=2, f.n do
						table.insert(lmap, f[j-1])
						table.insert(lmap, f[j-1])
						table.insert(lmap, f[j])
					end
				elseif f.type == "p" then
					for j=1, f.n do
						table.insert(lmap, f[j])
						table.insert(lmap, f[j])
						table.insert(lmap, f[j])
					end
				end
			end

			-- Get vertex normals
			for i=1, vertices.n do
				local v = vertices[i]
				local x, y, z = v.normal:normalizeInPlace():unpack()
				table.insert(lvertices[i], x)
				table.insert(lvertices[i], y)
				table.insert(lvertices[i], z)
			end

			-- Send vertices
			local lmesh = lg.newMesh({
				{ "VertexPosition", "float", 3 },
				{ "VertexColor",    "float", 3 },
				{ "VertexNormal",   "float", 3 }
			}, #lvertices > 0 and lvertices or 1, "triangles")

			-- Send vertex map
			lmesh:setVertexMap(lmap)

			self.lmesh = lmesh
		end
	end
}
model_mt.__index = model_mt

--- Loads an .obj/.iqe file, or import a LÖVE drawable, or import a drawing function, or create a empty model.
function wirefame.model(path, _vertices, _faces)
	local model = {
		-- Size
		n = 1,
		true,

		-- Tags
		tags = {},

		-- Model transformation matrices
		transformStack = { n = 1, changed = true, names = {}, m4.identity() },
		finalTransform = nil,

		-- Model color
		color = { wirefame.defaultColor[1], wirefame.defaultColor[2], wirefame.defaultColor[3], wirefame.defaultColor[4] },

		-- List of vertices, each vertices being a 3D vector with a color property.
		vertices = nil,
		-- List of faces, lines and points, each item being a table { type = "t", n = #face, vertex1index<integer>, vertex2index<integer>, ... }
		faces = nil,

		-- LÖVE-specific: drawable object (ideally a mesh with the correct vertex format)
		lmesh = nil,

		-- Hierarchy
		parents = {},
		scene = nil
	}

	-- Empty model
	if path == nil then
		model.vertices, model.faces = { n = 0 }, { n = 0 }
	-- Load an .obj file
	elseif type(path) == "string" then
		model.vertices, model.faces = parseModel(path, model.color)
	-- Function
	elseif type(path) == "function" then
		model.lmesh = path
		model.vertices, model.faces = _vertices, _faces
	-- Convertible to LÖVE meshes.
	elseif type(path) == "userdata" and path:type() == "Image" or path:type() == "Canvas" then
		model.vertices, model.faces = _vertices, _faces
		model.lmesh = love.graphics.newMesh({
			{ "VertexPosition", "float", 3 },
			{ "VertexTexCoord", "float", 2 },
			{ "VertexColor",    "byte",  4 },
			{ "VertexNormal",   "float", 3 }
		},
		{
			{
				0, 0, 0,
				0, 0,
				1, 1, 1, 1,
				0, 0, -1
			},
			{
				0, path:getHeight(), 0,
				0, 1,
				1, 1, 1, 1,
				0, 0, -1
			},
			{
				path:getWidth(), path:getHeight(), 0,
				1, 1,
				1, 1, 1, 1,
				0, 0, -1
			},
			{
				path:getWidth(), 0, 0,
				1, 0,
				1, 1, 1, 1,
				0, 0, -1
			}
		}, "fan")
		model.lmesh:setVertexMap(1, 2, 3, 4)
		model.lmesh:setTexture(path)
	else
		model.lmesh = path
		model.vertices, model.faces = _vertices, _faces
	end

	-- Create & return object
	return setmetatable(model, model_mt)
end

--- Light methods.
local lightType = {
	none = 0,
	ambient = 1,
	directional = 2,
	point = 3
}
local light_mt = {
	-- Rewrite model methods
	sendToShader = function(self, lshader)
		lshader:send("lights["..(self.index-1).."].type", self.type)
		lshader:send("lights["..(self.index-1).."].position", self.position:transform(self:getFinalTransform()))
		lshader:send("lights["..(self.index-1).."].color", self.color)
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
				break
			end
		end
		if not self.index then -- create new spot
			scene.shader.define.LIGHT_COUNT = scene.shader.define.LIGHT_COUNT + 1
			self.index = scene.shader.define.LIGHT_COUNT
			scene.shader.changed = true
		else
			self:sendToShader() -- update already existing array in shader
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
		scene.shader.lshader:send("lights["..(self.index-1).."].type", lightType.none)
	end,
	boundingBox = function(self)
		return bb3(v3(0,0,0), v3(0,0,0))
	end,
	setColor = function(self, ...)
		model_mt.setColor(self, ...)
		self.resend = true
		return self
	end,
	drawWireframe = function(self) end,
	drawLove = function(self)
		-- update position and stuff
		if self.transformStack.changed or self.resend then
			self:sendToShader(self.scene.shader.lshader)
			self.resend = false
		end
	end
}
for k, v in pairs(model_mt) do
	if light_mt[k] == nil then
		light_mt[k] = v
	end
end
light_mt.__index = light_mt

--- Create a light object
wirefame.light = function(type)
	local light = {
		-- Light
		type = lightType[type],
		position = v3(0, 0, 0),
		color = { wirefame.defaultColor[1], wirefame.defaultColor[2], wirefame.defaultColor[3], wirefame.defaultColor[4] },
		resend = false,

		-- Size
		n = 1,
		true,

		-- Tags
		tags = {},

		-- Group transformation matrices
		transformStack = { n = 1, changed = true, names = {}, m4.identity() },
		finalTransform = nil,

		-- Hierarchy
		parents = {},
		scene = nil
	}

	-- Create & return object
	return setmetatable(light, light_mt)
end

--- Group methods.
local group_mt = {
	--- Add a model to the node.
	add = function(self, ...)
		for _, m in ipairs({...}) do
			self.n = self.n + 1
			table.insert(self, m)
			table.insert(m.parents, self)
			if self.scene and not m.scene then
				m:onAddToScene(self.scene)
			end
		end
		return self
	end,

	--- Remove a model from the node.
	remove = function(self, ...)
		for _, m in ipairs({...}) do
			for i=1, self.n do
				if self[i] == m then
					self.n = self.n - 1
					table.remove(self, i)
					for j, p in ipairs(m.parents) do
						if p == self then
							table.remove(m.parents, j)
							break
						end
					end
					if m.scene and #m.parents == 0 then
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
	clone = function(self)
		local l = {}
		for i=1, self.n do table.insert(l, self[i]:clone()) end
		return wirefame.group(l)
			:setTransformStack(self.transformStack)
			:setColor(self.color[1], self.color[2], self.color[3], self.color[4])
			:tag(unpack(self:listTags()))
	end,
	get = function(self, ...)
		local l = {}
		for i=1, self.n do
			local il = self[i]:get(...)
			if #il > 0 then
				table.insert(l, il)
			end
		end
		return wirefame.group(l)
			:setTransformStack(self.transformStack)
			:setColor(self.color[1], self.color[2], self.color[3], self.color[4])
			:tag(unpack(self:listTags()))
	end,
	boundingBox = function(self, tr)
		local trans = self:getFinalTransform()
		if tr then trans = tr * trans end
		if #self > 0 then
			local r = self[1]:boundingBox(trans)
			for i=2, self.n do
				local b = self[i]:boundingBox(trans)
				r.min[1] = math.min(r.min[1], b.min[1])
				r.min[2] = math.min(r.min[2], b.min[2])
				r.min[3] = math.min(r.min[3], b.min[3])
				r.max[1] = math.max(r.max[1], b.max[1])
				r.max[2] = math.max(r.max[2], b.max[2])
				r.max[3] = math.max(r.max[3], b.max[3])
			end
			return r
		else
			return bb3(v3(0,0,0), v3(0,0,0))
		end
	end,
	drawWireframe = function(self, tr, viewDist, trCamZ)
		local trans = tr * self.transform
		for i=1, self.n do
			local r, g, b, a = self[i]:getColor()
			self[i]:setColor(self.color[1] * r, self.color[2] * g, self.color[3] * b, self.color[4] * a)
			self[i]:drawWireframe(trans, viewDist, trCamZ)
			self[i]:setColor(r, g, b, a)
		end
	end,
	sendToShader = function(self, lshader)
		for i=1, self.n do
			self[i]:sendToShader(lshader)
		end
	end,
	drawLove = function(self, lshader, transp, tr, col)
		local trans = self:getFinalTransform()
		if tr then trans = tr * trans end
		if col then col = { self.color[1] * col[1], self.color[2] * col[2], self.color[3] * col[3], self.color[4] * col[4] } end
		for i=1, self.n do
			self[i]:drawLove(lshader, transp, trans, col)
		end
	end
}
for k, v in pairs(model_mt) do
	if group_mt[k] == nil then
		group_mt[k] = v
	end
end
group_mt.__index = group_mt

--- Create a group of models.
wirefame.group = function(t)
	local group = {
		-- Size
		n = 0,

		-- Tags
		tags = {},

		-- Group transformation matrices
		transformStack = { n = 1, changed = true, names = {}, m4.identity() },
		finalTransform = nil,

		-- Group color
		color = { wirefame.defaultColor[1], wirefame.defaultColor[2], wirefame.defaultColor[3], wirefame.defaultColor[4] },

		-- Hierarchy
		parents = {},
		scene = nil
	}

	-- Create & return object
	return setmetatable(group, group_mt):add(unpack(t))
end

--- Scene methods
local scene_mt = {
	--- Sets the viewport matrix. Not used when rendering with LÖVE (handled by OpenGL).
	setViewport = function(self, x, y, width, height)
		return self:setTransform(4, m4.translate{x + width/2, y + height/2, 0} * m4.scale{width/2, height/2, 1})
	end,

	--- Set the projection matrix.
	setPerspective = function(self, fovy, ratio, near, far)
		return self:setTransform(3, m4.perspective(fovy, ratio, near, far))
	end,

	--- Sets the view and projection matrix.
	lookAt = function(self, eye, center, up)
		self.camera = v3(eye)
		return self:setTransform(2, m4.lookAt(eye, center, up))
	end,

	--- Sets the view distance, in world units (distance from the camera).
	setViewDistance = function(self, viewDist)
		self.viewDistance = viewDist
		return self
	end,

	--- Get model group with tags.
	get = function(self, ...)
		local r = {}
		for _, m in ipairs(self) do
			local il = m:get(...)
			if #il > 0 then
				table.insert(r, il)
			end
		end
		return wirefame.group(r)
	end,

	--- Rebuild the shader
	rebuildShader = function(self)
		if self.shader.changed then
			if self.shader.lshader then self.shader.lshader:release() end
			local s = ""
			for var, val in pairs(self.shader.define) do
				s = s .. ("# define %s %s"):format(var, val) .. "\n"
			end
			self.shader.lshader = lg.newShader(s .. lshaderCode)
			self.shader.lshader:send("scene_transform", m4.identity())
			self.shader.lshader:send("model_transform", m4.identity())
			for _, model in ipairs(self) do model:sendToShader(self.shader.lshader) end
			self.shader.changed = false
		end
		return self.shader.lshader
	end,

	--- Draws the scene.
	drawWireframe = function(self)
		-- Calculate transformation matrix
		local transform = self:getFinalTransform()

		-- Transformed camera Z coordinates
		local trCamZ = self.camera:transform(self.viewport * self.view)[3]

		-- Draw models
		for _, model in ipairs(self) do
			model:drawWireframe(transform, self.viewDistance, trCamZ)
		end
	end,

	--- Draw the scene using LÖVE. Use OpenGL/hardware acceleration, but it's not actually wireframe anymore.
	drawLove = function(self)
		-- Init shader
		local lshader = self:rebuildShader()

		-- Calculate transformation matrix
		lshader:send("scene_transform", self:getFinalTransform())

		-- Draw models
		lg.setShader(lshader)
		for _, model in ipairs(self) do
			model:drawLove(lshader, false) -- draw opaque models
		end
		for _, model in ipairs(self) do
			model:drawLove(lshader, true) -- draw transparent models
		end
		lg.setShader()
	end,

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
		viewDistance = 0, -- view distance, in world units
		shader = {
			changed = true, -- rebuild shader
			define = {}, -- map of variables to define in the shader
			lshader = nil, -- the shader
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
			m4.identity(), -- Custom: user-defined transformation to the models world coordinates in the scene (excluding camera)
			m4.identity(), -- View: world coordinates -> camera coordinates
			m4.identity(), -- Projection: camera coordinates -> perspective camera coordinates
			m4.identity(), -- Viewport: perspective camera coordinates -> screen coordinates
		},
		finalTransform = nil,

		-- Group color
		color = { wirefame.defaultColor[1], wirefame.defaultColor[2], wirefame.defaultColor[3], wirefame.defaultColor[4] },

		-- Hierarchy
		parents = {},
		scene = nil
	}
	scene.scene = scene

	-- Create & return object
	return setmetatable(scene, scene_mt)
end

return wirefame
