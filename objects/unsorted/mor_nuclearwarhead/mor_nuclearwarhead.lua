require "/scripts/rect.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/actions/world.lua"

-- HOOKS

function init()
  -- Define parameters
  self.position = object.position()

  self.startMusicRange = config.getParameter("startMusicRange")  -- Maximum distance, in blocks, the player must be from the point of detonation in order to hear the music.
  self.endMusicRange = config.getParameter("endMusicRange")  -- The maximum distance, in blocks, before the player stops hearing the music. Preferrably larger than self.startMusicRange
  self.music = config.getParameter("music")  -- The path to the music track you want to play. Example: ["/music/arctic-battle1-loop.ogg"]
  self.musicFadeInTime = config.getParameter("musicFadeInTime")  -- Amount of time, in seconds, it takes for the music to fade in.
  self.musicFadeOutTime = config.getParameter("musicFadeOutTime")  -- Amount of time, in seconds, it takes for the music to fade out.
  
  self.warheadProjectile = config.getParameter("warheadProjectile")  -- Projectile type on initial explosion
  self.warheadProjectileParameters = config.getParameter("warheadProjectileParameters", {})  -- Whatever parameters you want!
  self.warheadSpawnOffset = config.getParameter("warheadSpawnOffset")  -- x and y coordinates (in blocks) relative to self.position
  
  self.biomeType = config.getParameter("biomeType")  -- The name of the biome to convert
  self.blockSelector = config.getParameter("blockSelector", "largeClumps")  -- How the game chooses where to place sub blocks
  self.conversionWidth = config.getParameter("conversionWidth")  -- How wide, in blocks, the converted region will be
  self.conversionHeight = config.getParameter("conversionHeight")  -- How high, in blocks, the converted region will be. Only used for stagehands.
  self.conversionEffectMargin = config.getParameter("conversionEffectMargin")  -- Music and other things will trigger in an area self.conversionWidth - 2 * self.conversionEffectMargin wide
  self.conversionPosition = vec2.add(self.position, config.getParameter("conversionOffset", {0, 0}))
  
  self.flashRange = config.getParameter("flashRange")
  self.flashStatusEffect = config.getParameter("flashStatusEffect")  -- Flashbang status effect

  self.detonationTime = config.getParameter("detonationTime")  -- Number of seconds the player has to get the heck out of there
  self.countdownStatusEffect = config.getParameter("countdownStatusEffect")  -- Status effect to display the countdown
  self.countdownEndStatusEffect = config.getParameter("countdownEndStatusEffect")  -- Status effect to hide the countdown
  self.promptConfig = config.getParameter("promptConfig")  -- Configuration for prompt to confirm if the player wants to detonate the nuke
  self.loadArea = config.getParameter("loadArea")  -- Chunks intersecting this area relative to the warhead remain loaded while the warhead is active.
  self.loadRegion = rect.translate(self.loadArea, self.position)
  
  self.biomeStagehandType = config.getParameter("biomeStagehandType")
  self.biomeStagehandParameters = config.getParameter("biomeStagehandParameters", {})
  self.paddingStagehandType = config.getParameter("paddingStagehandType")
  self.paddingStagehandParameters = config.getParameter("paddingStagehandParameters", {})
  self.controllerStagehandType = config.getParameter("controllerStagehandType")
  self.controllerStagehandParameters = config.getParameter("controllerStagehandParameters", {})
  self.maxStagehandSize = config.getParameter("maxStagehandSize", 100)  -- Maximum height and length of a stagehand

  -- Define variables
  object.setInteractive(true)
  
  self.musicPlayers = {}
  self.countdownPlayers = {}

  self.pregenerationFinished = false
  
  self.state = FSM:new()
  if storage.timer then
    self.state:set(states.countdown)
  else
    self.state:set(states.noop)
  end
end

function onInteraction(args)
  local success, reason = canActivate()
  if success then
    self.state:set(states.prompt, args.sourceId)
  else
    return { "ShowPopup", { title = "Activation Failed!", message = string.format("^red;Cannot detonate nuke: %s.", reason), sound = "/sfx/interface/nav_insufficient_fuel.ogg"} }
  end
