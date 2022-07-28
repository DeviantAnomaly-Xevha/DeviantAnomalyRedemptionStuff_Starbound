function init()
  animator.setParticleEmitterOffsetRegion("mor_greenrashes", mcontroller.boundBox())
  animator.setParticleEmitterActive("mor_greenrashes", config.getParameter("particles", true))

  script.setUpdateDelta(5)

  self.healingRate = -2.0 / config.getParameter("infectionTime", 1)
end

function update(dt)
  status.modifyResource("health", self.healingRate * dt)
end

function uninit()
  
end
