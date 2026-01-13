AddCSLuaFile()
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Brazier (GPU Particles)"
ENT.Category = "Arcana"
ENT.Spawnable = true
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.Author = "Earu"

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "FloatHeight")
	self:NetworkVar("Float", 1, "CircleSize")

	if SERVER then
		-- Random float height between 80 and 150 units
		self:SetFloatHeight(math.Rand(100, 250))
		self:SetCircleSize(40)
	end
end

if SERVER then
	function ENT:Initialize()
		-- Use the shell model inverted
		self:SetModel("models/hunter/misc/shell2x2a.mdl")
		self:SetMaterial("arcana/pattern_antique_stone")

		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:Wake()
			phys:EnableMotion(false)
		end

		-- Start motion controller for floating
		self:StartMotionController()
		self.ShadowParams = {}

		-- Initialize rotation angle
		self._rotationAngle = 0

		-- Start looping fire sound
		self._fireSound = CreateSound(self, "ambient/fire/fire_med_loop1.wav")
		if self._fireSound then
			self._fireSound:Play()
			self._fireSound:SetSoundLevel(65)
		end
	end

	function ENT:SpawnFunction(ply, tr, className)
		if not tr or not tr.Hit then return end

		local pos = tr.HitPos + tr.HitNormal * 100
		local ent = ents.Create(classname or "arcana_brazier_gpu")
		if not IsValid(ent) then return end

		ent:SetPos(pos + Vector(0, 0, 100))
		ent:SetAngles(Angle(0, ply:EyeAngles().y, 0))
		ent:Spawn()
		ent:Activate()

		return ent
	end

	local TRACE_OFFSET = Vector(0, 0, 1000)
	local VECTOR_UP = Vector(0, 0, 1)

	function ENT:PhysicsSimulate(phys, deltatime)
		if not IsValid(phys) then return end

		phys:Wake()

		-- Trace down to find ground
		local currentPos = self.PositionOverride or self:GetPos()
		local tr = util.TraceLine({
			start = currentPos,
			endpos = currentPos - TRACE_OFFSET,
			mask = MASK_SOLID,
			filter = self,
		})

		-- Calculate target position from ground with gentle bobbing
		local bobOffset = math.sin(CurTime() * 0.8) * 8 + math.cos(CurTime() * 0.5) * 4
		local floatPos = tr.HitPos + (self:GetFloatHeight() + bobOffset) * VECTOR_UP

		-- Add extremely slow rotation
		self._rotationAngle = (self._rotationAngle + deltatime * 3) % 360
		local targetAng = Angle(180, self._rotationAngle, 0)

		-- Set shadow parameters for smooth floating
		self.ShadowParams.secondstoarrive = 0.15
		self.ShadowParams.pos = floatPos
		self.ShadowParams.angle = targetAng
		self.ShadowParams.maxangular = 3000
		self.ShadowParams.maxangulardamp = 8000
		self.ShadowParams.maxspeed = 100000
		self.ShadowParams.maxspeeddamp = 10000
		self.ShadowParams.dampfactor = 0.8
		self.ShadowParams.teleportdistance = 0
		self.ShadowParams.delta = deltatime

		phys:ComputeShadowControl(self.ShadowParams)
	end

	function ENT:OnRemove()
		-- Stop the looping fire sound cleanly
		if self._fireSound then
			self._fireSound:Stop()
			self._fireSound = nil
		end
	end
end