end

-- This function fires about 60 times per second
function update(dt)
  self.state:update()
end

function die()
  if storage.timer then
    deactivate()
  end
end

-- STATES

states = {}

-- Do nothing
function states.noop()
  while true do
    coroutine.yield()
  end
end

-- Make sure the player REALLY DOES want to set this thing off.
function states.prompt(sourceId)
  local promptArgs = copy(self.promptConfig)
  promptArgs.player = sourceId
  result = playerConfirm(promptArgs)  -- Intended for use in behavior trees, but it works just as well in coroutines.
  
  if result then
    self.state:set(states.countdown)
  else
    self.state:set(states.noop)
  end
end

-- Countdown segment
function states.countdown()
  world.setProperty("mor_hasActiveWarhead", true)
  object.setInteractive(false)

  if not storage.timer then
    storage.timer = self.detonationTime
  end

  local dt = script.updateDt()
  
  -- Prepare for asynchronous biome generation
  world.pregenerateAddBiome(self.conversionPosition, self.conversionWidth)

  while storage.timer > 0 or not self.pregenerationFinished do
    world.loadRegion(self.loadRegion)  -- Keep the area loaded

    playMusic()
    showCountdown()
    world.debugText("Get out in %s seconds", storage.timer, self.position, "green")

    -- I have no idea what exactly this does, but I'm keeping it in case it fixes a problem I am unaware of.
    if not self.pregenerationFinished then
      self.pregenerationFinished = world.pregenerateAddBiome(self.conversionPosition, self.conversionWidth)
      if self.pregenerationFinished then sb.logInfo("pregeneration to add biome finished at %s seconds", storage.timer) end
    end

    storage.timer = storage.timer - dt
    coroutine.yield()
  end
  
  storage.timer = nil
  
  self.state:set(states.detonate)
end

-- Detonate segment
function states.detonate()
  deactivate()

  -- The big boom
  world.spawnProjectile(self.warheadProjectile, vec2.add(self.position, self.warheadSpawnOffset), entity.id(), {0, -1}, false, self.warheadProjectileParameters)
  
  -- The flash
  local players = world.players()
  for _, playerId in ipairs(players) do
    local playerPos = world.entityPosition(playerId)
    if world.magnitude(self.position, playerPos) < self.flashRange then
      world.sendEntityMessage(playerId, "applyStatusEffect", self.flashStatusEffect)
    end
  end
  
  -- Convert biome
  createBiomeStagehands()
  world.addBiomeRegion(self.conversionPosition, self.biomeType, self.blockSelector, self.conversionWidth)
  
  object.smash(true)
  
  self.state:set(states.noop)
end

-- FUNCTIONS

function playMusic()
  -- Play music for players who are close enough to the detonation site and stop music for those who are too far or are no longer present in the current world.
  for playerId, _ in pairs(self.musicPlayers) do
    if not world.entityExists(playerId) then
      self.musicPlayers[playerId] = nil
    else
      local playerPos = world.entityPosition(playerId)
      if world.magnitude(self.position, playerPos) > self.endMusicRange then
        world.sendEntityMessage(playerId, "stopAltMusic", self.musicFadeOutTime)
        self.musicPlayers[playerId] = nil
      end
    end
  end
  local newPlayers = world.entityQuery(self.position, self.startMusicRange, {includedTypes = {"player"}})
  for _, playerId in ipairs(newPlayers) do
    if not self.musicPlayers[playerId] then
      world.sendEntityMessage(playerId, "playAltMusic", self.music, self.musicFadeInTime)
      self.musicPlayers[playerId] = true
    end
  end
end

function stopMusic()
  local queriedPlayers = world.entityQuery(self.position, self.endMusicRange, {includedTypes = {"player"}})
  for _, playerId in ipairs(queriedPlayers) do
    if world.entityExists(playerId) then
      world.sendEntityMessage(playerId, "stopAltMusic", self.musicFadeOutTime)
    end
  end
end

