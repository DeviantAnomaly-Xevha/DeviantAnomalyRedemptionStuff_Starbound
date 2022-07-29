require "/scripts/stagehandutil.lua"

function init()
  self.groupedStagehands = config.getParameter("groupedStagehands", {})
  self.uniqueId = config.getParameter("uniqueId")
  
  if self.uniqueId then
    register()
  end
  
  message.setHandler("die", die)
end

function die()
  for _, stagehandId in ipairs(self.groupedStagehands) do
    world.sendEntityMessage(stagehandId, "mor_wasteland_die")
  end
  stagehand.die()
  
  if self.uniqueId then
    deregister()
  end
end

function register()
  local wastelands = world.getProperty("mor_wastelands", {})
  wastelands[self.uniqueId] = stagehand.position()
  world.setProperty("mor_wastelands", wastelands)
end

function deregister()
  local wastelands = world.getProperty("mor_wastelands", {})
  wastelands[self.uniqueId] = nil
  world.setProperty("mor_wastelands", wastelands)
end
