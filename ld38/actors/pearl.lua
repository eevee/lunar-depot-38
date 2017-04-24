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
    lifetime = 0.5,

    spawn_sfx_path = 'assets/sfx/fishball1.ogg',
}

function FishBall:init(shooter, ...)
    FishBall.__super.init(self, ...)

    self.facing_left = shooter.facing_left
    self.sprite:set_facing_right(not self.facing_left)
    self.velocity = Vector(384, 0)
    if self.facing_left then
        self.velocity.x = -self.velocity.x
    end
    -- big fishball's default sprite is not default, because of the way the
    -- spritesheet is arranged, whoops
    self.sprite:set_pose('default')

    self.lifetime = shooter.firing_range / 2

    actors_angels.play_positional_sound(
        game.resource_manager:get(self.spawn_sfx_path), self)
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

    -- Turn overlaps into collisions before consulting super; if we spawned
    -- inside something then we should hit it immediately, not ignore it
    if collision.touchtype < 0 then
        collision.touchtype = 1
    end

    local passable = FishBall.__super.on_collide_with(self, actor, collision)
    if passable then
        return true
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

    if self.destroyed_state == 0 and self.timer > self.lifetime then
        self:_pop()
    end
end


local BigFishBall = FishBall:extend{
    name = 'fishball big',
    sprite_name = 'fishball big',

    spawn_sfx_path = 'assets/sfx/fishball2.ogg',
}


-- chosen to match the rainbow lake
local PAINT_COLORS = {
    {255, 58, 141},
    {154, 134, 255},
    {60, 201, 228},
    {46, 244, 195},
    {181, 255, 170},
    {234, 255, 170},
    {255, 213, 170},
    {246, 139, 137},
}

-- Splash from a paint bucket
local PaintSplatter = actors_base.MobileActor:extend{
    name = 'paint splatter',
    sprite_name = 'paint splatter',

    is_projectile = true,
    destroyed_state = 0,

    PAINT_INDEX = 1,
    color = nil,
}

function PaintSplatter:init(shooter, ...)
    PaintSplatter.__super.init(self, ...)

    local dv = Vector(32, -64)
    if shooter.facing_left then
        dv.x = -dv.x
    end
    self.velocity = shooter.velocity + dv

    if self.velocity.x < 0 then
        self.sprite:set_facing_right(false)
    end

    self.color = PAINT_COLORS[PaintSplatter.PAINT_INDEX]
    PaintSplatter.PAINT_INDEX = PaintSplatter.PAINT_INDEX + 1
    if PaintSplatter.PAINT_INDEX > #PAINT_COLORS then
        PaintSplatter.PAINT_INDEX = 1
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

    -- Turn overlaps into collisions before consulting super; if we spawned
    -- inside something then we should hit it immediately, not ignore it
    if collision.touchtype < 0 then
        collision.touchtype = 1
    end

    local passable = FishBall.__super.on_collide_with(self, actor, collision)
    if passable then
        return true
    end

    -- Deal with hitting something.  If we actually inflict damage, we set
    -- destroyed_state to 2, which makes us ignore all other collisions even in
    -- this tic; otherwise, we set destroyed_state to 1, which lets us possibly
    -- collide with other things this tic but gets set to 2 in our next update.
    -- Thus a paint splatter can only ever damage one thing.
    -- TODO "stop colliding after this" seems like a common problem
    self.destroyed_state = 1
    if actor and actor.damage then
        if actor:damage(1, 'paint', self) then
            self.destroyed_state = 2
        end
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


local PaintSpray = actors_base.MobileActor:extend{
    name = 'spraypaint',
    sprite_name = 'spraypaint',

    -- TODO this should be immune to /all/ outside forces
    gravity_multiplier = 0,

    dt = 0,
    damage_rate = 1,
    paint_current = 1,
    paint_next = 2,
    paint_progress = 0,
}

