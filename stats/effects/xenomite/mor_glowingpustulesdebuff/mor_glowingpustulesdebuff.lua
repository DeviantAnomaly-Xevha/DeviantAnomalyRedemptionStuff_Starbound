function init()

  self.healingRate = -2.0 / config.getParameter("infectionTime", 1)
end

function update(dt)
  status.modifyResource("health", self.healingRate * dt)
end

function uninit()
  
end
