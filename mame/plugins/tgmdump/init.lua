-- license:BSD-3-Clause
-- copyright-holders:tom14159
require('io')
local exports = {}
exports.name = "tgmdump"
exports.version = "0.0.1"
exports.description = "TGM dumper"
exports.license = "The BSD 3-Clause License"
exports.author = { name = "tom14159" }

local tgmdump = exports

function tgmdump.startplugin()
	local mem
	local pipe
	local function pvals()
		if pipe then
			local state = mem:read_i16(0x0017695D)
			local level = mem:read_i16(0x0017699A)
			local timer = mem:read_i32(0x0017698C)
			local grade = mem:read_i16(0x0017699C)
			local section = mem:read_i16(0x0017699E)

			pipe:write(state .. " " .. timer .. " " .. section .. " " .. level .. " " .. grade .. "\n")
			pipe:flush()
		end
	end

	emu.register_start(function()
		if emu.romname() == "tgmj" then
			mem = manager:machine().devices[":maincpu"].spaces["program"]
			pipe = io.open("/dev/shm/tgm", "w")
			emu.register_frame_done(function()
				pvals()
			end)
		end
	end)

	emu.register_end(function()
		if pipe then
			pipe:close()
		end
	end)
end

return exports
