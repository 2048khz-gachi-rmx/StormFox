
local clamp,min,max,ran,sin,cos,rad,ran,abs = math.Clamp,math.min,math.max,math.random,math.sin,math.cos,math.rad,math.random,math.abs
local rainmat_smoke = {}
for i = 1,5 do
	table.insert(rainmat_smoke,(Material("particle/smokesprites_000" .. i)))
end
-- ParticleEmiters
	_STORMFOX_PEM = _STORMFOX_PEM or ParticleEmitter(Vector(0,0,0),true)
	_STORMFOX_PEM2d = _STORMFOX_PEM2d or ParticleEmitter(Vector(0,0,0))
	_STORMFOX_PEM:SetNoDraw(true)
	_STORMFOX_PEM2d:SetNoDraw(true)

local particles = {}
	particles.main = {}
	particles.bg = {}

local rain_range = 250

local random_side = 300
local random_bg_side = 600

local downfallNorm = Vector(0,0,1)
local SysTime = SysTime
local EyeAngles = EyeAngles

local renvec, renpos = Vector(), Vector()

local function ubLerp(f, a, b)
	return a + ( b - a ) * f
end

local raindebug = StormFox.GetNetworkData("Raindebug",false)
local materials = {}
	materials.Rain 				= Material("stormfox/raindrop.png","noclamp smooth")
	materials.RainMultiTexture 	= Material("stormfox/raindrop-multi.png","noclamp smooth")
	materials.RainSmoke 	 	= Material("particle/smokesprites_0001")

	materials.Snow 				= Material("particle/snow")
	materials.SnowSmoke			= Material("particle/smokesprites_0001")
	materials.SnowMultiTexture	= Material("stormfox/snow-multi.png","noclamp smooth")
local snowEnabled,GaugeColor = true,Color(255,255,255)
local wind = StormFox.GetNetworkData("Wind",0) * 0.75
local temp = StormFox.GetNetworkData("Temperature",20)
local Gauge = StormFox.GetData("Gauge",0)
-- Downfall functions
	local util_TraceLine = util.TraceLine
	local util_TraceHull = util.TraceHull

	local out_t = {}
	local in_t = { output = out_t }

	local traceSharedVec = Vector()

	local function ETPos(pos, pos2, mask)
		in_t.start = pos
		in_t.endpos = pos2
		in_t.mask = mask
		in_t.filter = LocalPlayer():GetViewEntity() or LocalPlayer()

		util_TraceLine(in_t)

		-- t.HitPos = t.HitPos or (pos + pos2)
		return out_t
	end

	local function ET(pos, pos2, mask)
		traceSharedVec:Set(pos)
		traceSharedVec:Add(pos2)

		return ETPos(pos, traceSharedVec, mask)
	end

	local out_t = {}
	local in_t = { output = out_t }
	local mins, maxs = Vector(), Vector()

	local function ETHull(pos, pos2, size, mask)
		maxs:SetUnpacked(size, size, 4)
		mins:SetUnpacked(-size, -size, 0)

		traceSharedVec:Set(pos)
		traceSharedVec:Add(pos2)

		in_t.start = pos
		in_t.endpos = traceSharedVec
		in_t.maxs = maxs
		in_t.mins = mins
		in_t.mask = mask or LocalPlayer()
		in_t.filter = LocalPlayer():GetViewEntity() or LocalPlayer()

		util_TraceHull(in_t)

		return out_t
	end

	local function ETCalcTrace(pos,size,fDN)
		if not size then size = 1 end
		local sky = ET(pos, fDN * -16384) --, MASK_SHOT)
		if not sky.HitSky and sky.HitTexture != "TOOLS/TOOLSINVISIBLE" then
			return nil
		end -- Not under sky
		--PrintTable(ET(sky.HitPos,pos))
		--PrintTable(ET(sky.HitPos - Vector(0,0,5),pos))
		local btr = ETPos(sky.HitPos + fDN,pos  + fDN)
		if btr.Hit then return nil end -- Trace was inside world .. but backtrace checked it

		-- We got a valid position now .. for now
		local t_ground = ETHull(pos ,fDN * 16384 ,size , MASK_SHOT )
		if not t_ground.Hit then return nil,"No ground found" end -- Outside the world

		-- Checl fpr water
		local wtr = ETPos(t_ground.StartPos,t_ground.HitPos,-1)
		if wtr.Hit and string.find(wtr.HitTexture:lower(),"water") then
			t_ground = wtr
			t_ground.HitWater = true
		else
			t_ground.HitWater = false
		end
		return t_ground
	end
