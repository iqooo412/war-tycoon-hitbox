--[[
	War Tycoon - Complete Head Hitbox System
	Невидимый хитбокс для головы, подстраивается под размер головы персонажа
	Все в одном скрипте для удобства
]]

local HeadHitbox = {}
HeadHitbox.__index = HeadHitbox

--[[
	Создает новый хитбокс для персонажа
	@param character - Character model
	@param config - Configuration table (optional)
		- sizeMultiplier: number (default: 1.0) - множитель размера головы
		- offset: Vector3 (default: Vector3.new(0, 0, 0))
		- canCollide: boolean (default: false)
		- transparency: number (default: 1)
]]
function HeadHitbox.new(character, config)
	local self = setmetatable({}, HeadHitbox)
	
	config = config or {}
	
	self.character = character
	self.humanoid = character:WaitForChild("Humanoid")
	self.head = character:WaitForChild("Head")
	
	-- Получаем размер головы и применяем множитель
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
	self.hitCooldown = 0.1 -- Предотвращение множественных срабатываний за раз
	
	self:_createHitbox()
	
	return self
end

--[[
	Создает невидимый mesh-хитбокс на основе размера головы
]]
function HeadHitbox:_createHitbox()
	-- Создаем Part для хитбокса
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
	
	-- Используем WeldConstraint для привязки к голове
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = self.head
	weld.Part1 = self.hitbox
	weld.Parent = self.hitbox
	
	-- Устанавливаем offset если нужно
	if self.offset ~= Vector3.new(0, 0, 0) then
		self.hitbox.Position = self.head.Position + self.offset
	end
	
	-- Делаем хитбокс невидимым в режиме просмотра
	self.hitbox.CanQuery = false
	
	-- Подключаемся к событиям попаданий
	self:_setupTouchConnection()
end

--[[
	Настраивает обнаружение попаданий через Touched событие
]]
function HeadHitbox:_setupTouchConnection()
	self.hitConnection = self.hitbox.Touched:Connect(function(hit)
		if self.isDestroyed then
			return
		end
		
		-- Проверяем, прошел ли кулдаун
		local currentTime = tick()
		if currentTime - self.lastHitTime < self.hitCooldown then
			return
		end
		
		-- Проверяем, не это ли наш собственный персонаж
		if hit.Parent == self.character then
			return
		end
		
		self.lastHitTime = currentTime
		
		-- Вызываем все зарегистрированные callbacks
		for _, callback in ipairs(self.onHitCallbacks) do
			pcall(callback, hit, self.hitbox)
		end
	end)
end

--[[
	Регистрирует callback для срабатывания при попадании
	@param callback - функция(hitPart, hitbox)
]]
function HeadHitbox:OnHit(callback)
	if type(callback) == "function" then
		table.insert(self.onHitCallbacks, callback)
	end
end

--[[
	Устанавливает множитель размера хитбокса относительно размера головы
	@param multiplier - число (1.0 = размер головы, 1.5 = 150% размера головы)
]]
function HeadHitbox:SetSizeMultiplier(multiplier)
	if not self.isDestroyed then
		self.sizeMultiplier = multiplier
		self.size = self.headSize * multiplier
		self.hitbox.Size = self.size
	end
end

--[[
	Получает текущий множитель размера
	@return число множитель
]]
function HeadHitbox:GetSizeMultiplier()
	return self.sizeMultiplier
end

--[[
	Получает размер головы
	@return Vector3 размер головы
]]
function HeadHitbox:GetHeadSize()
	return self.headSize
end

--[[
	Устанавливает прозрачность хитбокса
	@param transparency - число от 0 до 1
]]
function HeadHitbox:SetTransparency(transparency)
	if not self.isDestroyed then
		self.transparency = transparency
		self.hitbox.Transparency = transparency
	end
end

--[[
	Получает Part хитбокса
	@return Part хитбокса
]]
function HeadHitbox:GetPart()
	return self.hitbox
end

--[[
	Уничтожает хитбокс и отключает все события
]]
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
local HitboxManager = {}
local playerHitboxes = {}

--[[
	Инициализирует хитбокс для персонажа
	@param character - Character model
	@param player - Player объект (опционально)
]]
function HitboxManager:InitializeCharacter(character, player)
	if playerHitboxes[character] then
		return
	end
	
	local config = {
		sizeMultiplier = 1.0, -- Хитбокс размером с голову
		transparency = 1, -- Полностью невидимый
		canCollide = false
	}
	
	local hitbox = HeadHitbox.new(character, config)
	playerHitboxes[character] = hitbox
	
	-- Регистрируем callback для обработки попаданий
	hitbox:OnHit(function(hitPart, hitbox)
		self:_onCharacterHit(character, hitPart, hitbox, player)
	end)
	
	-- Удаляем хитбокс когда персонаж умирает или удаляется
	character:WaitForChild("Humanoid").Died:Connect(function()
		if playerHitboxes[character] then
			playerHitboxes[character]:Destroy()
			playerHitboxes[character] = nil
		end
	end)
	
	print("✅ Hitbox initialized for character: " .. character.Name)
end

--[[
	Обработчик события попадания в хитбокс
]]
function HitboxManager:_onCharacterHit(character, hitPart, hitbox, player)
	print("💥 Character " .. character.Name .. " was hit by " .. hitPart.Name)
	
	-- Здесь можно добавить логику обработки урона
	-- Например, нанесение урона, проверку типа оружия и т.д.
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		humanoid:TakeDamage(25) -- 25 урона за попадание в голову
		print("💔 " .. character.Name .. " получил 25 урона!")
	end
end

--[[
	Получает хитбокс персонажа
	@param character - Character model
	@return HeadHitbox объект или nil
]]
function HitboxManager:GetHitbox(character)
	return playerHitboxes[character]
end

--[[
	Удаляет хитбокс персонажа
	@param character - Character model
]]
function HitboxManager:DestroyHitbox(character)
	if playerHitboxes[character] then
		playerHitboxes[character]:Destroy()
		playerHitboxes[character] = nil
	end
end

-- ============================================
-- ИНИЦИАЛИЗАЦИЯ
-- ============================================

-- Инициализация при добавлении игрока
Players.PlayerAdded:Connect(function(player)
	print("👤 Player joined: " .. player.Name)
	player.CharacterAdded:Connect(function(character)
		wait(0.1) -- Небольшая задержка для инициализации персонажа
		HitboxManager:InitializeCharacter(character, player)
	end)
end)

-- Очистка при удалении игрока
Players.PlayerRemoving:Connect(function(player)
	print("👤 Player left: " .. player.Name)
	if player.Character then
		HitboxManager:DestroyHitbox(player.Character)
	end
end)

-- Инициализация уже подключенных игроков (при перезагрузке скрипта)
for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then
		HitboxManager:InitializeCharacter(player.Character, player)
	end
	
	player.CharacterAdded:Connect(function(character)
		wait(0.1)
		HitboxManager:InitializeCharacter(character, player)
	end)
end

return HeadHitbox
