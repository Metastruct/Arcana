AddCSLuaFile()

ENT.ClassName = "arcana_fairy"
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.Category = "Arcana"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

ENT.Size = 1
ENT.Visibility = 0
ENT.next_sound = 0
ENT.WingSpeed = 6.3
ENT.FlapLength = 30
ENT.WingSize = 0.4
ENT.SizePulse = 1
ENT.Blink = math.huge

if CLIENT then
	local function DrawFairySunbeams()
		local fairies = ents.FindByClass("arcana_fairy")
		local count = #fairies
		for key, ent in ipairs(fairies) do
			ent:DrawSunbeams(ent:GetPos(), 0.05/count, 0.025)
		end
	end

	local function VectorRandSphere()
		return Angle(math.Rand(-180,180), math.Rand(-180,180), math.Rand(-180,180)):Up()
	end

	function ENT:SetFairyHue(hue)
		self.Color = HSVToColor(hue, 0.4, 1)
	end

	function ENT:SetFairyColor(color)
		self.Color = color
	end

	do -- sounds
		function ENT:CalcSoundQueue(play_next_now)
			if #self.SoundQueue > 0 and (play_next_now or self.next_sound < CurTime()) then

				-- stop any previous sounds
				if self.current_sound then
					self.current_sound:Stop()
				end

				-- remove and get the first sound from the queue
				local data = table.remove(self.SoundQueue, 1)

				if data.snd and data.pitch then
					data.snd:PlayEx(100, data.pitch)

					-- pulse the fairy a bit so it looks like it's talking
					self:PulseSize(1.3, 1.8)

					-- store the sound so we can stop it before we play the next sound
					self.current_sound = data.snd
				end

				-- store when to play the next sound
				self.next_sound = CurTime() + data.duration
			end
		end

		function ENT:AddToSoundQueue(path, pitch, play_now)

			-- if play_now is true don't add to the old queue
			local queue = play_now and {} or self.SoundQueue

			if path == "." then
				table.insert(
					queue,
					{
						duration = 0.5,
					}
				)
			else
				table.insert(
					queue,
					{
						snd = CreateSound(self, path),
						pitch = pitch,

						-- get the sound length of the sound and scale it with the pitch above
						-- the sounds have a little empty space at the end so subtract 0.05 seconds from their time
						duration = SoundDuration(path) * (pitch / 100) - 0.05,
					}
				)
			end

			self.SoundQueue = queue

			if play_now then
				self:CalcSoundQueue(true)
			end
		end

		function ENT:Ouch(time)
			time = time or 0

			local path = "arcana/fairy/nymph/NymphHit_0"..math.random(4)..".wav"
			local pitch = math.random(95,105)

			self:AddToSoundQueue(path, pitch, true)

			-- make the fairy hurt for about 1-2 seconds
			self.Hurting = true

			timer.Simple(time, function()
				if self:IsValid() then
					self.Hurting = false
				end
			end)
		end

		-- this doesn't need to use the sound queue
		function ENT:Bounce()
			local csp = CreateSound(self, "arcana/fairy/bonk.wav")
			csp:PlayEx(100, math.random(150, 220))
			csp:FadeOut(math.random()*0.75)
		end
	end

	local wing_mdl = Model("models/arcana/fairy/wing.mdl")
	local function CreateEntity(mdl)
		local ent = ClientsideModel(mdl)

		ent:SetMaterial("models/arcana/fairy/wing")

		function ent:RenderOverride()
			if self.scale then
				local matrix = Matrix()
				matrix:Scale(self.scale)
				self:EnableMatrix("RenderMultiply", matrix)
			end

			render.CullMode(1)
			self:DrawModel()
			render.CullMode(0)
			self:DrawModel()
		end

		return ent
	end

	function ENT:Initialize()
		self.SoundQueue = {}

		self.Emitter = ParticleEmitter(vector_origin)
		self.Emitter:SetNoDraw(true)

		self:InitWings()

		self.light = DynamicLight(self:EntIndex())
		self.light.Decay = -0
		self.light.DieTime = 9999999

		self.flap = CreateSound(self, "arcana/fairy/flap.wav")
        self.float = CreateSound(self, "arcana/fairy/float.wav")

        self.flap:Play()
        self.float:Play()

        self.flap:ChangeVolume(0.2)

		-- randomize the fairy hue
		self:SetFairyHue(tonumber(util.CRC(self:EntIndex()))%360)

		-- random size
		self.Size = (tonumber(util.CRC(self:EntIndex()))%100/100) + 0.5

		self.pixvis = util.GetPixelVisibleHandle()

		if render.SupportsPixelShaders_2_0() then
			hook.Add("RenderScreenspaceEffects", "arcana_fairy_sunbeams", DrawFairySunbeams)
		end
	end

	function ENT:InitWings()
		self.leftwing = CreateEntity(wing_mdl)
		self.rightwing = CreateEntity(wing_mdl)
		self.bleftwing = CreateEntity(wing_mdl)
		self.brightwing = CreateEntity(wing_mdl)

		self.leftwing:SetNoDraw(true)
		self.rightwing:SetNoDraw(true)
		self.bleftwing:SetNoDraw(true)
		self.brightwing:SetNoDraw(true)
	end

	function ENT:DrawTranslucent()
		self:CalcAngles()

		self:DrawParticles()
		self:DrawWings(0)
		self:DrawSprites()
	end

	function ENT:Draw()
		self:DrawTranslucent()
	end

	function ENT:Think()
		self:CalcSounds()
		self:CalcLight()
		self:CalcPulse()

		self:NextThink(CurTime())
		return true
	end

	function ENT:PulseSize(min, max)
		self.SizePulse = math.Rand(min or 1.3, max or 1.8)
	end

	function ENT:CalcPulse()
		self.SizePulse = math.Clamp(self.SizePulse + ((1 - self.SizePulse) * FrameTime() * 5), 1, 3)
	end

	function ENT:CalcAngles()
		if self.Hurting then return end

		local vel = self:GetVelocity()
		if vel:Length() > 10 then
			local ang = vel:Angle()
			self:SetAngles(ang)
			self:SetRenderAngles(ang)
			self.last_ang = ang
		elseif self.last_ang then
			self:SetAngles(self.last_ang)
		end
	end

	function ENT:CalcSounds()
		local own = self:GetOwner()

		if own:IsValid() and own.VoiceVolume then
			self.SizePulse = (own:VoiceVolume() * 10) ^ 0.5
		end

		if self.Hurting then
			self.flap:Stop()
		else
			self.flap:Play()
			self.flap:ChangeVolume(0.2)
		end

	    local length = self:GetVelocity():Length()

        self.float:ChangePitch(length/50+100)
        self.float:ChangeVolume(length/100)

        self.flap:ChangePitch((length/50+100) + self.SizePulse * 20)
		self.flap:ChangeVolume(0.1+(length/100))

		self:CalcSoundQueue()
	end

	function ENT:CalcLight()
		if self.light then
			self.light.Pos = self:GetPos()

			self.light.r = self.Color.r/8
			self.light.g = self.Color.g/8
			self.light.b = self.Color.b/8

			self.light.Brightness = self.Size * 0.5
			self.light.Size = math.Clamp(self.Size * 512/2, 0, 1000)
		end
	end

	local glow = Material("sprites/light_glow02_add")
	local warp = Material("particle/warp2_warp")
	local mouth = Material("icon16/add.png")
	local blur = Material("sprites/heatwave")

	local eye_hurt = Material("sprites/key_12")
	local eye_idle = Material("icon16/tick.png")
	local eye_happy = Material("icon16/error.png")
	local eye_heart = Material("icon16/heart.png")

	function ENT:DrawSprites()
		local pos = self:GetPos()
		local pulse = math.sin(CurTime()*2) * 0.5

		render.SetMaterial(warp)
			render.DrawSprite(
				pos, 12 * self.Size + pulse,
				12 * self.Size + pulse,
				Color(self.Color.r, self.Color.g, self.Color.b, 100)
			)

		render.SetMaterial(blur)
			render.DrawSprite(
				pos, (1-self.SizePulse) * 20,
				(1-self.SizePulse) * 20,
				Color(10,10,10, 1)
			)

		render.SetMaterial(glow)
			render.DrawSprite(
				pos,
				50 * self.Size,
				50 * self.Size,
				Color(self.Color.r, self.Color.g, self.Color.b, 150)
			)
			render.DrawSprite(
				pos,
				30 * self.Size,
				30 * self.Size,
				self.Color
			)

		local fade_mult = math.Clamp(-self:GetForward():Dot((self:GetPos() - EyePos()):GetNormalized()), 0, 1)

		if fade_mult ~= 0 then
			if self.Hurting then
				render.SetMaterial(eye_hurt)
			else
				render.SetMaterial(eye_heart)
			end

			if self.Blink > CurTime() then
				for i = 0, 1 do
					render.DrawSprite(
						pos + (self:GetRight() * (i == 0 and 0.8 or -0.8) + self:GetUp() * 0.7) * self.Size,

						0.5 * fade_mult * self.Size,
						0.5 * fade_mult * self.Size,

						Color(10,10,10,200 * fade_mult)
					)
				end
			else
				self.Blink = math.random() < 0.99 and CurTime()-0.2 or math.huge
			end

			render.SetMaterial(mouth)

			render.DrawSprite(
				pos + (self:GetRight() * -0.05 -self:GetUp() * 0.7) * self.Size,

				0.6 * fade_mult * self.Size * self.SizePulse ^ 1.5,
				0.6 * fade_mult * self.Size * self.SizePulse,

				Color(10, 10, 10, 200 * fade_mult)
			)
		end
	end

	function ENT:DrawSunbeams(pos, mult, siz)
		local ply = LocalPlayer()
		local eye = EyePos()

		self.Visibility = util.PixelVisible(self:GetPos(), self.Size * 4, self.pixvis)

		if self.Visibility > 0 then
			local spos = pos:ToScreen()
			DrawSunbeams(
				0.25,
				math.Clamp(mult * (math.Clamp(EyeVector():DotProduct((pos - eye):GetNormalized()) - 0.5, 0, 1) * 2) ^ 5, 0, 1),
				siz,
				spos.x / ScrW(),
				spos.y / ScrH()
			)
		end
	end

	function ENT:DrawParticles()
		local particle = self.Emitter:Add("particle/fire", self:GetPos() + (VectorRandSphere() * self.Size * 4 * math.random()))
		local mult = math.Clamp((self:GetVelocity():Length() * 0.1), 0, 1)

		particle:SetDieTime(math.Rand(0.5, 2)*self.SizePulse*5)
		particle:SetColor(self.Color.r, self.Color.g, self.Color.b)


		if self.Hurting then
			particle:SetGravity(physenv.GetGravity())
			particle:SetVelocity((self:GetVelocity() * 0.1) + (VectorRandSphere() * math.random(20, 30)))
			particle:SetAirResistance(math.Rand(1,3))
		else
			particle:SetAirResistance(math.Rand(5,15)*10)
			particle:SetVelocity((self:GetVelocity() * 0.1) + (VectorRandSphere() * math.random(2, 5))*(self.SizePulse^5))
			particle:SetGravity(VectorRand() + physenv.GetGravity():GetNormalized() * (math.random() > 0.9 and 10 or 1))
		end

		particle:SetStartAlpha(0)
		particle:SetEndAlpha(255)

		particle:SetStartSize(math.Rand(1, self.Size*8)/3)
		particle:SetEndSize(0)

		particle:SetCollide(true)
		particle:SetRoll(math.random())
		particle:SetBounce(0.8)

		self.Emitter:Draw()
	end

	function ENT:DrawWings(offset)
		if not self.leftwing:IsValid() then
			self:InitWings()
		return end

		local size = self.Size * self.WingSize * 0.4
		local ang = self:GetAngles()
		ang:RotateAroundAxis(self:GetUp(), -90)

		offset = offset or 0
		self.WingSpeed = 6.3 * (self.Hurting and 0 or 1)

		local leftposition, leftangles = LocalToWorld(Vector(0, 0, 0), Angle(0,TimedSin(self.WingSpeed,self.FlapLength*2,0,offset), 0), self:GetPos(), ang)
		local rightposition, rightangles = LocalToWorld(Vector(0, 0, 0), Angle(0, -TimedSin(self.WingSpeed,self.FlapLength*2,0,offset), 0), self:GetPos(), ang)


		self.leftwing:SetPos(leftposition)
		self.rightwing:SetPos(rightposition)

		self.leftwing:SetAngles(leftangles)
		self.rightwing:SetAngles(rightangles)

		local bleftposition, bleftangles = LocalToWorld(Vector(0, 0, -0.5), Angle(30, TimedSin(self.WingSpeed,self.FlapLength,0,offset+math.pi)/2, 50), self:GetPos(), ang)
		local brightposition, brightangles = LocalToWorld(Vector(0, 0, -0.5), Angle(-30, -TimedSin(self.WingSpeed,self.FlapLength,0,offset+math.pi)/2, 50), self:GetPos(), ang)

		self.bleftwing:SetPos(bleftposition)
		self.brightwing:SetPos(brightposition)

		self.bleftwing:SetAngles(bleftangles)
		self.brightwing:SetAngles(brightangles)

		render.SuppressEngineLighting(true)
		render.SetColorModulation(self.Color.r/200, self.Color.g/200, self.Color.b/200)

		self.leftwing.scale = Vector(0.75,1.25,2.5)*size
		self.rightwing.scale = Vector(0.75,1.25,2.5)*size

		self.bleftwing.scale = Vector(0.25,0.75,2)*size
		self.brightwing.scale = Vector(0.25,0.75,2)*size

		self.leftwing:SetupBones()
		self.rightwing:SetupBones()
		self.bleftwing:SetupBones()
		self.brightwing:SetupBones()

		self.leftwing:DrawModel()
		self.rightwing:DrawModel()
		self.bleftwing:DrawModel()
		self.brightwing:DrawModel()

		render.SetColorModulation(0,0,0)
		render.SuppressEngineLighting(false)
	end

	function ENT:OnRemove()
        SafeRemoveEntity(self.leftwing)
        SafeRemoveEntity(self.rightwing)
        SafeRemoveEntity(self.bleftwing)
        SafeRemoveEntity(self.brightwing)

		self.flap:Stop()
		self.float:Stop()

		self.light.Decay = 0
		self.light.DieTime = 0

		if #ents.FindByClass("arcana_fairy") == 1 then
			hook.Remove("RenderScreenspaceEffects", "arcana_fairy_sunbeams")
		end
	end

	net.Receive("arcana_fairy_func_call", function()
		local ent = net.ReadEntity()
		local func = net.ReadString()
		local args = net.ReadTable()

		if ent:IsValid() then
			ent[func](ent, unpack(args))
		end
	end)