-- Do the math and update stuff outside
	local mainpos = Vector(0,0,0)
	timer.Create("StormFox - MainPos",0.5,0,function()
		if not StormFox.EFEnabled() then return end
		local lp = LocalPlayer()
		if not lp or not IsValid(lp) then return end

		local view = StormFox.GetCalcViewResult()
		local pos,ang = view.pos,view.ang
		local angf = ang:Forward()
			angf.z = 0
		local vel = lp:GetVelocity() * 0.6
			vel.z = 0
		local _tmainpos = pos + angf * (rain_range * 0.8)
			_tmainpos = ET(_tmainpos,Vector(0,0,rain_range - ran(50))).HitPos + (lp:GetShootPos() - lp:GetPos()) * 2 + vel
		if not _tmainpos then return end
		mainpos = _tmainpos
			--debugoverlay.Box(mainpos,Vector(0,0,0),Vector(5,5,5),1,Color( 255, 255, 255 ))
	end)
	timer.Create("StormFox - Downfallupdater",1,0,function()
		if not StormFox.EFEnabled() then return end
		raindebug = StormFox.GetNetworkData("Raindebug",false)
		-- update materials and vars
				materials.Rain 				= StormFox.GetData("RainTexture") or Material("stormfox/raindrop.png","noclamp smooth")
				materials.RainMultiTexture 	= StormFox.GetData("RainMultiTexture") or Material("stormfox/raindrop-multi.png","noclamp smooth")
				materials.RainSmoke 	 	= StormFox.GetData("RainSmoke") or Material("particle/smokesprites_0001")

				materials.Snow 				= StormFox.GetData("SnowTexture") or materials.RainSmoke or materials.Rain or Material("particle/snow")
				materials.SnowSmoke			= StormFox.GetData("SnowSmoke") or Material("particle/smokesprites_0001")
				materials.SnowMultiTexture	= StormFox.GetData("SnowMultiTexture") or materials.RainMultiTexture or Material("stormfox/snow-multi.png","noclamp smooth")
			snowEnabled,GaugeColor = StormFox.GetData("EnableSnow"),StormFox.GetData("GaugeColor") or Color(255,255,255)

		Gauge = StormFox.GetData("Gauge",0)
		temp = StormFox.GetNetworkData("Temperature",20)
		if Gauge <= 0 then return end

		wind = StormFox.GetNetworkData("Wind",0) * 0.75
		local windangle = StormFox.GetNetworkData("WindAngle",0)

		local downspeed = -max(1.56 * Gauge + 1.22,10) -- Base on realworld stuff .. and some tweaking (Was too slow)
		downfallNorm = Angle(0,windangle,0):Forward() * wind
			downfallNorm.z = downfallNorm.z + downspeed
	end)

local downForce = Vector()

