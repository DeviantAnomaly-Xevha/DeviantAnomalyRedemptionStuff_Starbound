require "/scripts/util.lua"
require "/scripts/stagehandutil.lua"

function init()
  self.players = {}
  self.music = config.getParameter("music", {})
  self.fadeInTime = config.getParameter("fadeInTime")
  self.fadeOutTime = config.getParameter("fadeOutTime")
  self.environmentStatusEffects = config.getParameter("environmentStatusEffects")
  
  message.setHandler("mor_wasteland_die", die)
end

function update(dt)
  local oldPlayers = copy(self.players)
  self.players = {}

  local newPlayers = broadcastAreaQuery({ includedTypes = {"player"} })
  for _, playerId in pairs(newPlayers) do
    if not oldPlayers[playerId] then
      world.sendEntityMessage(playerId, "playAltMusic", self.music, self.fadeInTime)
    end
    for _, statusEffect in ipairs(self.environmentStatusEffects) do
      if type(statusEffect) == "string" then
        world.sendEntityMessage(playerId, "applyStatusEffect", statusEffect)
      elseif type(statusEffect) == "table" then
        world.sendEntityMessage(playerId, "applyStatusEffect", statusEffect.effect, statusEffect.duration)
      else
        error("Expected string or table, got " .. type(statusEffect))
      end
    end
    self.players[playerId] = true
  end
end

function die()
  local players = broadcastAreaQuery({ includedTypes = {"player"} })
  for _, playerId in pairs(players) do
    world.sendEntityMessage(playerId, "stopAltMusic", self.fadeOutTime)
  end
  stagehand.die()
end