function createBiomeStagehands()
  local bundledStagehands = {}
  local uuid = sb.makeUuid()
  local stagehandId = 0

  local spawnStagehand = function(offset, stagehandType, broadcastArea, stagehandParams)
    local params = copy(stagehandParams)
    local uid = uuid .. "-" .. stagehandId
    params.broadcastArea = broadcastArea
    params.uniqueId = params.uniqueId or uid
    stagehandId = stagehandId + 1
    local stagehand = world.spawnStagehand(vec2.add(self.position, offset), stagehandType, params)
    if stagehand then
      return uid
    end
  end

  local boundaries = {-(self.conversionWidth - self.conversionEffectMargin), -self.conversionHeight / 2, self.conversionWidth - self.conversionEffectMargin, self.conversionHeight / 2}

  local x = boundaries[1]
  while x < boundaries[3] do
    local y = boundaries[2]
    while y < boundaries[4] do
      local xLength = math.min(boundaries[3] - x, self.maxStagehandSize)
      local yLength = math.min(boundaries[4] - y, self.maxStagehandSize)

      -- Left padding
      if x == boundaries[1] then
        local stagehand = spawnStagehand({x - self.conversionEffectMargin, y}, self.paddingStagehandType, {0, 0, self.conversionEffectMargin, yLength}, self.paddingStagehandParameters)
        if stagehand then
          table.insert(bundledStagehands, stagehand)
        end
      end
      
      -- Right padding
      if boundaries[3] - x <= self.maxStagehandSize then
        local stagehand = spawnStagehand({x + xLength, y}, self.paddingStagehandType, {0, 0, self.conversionEffectMargin, yLength}, self.paddingStagehandParameters)
        if stagehand then
          table.insert(bundledStagehands, stagehand)
        end
      end

      -- Top padding
      if y == boundaries[2] then
        local stagehand = spawnStagehand({x, y - self.conversionEffectMargin}, self.paddingStagehandType, {0, 0, xLength, self.conversionEffectMargin}, self.paddingStagehandParameters)
        if stagehand then
          table.insert(bundledStagehands, stagehand)
        end
      end
      
      -- Bottom padding
      if boundaries[4] - y <= self.maxStagehandSize then
        local stagehand = spawnStagehand({x, y + yLength}, self.paddingStagehandType, {0, 0, xLength, self.conversionEffectMargin}, self.paddingStagehandParameters)
        if stagehand then
          table.insert(bundledStagehands, stagehand)
        end
      end
      
      -- Base stagehands
      local stagehand = spawnStagehand({x, y}, self.biomeStagehandType, {0, 0, xLength, yLength}, self.biomeStagehandParameters)
      if stagehand then
        table.insert(bundledStagehands, stagehand)
      end

      y = y + self.maxStagehandSize
    end
    x = x + self.maxStagehandSize
  end

  local controllerParams = copy(self.controllerStagehandParameters)
  controllerParams.groupedStagehands = bundledStagehands
  controllerParams.uniqueId = uuid
  spawnStagehand({0, 0}, self.controllerStagehandType, {-1, -1, 1, 1}, controllerParams)
end

function showCountdown()
  -- Clean up players who are no longer on the planet.
  for playerId, _ in pairs(self.countdownPlayers) do
    if not world.entityExists(playerId) then
      self.countdownPlayers[playerId] = nil
    end
  end

  -- Add new players
  for _, playerId in ipairs(world.players()) do
    if not self.countdownPlayers[playerId] then
      world.sendEntityMessage(playerId, "applyStatusEffect", self.countdownStatusEffect, storage.timer or self.detonationTime)
      self.countdownPlayers[playerId] = true
    end
  end
end

function hideCountdown()
  for _, playerId in ipairs(world.players()) do
    world.sendEntityMessage(playerId, "applyStatusEffect", self.countdownEndStatusEffect)
  end
end

function canActivate()
  if not world.terrestrial() then
    return false, "warhead must be placed on a planet"
  end

  if not world.inSurfaceLayer(self.position) then
    return false, "warhead must be on the surface"
  end
  
  if world.getProperty("mor_hasActiveWarhead") then
    return false, "world has active warhead"
  end
  
  return true, ""
end

function deactivate()
  stopMusic()
  hideCountdown()
  world.setProperty("mor_hasActiveWarhead", false)
end