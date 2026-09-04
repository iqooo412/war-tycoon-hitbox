--[[
	War Tycoon - Head Hitbox System (No UI/Menu)
	Невидимый хитбокс для головы, подстраивается под размер головы персонажа
	Без меню и интерфейса - просто система хитбоксов
]]

local HeadHitbox = {}
HeadHitbox.__index = HeadHitbox

function HeadHitbox.new(character, config)
	local self = setmetatable({}, HeadHitbox)
	
	config = config or {}
	
	self.character = character
	self.humanoid = character:WaitForChild("Humanoid")
	self.head = character:WaitForChild("Head")
	
	self.sizeMultiplier = config.sizeMultiplier or 1.0
	self.headSize = self.head.Size
	self.size = self.headSize * self.sizeMultiplier
	
	self.offset = config.offset or Vector3.new(0, 0, 0)
	self.canCollide = config.canCollide or false
	self.transparency = config.transparency or 1
	
	self.hitConnection = nil
	self.isDestroyed = false
	self.onHitCallbacks = {}
	self.lastHitTime = 0
	self.hitCooldown = 0.1
	
	self:_createHitbox()
	
	return self
end

function HeadHitbox:_createHitbox()
	self.hitbox = Instance.new("Part")
	self.hitbox.Name = "HeadHitbox"
	self.hitbox.Shape = Enum.PartType.Ball
	self.hitbox.Material = Enum.Material.SmoothPlastic
	self.hitbox.CanCollide = self.canCollide
	self.hitbox.Transparency = self.transparency
	self.hitbox.TopSurface = Enum.SurfaceType.Smooth
	self.hitbox.BottomSurface = Enum.SurfaceType.Smooth
	self.hitbox.Size = self.size
	self.hitbox.Parent = self.head
	
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = self.head
	weld.Part1 = self.hitbox
	weld.Parent = self.hitbox
	
	if self.offset ~= Vector3.new(0, 0, 0) then
		self.hitbox.Position = self.head.Position + self.offset
	end
	
	self.hitbox.CanQuery = false
	
	self:_setupTouchConnection()
end

function HeadHitbox:_setupTouchConnection()
	self.hitConnection = self.hitbox.Touched:Connect(function(hit)
		if self.isDestroyed then
			return
		end
		
		local currentTime = tick()
		if currentTime - self.lastHitTime < self.hitCooldown then
			return
		end
		
		if hit.Parent == self.character then
			return
		end
		
		self.lastHitTime = currentTime
		
		for _, callback in ipairs(self.onHitCallbacks) do
			pcall(callback, hit, self.hitbox)
		end
	end)
end

function HeadHitbox:OnHit(callback)
	if type(callback) == "function" then
		table.insert(self.onHitCallbacks, callback)
	end
end

function HeadHitbox:SetSizeMultiplier(multiplier)
	if not self.isDestroyed then
		self.sizeMultiplier = multiplier
		self.size = self.headSize * multiplier
		self.hitbox.Size = self.size
	end
end

function HeadHitbox:GetSizeMultiplier()
	return self.sizeMultiplier
end

function HeadHitbox:GetHeadSize()
	return self.headSize
end

function HeadHitbox:SetTransparency(transparency)
	if not self.isDestroyed then
		self.transparency = transparency
		self.hitbox.Transparency = transparency
	end
end

function HeadHitbox:GetPart()
	return self.hitbox
end

function HeadHitbox:Destroy()
	if not self.isDestroyed then
		self.isDestroyed = true
		
		if self.hitConnection then
			self.hitConnection:Disconnect()
		end
		
		if self.hitbox then
			self.hitbox:Destroy()
		end
		
		self.onHitCallbacks = {}
	end
end

-- ============================================
-- МЕНЕДЖЕР ХИТБОКСОВ
-- ============================================

local Players = game:GetService("Players")
local playerHitboxes = {}

local function InitializeCharacter(character, player)
	if playerHitboxes[character] then
		return
	end
	
	local config = {
		sizeMultiplier = 1.0,
		transparency = 1,
		canCollide = false
	}
	
	local hitbox = HeadHitbox.new(character, config)
	playerHitboxes[character] = hitbox
	
	hitbox:OnHit(function(hitPart, hitbox)
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid:TakeDamage(25)
		end
	end)
	
	character:WaitForChild("Humanoid").Died:Connect(function()
		if playerHitboxes[character] then
			playerHitboxes[character]:Destroy()
			playerHitboxes[character] = nil
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		wait(0.1)
		InitializeCharacter(character, player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	if player.Character then
		if playerHitboxes[player.Character] then
			playerHitboxes[player.Character]:Destroy()
			playerHitboxes[player.Character] = nil
		end
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then
		InitializeCharacter(player.Character, player)
	end
	
	player.CharacterAdded:Connect(function(character)
		wait(0.1)
		InitializeCharacter(character, player)
	end)
end

return HeadHitbox