end

if SERVER then
	util.AddNetworkString("arcana_fairy_func_call")
	util.AddNetworkString("Arcana_FairyVendor_Open")
	util.AddNetworkString("Arcana_FairyVendor_Confirm")

	resource.AddFile("models/arcana/fairy/wing.mdl")
	resource.AddFile("materials/models/arcana/fairy/wing.vmt")

	for _, f in ipairs(file.Find("sound/arcana/fairy/*.wav", "GAME")) do
		resource.AddFile("sound/arcana/fairy/" .. f)
	end

	for _, f in ipairs(file.Find("sound/arcana/fairy/nymph/*.wav", "GAME")) do
		resource.AddFile("sound/arcana/fairy/nymph/" .. f)
	end

	function ENT:Initialize()
		self:SetModel("models/dav0r/hoverball.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:PhysWake()
		self:SetUseType(SIMPLE_USE)

		self:StartMotionController()

		self:GetPhysicsObject():SetMass(0.1)
		self:GetPhysicsObject():EnableGravity(false)
	end

	-- Simple vendor Use interaction when flagged as vendor
	function ENT:Use(ply)
		if not IsValid(ply) or not ply:IsPlayer() then return end
		if not self:GetNWBool("Arcana_FairyVendor", false) then return end

		local have = (ply.GetItemCount and ply:GetItemCount("solidified_spores")) or 0
		local price = self:GetNWInt("Arcana_FairyVendorPrice", 250)

		net.Start("Arcana_FairyVendor_Open")
		net.WriteEntity(self)
		net.WriteUInt(math.max(have, 0), 32)
		net.WriteUInt(math.max(price, 0), 32)
		net.Send(ply)

		self:EmitSound("buttons/button9.wav", 60, 110)
	end

	net.Receive("Arcana_FairyVendor_Confirm", function(_, ply)
		local ent = net.ReadEntity()
		local qty = net.ReadUInt(32)
		if not IsValid(ply) or not IsValid(ent) or ent:GetClass() ~= "arcana_fairy" then return end
		if not ent:GetNWBool("Arcana_FairyVendor", false) then return end
		if qty <= 0 then return end

		local have = (ply.GetItemCount and ply:GetItemCount("solidified_spores")) or 0
		if have <= 0 or qty > have then
			ply:ChatPrint("You don't have enough spores to exchange.")
			return
		end

		local price = ent:GetNWInt("Arcana_FairyVendorPrice", 250)
		local coins = math.min(1e6, math.max(1, qty * price)) -- cap at 1 million coins, min 1 coin

		-- consume and payout
		if ply.TakeItem then ply:TakeItem("solidified_spores", qty, "Fairy Vendor Exchange") end
		if ply.GiveCoins then ply:GiveCoins(coins, "Fairy Vendor Exchange") end
		ent:EmitSound("buttons/button14.wav", 60, 120)

		ply:ChatPrint("Exchanged " .. tostring(qty) .. " spores for " .. tostring(coins) .. " coins.")
	end)

	function ENT:MoveTo(pos)
		self.MovePos = pos
	end

	function ENT:HasReachedTarget()
		return self.MovePos and self:GetPos():Distance(self.MovePos) < 50
	end

	function ENT:PhysicsSimulate(phys)
		if self.GravityOn then return end

		if self.MovePos and not self:HasReachedTarget() then
			phys:AddVelocity(self.MovePos - phys:GetPos())
			phys:AddVelocity(self:GetVelocity() * -0.4)
			self.MovePos = nil
		end
	end

	function ENT:Think()
		self:PhysWake()
	end

	function ENT:EnableGravity(time)
		local phys = self:GetPhysicsObject()
		phys:EnableGravity(true)
		self.GravityOn = true

		timer.Simple(time, function()
			if self:IsValid() and phys:IsValid() then
				phys:EnableGravity(false)
				self.GravityOn = false
			end
		end)
	end


	function ENT:CallClientFunction(func, ...)
		net.Start("arcana_fairy_func_call")
			net.WriteEntity(self)
			net.WriteString(func)
			net.WriteTable({...})
		net.Broadcast()
	end

	function ENT:OnTakeDamage(dmg)
		local time = math.Rand(1,2)
		self:EnableGravity(time)
		self:CallClientFunction("Ouch", time)

		self.Hurting = true

		timer.Simple(time, function()
			if self:IsValid() then
				self.Hurting = false
			end
		end)

		local phys = self:GetPhysicsObject()
		phys:AddVelocity(dmg:GetDamageForce())
	end

	function ENT:PhysicsCollide(data, phys)
		if not self.last_collide  or self.last_collide < CurTime() then
			local ent = data.HitEntity
			if ent:IsValid() and not ent:IsPlayer() and ent:GetModel() then
				self.last_collide = CurTime() + 1
			end
		end

		if data.Speed > 50 and data.DeltaTime > 0.2 then
			local time = math.Rand(0.5,1)
			self:EnableGravity(time)
			self:CallClientFunction("Ouch", time)
			self:CallClientFunction("Bounce")
			self.follow_ent = NULL
		end

		phys:SetVelocity(phys:GetVelocity():GetNormalized() * data.OurOldVelocity:Length() * 0.99)
	end
end

if CLIENT then
    net.Receive("Arcana_FairyVendor_Open", function()
        local ent = net.ReadEntity()
        local have = net.ReadUInt(32) or 0
        local price = net.ReadUInt(32) or 0
        if not IsValid(ent) then return end

        -- Fonts (ensure available)
        surface.CreateFont("Arcana_AncientSmall", {font = "Georgia", size = 16, weight = 600, antialias = true, extended = true})
        surface.CreateFont("Arcana_Ancient", {font = "Georgia", size = 20, weight = 700, antialias = true, extended = true})
        surface.CreateFont("Arcana_AncientLarge", {font = "Georgia", size = 24, weight = 800, antialias = true, extended = true})
        surface.CreateFont("Arcana_DecoTitle", {font = "Georgia", size = 26, weight = 900, antialias = true, extended = true})

        local decoBg = Color(26, 20, 14, 235)
        local gold = Color(198, 160, 74, 255)
        local paleGold = Color(222, 198, 120, 255)
        local textBright = Color(236, 230, 220, 255)
        local textDim = Color(180, 170, 150, 255)

        local blurMat = Material("pp/blurscreen")
        local function Arcana_DrawBlurRect(x, y, w, h, layers, density)
            surface.SetMaterial(blurMat)
            surface.SetDrawColor(255, 255, 255)
            render.SetScissorRect(x, y, x + w, y + h, true)
            for i = 1, (layers or 4) do
                blurMat:SetFloat("$blur", (i / (layers or 4)) * (density or 8))
                blurMat:Recompute()
                render.UpdateScreenEffectTexture()
                surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
            end
            render.SetScissorRect(0, 0, 0, 0, false)
        end

        local function Arcana_FillDecoPanel(x, y, w, h, col, corner)
            local c = math.max(8, corner or 12)
            draw.NoTexture()
            surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
            local pts = {{x = x + c, y = y},{x = x + w - c, y = y},{x = x + w, y = y + c},{x = x + w, y = y + h - c},{x = x + w - c, y = y + h},{x = x + c, y = y + h},{x = x, y = y + h - c},{x = x, y = y + c}}
            surface.DrawPoly(pts)
        end

        local function Arcana_DrawDecoFrame(x, y, w, h, col, corner)
            local c = math.max(8, corner or 12)
            surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
            surface.DisableClipping(true)
            surface.DrawLine(x + c, y, x + w - c, y)
            surface.DrawLine(x + w, y + c, x + w, y + h - c)
            surface.DrawLine(x + w - c, y + h, x + c, y + h)
            surface.DrawLine(x, y + h - c, x, y + c)
            surface.DrawLine(x, y + c, x + c, y)
            surface.DrawLine(x + w - c, y, x + w, y + c)
            surface.DrawLine(x + w, y + h - c, x + w - c, y + h)
            surface.DrawLine(x + c, y + h, x, y + h - c)
            surface.DisableClipping(false)
        end

        local frame = vgui.Create("DFrame")
        frame:SetSize(520, 260)
        frame:Center()
        frame:SetTitle("")
        frame:MakePopup()

        hook.Add("HUDPaint", frame, function()
            local x, y = frame:LocalToScreen(0, 0)
            Arcana_DrawBlurRect(x, y, frame:GetWide(), frame:GetTall(), 4, 8)
        end)

        frame.Paint = function(pnl, w, h)
            Arcana_FillDecoPanel(6, 6, w - 12, h - 12, decoBg, 14)
            Arcana_DrawDecoFrame(6, 6, w - 12, h - 12, gold, 14)
            draw.SimpleText("FAE MARKET", "Arcana_DecoTitle", 18, 10, paleGold)
        end

        if IsValid(frame.btnMinim) then frame.btnMinim:Hide() end
        if IsValid(frame.btnMaxim) then frame.btnMaxim:Hide() end
        if IsValid(frame.btnClose) then
            local close = frame.btnClose
            close:SetText("")
            close:SetSize(26, 26)
            function frame:PerformLayout(w, h)
                if IsValid(close) then close:SetPos(w - 26 - 10, 8) end
            end
            close.Paint = function(pnl, w, h)
                surface.SetDrawColor(paleGold)
                local pad = 8
                surface.DrawLine(pad, pad, w - pad, h - pad)
                surface.DrawLine(w - pad, pad, pad, h - pad)
            end
        end

        local content = vgui.Create("DPanel", frame)
        content:Dock(FILL)
        content:DockMargin(12, 12, 12, 12)
        content.Paint = function(pnl, w, h)
            Arcana_FillDecoPanel(0, 0, w, h, Color(32, 24, 18, 235), 10)
            Arcana_DrawDecoFrame(0, 0, w, h, gold, 10)
        end

        local label = vgui.Create("DLabel", content)
        label:Dock(TOP)
        label:DockMargin(12, 10, 12, 6)
        label:SetFont("Arcana_Ancient")
        label:SetTextColor(textBright)
        label:SetWrap(true)
        label:SetText("How many mushroom spores do you want to exchange (you have " .. tostring(have) .. ")?")

        -- Entry row with a MAX button on the right
        local entryRow = vgui.Create("DPanel", content)
        entryRow:Dock(TOP)
        entryRow:DockMargin(12, 2, 12, 6)
        entryRow:SetTall(32)
        entryRow.Paint = nil

        local entry = vgui.Create("DTextEntry", entryRow)
        entry:Dock(FILL)
        entry:DockMargin(0, 0, 8, 0)
        entry:SetNumeric(true)
        entry:SetUpdateOnType(true)
        entry:SetText("0")
        entry:SetTall(28)

        local maxBtn = vgui.Create("DButton", entryRow)
        maxBtn:Dock(RIGHT)
        maxBtn:SetWide(100)
        maxBtn:SetText("")

        local priceLbl = vgui.Create("DLabel", content)
        priceLbl:Dock(TOP)
        priceLbl:DockMargin(12, 2, 12, 8)
        priceLbl:SetFont("Arcana_AncientSmall")
        priceLbl:SetTextColor(paleGold)
        priceLbl:SetWrap(true)
        local function refreshPrice()
            local n = tonumber(entry:GetText()) or 0
            n = math.Clamp(math.floor(n), 0, have)
            priceLbl:SetText("Price per spore: " .. string.Comma(price) .. " coins | You will receive: " .. string.Comma(n * price))
            priceLbl:SizeToContentsY()
        end
        function entry:OnValueChange() refreshPrice() end
        refreshPrice()

        -- Ensure wrapped labels expand properly
        function content:PerformLayout(w, h)
            if IsValid(label) then
                label:SetWide(w - 24)
                label:SizeToContentsY()
            end
            if IsValid(priceLbl) then
                priceLbl:SetWide(w - 24)
                priceLbl:SizeToContentsY()
            end
        end

        local buttons = vgui.Create("DPanel", content)
        buttons:Dock(BOTTOM)
        buttons:SetTall(52)
        buttons:DockMargin(12, 8, 12, 10)
        buttons.Paint = nil

        local confirm = vgui.Create("DButton", buttons)
        confirm:SetText("")
        confirm:SetTall(40)
        local cancel = vgui.Create("DButton", buttons)
        cancel:SetText("")
        cancel:SetTall(40)

        buttons.PerformLayout = function(pnl, w, h)
            local gap = 10
            local bw = math.floor((w - gap) * 0.5)
            confirm:SetSize(bw, confirm:GetTall())
            confirm:SetPos(0, math.floor((h - confirm:GetTall()) * 0.5))
            cancel:SetSize(w - bw - gap, cancel:GetTall())
            cancel:SetPos(bw + gap, math.floor((h - cancel:GetTall()) * 0.5))
        end

        local function paintBtn(pnl, w, h, label, enabled)
            local hovered = pnl:IsHovered() and enabled
            local bg = hovered and Color(58, 44, 32, 235) or Color(46, 36, 26, 235)
            Arcana_FillDecoPanel(0, 0, w, h, bg, 8)
            Arcana_DrawDecoFrame(0, 0, w, h, enabled and gold or Color(140, 120, 90, 255), 8)
            draw.SimpleText(label, "Arcana_AncientLarge", w * 0.5, h * 0.5, enabled and textBright or Color(200, 190, 170, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        maxBtn.Paint = function(pnl, w, h) paintBtn(pnl, w, h, "MAX", true) end
        maxBtn.DoClick = function()
            local n = math.Clamp(have, 0, have)
            entry:SetText(tostring(n))
            if entry.OnValueChange then entry:OnValueChange() end
        end

        confirm.Paint = function(pnl, w, h) paintBtn(pnl, w, h, "Confirm", true) end
        cancel.Paint = function(pnl, w, h) paintBtn(pnl, w, h, "Cancel", true) end

        confirm.DoClick = function()
            local n = math.max(1, tonumber(entry:GetText()) or 0)
            net.Start("Arcana_FairyVendor_Confirm")
            net.WriteEntity(ent)
            net.WriteUInt(n, 32)
            net.SendToServer()
            frame:Close()
        end

        cancel.DoClick = function()
            frame:Close()
        end
    end)
end