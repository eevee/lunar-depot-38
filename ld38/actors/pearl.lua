local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local Player = require 'klinklang.actors.player'

local actors_angels = require 'ld38.actors.angels'


-- Fish bubble projectile
local FishBall = actors_base.MobileActor:extend{
    name = 'fishball',
    sprite_name = 'fishball',

    gravity_multiplier = 0,

    is_projectile = true,
    destroyed_state = 0,
}

function FishBall:init(facing_left, ...)
    FishBall.__super.init(self, ...)

    self.facing_left = facing_left
    self.sprite:set_facing_right(not facing_left)
    self.velocity = Vector(384, 0)
    if facing_left then
        self.velocity.x = -self.velocity.x
    end

    actors_angels.play_positional_sound(
        game.resource_manager:get('assets/sfx/fishball1.ogg'), self)
end

function FishBall:blocks()
    return false
end

function FishBall:on_collide_with(actor, collision)
    if self.destroyed_state == 1 then
        return true
    end

    if actor and (actor.is_projectile or actor.is_player) then
        return true
    end

    -- Treat overlaps as collisions, in case we spawned inside something
    if collision.touchtype >= 0 then
        local passable = FishBall.__super.on_collide_with(self, actor, collision)
        if passable then
            return true
        end
    end

    -- If we already popped, then just vanish the fish
    if self.destroyed_state == 2 then
        worldscene:remove_actor(self)
        return true
    end

    -- Deal with hitting something
    if actor and actor.damage then
        actor:damage(1, 'stun', self)
    end
    self:_pop()
    return false
end

function FishBall:_pop()
    if self.destroyed_state ~= 0 then
        return
    end
    self.velocity.x = 0
    self.velocity.y = 0
    self.destroyed_state = 1
    self.sprite:set_pose('hit', function()
        self.sprite:set_pose('swim away')
        self.velocity.y = -192
        self.destroyed_state = 2
    end)
    actors_angels.play_positional_sound(
        game.resource_manager:get('assets/sfx/fishballhit.ogg'), self)
end

function FishBall:update(dt)
    FishBall.__super.update(self, dt)

    if self.destroyed_state == 0 and self.timer > 10 then
        self:_pop()
    end
end

-- Splash from a paint bucket
local PaintSplatter = actors_base.MobileActor:extend{
    name = 'paint splatter',
    sprite_name = 'paint splatter',

    is_projectile = true,
    destroyed_state = 0,

    -- chosen to match the rainbow lake
    PAINT_COLORS = {
        {255, 58, 141},
        {154, 134, 255},
        {60, 201, 228},
        {46, 244, 195},
        {181, 255, 170},
        {234, 255, 170},
        {255, 213, 170},
        {246, 139, 137},
    },
    PAINT_COLOR_INDEX = 1,
    color = nil,
}

function PaintSplatter:init(shooter, ...)
    PaintSplatter.__super.init(self, ...)

    local dv = Vector(32, -32)
    if shooter.facing_left then
        dv.x = -dv.x
    end
    self.velocity = shooter.velocity + dv

    if self.velocity.x < 0 then
        self.sprite:set_facing_right(false)
    end

    self.color = PaintSplatter.PAINT_COLORS[PaintSplatter.PAINT_COLOR_INDEX]
    PaintSplatter.PAINT_COLOR_INDEX = PaintSplatter.PAINT_COLOR_INDEX + 1
    if PaintSplatter.PAINT_COLOR_INDEX > #PaintSplatter.PAINT_COLORS then
        PaintSplatter.PAINT_COLOR_INDEX = 1
    end
end

function PaintSplatter:blocks()
    return false
end

function PaintSplatter:on_collide_with(actor, collision)
    if self.destroyed_state == 2 then
        return
    end

    if actor and (actor.is_projectile or actor.is_player) then
        return true
    end

    -- Treat overlaps as collisions, in case we spawned inside something
    if collision.touchtype >= 0 then
        local passable = PaintSplatter.__super.on_collide_with(self, actor, collision)
        if passable then
            return true
        end
    end

    -- Deal with hitting something
    -- FIXME this doesn't end collision, so it can hit multiple things at once!
    -- same problem with angels, really.  hmm.
    if actor and actor.damage then
        actor:damage(1000, 'paint', self)
        self.destroyed_state = 2
    else
        -- If we hit geometry, let us keep colliding in case we also hit an
        -- angel this tic
        self.destroyed_state = 1
    end
    self.velocity.x = 0
    self.velocity.y = 0
    self.gravity_multiplier = 0
    -- FIXME maybe i want to remove it from collision?  noblockmap?
    self.sprite:set_pose('hit', function()
        worldscene:remove_actor(self)
    end)
    actors_angels.play_positional_sound(
        game.resource_manager:get(("assets/sfx/splash%d.ogg"):format(math.random(1, 5))), self)
    return false
end

function PaintSplatter:update(dt)
    PaintSplatter.__super.update(self, dt)

    -- Only become completely destroyed at the end of an update
    if self.destroyed_state == 1 then
        self.destroyed_state = 2
    end
end

function PaintSplatter:draw()
    love.graphics.push('all')
    love.graphics.setColor(self.color)
    PaintSplatter.__super.draw(self)
    love.graphics.pop()
end



local Pearl = Player:extend{
    --name = 'pearl',
    sprite_name = 'pearl: gun',
    jumpvel = actors_base.get_jump_velocity(128),
    max_slope = Vector(2, -1),

    decision_shoot = 0,

    is_critter = true,
    current_weapon = 'gun',
}


function Pearl:on_collide_with(actor, ...)
    if actor and actor.is_critter then
        return true
    end

    return Pearl.__super.on_collide_with(self, actor, ...)
end

-- Decide to shoot.  TODO unfinished, doesn't apply to everyone, may come with
-- directions, etc etc...  this is something that direly needs to be
-- customizable easily
function Pearl:decide_shoot()
    if self.decision_shoot == 0 then
        self.decision_shoot = 1
    end
end

function Pearl:switch_weapons()
    if self.decision_shoot > 0 then
        return
    end

    if self.current_weapon == 'gun' then
        self.current_weapon = 'bucket'
    else
        self.current_weapon = 'gun'
    end

    self:set_sprite('pearl: ' .. self.current_weapon)
end

function Pearl:update_pose()
    if self.decision_shoot == 1 then
        self.decision_shoot = 2
        self.sprite:set_pose('shoot', function()
            self.decision_shoot = 0
            local d = Vector(16, -8)
            if self.facing_left then
                d.x = -d.x
            end
            if self.current_weapon == 'gun' then
                worldscene:add_actor(FishBall(self.facing_left, self.pos + d))
            elseif self.current_weapon == 'bucket' then
                worldscene:add_actor(PaintSplatter(self, self.pos + d))
            end
        end)
    elseif self.decision_shoot == 2 then
    else
        Pearl.__super.update_pose(self)
    end
end


return Pearl
