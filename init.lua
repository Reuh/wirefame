--- WireFame v0.4.0 by Reuh: initially a wireframe software rendering engine, now also a 3D framework for Löve (optional).
-- Should be compatible with Lua 5.1 to 5.3. There are 3 functions you will need to implement yourself to make
-- this works with your graphical backend.
-- Name found by Lenade Lamidedi.
-- Thanks to tinyrenderer (https://github.com/ssloy/tinyrenderer/wiki) for explaining how a 3D renderer works.

local wirefame = {
	--- Default drawing color used when creating models.
	defaultColor = { 1, 1, 1, 1 },
	--- Model loaders
	loader = {
		gltf = require((...)..".loader.gltf")
	},
	-- Math classes
	m4 = require((...)..".math.m4"),
	v3 = require((...)..".math.v3"),
	bb3 = require((...)..".math.bb3"),
	bs3 = require((...)..".math.bs3"),
	-- Shader code
	shader = {
		render = require((...)..".shader.render"),
		pick = require((...)..".shader.pick")
	}
}
package.loaded[(...)] = wirefame

--- Load Wirefame functions.
require((...)..".wirefame.model")
require((...)..".wirefame.light")
require((...)..".wirefame.group")
require((...)..".wirefame.scene")

return wirefame
