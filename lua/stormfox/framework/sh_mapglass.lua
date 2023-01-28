--[[-------------------------------------------------------------------------
Read the BSP
Functions:
	StormFox.MAP.Version() 				Returns the map-version.
	StormFox.MAP.Entities()				Returns the entities in the map.
	StormFox.MAP.StaticProps()			Returns the staticprops in the map.
	StormFox.MAP.AllTextures()			Returns the textures used in the map.
	StormFox.MAP.Textures()				Returns the texture-data from the map.
	StormFox.MAP.GenerateTextureTree()	Return the generated textures from the map. ( Note that this is only from the BSP. Not from SF )
	StormFox.MAP.FindClass(sClass) 		Returns all entities matching the entity-class, from the BSP data.

Hook:
	StormFox.MAP.Loaded 				Gets called when the BSP-data is loaded.

Useful: https://github.com/NicolasDe/AlienSwarm/blob/c5a2d3fa853c726d040032ff2c7b90c8ed8d5d84/src/public/bspfile.h
		https://developer.valvesoftware.com/wiki/Source_BSP_File_Format

There might still be bugs...

Tested from HL1 to CS:GO maps.
---------------------------------------------------------------------------]]
StormFox.MAP = {}
StormFox.TestingBitbuf = false
StormFox.UseBitbuf = true

-- FProfiler.start()
local bbuf = StormFox.UseBitbuf and BitBuffer:new()
local bfl

local whitelist = {
	["ReadString"] = "Read",
}

local READ_PAGE = bit.lshift(1, 18)

