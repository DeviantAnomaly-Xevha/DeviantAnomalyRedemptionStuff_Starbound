require "/scripts/status.lua"
function init()
  effect.addStatModifierGroup({
  {stat = "maxHealth", amount = 50},
  {stat = "mor_xenomiteStatusImmunity", amount = 1},
  {stat = "mor_xenomiteResistance", amount = 0.4},
  {stat = "biomeradiationImmunity", amount = 1},
  {stat = "mor_infectedwaterStatusImmunity", amount = 1},
  {stat = "physicalResistance", amount = -0.2}
  })
end