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


local SpaceCash = actors_base.Actor:extend{
    name = 'space cash',
    sprite_name = 'space cash',

    speed = 0,
    acceleration = 8,
}

function SpaceCash:update(dt)
    local dx = modular_distance(self.pos.x, worldscene.player.pos.x, worldscene.map.width)
    local dy = (worldscene.player.pos.y - 16) - self.pos.y
    local d = Vector(dx, dy)
    local l = d:len()
    if l < self.speed then
        -- ch-ching
        game.space_cash = game.space_cash + 1
        worldscene:remove_actor(self)
        return
    end

    self.speed = self.speed + self.acceleration * dt
    self.pos = self.pos + d * (self.speed / l)

    SpaceCash.__super.update(self, dt)
end


local BaseAngel = actors_base.SentientActor:extend{
    max_slope = Vector(16, -1),

    is_angel = true,
    is_critter = true,
    attack_sfx_path = nil,
    -- chase: trying to move towards its target
    -- aimless: running around with no particular target
    -- attack: currently hitting the door
    -- idle: pausing between attacks
    -- stunned: stunned, can be hurt
    state = nil,

    resist = 1,  -- health before becoming stunned
    health = 1,  -- health before dying
    stun_duration = 5,
    damage_inflicted = 1,
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

function BaseAngel:on_wave_complete()
    self.state = 'dead'
    self.sprite:set_pose('die', function()
        worldscene:remove_actor(self)
    end)
end

function BaseAngel:on_wave_failed()
    self:on_wave_complete()
end

function BaseAngel:think()
    if self.state == 'stunned' or self.state == 'dead' then
        return
    end

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
            self.ptrs.target:damage(self.damage_inflicted, 'angel', self)
        end
        -- AUGH, geez.  That damage can cause us to die, if we dealt the final
        -- blow to the door!
        if self.state == 'attack' then
            self.sprite:set_pose('attack', function()
                if self.state ~= 'attack' then
                    return
                end
                self.state = 'idle'
                self.sprite:set_pose('stand')
                worldscene.tick:delay(function()
                    -- FIXME ugh this is a clusterfuck; don't want to do this if we were stunned in this window
                    if self.state == 'idle' then
                        self.state = 'chase'
                    end
                end, 0.5)
            end)
        end
        play_positional_sound(game.resource_manager:get(self.attack_sfx_path), self)
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

        self.resist = math.max(0, self.resist - amount)
        if self.resist == 0 then
            self.is_locked = true
            self.sprite:set_pose('flinch')
            self.state = 'stunned'
            worldscene.tick:delay(function()
                if self.state ~= 'stunned' then
                    return
                end
                self.is_locked = false
                self.resist = 1
                -- Resume whatever we were doing
                self:think()
            end, self.stun_duration)
        end
    elseif kind == 'paint' then
        if self.state ~= 'stunned' then
            return
        end

        self.health = math.max(0, self.health - amount)
        if self.health == 0 then
            -- Destroy us
            self.state = 'dead'
            self.sprite:set_pose('die', function()
                worldscene:remove_actor(self)
            end)
            worldscene:add_actor(SpaceCash(self.pos + Vector(math.random(-8, 8), math.random(-8, 8))))
            play_positional_sound(game.resource_manager:get('assets/sfx/angedestroyed.ogg'), self)
        end
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
    if self.state == 'attack' or self.state == 'dead' then
        return
    end

    BaseAngel.__super.update_pose(self)
end


local EyeAngel1 = BaseAngel:extend{
    name = 'eye angel 1',
    sprite_name = 'eye angel 1',
    xaccel = 512,
    max_speed = 96,

    attack_sfx_path = 'assets/sfx/angelhit1.ogg',
    resist = 1,
    health = 1,
}

local EyeAngel2 = BaseAngel:extend{
    name = 'eye angel 2',
    sprite_name = 'eye angel 2',
    max_speed = 256,

    attack_sfx_path = 'assets/sfx/angelhit2.ogg',
    resist = 2,
    health = 1,
}

local EyeAngel3 = BaseAngel:extend{
    name = 'eye angel 3',
    sprite_name = 'eye angel 3',
    max_speed = 128,

    attack_sfx_path = 'assets/sfx/angelhit3.ogg',
    resist = 1,
    health = 2,
    stun_duration = 1,
}

local EyeAngel4 = BaseAngel:extend{
    name = 'eye angel 4',
    sprite_name = 'eye angel 4',
    max_speed = 128,

    attack_sfx_path = 'assets/sfx/angelhit4.ogg',
    resist = 1,
    health = 4,
}

local RadioAngel3 = BaseAngel:extend{
    name = 'radio angel 3',
    sprite_name = 'radio angel 3',
    max_speed = 64,

    attack_sfx_path = 'assets/sfx/angelhit5.ogg',
    resist = 5,
    health = 5,
    damage_inflicted = 5,
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


local ANGELS = {
    EyeAngel1,
    EyeAngel2,
    EyeAngel3,
    EyeAngel4,
    RadioAngel3,
}

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
        if game.wave_begun and worldscene.angel_count < 20 and math.random() < 4/32 + 1.5/32 * (game.wave - 1) then
            local Angel = ANGELS[math.random(1, game.wave)]
            local x = math.random(0, worldscene.map.width)
            worldscene:add_actor(Angel(self.pos:clone()))
        end
        self:_schedule_angel_spawn()
    end, 2)
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
