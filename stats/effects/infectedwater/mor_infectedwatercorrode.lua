function init()
  animator.setParticleEmitterOffsetRegion("mor_acidsmoke", mcontroller.boundBox())
  animator.setParticleEmitterActive("mor_acidsmoke", true)
  effect.setParentDirectives("fade=20ae1c=0.2")
  animator.playSound("burn", -1)

  script.setUpdateDelta(5)

  self.healingRate = -30.0 / config.getParameter("burnTime", 60)
end

function update(dt)
  status.modifyResource("health", self.healingRate * dt)
end

function uninit()
  
end
