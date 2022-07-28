function init()
  self.roarFadeOutTime = config.getParameter("roarFadeOutTime", 0.5)
  self.fadingOut = false

  animator.playSound("boom")
  animator.playSound("roar", -1)
end

function update(dt)
  if effect.duration() < self.roarFadeOutTime and not self.fadingOut then
    animator.setSoundVolume("roar", 0.0, self.roarFadeOutTime)
    self.fadingOut = true
  end
end