if CLIENT then
	-- Magical glow material
	local glowMat = Material("sprites/light_glow02_add")

	-- Create global material with scaled texture (4x larger) - shared by all braziers
	local BRAZIER_MATERIAL_NAME = "arcana_brazier_scaled_" .. FrameNumber()
	local BRAZIER_MATERIAL = CreateMaterial(BRAZIER_MATERIAL_NAME, "VertexLitGeneric", {
		["$basetexture"] = "arcana/pattern_antique_stone",
		["$basetexturetransform"] = "center 0 0 scale 0.25 0.25 rotate 0 translate 0 0",
		["$model"] = 1,
	})

	function ENT:Initialize()
		self._circle = nil

		-- Set large render bounds to account for:
		-- - Dynamic lights (up to 400 unit radius)
		-- - Fire particles rising high above
		-- - Magic circle potentially far below
		self:SetRenderBounds(Vector(-450, -450, -300), Vector(450, 450, 500))

		-- Initialize GPU particle systems
		if Arcana and Arcana.GPUParticles then
			-- Fire particles (main fire) - matching CPU config
			self._fireParticles = Arcana.GPUParticles.Create({
				maxParticles = 300,
				lifetime = 1.85, -- Average of 1.2-2.5
				spawnPosition = self:GetPos(),
				spawnRadius = 25,
				velocity = Vector(0, 0, 120), -- Average of 80-160
				velocityVariance = 25, -- VectorRand() * 25
				gravity = Vector(0, 0, 15),
				airResistance = 40,
				particleSize = 30, -- Average of 20-40 (start size)
				sizeVariance = 0.5,
				endSize = 8.5, -- Average of 5-12
				startAlpha = 255,
				endAlpha = 0,
				roll = 180, -- -180 to 180
				rollDelta = 8, -- -8 to 8 deg/sec (matching CPU)
				color = Color(255, 180, 50),
				texture = "effects/fire_cloud1",
			})

			-- Levitation magic particles (from below) - matching CPU config
			self._magicParticles = Arcana.GPUParticles.Create({
				maxParticles = 200,
				lifetime = 2.0, -- Average of 1.5-2.5
				spawnPosition = self:GetPos() - Vector(0, 0, self:GetFloatHeight() * 0.8),
				spawnRadius = 60,
				velocity = Vector(0, 0, 80), -- Average of 60-100
				velocityVariance = 15, -- x/y: -15 to 15
				gravity = Vector(0, 0, 0),
				airResistance = 25,
				particleSize = 6.5, -- Average of 4-9 (start size)
				sizeVariance = 0.3,
				endSize = 0, -- Fades to 0
				startAlpha = 220,
				endAlpha = 0,
				roll = 180, -- -180 to 180
				rollDelta = 2, -- -2 to 2 deg/sec (matching CPU)
				color = Color(255, 160, 50),
				texture = "sprites/light_glow02_add",
			})
		else
			ErrorNoHalt("[Arcana Brazier] GPU Particle system not loaded!\n")
		end
	end

	-- Create magic circle on ground underneath showing fire levitation
	function ENT:CreateLevitationCircle()
		if not MagicCircle or not MagicCircle.new then return end
		if self._circle and self._circle.IsActive and self._circle:IsActive() then return end

		-- Trace down to ground to get proper position and normal
		local center = self:GetPos()
		local tr = util.TraceLine({
			start = center,
			endpos = center - Vector(0, 0, 2000),
			mask = MASK_SOLID,
			filter = self,
		})

		if not tr.Hit then return end

		-- Position circle on the ground surface
		local pos = tr.HitPos + tr.HitNormal * 2

		-- Align circle with ground surface
		local ang = tr.HitNormal:Angle()
		ang:RotateAroundAxis(ang:Right(), 90)

		-- Fire magic color for levitation (orange/red)
		local circleColor = Color(255, 140, 50, 220)
		local size = 70
		local intensity = 5

		self._circle = MagicCircle.new(pos, ang, circleColor, intensity, size, 2.5)
		if self._circle then
			MagicCircleManager:Add(self._circle)
		end
	end

	function ENT:OnRemove()
		-- Clean up magic circle
		if self._circle and self._circle.Destroy then
			self._circle:Destroy()
		end
		self._circle = nil

		-- Clean up GPU particle systems
		if self._fireParticles then
			self._fireParticles:Destroy()
			self._fireParticles = nil
		end

		if self._magicParticles then
			self._magicParticles:Destroy()
			self._magicParticles = nil
		end
	end

	function ENT:Think()
		-- Ensure levitation circle exists below
		self:CreateLevitationCircle()

		-- Update circle position to stay on ground below brazier
		if self._circle and self._circle.IsActive and self._circle:IsActive() then
			local center = self:GetPos()
			local tr = util.TraceLine({
				start = center,
				endpos = center - Vector(0, 0, 2000),
				mask = MASK_SOLID,
				filter = self,
			})

			if tr.Hit then
				self._circle.position = tr.HitPos + tr.HitNormal * 2
				local ang = tr.HitNormal:Angle()
				ang:RotateAroundAxis(ang:Right(), 90)
				self._circle.angles = ang
			end
		end

		-- Update GPU particle spawn positions
		local center = self:GetPos()

		if self._fireParticles then
			self._fireParticles:SetSpawnPosition(center)
		end

		if self._magicParticles then
			-- Magic particles spawn from below
			local tr = util.TraceLine({
				start = center,
				endpos = center - Vector(0, 0, 2000),
				mask = MASK_SOLID,
				filter = self,
			})

			if tr.Hit then
				-- Spawn from ground, particles rise up to brazier
				self._magicParticles:SetSpawnPosition(tr.HitPos + tr.HitNormal * 5)
			end
		end

		self:SetNextClientThink(CurTime() + 0.05)
		return true
	end

	function ENT:Draw()
		-- Draw the brazier model with scaled material
		render.MaterialOverride(BRAZIER_MATERIAL)
		self:DrawModel()
		render.MaterialOverride()
	end

	function ENT:DrawTranslucent()
		local center = self:GetPos()
		local t = CurTime()

		-- Massive fire glow from inside brazier
		local pulse = 0.7 + 0.3 * math.sin(t * 2.5)
		local glowSize = 140 + 60 * pulse -- Much larger

		render.SetMaterial(glowMat)
		-- Outer orange fire glow
		--render.DrawSprite(center, glowSize, glowSize, Color(255, 160, 60, 220 * pulse))
		-- Mid yellow-orange glow
		--render.DrawSprite(center, glowSize * 0.7, glowSize * 0.7, Color(255, 200, 80, 200 * pulse))
		-- Inner bright yellow core
		--render.DrawSprite(center, glowSize * 0.4, glowSize * 0.4, Color(255, 240, 140, 240 * pulse))

		-- Fire magic levitation glow from below (on ground)
		local tr = util.TraceLine({
			start = center,
			endpos = center - Vector(0, 0, 2000),
			mask = MASK_SOLID,
			filter = self,
		})

		if tr.Hit then
			local magicPos = tr.HitPos + tr.HitNormal * 5
			local magicPulse = 0.6 + 0.4 * math.sin(t * 2.2)
			local magicSize = 140 + 50 * magicPulse

			render.DrawSprite(magicPos, magicSize, magicSize, Color(255, 140, 50, 150 * magicPulse))
		end

		-- Dynamic light (intense fire from above)
		local dl = DynamicLight(self:EntIndex())
		if dl then
			dl.pos = center
			dl.r = 255
			dl.g = 180
			dl.b = 60
			dl.brightness = 6 + pulse * 3
			dl.Decay = 400
			dl.Size = 400 -- Much larger light
			dl.DieTime = t + 0.1
		end

		-- Secondary light for fire levitation magic (below on ground)
		if tr.Hit then
			local dl2 = DynamicLight(self:EntIndex() + 1)
			if dl2 then
				local magicPulse = 0.6 + 0.4 * math.sin(t * 2.2)
				dl2.pos = tr.HitPos + tr.HitNormal * 5
				dl2.r = 255
				dl2.g = 140
				dl2.b = 50
				dl2.brightness = 3 + magicPulse * 2
				dl2.Decay = 300
				dl2.Size = 280
				dl2.DieTime = t + 0.1
			end
		end

		-- Draw GPU particles
		if self._fireParticles then
			self._fireParticles:Draw()
		end

		if self._magicParticles then
			self._magicParticles:Draw()
		end
	end
end
