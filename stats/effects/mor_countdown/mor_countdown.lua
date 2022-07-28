function init()
  self.digits = config.getParameter("digits")
  self.flashThreshold = config.getParameter("flashThreshold")
end

function update(dt)
  updateCountdown(effect.duration())
end

function updateCountdown(timer)
  digits = {}
  for i = 1, self.digits do
    local digit = extractDigit(timer, i)
    animator.setPartTag("digit" .. i, "value", digit)
    table.insert(digits, digit)
  end
  if timer < self.flashThreshold then
    animator.setAnimationState("digit", "flash")
  end
end

function extractDigit(number, place)
  return (number // (10 ^ (place - 1))) % (10 ^ place)
end

function uninit()
  effect.expire()
end