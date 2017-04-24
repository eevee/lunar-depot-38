local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'


local function modular_distance(a, b, base)
    local d = b - a
    if d > base / 2 then
        d = d - base
    elseif d < -base / 2 then
        d = d + base
    end
    return d
end

local function play_positional_sound(sound, source)
    sound = sound:clone()
    local player_pos = worldscene.player.pos
    local dx = modular_distance(source.pos.x, player_pos.x, worldscene.map.width)
    sound:setVolume(0.25 + 0.5 * (1 - math.abs(dx) / (worldscene.map.width / 2)))
    sound:play()
end

local BaseAngel = actors_base.SentientActor:extend{
    max_slope = Vector(16, -1),

    is_angel = true,
    is_critter = true,
    -- chase: trying to move towards its target
    -- aimless: running around with no particular target
    -- attack: currently hitting the door
    -- idle: pausing between attacks
    -- stunned: stunned, can be hurt
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
            local dx = modular_distance(self.pos.x, actor.pos.x, mw)
            if math.abs(dx) < nearest_target_x then
                nearest_target_x = math.abs(dx)
                self.ptrs.target = actor
            end
        end
    end

    self:think()
end

function BaseAngel:think()
    if self.ptrs.target then
        self.state = 'chase'
        local dx = modular_distance(self.pos.x, self.ptrs.target.pos.x, worldscene.map.width)
        if dx > 0 then
            self:decide_walk(1)
        else
            self:decide_walk(-1)
        end
    else
        self.state = 'aimless'
        if math.random() < 0.5 then
            self:decide_walk(1)
        else
            self:decide_walk(-1)
        end
    end
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
                -- FIXME ugh this is a clusterfuck; don't want to do this if we were stunned in this window
                if self.state == 'idle' then
                    self.state = 'chase'
                end
            end, 0.5)
        end)
        play_positional_sound(game.resource_manager:get('assets/sfx/angelhit1.ogg'), self)
    end

    return BaseAngel.__super.on_collide_with(self, actor, ...)
end

function BaseAngel:damage(amount, kind, source)
    if self.state == 'dead' then
        return
    end

    if kind == 'stun' then
        if self.state == 'stunned' then
            return
        end

        self.is_locked = true
        self.sprite:set_pose('flinch')
        self.state = 'stunned'
        worldscene.tick:delay(function()
            self.is_locked = false
            -- Resume whatever we were doing
            self:think()
        end, 5)
    elseif kind == 'paint' then
        if self.state ~= 'stunned' then
            return
        end

        -- Destroy us
        self.state = 'dead'
        worldscene:remove_actor(self)
        play_positional_sound(game.resource_manager:get('assets/sfx/angedestroyed.ogg'), self)
    end

    return true
end

function BaseAngel:update(dt)
    if self.state == 'chase' and math.abs(self.velocity.x) < 2 and self.on_ground then
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


local SpaceshipSmoke = actors_base.Actor:extend{
    name = 'spaceship smoke',
    sprite_name = 'spaceship smoke',

    z = 1,  -- in front of angels
    opacity = 1,
}

function SpaceshipSmoke:init(...)
    SpaceshipSmoke.__super.init(self, ...)

    self.sprite:set_pose("" .. math.random(1, 2))
    self.velocity = Vector(-16, 0)
    self.acceleration = Vector(-16, 0)

    worldscene.fluct:to(self, 1, { opacity = 0 })
    :oncomplete(function()
        worldscene:remove_actor(self)
    end)
end

function SpaceshipSmoke:update(dt)
    self.velocity = self.velocity + self.acceleration * dt
    self.pos = self.pos + self.velocity * dt

    SpaceshipSmoke.__super.update(self, dt)
end

function SpaceshipSmoke:draw()
    love.graphics.push('all')
    love.graphics.setColor(255, 255, 255, 255 * self.opacity)
    SpaceshipSmoke.__super.draw(self)
    love.graphics.pop()
end


local Spaceship = actors_base.MobileActor:extend{
    name = 'spaceship',
    sprite_name = 'spaceship',

    z = 1,  -- in front of angels
    gravity_multiplier = 0,
}

function Spaceship:init(...)
    Spaceship.__super.init(self, ...)

    self.velocity = Vector(256, 0)
    self:_schedule_angel_spawn()
    self:_schedule_exhaust()
end

function Spaceship:blocks()
    return false
end

function Spaceship:_schedule_angel_spawn()
    worldscene.tick:delay(function()
        if math.random() < 0.25 then
            local x = math.random(0, worldscene.map.width)
            worldscene:add_actor(EyeAngel2(self.pos:clone()))
        end
        self:_schedule_angel_spawn()
    end, 5)
end

function Spaceship:_schedule_exhaust()
    worldscene.tick:delay(function()
        worldscene:add_actor(SpaceshipSmoke(self.pos + Vector(math.random(-8, 0), math.random(-16, 16))))
        self:_schedule_exhaust()
    end, 0.125)
end



return {
    EyeAngel1 = EyeAngel1,
    EyeAngel2 = EyeAngel2,
    EyeAngel3 = EyeAngel3,
    EyeAngel4 = EyeAngel4,
    RadioAngel3 = RadioAngel3,

    modular_distance = modular_distance,
    play_positional_sound = play_positional_sound,
}