-- Create Downfall drops
hook.Add("Think","StormFox - RenderFalldownThink",function()
	if not StormFox.EFEnabled() then return end
	if Gauge <= 0 then return end

	local sharedVec = Vector()
	local ft = RealFrameTime()

	local IsRain = true

	if temp < 5 and snowEnabled then
		if temp < -2 then
			IsRain = false
		else
			IsRain = temp > ran(-2,5)
		end
	end

	local exp = StormFox.GetExspensive()
	local maxparticles = max(exp,1) * 32

	local maxbg = 32 + max(exp,1) * 16 -- * (Gauge / 10)
	if not IsRain then maxbg = maxbg * 0.5 end

	local weight = IsRain and 1 or 0.2

	local dx, dy, dz = renvec:Unpack()

	downForce:Set(downfallNorm)

	if not IsRain then
		downForce:Mul(weight)
	end

	local fDN = downForce
	local fX, fY, fZ = downForce:Unpack()
	local max_gauge = 10

	if #particles.main < maxparticles then
		local maxmake = maxparticles - #particles.main
		local m = maxmake * ft * max_gauge * 2
		for i = 1,min(m,maxmake) do
			-- Make a rain/snowdrop

			local invx = 1 - dx
			local invy = 1 - dy

			sharedVec:SetUnpacked(
				ubLerp(ran(), -random_side - invy * 200, random_side + invy * 200) + fX * -(40 / weight),
				ubLerp(ran(), -random_side - invx * 200, random_side + invx * 200) + fY * -(40 / weight),
				ubLerp(ran(), 1 / weight * 25, 1 / weight * 30) -- desync the vertical speed for more uniform drops
			)

			sharedVec:Add(mainpos)

			local testpos = sharedVec
			testpos[3] = math.min(testpos[3], mainpos[3]) + ran() * 10
			
			--[[if not LocalPlayer():KeyDown(IN_SPEED) then
				debugoverlay.Axis(sharedVec, angle_zero, 5, 2, true)
			end]]

			local smoke = false -- ran(100) < min(wind * 2, 70) - 14

			local size = IsRain and (smoke and 20 * Gauge or clamp(Gauge / ran(3,5),1,3)) or (smoke and ran(10,30) * Gauge or clamp(Gauge / ran(3,5),1,3))
			local tr = ETCalcTrace(testpos, size, fDN)
			local break_ = IsRain and 1 or max(wind / 25,0.4)
			if tr then
				local drop = {}
					drop.smoke = smoke
				-- StartPos
					drop.pos = Vector(testpos)
				-- Norm
					drop.norm = fDN * break_
				-- Random
					drop.length_m = ran(1,2)
					drop.size = size
				-- EndPos
					drop.endpos = tr.HitPos
					-- debugoverlay.Axis(tr.HitPos, angle_zero, 5, 1, true)
				-- HitNormal
					drop.hitnorm = tr.HitNormal
				-- HitWater
					drop.hitwater = tr.HitWater
				-- NoDrop
					drop.nodrop = string.find(tr.HitTexture,"TOOLS/TOOLSSKYBOX") or string.find(tr.HitTexture,"TOOLS/TOOLSINVISIBLE") or smoke or false
					drop.alive = true
					drop.r = ran(360)
					drop.r2 = ran(10)
					drop.rain = IsRain
					drop.material = smoke and (IsRain and materials.RainSmoke or materials.SnowSmoke) or (IsRain and materials.Rain or materials.Snow)
				table.insert(particles.main,drop)
			end
		end
	end
-- Create Multi (background) Particle
	if #particles.bg < maxbg then
		local maxmake = maxbg - #particles.bg

		local m = maxmake * ft * max_gauge

		for i = 1,min(m,maxmake) do
			local s = ran(1, 4)
			local xx = 0
			local yy = 0
			local mindistance = random_bg_side * 2
			local maxdistance = random_bg_side * 4

			local dir = ran() * math.pi * 2
			local radRoll = ran()
			local rad = ubLerp(radRoll, mindistance, maxdistance)
			xx, yy = sin(dir) * rad, cos(dir) * rad

			local testpos = mainpos + Vector(xx + fDN.x * -(20 / weight) ,yy + fDN.y * -(20 / weight),1 / weight * 30)
			local smoke = ran(100) < clamp(wind * 2,0,70) - 14
			local size = smoke and (IsRain and 30 or 20 * max_gauge) or (clamp(max_gauge / ran(3,5), 1, 3) * (IsRain and 32 or 64 + Gauge * 4))
			local tr = ETCalcTrace(testpos,size,fDN)

			if tr then
				local drop = {}
				local break_ = smoke and (IsRain and 0.5 or 0.7) or 1
					drop.pos = testpos
					drop.norm = fDN * break_
					drop.smoke = smoke
					drop.a = 0
					drop.max_a = ubLerp(Gauge / 10, ubLerp(radRoll, 0.1, 0.3), ubLerp(radRoll, 0.3, 1))
					drop.size = size
					drop.length_m = ran(2,4)
					drop.endpos = tr.HitPos
					drop.hitnorm = tr.HitNormal
					drop.hitwater = string.find(tr.HitTexture,"water")
					drop.nodrop = string.find(tr.HitTexture,"TOOLS/TOOLSSKYBOX") or string.find(tr.HitTexture,"TOOLS/TOOLSINVISIBLE") or false
					drop.alive = true
					drop.r = ran(360)
					drop.r2 = ran(10)
					drop.ang = fDN:Angle()
					drop.rain = IsRain
					drop.squish = ran()
					drop.material = IsRain and (smoke and materials.RainSmoke or materials.RainMultiTexture) or (smoke and materials.SnowSmoke or materials.SnowMultiTexture)
				table.insert(particles.bg,drop)
				--if raindebug then
					--debugoverlay.Cross(testpos,10,0.1,Color(0,255,0))
					--debugoverlay.Cross(tr.HitPos,10,0.1,Color(255,255,255))
				--end
			end
		end
	end
end)

