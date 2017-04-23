local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'


local BaseAngel = actors_base.SentientActor:extend{
    max_slope = Vector(16, -1),

    is_angel = true,
    is_critter = true,
}

function BaseAngel:init(...)
    BaseAngel.__super.init(self, ...)

    self:decide_walk(1)
end

function BaseAngel:blocks()
    if self.is_locked then
        return false
    end

    return true
end

function BaseAngel:on_collide_with(actor, ...)
    if actor and actor.is_critter then
        return true
    end

    return BaseAngel.__super.on_collide_with(self, actor, ...)
end

function BaseAngel:damage(amount, kind, source)
    if kind == 'stun' then
        if self.is_locked then
            -- Already stunned
            return
        end

        self.is_locked = true
        self.sprite:set_pose('flinch')
        worldscene.tick:delay(function()
            self.is_locked = false
            self:decide_walk(1)
        end, 5)
    elseif kind == 'paint' then
        if not self.is_locked then
            -- No effect if not stunned
            return
        end

        -- Destroy us
        worldscene:remove_actor(self)
    end
end


local EyeAngel1 = BaseAngel:extend{
    name = 'eye angel 1',
    sprite_name = 'eye angel 1',
}

local EyeAngel2 = BaseAngel:extend{
    name = 'eye angel 2',
    sprite_name = 'eye angel 2',
}

local EyeAngel3 = BaseAngel:extend{
    name = 'eye angel 3',
    sprite_name = 'eye angel 3',
}

local EyeAngel4 = BaseAngel:extend{
    name = 'eye angel 4',
    sprite_name = 'eye angel 4',
}

local RadioAngel3 = BaseAngel:extend{
    name = 'radio angel 3',
    sprite_name = 'radio angel 3',
}


return {
    EyeAngel1 = EyeAngel1,
    EyeAngel2 = EyeAngel2,
    EyeAngel3 = EyeAngel3,
    EyeAngel4 = EyeAngel4,
    RadioAngel3 = RadioAngel3,
}
