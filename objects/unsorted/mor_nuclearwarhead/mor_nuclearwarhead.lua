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
  
  self.flashRange = config.getParameter("flashRange")
  self.flashStatusEffect = config.getParameter("flashStatusEffect")  -- Flashbang status effect

  self.detonationTime = config.getParameter("detonationTime")  -- Number of seconds the player has to get the heck out of there
  self.countdownStatusEffect = config.getParameter("countdownStatusEffect")
  self.countdownEndStatusEffect = config.getParameter("countdownEndStatusEffect")
  self.promptConfig = config.getParameter("promptConfig")
  self.loadArea = config.getParameter("loadArea")
  self.loadRegion = rect.translate(self.loadArea, self.position)

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
  world.pregenerateAddBiome(self.position, self.conversionWidth)

  while storage.timer > 0 or not self.pregenerationFinished do
    world.loadRegion(self.loadRegion)  -- Keep the area loaded

    playMusic()
    showCountdown()
    world.debugText("Get out in %s seconds", storage.timer, self.position, "green")

    -- I have no idea what exactly this does, but I'm keeping it in case it fixes a problem I am unaware of.
    if not self.pregenerationFinished then
      self.pregenerationFinished = world.pregenerateAddBiome(self.position, self.conversionWidth)
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
  world.addBiomeRegion(self.position, self.biomeType, self.blockSelector, self.conversionWidth)
  
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

-- TODO: Make this callable repeatedly so that players who beam down while a warhead is active can see the countdown too.
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