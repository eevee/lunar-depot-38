local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'


local EyeAngel2 = actors_base.SentientActor:extend{
    name = 'eye angel 2',
    sprite_name = 'eye angel 2',
    max_slope = Vector(16, -1),
}

function EyeAngel2:init(...)
    EyeAngel2.__super.init(self, ...)

    self:decide_walk(1)
end


return {
    EyeAngel2 = EyeAngel2,
}