function PaintSpray:init(...)
    PaintSpray.__super.init(self, ...)

    self.paint_current = math.random(1, #PAINT_COLORS)
    self.paint_next = self.paint_current % #PAINT_COLORS + 1
end

function PaintSpray:on_enter()
    self.sfx = game.resource_manager:get('assets/sfx/sprayloop.ogg'):clone()
    self.sfx:setLooping(true)
    self.sfx:play()
end

function PaintSpray:on_leave()
    self.sfx:stop()
end

function PaintSpray:blocks()
    return false
end

function PaintSpray:update(dt)
    self.dt = dt

    self.paint_progress = self.paint_progress + dt
    while self.paint_progress > 1 do
        self.paint_progress = self.paint_progress - 1
        self.paint_current = self.paint_current % #PAINT_COLORS + 1
        self.paint_next = self.paint_current % #PAINT_COLORS + 1
    end

    PaintSpray.__super.update(self, dt)
end

function PaintSpray:draw()
    love.graphics.push('all')
    local color0 = PAINT_COLORS[self.paint_current]
    local color1 = PAINT_COLORS[self.paint_next]
    love.graphics.setColor(
        color0[1] + (color1[1] - color0[1]) * self.paint_progress,
        color0[2] + (color1[2] - color0[2]) * self.paint_progress,
        color0[3] + (color1[3] - color0[3]) * self.paint_progress)
    PaintSpray.__super.draw(self)
    love.graphics.pop()
end

function PaintSpray:on_collide_with(actor, collision)
    if actor and actor.damage and not actor.is_player then
        actor:damage(self.damage_rate * self.dt, 'paint', self)
    end
    return true
end


local BigPaintSpray = PaintSpray:extend{
    name = 'spraypaint big',
    sprite_name = 'spraypaint big',

    damage_rate = 2,
}


local Pearl = Player:extend{
    --name = 'pearl',
    sprite_name = 'pearl: gun',
    jumpvel = actors_base.get_jump_velocity(128),
    max_slope = Vector(2, -1),
    dialogue_position = 'left',
    dialogue_chatter_sound = {
        'assets/sfx/pearl1.ogg',
        'assets/sfx/pearl2.ogg',
        'assets/sfx/pearl3.ogg',
        'assets/sfx/pearl4.ogg',
        'assets/sfx/pearl5.ogg',
    },
    dialogue_color = {58, 52, 114},
    dialogue_shadow = {139, 134, 165},
    dialogue_sprites = {
        { name = 'base', sprite_name = 'pearl portrait', while_talking = { default = 'talking' } },
        { name = 'eyes', sprite_name = 'pearl portrait - eyes', default = false },
        { name = 'tail', sprite_name = 'pearl portrait - tail' },
        default = { eyes = false },
        [">_<"] = { eyes = '>_<' },
        [">:|"] = { eyes = '>:|' },
    },
    inventory_cursor = 0,

    decision_shoot = nil,
    last_shot = 1,
    is_shooting = false,
    can_shoot = true,

    is_critter = true,
    fish_weapon = 'gun',
    paint_weapon = 'bucket',
    spraypaint_anchor = Vector(13, -7),
    firing_range = 1,
    firing_speed = 1,
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
function Pearl:decide_shoot_fish()
    self.decision_shoot = self.fish_weapon
end

function Pearl:decide_shoot_paint()
    self.decision_shoot = self.paint_weapon
end

function Pearl:update(dt)
    local weapon = self.decision_shoot
    self.decision_shoot = nil
    if weapon and not self.is_shooting and self.can_shoot then
        if weapon == 'gun' or weapon == 'big gun' then
            self:set_sprite('pearl: gun')
        elseif weapon == 'bucket' then
            self:set_sprite('pearl: bucket')
        else
            self:set_sprite('pearl: spraypaint')
        end

        if weapon == 'gun' or weapon == 'big gun' or weapon == 'bucket' then
            self.is_shooting = weapon
            self.can_shoot = false
            worldscene.tick:delay(function()
                self.can_shoot = true
            end, 1 / self.firing_speed)
            self.sprite:set_pose('shoot', function()
                self.is_shooting = nil
                local d = Vector(12, -8)
                if self.facing_left then
                    d.x = -d.x
                end
                local Projectile
                if weapon == 'gun' then
                    Projectile = FishBall
                elseif weapon == 'big gun' then
                    Projectile = BigFishBall
                elseif weapon == 'bucket' then
                    Projectile = PaintSplatter
                end
                worldscene:add_actor(Projectile(self, self.pos + d))
            end)
        else
            local Spraypaint
            if weapon == 'spraypaint' then
                Spraypaint = PaintSpray
            elseif weapon == 'big spraypaint' then
                Spraypaint = BigPaintSpray
            end
            if not self.ptrs.spraypaint or not self.ptrs.spraypaint:isa(Spraypaint) then
                if self.ptrs.spraypaint then
                    worldscene:remove_actor(self.ptrs.spraypaint)
                end
                local spraypaint = Spraypaint(self.pos)
                worldscene:add_actor(spraypaint)
                self.ptrs.spraypaint = spraypaint
            end
        end
    end

    Pearl.__super.update(self, dt)

    -- Do this after the main update so it sticks to our new position
    if self.ptrs.spraypaint then
        if weapon == 'spraypaint' or weapon == 'big spraypaint' then
            local anchor = self.spraypaint_anchor
            if self.facing_left then
                anchor = Vector(-anchor.x, anchor.y)
            end
            self.ptrs.spraypaint:move_to(self.pos + anchor)
            self.ptrs.spraypaint.sprite:set_facing_right(not self.facing_left)
        else
            worldscene:remove_actor(self.ptrs.spraypaint)
            self.ptrs.spraypaint = nil
        end
    end
end

function Pearl:update_pose()
    if self.is_shooting then
        -- TODO could do the shooty jump sprites here
    else
        Pearl.__super.update_pose(self)
    end
end


return Pearl