-- Handle and kill raindrops
	local rainsplash_w = Material("effects/splashwake3")
	local rainsplash = Material("effects/splash4")
	local last = SysTime()
	local pf = function( part, hitpos, hitnormal )
		part:SetDieTime(0)
	end

	local b = bench("thonk", 600)
	local toKill = {}

	local sharedVec = Vector()
	local sharedVec2 = Vector()
	local diffVec = Vector()

	hook.Add("Think","StormFox - RenderFalldownHandle",function()
		if not StormFox.EFEnabled() then return end
		-- b:Open()
		local FT = (SysTime() - last) * 100
		last = SysTime()

		local exp = StormFox.GetExspensive()
		local Gauge = StormFox.GetData("Gauge",0)
		local eyepos = StormFox.GetEyePos()

		if LocalPlayer():WaterLevel() >= 3 then return end
		--local sky_col = StormFox.GetData("Bottomcolor",Color(204,255,255))
		--	sky_col = Color(max(sky_col.r,24),max(sky_col.g,155),max(sky_col.b,155),155)

		local snowmat = StormFox.GetData("SnowTexture") or Material("particle/snow")
		local dropChance = ubLerp((exp / 20) ^ 0.5, 0.6, 0.06) -- inverse because less expensive = less particles already; we compensate this way

		local eyez = eyepos.z

		for id, data in ipairs(particles.main) do
			if not data.alive then continue end
			sharedVec:Set(data.norm)
			sharedVec:Mul(-FT)

			local speed = sharedVec
			local z = data.pos.z

			local toolow = z < eyez - 200

			if not data.markfordeath and (z <= data.endpos.z + speed.z + data.size / 2 or toolow) then
				-- mark for death
				data.markfordeath = true
				-- Skip to the bottom
				if not toolow then
					data.pos = data.endpos
					data.size = data.size / 2
				else
					data.alive = false
				end
			end

			if data.markfordeath then
				data.a = (data.a or 1) - FT / 250
				data.alive = data.a <= 0

				diffVec:Set(eyepos)
				diffVec:Sub(data.endpos)
				diffVec:Normalize()

				if exp >= 4 and ran() < dropChance and not data.nodrop and not data.smoke then
					-- Splash
					if data.rain then
						if data.hitwater then
							local p = _STORMFOX_PEM:Add(rainsplash_w,data.endpos + Vector(0,0,1))
								p:SetAngles(data.hitnorm:Angle())
								p:SetStartSize(8)
								p:SetEndSize(40)
								p:SetDieTime(1)
								p:SetEndAlpha(0)
								p:SetStartAlpha(4)
						else
							-- for reasons unknown, +1 doesn't suffice...??????
							-- it just straight up doesnt fucking show; i don't know why
							sharedVec2:SetUnpacked(0, 0, 19)
							sharedVec2:Add(data.endpos)

							-- debugoverlay.Axis(vec, angle_zero, 4, 1, true)
							local p = _STORMFOX_PEM:Add(rainsplash, sharedVec2)
								p:SetAngles(data.hitnorm:Angle())
								p:SetStartSize(4)
								p:SetEndSize(10)
								p:SetDieTime(0.2)
								p:SetEndAlpha(0)
								p:SetStartAlpha(40)
							--	p:SetColor(sky_col)
						end
					else
						-- Snow
						if data.hitwater then
							local p = _STORMFOX_PEM:Add(rainsplash_w,data.endpos + Vector(0,0,1))
							p:SetAngles(data.hitnorm:Angle())
							p:SetStartSize(8)
							p:SetEndSize(40)
							p:SetDieTime(1)
							p:SetEndAlpha(0)
							p:SetStartAlpha(4)
						else
							local p = _STORMFOX_PEM2d:Add(snowmat,data.endpos + Vector(0,0,1))
							p:SetStartSize(min(1.5,data.size))
							p:SetEndSize(min(1.5,data.size))
							p:SetDieTime(4)
							p:SetEndAlpha(0)
							p:SetStartAlpha(200)
						end
					end
				end
			end

			if data.alive then
				data.a = min(1, (data.a or 0) + FT / 50)
				data.pos:Sub(speed)
			else
				toKill[#toKill + 1] = id
			end

		end

		if toKill[1] then
			local main = particles.main
			local len = #main

			for i = #toKill, 1, -1 do
				main[toKill[i]] = main[len] -- replace the dead particle with the last element in the array
				main[len] = nil -- then kill the last element (so there are no duplicates) ((also takes care of the case where the last element is the dead one))
				toKill[i] = nil
				len = len - 1
			end
		end

		for id,data in ipairs(particles.bg) do
			if not data.alive then continue end

			sharedVec:Set(data.norm)
			sharedVec:Mul(-FT * (data.rain and 3 or 1))

			local speed = sharedVec
			local z = data.pos.z

			local toolow = z < eyez - 400

			if not data.markfordeath and (z <= data.endpos.z + speed.z - data.size / 2 or toolow) then
				-- Skip to the bottom
				if not toolow then
					-- data.pos = data.endpos
					data.markfordeath = true
				else
					data.alive = false
				end
			elseif data.markfordeath then
				data.a = (data.a or 1) - FT / 20
				data.alive = data.a > 0

				if exp >= 4 and ran() < dropChance / 3 and not data.nodrop then
					-- Splash
					local size = max(wind * 8.2, 120)
					if data.rain then
						local p = _STORMFOX_PEM2d:Add(table.Random(rainmat_smoke),data.endpos + (data.hitnorm * size) ) -- + Vector(0,0,ran(size / 2,size * 0.4)
							p:SetAngles(data.hitnorm:Angle())
							p:SetStartSize(size)
							p:SetEndSize(size * 1.2)
							p:SetDieTime(ran(2,5))
							p:SetEndAlpha(0)
							p:SetStartAlpha( min(max(1000 / _STORMFOX_PEM2d:GetNumActiveParticles(), 2), 5) )
							p:SetColor(255,255,255)
							p:SetGravity(Vector(0,0,ran(4)))
							p:SetCollide(true)
							p:SetBounce(0)
							p:SetAirResistance(20)
							p:SetVelocity(Vector(downfallNorm.x * wind,downfallNorm.y * wind,0) + data.hitnorm * -10)
							p:SetCollideCallback( pf )
							--	p:SetStartLength(1)
						data.alive = false
					elseif false then
						-- Snow
						if data.hitwater then
							local p = _STORMFOX_PEM:Add(rainsplash_w,data.endpos + Vector(0,0,1))
							p:SetAngles(data.hitnorm:Angle())
							p:SetStartSize(8)
							p:SetEndSize(30)
							p:SetDieTime(1)
							p:SetEndAlpha(0)
							p:SetStartAlpha(50)
						else
							local p = _STORMFOX_PEM2d:Add(snowmat,data.endpos + Vector(0,0,1))
							p:SetStartSize(min(1.5,data.size))
							p:SetEndSize(min(1.5,data.size))
							p:SetDieTime(4)
							p:SetEndAlpha(0)
							p:SetStartAlpha(255)
						end
					end
				end
			end

			if data.alive then -- still alive, keep the sim
				data.a = min(data.max_a or 1, data.a + FT / 50)
				data.pos:Sub(speed)
			else
				toKill[#toKill + 1] = id
			end
		end

		if toKill[1] then
			local main = particles.bg
			local len = #main

			for i = #toKill, 1, -1 do
				main[toKill[i]] = main[len] -- replace the dead particle with the last element in the array
				main[len] = nil -- then kill the last element (so there are no duplicates) ((also takes care of the case where the last element is the dead one))
				toKill[i] = nil
				len = len - 1
			end
		end

		-- b:Close():print()
	end)
-- Render the raindrops
	local render_DrawBeam = render.DrawBeam
	local render_DrawSprite = render.DrawSprite
	local render_SetMaterial = render.SetMaterial

	local sharedCol = Color(204, 255, 255)

	local rainCol = Color(0, 0, 0)
	local rainColSmoke = Color(0, 0, 0)
	local snowCol = Color(0, 0, 0)
	local snowColSmoke = Color(0, 0, 0)

	local sharedVec = Vector()
	local b = bench("render", 600)
	local diff = Vector()

	local RenderRain = function(depth, sky)
		--if depth or sky then return end
		--if true then return end
		if LocalPlayer():WaterLevel() >= 3 then return end
		if not StormFox.GetData then return end
		if depth or sky then return end

		-- b:Open()

		_STORMFOX_PEM:Draw()
		_STORMFOX_PEM2d:Draw()
		local Gauge = StormFox.GetData("Gauge",0)
		local alpha = 75 + min(Gauge * 10,150)

		rainCol:Set(GaugeColor.r, GaugeColor.g, GaugeColor.b, 15)
		rainColSmoke:Set(GaugeColor.r * 0.5, GaugeColor.g * 0.5, GaugeColor.b * 0.5, 15)

		snowCol:Set(GaugeColor.r * 0.5, GaugeColor.g * 0.5, GaugeColor.b * 0.5)
		snowColSmoke:Set(GaugeColor.r * 0.5, GaugeColor.g * 0.5, GaugeColor.b * 0.5, max(5, Gauge * 2))

		local lastMat
		local renvec = LocalPlayer():GetAimVector()

		for id, data in ipairs(particles.main) do

			diff:Set(renpos)
			diff:Sub(data.pos)
			-- diff:Normalize()

			if diff:Dot(renvec) > 0 then continue end

			local useMat = data.material or materials.Rain
			if lastMat ~= useMat then
				render_SetMaterial(useMat)
				lastMat = useMat
			end

			if data.rain then
				if data.smoke then
					rainColSmoke.a = 15 * data.a
					render_DrawSprite(data.pos, data.size, data.size, rainColSmoke)
				else
					sharedVec:Set(data.norm)
					sharedVec:Mul(-data.size * data.length_m)
					sharedVec:Add(data.pos)

					render_DrawBeam(data.pos, sharedVec, 10 * data.size, 1, 0, rainCol)
				end
			else
				if data.smoke then
					snowColSmoke.a = max(5, Gauge * 2) * data.a
					render_DrawSprite(data.pos, data.size * 1.4, data.size * 1.4, snowColSmoke)
				else
					local d = data.pos.z - data.endpos.z + data.r
					local n = sin(d / 100)
					local s = data.size
					local nn = max(0, 16 - wind)


					sharedVec:SetUnpacked(n * nn, n * nn, 0)
					sharedVec:Add(data.pos)

					render_DrawSprite(sharedVec, s, s, snowCol)
					-- debugoverlay.Axis(sharedVec, angle_zero, 4, 0.1, true)
				end
			end

			if raindebug then
				render_SetMaterial(Material("sprites/sent_ball"))
				if data.smoke then
					render_DrawSprite(data.endpos, 10,10,Color(0,0,255))
				else
					render_DrawSprite(data.endpos, 10,10,Color(0,255,0))
				end
			end
		end


		render.DepthRange(0.25, 1)

		for id,data in ipairs(particles.bg) do
			-- do NOT render the background particles up against the player's eyes.
			-- worst mistake of my life.
			diff:Set(renpos)
			diff:Sub(data.pos)
			-- diff:Normalize()

			if diff:Dot(renvec) > 0 then continue end

			if lastMat ~= data.material then
				render_SetMaterial(data.material)
				lastMat = data.material
			end

			if data.rain then

				sharedVec:Set(data.norm)
				sharedVec:Mul(-data.size * data.length_m)
				sharedVec:Add(data.pos)

				if data.smoke then
					--render.DrawBeam(startPos,  endPos                    ,number width,number textureStart,number textureEnd,table color)
					rainCol.a = 6 * data.a
					render_DrawBeam(data.pos, sharedVec, 4 * data.size, 1, 0, rainCol)
				else
					rainColSmoke.a = 25 * (data.a ^ 0.2)
					render_DrawBeam(  data.pos,  sharedVec, data.size * 6, 2, 0, rainColSmoke)
				end
			else
				if data.smoke then
					rainCol.a = data.a

					sharedVec:Set(data.norm)
					sharedVec:Mul(-data.size * data.length_m)
					sharedVec:Add(data.pos)

					render_DrawBeam(  data.pos,  sharedVec,  data.size * 10, 1, 0, rainCol)
				else
					rainCol.a = 55 * (data.a or 1)

					local d = data.pos.z - data.endpos.z + data.r
					local n = sin(d / 150)
					local s = data.size * 10
					local nn = clamp(10 + Gauge * 4, 0, 32)

					-- hack: /10 to then mul by 10
					sharedVec:SetUnpacked(n * nn / 10, n * nn / 10, 0)
					sharedVec:Add(data.ang:Forward())
					sharedVec:Mul(10)
					sharedVec:Add(data.pos)

					render_DrawSprite(sharedVec, s, s * ubLerp(data.squish, 1.2, 1.7), rainCol)
				end
			end
			if raindebug then
				render_SetMaterial(Material("sprites/sent_ball"))
				render_DrawSprite(data.endpos, 10,10,Color(255,0,0))
			end
		end
		render.DepthRange(0, 1)
		-- b:Close():print()
	end

	hook.Add("PostDrawTranslucentRenderables", "StormFox - RenderFalldown", function(depth,sky)
		if sky or depth then return end
		if not StormFox.EFEnabled() then return end

		renvec, renpos = EyeVector(), EyePos()
		RenderRain(depth,sky)
	end)

-- 2D Rain
	local screenParticles = {}
	local l = 0
	local w = 0
	local rand = math.Rand
	local viewAmount = 0
	local rainAmount = 0
	local snow_particles = {(Material("particle/smokesprites_0001")),(Material("particle/smokesprites_0002")),(Material("particle/smokesprites_0003"))}
	local rain_particles = { (Material("stormfox/effects/raindrop")), (Material("stormfox/effects/raindrop2"))}--, (Material("stormfox/effects/raindrop2")) }
	-- Create 2D raindrops
		hook.Add("Think","StormFox - RenderFalldownScreenThink",function()
			if not LocalPlayer() then return end
			if not StormFox.EFEnabled() then table.Empty(screenParticles) return end
			local Gauge = StormFox.GetData("Gauge",0)
			if LocalPlayer():WaterLevel() >= 3 or Gauge <= 0 then
				if #screenParticles > 0 then
					table.Empty(screenParticles)
				end
				return
			end
			if l > SysTime() then return end
			-- Bin old particles
				for i = #screenParticles,1,-1 do
					if screenParticles[i].life < SysTime() then
						table.remove(screenParticles,i)
					end
				end
			-- Is it even raining?
				
				if Gauge <= 0 then table.Empty(screenParticles) return end
			-- Safty first
				if #screenParticles > 200 then return end
			-- Are you standing in the rain?
				if not StormFox.Env.IsInRain() then return end
			-- Get the temp and type
				local temp = StormFox.GetNetworkData("Temperature",20)
				local rain = temp > 0
			-- Get the dot
				local fDN = Vector(downfallNorm.x,downfallNorm.y,downfallNorm.z * 1)
					fDN:Normalize()
				local a = EyeAngles():Forward():Dot(fDN)
			viewAmount = -a
			if viewAmount <= 0 then viewAmount = 0 return end
			rainAmount = max((10 - Gauge) / 10,0.1) -- 0 in heavy rain, 1 in light
			-- Next rainrop
				l = SysTime() + (rand(rainAmount,rainAmount * 2) / viewAmount * 0.01 * (rain and 1 or 100))
			local drop = {}
				drop.life = SysTime() + ran(0.4,1)
				drop.x = ran(ScrW())
				drop.y = ran(ScrH())
				drop.size = 25 + rand(2,3) * Gauge * (rain and 1 or 2)
				drop.weight = ran(0,1)
				drop.rain = rain
				drop.r = ran(360)
				drop.p = rain and ran(1,#rain_particles) or ran(1,#snow_particles)
			table.insert(screenParticles,drop)
		end)
	-- 2D rainscreenfunctions
		local ceil = math.ceil
		local function drawSemiRandomUV(x,y,w,h,length,height)
			local nw = ceil(w / length)
			local nh = ceil(h / height)
			local flipi = 0
			local flip = 1
			local flipy = 1
			for ih = 1,nh do
				for i = 1,nw do
					flipi = flipi + 1
					if flipi == 2 then
						flip = 1 - flip
					end
					if flipi > 3 then
						flipy = 1 - flipy
					end
					surface.DrawTexturedRectUV(x + (i - 1) * length,y + (ih - 1) * height,length,height,1 - flip,1 - flipy,flip,flipy)
				end
			end
		end

-- Draw drain on screen
	local RainScreen_RT = GetRenderTarget("StormFox RainScreenRT",ScrW(),ScrH())
	local ScreenDummy = Material("stormfox/effects/rainscreen_dummy")
	local mat_Copy		= Material( "pp/fb" )
	local rainscreen_mat = Material("stormfox/effects/rainscreen", "noclamp")

	local old_raindrop = Material("sprites/heatwave")
	local rainscreen_alpha = 0
	hook.Add("HUDPaint","StormFox - RenderRainScreen",function()
		if not LocalPlayer() then return end
		local con = GetConVar("sf_allow_raindrops")
		if con and not con:GetBool() then return end
		if not StormFox.EFEnabled() then return end

		local Gauge = StormFox.GetData("Gauge",20)
		if LocalPlayer():WaterLevel() >= 3 then rainscreen_alpha = 0.8 return end
		local ft = RealFrameTime()
		local temp = StormFox.GetNetworkData("Temperature",20)

		local acc = (viewAmount * clamp(temp - 4,0,(Gauge / 200))) * ft * 2
		if acc <= 0 or not StormFox.Env.IsInRain() or Gauge <= 0 then
			acc = -0.1 * ft
		end
		rainscreen_alpha = clamp(rainscreen_alpha + acc, 0, 0.6)
		if rainscreen_alpha <= 0 then return end
		--if true then return end
		cam.Start2D()
		local w,h = ScrW(),ScrH()
		local scale = 256 * 1
		-- Copy the backbuffer to the screen effect texture
		render.UpdateScreenEffectTexture()
		-- Render the screen
		local OldRT = render.GetRenderTarget()
			ScreenDummy:SetFloat( "$translucent", 1 )
			ScreenDummy:SetFloat( "$alpha", 1 - rainscreen_alpha )
			ScreenDummy:SetFloat( "$vertexalpha", 1 )

			render.SetRenderTarget( RainScreen_RT )
				render.SetMaterial( mat_Copy )
				render.DrawScreenQuad()
		-- Reset
		render.SetRenderTarget( OldRT )
		-- Draw raindrops
			surface.SetDrawColor(255,255,255)
			surface.SetMaterial(rainscreen_mat)
			local st = SysTime()

			for i=1, 2 do
				
				local mult = (-1) ^ i
				local u0 = ((st + (i * 43.7)) * mult / 150) % 1
				local v0 = (-(st + (i * 8.5)) / 30) % 1

				surface.DrawTexturedRectUV(0, 0, w, h, u0, v0, (i * 2) + u0, (i * 2) + v0)
				-- drawSemiRandomUV(0, 0, w, h, scale + y / scale, scale - y / scale)
			end
		-- Override screen with old and draw
			ScreenDummy:SetTexture("$basetexture",RainScreen_RT)
		cam.End2D()
		render.SetMaterial(ScreenDummy)
		render.DrawScreenQuad()
	end)

	hook.Add("HUDPaint","StormFox - RainScreenEffect",function()
		if not StormFox.EFEnabled() then return end
		surface.SetDrawColor(255,255,255)
		local grav = max(50 -  abs(EyeAngles().p),0) / 60 --Gravity the raindrops
		local con = GetConVar("sf_allow_raindrops")
		local oldrain = con and not con:GetBool() or false
		local ms = 1
		if oldrain then
			ms = 2
		end

		local rain

		for i,d in ipairs(screenParticles) do
			if d.rain then
				if not rain then
					rain = true
					surface.SetDrawColor(255, 255, 255)
				end

				surface.SetMaterial(oldrain and old_raindrop or rain_particles[d.p or 1])
				surface.DrawTexturedRect(d.x,d.y,d.size * ms,d.size * 1.2 * ms)
				screenParticles[i].y = d.y + grav * d.weight * 100 * FrameTime()
			else
				rain = false
				local ll = d.life - SysTime()
				surface.SetDrawColor(255,255,255,55 * ll)
				surface.SetMaterial(snow_particles[d.p])
				surface.DrawTexturedRectRotated(d.x,d.y,d.size + d.weight * 5,d.size + d.weight * 5,d.r)
				screenParticles[i].y = d.y + grav * d.weight * 100 * FrameTime()
			end
			screenParticles[i].weight = max(screenParticles[i].weight - rand(1,0.2) * FrameTime(),0.01)
		end
	end)