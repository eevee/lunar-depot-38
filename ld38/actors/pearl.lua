local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local Player = require 'klinklang.actors.player'


local FishBall = actors_base.MobileActor:extend{
    name = 'fishball',
    sprite_name = 'fishball',

    gravity_multiplier = 0,

    is_swimming_away = false,
}

function FishBall:init(facing_left, ...)
    FishBall.__super.init(self, ...)

    self.facing_left = facing_left
    self.sprite:set_facing_right(not facing_left)
    self.velocity = Vector(384, 0)
    if facing_left then
        self.velocity.x = -self.velocity.x
    end
end

function FishBall:blocks()
    return false
end

function FishBall:on_collide_with(actor, ...)
    if actor and (actor:isa(FishBall) or actor.is_player) then
        return true
    end

    local passable = FishBall.__super.on_collide_with(self, actor, ...)
    if passable then
        return true
    end

    -- If we already popped, then just vanish the fish
    if self.is_swimming_away then
        worldscene:remove_actor(self)
    end

    -- Deal with hitting something
    if actor and actor.damage then
        actor:damage(1, 'stun', self)
    end
    self.velocity.x = 0
    self.velocity.y = 0
    self.sprite:set_pose('hit', function()
        self.sprite:set_pose('swim away')
        self.is_swimming_away = true
        self.velocity.y = -192
    end)
    return false
end


local Pearl = Player:extend{
    --name = 'pearl',
    sprite_name = 'pearl',
    jumpvel = actors_base.get_jump_velocity(128),
    max_slope = Vector(2, -1),

    decision_shoot = 0,

    is_critter = true,
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

function Pearl:update_pose()
    if self.decision_shoot == 1 then
        self.decision_shoot = 2
        self.sprite:set_pose('shoot', function()
            self.decision_shoot = 0
            local d = Vector(16, -8)
            if self.facing_left then
                d.x = -d.x
            end
            worldscene:add_actor(FishBall(self.facing_left, self.pos + d))
        end)
    elseif self.decision_shoot == 2 then
    else
        Pearl.__super.update_pose(self)
    end
end


return Pearl
