function init()
  effect.addStatModifierGroup({
  {stat = "protection", amount = -7}
  })
  animator.setParticleEmitterOffsetRegion("mor_greenrashes", mcontroller.boundBox())
  animator.setParticleEmitterActive("mor_greenrashes", config.getParameter("particles", true))

  script.setUpdateDelta(5)
end

function uninit()
  
end