if bbuf then
	local ring = RingBuffer(10)

	function bbuf:ImitateFile()
		local fl = self.cmpFile
		fl:Seek(0)

		function bbuf:PageFault()
			local bufCur = self:Tell()
			local bufSz = self:Size()

			local flCur, flSz = fl:Tell(), fl:Size()
			local toRead = math.min(flSz - flCur, bufCur - bufSz + READ_PAGE)

			-- move to end of buf
			self:Seek(bufSz)
			fl:Seek(bufSz)
			self:WriteString(fl:Read(toRead), toRead)

			-- move back to read cursor
			self:Seek(bufCur)

			fl:Seek(flCur) -- move file cursor back, too
			return true
		end

		if not StormFox.TestingBitbuf then
			self.Close = function() fl:Close() end
			self.Read = self.ReadString
			return
		end

		local in_dtor = false

		-- tee function calls to gmod's File as well to check whether bitbuf works correctly
		-- done quick, dirty and ugly

		for k,v in pairs(BitBuffer) do
			local flk = whitelist[k] or k
			if not fl[flk] and isfunction(v) then continue end

			self["real" .. k] = self[k]

			bbuf[k] = function(self, ...)
				if in_dtor then return self["real" .. k] (self, ...) end

				in_dtor = true
				-- print(">> call:", k, ...)

				local ours = BitBuffer[k] (self, ...)
				local compare = fl[flk] (fl, ...)

				in_dtor = false

				ring:Add(k)

				local is_nan = not (compare == compare) and not (ours == ours)
				if compare ~= ours and not is_nan then
					if isstring(compare) and isstring(ours) then
						if #compare + #ours < 200 then
							longprintf("epic failure: `:%s()` => file [%s] vs bitbuf [%s]", k, compare, ours)
						else
							print("too long of a print")
						end
						printf("\tlengths: %d vs. %d", #compare, #ours)
					else
						longprintf("epic failure: `:%s()` => file [%s] vs bitbuf [%s]", k, compare, ours)
					end

					printf("\tbitbuf: %s", self:realTell())
					printf("\tfile: %s", fl:Tell())

					for i=-1, -10, -1 do
						printf("\t%s", ring:GetIn(i))
					end

					printf("dump: %s %s", self[1], self[2])
					self:_spew(self[1] - 2, self[1] + 2)

					file.Write("file.txt", compare)
					file.Write("bitbuf.txt", ours)

					bbuf = nil
					errorf("^")
				end

				return ours
			end
		end

		bbuf.Read = bbuf.ReadString
		bbuf.Close = function() fl:Close() end
	end
end

local start = 0

-- Local vars
	local file = table.Copy(file)
	local Vector = Vector
	local Color = Color
	local table = table.Copy(table)
	local string = table.Copy(string)
	local util = table.Copy(util)
	local abs = math.abs
	local isl4dmap
	local BSPDATA = {}

	local NO_TYPE = -1
	local DIRTGRASS_TYPE = 0
	local ROOF_TYPE = 1
	local ROAD_TYPE = 2
	local PAVEMENT_TYPE = 3

	local CONTENTS_WATER = 0x20
	local CONTENTS_WINDOW = 0x2
	local CONTENTS_SOLID = 0x1
-- Read functions
	local function ReadFloatSafe( f )
		return f:ReadFloat()
	end

	local function ReadBits( f, bits ) -- save.WriteInt
		assert(bits == 4)
		return f:ReadLong()
	end

	local function ReadVec( f )
		return Vector( ReadFloatSafe(f),ReadFloatSafe(f),ReadFloatSafe(f))
	end
	local function ReadLump( f, version )
		local t = {}
		if version ~= 21 then
			t.fileofs = f:ReadLong()
			t.filelen = f:ReadLong()
			t.version = f:ReadLong()
			t.fourCC = ReadBits(f,4)
		else-- "People might decompile the maps before we release L4D2. What do we do?"
			-- "Just switch up the lump data a bit. But only for L4D2. So nothing is compatible ..."
			if isl4dmap == nil then
				-- Check if it is a l4d map. The first lump is Entities, and there are always one map-entity.
				local fileofs = f:ReadLong() -- Version
				local filelen = f:ReadLong() -- fileofs
				local version = f:ReadLong() -- filelen
				t.fourCC = ReadBits(f,4) -- fourcc
				if fileofs <= 8 then -- We are already 8 bytes in. Therefore this is invalid and must be a l4d2 map.
					isl4dmap = true
					t.version = fileofs
					t.fileofs = filelen
					t.filelen = version
				else
					isl4dmap = false
					t.fileofs = fileofs
					t.filelen = filelen
					t.version = version
				end
			elseif isl4dmap == true then
				t.version = f:ReadLong()
				t.fileofs = f:ReadLong()
				t.filelen = f:ReadLong()
				t.fourCC = ReadBits(f,4)
			elseif isl4dmap == false then
				t.fileofs = f:ReadLong()
				t.filelen = f:ReadLong()
				t.version = f:ReadLong()
				t.fourCC = ReadBits(f,4)
			end
		end
		return t
	end
-- Local functions
	local function unsigned( val, length )
		if not val then return end
	    if val < 0 then
	        val = val + 2^(length * 8)
	    end
	    return val
	end
-- Lump functions
	local function GetLump( f , lump)
		f:Seek(lump.fileofs)
		return f:Read(lump.filelen)
	end
	local function SetToLump( f , lump)
		f:Seek(lump.fileofs)
		return lump.filelen
	end
-- Find soundscape in PAK
	local conVar = GetConVar("sf_overridemapsounds")
	local function PAKSearch(f,len)
		if not conVar:GetBool() then return end -- Soundscape isn't enabled on the map. Ignore.

		bfl:Seek(f:Tell())
		local data = bfl:Read(len) -- just read from file; we'll deal with it as a string anyhoo
		-- file.Write("oi3.txt",data)
		local found = false

		-- TODO: test this... i'm not sure if this will even match correctly???
		local sst, send = 0
		local find = "scripts\\soundscapes_"

		--[[
		local xdpos = math.random(#data)
		data = data:sub(1, xdpos) ..
			"scripts\\soundscapes_beebis.txt{\"much like my political views i support the separation between client and server, just like i support the separation between church and state\" - rwf93}PK"
			.. data:sub(xdpos)
		]]

		while sst do
			local st, en = string.find(data, find, send, true)
			if not st then break end

			sst, send = st, en

			local second_half = data:match("(.-)txt", en)
			if not second_half then continue end

			local fn = find .. second_half

			local contents = data:match("(.-)PK", st + #fn)
			if not contents then continue end

			if not found then
				found = true
				StormFox.Msg("Found custom soundscapes:")
			end

			StormFox.Msg(fn)
			if #fn > 0 then
				_STORMFOX_MAP__SoundScapes = _STORMFOX_MAP__SoundScapes or {}
				_STORMFOX_MAP__SoundScapes[fn] = contents
			end
		end

		-- leaving this for reference

		--[[
		for s in string.gmatch( data, "scripts\\soundscapes_.-txt.-PK" ) do
			if not found then
				found = true
				StormFox.Msg("Found custom soundscapes:")
			end
			local fil = string.match(s, "scripts\\soundscapes_.-txt")
			local file_name = string.GetFileFromFilename(fil or "") or ""
			StormFox.Msg(file_name)
			if #file_name > 0 then
				_STORMFOX_MAP__SoundScapes = _STORMFOX_MAP__SoundScapes or {}
				_STORMFOX_MAP__SoundScapes[file_name] = s:sub(#fil + 1,#s - 4)
			end
		end
		]]
	end

-- Load BSP data.
	local function GetBSPData(str)
		local s = SysTime()
		table.Empty(BSPDATA)
		str = game.GetMap()
		if not string.match(str,".bsp$") then
			str = str .. ".bsp"
		end
		local fil = "maps/" .. str
		if not file.Exists(fil,"GAME") then return end
		local f = file.Open(fil,"rb","GAME")

		bfl = f

		if StormFox.UseBitbuf then
			local sz = f:Size()
			local toFill = math.min( READ_PAGE, sz )
			bbuf:WriteString(f:Read(toFill), toFill)
			bbuf:ResetCursor()

			bbuf.cmpFile = f
			bbuf:ImitateFile()

			f = bbuf
		end

		start = SysTime()

		-- BSP file header
			if f:Read(4) ~= "VBSP" then -- Invalid
				return false
			end
			BSPDATA.version = ReadBits(f,4)
			if BSPDATA.version > 21 then
				error("What year is it? SF is too old to read those maps.")
			end
			local lumps = {}
			for i = 1,64 do
				lumps[i] = ReadLump(f,BSPDATA.version)
			end
		-- Read entities (LUMP 0)
			BSPDATA.Entities = {}
			local data = GetLump(f,lumps[1])
			if data then
				for s in string.gmatch( data, "%{.-%\n}" ) do
					local t = util.KeyValuesToTable("t" .. s)
					-- Convert a few things to make it easier
						t.origin = util.StringToType(t.origin or "0 0 0","Vector")
						t.angles = util.StringToType(t.angles or "0 0 0","Angle")
						local c = util.StringToType(t.rendercolor or "255 255 255","Vector")
						t.rendercolor = Color(c.x,c.y,c.z)
					table.insert(BSPDATA.Entities,t)
				end
			else
				error("Invalid BSP data. SF is unable to process the BSP.")
			end
		-- Read game lump (LUMP 35) This is for static props and other things
			local len = SetToLump(f,lumps[36])
			local count = f:ReadLong()
			local GameLump = {}

			for i = 1,count do
				GameLump[i] = {
					id = f:ReadLong(),
					flags = unsigned(f:ReadShort(),2),
					version = unsigned(f:ReadShort(),2),
					fileofs = f:ReadLong(),
					filelen = f:ReadLong()
				}
			end
			local staticprop_lump = -1
			local staticprop_version = -1
			for i = 1,count do
				if GameLump[i].id == 1936749168 then
					staticprop_lump = i
					staticprop_version = GameLump[i].version
					break
				end
			end
			BSPDATA.StaticProps = {}
			if staticprop_lump >= 0 then
				-- Read the static prop models
					f:Seek(GameLump[staticprop_lump].fileofs)
					local n = f:ReadLong() -- Number of models
					local m = {}
					for i = 1, n do
						m[i] = f:ReadString(128):gsub("[^%w_%-%.%/]", "")
					end

				-- Locate the leafs
					local leaf = {}
					local n = f:ReadLong()
					for i = 1,n do
						leaf[n] = unsigned(f:ReadShort(), 2)
					end
				-- Static prop lump
					local count = f:ReadLong()
					--local startRead = f:Tell()
					for i = 1, count do --1340 = crash
						local t = {}
						-- Version 4
							t.Origin = ReadVec(f)
							t.Angles = ReadVec(f)
						-- Version 11
							if staticprop_version >= 11 then
								t.Scale = f:ReadShort()
							end
						-- Version 4
							t.PropType = m[unsigned(f:ReadShort(),2) + 1]
							t.First_leaf = unsigned(f:ReadShort(),2)
							t.LeafCount = unsigned(f:ReadShort(),2)
							t.Solid = unsigned(f:ReadByte())
							t.Flags = unsigned(f:ReadByte())
							t.Skin = f:ReadLong()
							t.FadeMinDist = ReadFloatSafe(f)
							t.FadeMaxDist = ReadFloatSafe(f)
							local x =  ReadFloatSafe(f)
							local y =  ReadFloatSafe(f)
							local z =  ReadFloatSafe(f)
							t.LightingOrigin = Vector(x,y,z)
						-- Version 5
							if staticprop_version >= 5 then
								t.ForcedFadeScale = ReadFloatSafe(f)
							end
						-- Version 6 and 7
							if staticprop_version == 6 or staticprop_version == 7 then
								t.MinDXLevel = unsigned(f:ReadShort(),2)
								t.MaxDXLevel = unsigned(f:ReadShort(),2)
						-- Version 8
							elseif staticprop_version >= 8 then
								t.MinCPULevel = unsigned(f:ReadByte())
								t.MaxCPULevel = unsigned(f:ReadByte())
								t.MinGPULevel = unsigned(f:ReadByte())
								t.MaxGPULevel = unsigned(f:ReadByte())
							end
						-- Version 7
						--	if staticprop_version >= 7 then
						-- 		DiffuseModulation seems not to work .. not sure why
						--		local r,g,b,a = ReadBits(f , 8),ReadBits(f , 8),ReadBits(f , 8),ReadBits(f , 8)
						--		t.DiffuseModulation = Color(r,g,b,a)
						--	end
						-- Version 10
							if staticprop_version >= 10 then f:ReadFloat() end
						-- xBOX thingy
							if staticprop_version == 9 then -- Check
								f:ReadLong()
							end
						table.insert(BSPDATA.StaticProps,t)
					end
			end
		-- Textures are tricky. You have to load them with LUMP 2, then LUMP 43 for the position in LUMP 44
		-- Too complex .. lets just load the mapmaterial array
			local len = SetToLump(f,lumps[44])
			local tex = {}
			local r = true

			for i = 1,len do
				local c = string.char(f:ReadByte())
				if string.match(c,"[%w_%-%/]") then
					if r then
						tex[#tex] = (tex[#tex] or "") .. c
					else
						tex[#tex + 1] = c
						r = true
					end
				else
					r = false
				end
			end
			BSPDATA.TextureArray = tex
		-- BOM, Easy .. now load the textdata (LUMP 2)
			local len = SetToLump(f,lumps[3]) / 32
			local texdata_t = {}
			for i = 1,len do
				local dtexdata_t = {}
				dtexdata_t.reflectivity = ReadVec(f)
				dtexdata_t.nameStringTableID = f:ReadLong()
				dtexdata_t.width, dtexdata_t.height = f:ReadLong(),f:ReadLong()
				dtexdata_t.view_width, dtexdata_t.view_height = f:ReadLong(),f:ReadLong()
				dtexdata_t.texture = tex[dtexdata_t.nameStringTableID] or "" -- Add the texture array
				table.insert(texdata_t,dtexdata_t)
			end
			BSPDATA.Textures = texdata_t
		-- PAK search
			local len = SetToLump(f,lumps[41])
			if len > 10 then
				StormFox.Msg("Found mapdata ..")
				PAKSearch(f,len)
			end
			--pak_data = f:Read(len)
		f:Close()
		StormFox.Msg("Took " .. (SysTime() - s) .. " seconds to load the mapdata.")
		hook.Run("StormFox.MAP.Loaded")
	end
-- MAP functions
	function StormFox.MAP.Entities()
		return BSPDATA.Entities or {}
	end
	function StormFox.MAP.StaticProps()
		return BSPDATA.StaticProps or {}
	end
	function StormFox.MAP.AllTextures()
		return BSPDATA.TextureArray or {}
	end
	function StormFox.MAP.Textures()
		return BSPDATA.Textures or {}
	end
	function StormFox.MAP.Version()
		return BSPDATA.version or 0
	end
-- Type Guesser function
	local blacklist = {"indoor","foliage","model","dirtfloor005c","dirtground010","concretefloor027a","swamp"}
	local function GetTexType(str)
		for _,bl in pairs(blacklist) do
			if string.match(str,bl) then return NO_TYPE end
		end
		-- Dirt grass and gravel
			if string.find(str,"grass") then return DIRTGRASS_TYPE end
			if string.find(str,"dirt") then return DIRTGRASS_TYPE end
			if string.find(str,"gravel") then return DIRTGRASS_TYPE end
		-- Roof
			if string.find(str,"roof") then return ROOF_TYPE end
		-- Road
			if string.find(str,"road") then return ROAD_TYPE end
			if string.find(str,"asphalt") then return ROAD_TYPE end
		-- Pavement This is disabled, since it messes most maps up
			--if string.find(str,"pavement") or string.find(str,"cobble") or string.find(str,"concretefloor") then return PAVEMENT_TYPE end
		return NO_TYPE
	end
-- Material Type Generator
	function StormFox.MAP.GenerateTextureTree()
		local tree = {}
		-- Load all textures
			for _,tex_string in pairs(StormFox.MAP.AllTextures()) do
				if tree[tex_string:lower()] then continue end
				local mat = Material(tex_string)
				if not mat then continue end
				local tex1,tex2 = mat:GetTexture("$basetexture"),mat:GetTexture("$basetexture2")
				if not tex1 and not tex2 then continue end
				-- Guess from the textures
					if tex1 and not tex1:IsError() then
						local t = GetTexType(tex1:GetName())
						if t ~= NO_TYPE then
							tree[tex_string:lower()] = {}
							tree[tex_string:lower()][1] = t
						end
					end
					if tex2 and not tex2:IsError() then
						local t = GetTexType(tex2:GetName())
						if t ~= NO_TYPE then
							tree[tex_string:lower()] = tree[tex_string:lower()] or {}
							tree[tex_string:lower()][2] = t
						end
					end
			end
		return tree
	end
-- Find an entity-class matching the input
	function StormFox.MAP.FindClass(sClass)
		local t = {}
		for k,v in pairs(BSPDATA.Entities) do
			if string.match(v.classname,sClass) then
				table.insert(t,v)
			end
		end
		return t
	end
	function StormFox.MAP.FindTargetName(sTargetName)
		local t = {}
		for k,v in pairs(BSPDATA.Entities) do
			if string.match(v.targetname or "",sTargetName) then
				table.insert(t,v)
			end
		end
		return t
	end
	function StormFox.MAP.FindEntity(eEnt)
		local c = eEnt:GetClass()
		for k,v in pairs(BSPDATA.Entities) do
			if c == v.classname and eEnt:GetKeyValues().hammerid == v.hammerid then
				return v
			end
		end
		return
	end
	function StormFox.MAP.FindHammerid(id)
		for k,v in pairs(ents.GetAll()) do
			if v:GetKeyValues().hammerid == id then
				return v
			end
		end
		return
	end
-- Load
	GetBSPData()
	bbuf = nil
	-- FProfiler.stop()