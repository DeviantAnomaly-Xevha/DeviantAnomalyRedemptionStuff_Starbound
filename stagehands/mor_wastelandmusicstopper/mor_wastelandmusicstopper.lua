require "/scripts/util.lua"
require "/scripts/stagehandutil.lua"

function init()
  self.players = {}
  self.fadeOutTime = config.getParameter("fadeOutTime")
  
  message.setHandler("mor_wasteland_die", stagehand.die)
end

function update(dt)
  local oldPlayers = copy(self.players)
  self.players = {}

  local newPlayers = broadcastAreaQuery({ includedTypes = {"player"} })
  for _, playerId in pairs(newPlayers) do
    if not oldPlayers[playerId] then
      world.sendEntityMessage(playerId, "stopAltMusic", self.fadeOutTime)
    end
    self.players[playerId] = true
  end
end
