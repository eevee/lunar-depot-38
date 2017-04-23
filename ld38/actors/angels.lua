local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'


local function _modular_distance(a, b, base)
    local d = b - a
    if d > base / 2 then
        d = d + base
    elseif d < -base / 2 then
        d = d - base
    end
    return d
end

local BaseAngel = actors_base.SentientActor:extend{
    max_slope = Vector(16, -1),

    is_angel = true,
    is_critter = true,
    state = nil,
}

function BaseAngel:init(...)
    BaseAngel.__super.init(self, ...)

    self:decide_walk(1)
    self.state = 'aimless'

    local nearest_target_x = math.huge
    local mw = worldscene.map.width
    for _, actor in ipairs(worldscene.actors) do
        if actor.is_angel_target then
            local dx = _modular_distance(self.pos.x, actor.pos.x, mw)
            if math.abs(dx) < nearest_target_x then
                nearest_target_x = math.abs(dx)
                self.ptrs.target = actor
                if dx > 0 then
                    self:decide_walk(1)
                else
                    self:decide_walk(-1)
                end
                self.state = 'chase'
            end
        end
    end
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

    if self.state == 'chase' and actor and actor == self.ptrs.target then
        self.state = 'attack'
        self:decide_walk(0)
        if self.ptrs.target.damage then
            self.ptrs.target:damage(1, 'angel', self)
        end
        self.sprite:set_pose('attack', function()
            self.state = 'idle'
            self.sprite:set_pose('stand')
            worldscene.tick:delay(function()
                self.state = 'chase'
            end, 0.5)
        end)
    end

    return BaseAngel.__super.on_collide_with(self, actor, ...)
end

function BaseAngel:damage(amount, kind, source)
    if self.is_dead then
        return
    end

    if kind == 'stun' then
        if self.is_locked then
            -- Already stunned
            return
        end

        self.is_locked = true
        self.sprite:set_pose('flinch')
        worldscene.tick:delay(function()
            self.is_locked = false
            -- FIXME resume whatever we were doing
            self:decide_walk(1)
        end, 5)
    elseif kind == 'paint' then
        if not self.is_locked then
            -- No effect if not stunned
            return
        end

        -- Destroy us
        self.is_dead = true
        worldscene:remove_actor(self)
    end
end

function BaseAngel:update(dt)
    if self.state == 'chase' and math.abs(self.velocity.x) < 2 and self.velocity.y <= 0 then
        self:decide_jump()
    end

    BaseAngel.__super.update(self, dt)
end

function BaseAngel:update_pose()
    if self.state == 'attack' then
        return
    end

    BaseAngel.__super.update_pose(self)
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
