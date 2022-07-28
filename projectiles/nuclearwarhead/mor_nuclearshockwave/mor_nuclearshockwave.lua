require "/scripts/rect.lua"

function init()
  self.broadcastArea = config.getParameter("broadcastArea")
  self.broadcastEffect = config.getParameter("broadcastEffect")
  self.players = {}
end

function update(dt)
  local broadcastArea = rect.translate(self.broadcastArea, mcontroller.position())
  local queried = world.entityQuery({broadcastArea[1], broadcastArea[2]}, {broadcastArea[3], broadcastArea[4]}, {includedTypes = {"player"}})
  for _, playerId in ipairs(queried) do
    world.sendEntityMessage(playerId, "applyStatusEffect", self.broadcastEffect)
  end
end