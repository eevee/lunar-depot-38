local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local Player = require 'klinklang.actors.player'


local FishBall = actors_base.MobileActor:extend{
    name = 'fishball',
    sprite_name = 'fishball',

    gravity_multiplier = 0,
}

function FishBall:init(facing_left, ...)
    FishBall.__super.init(self, ...)

    self.facing_left = facing_left
    self.sprite:set_facing_right(not facing_left)
    self.velocity = Vector(128, 0)
    if facing_left then
        self.velocity.x = -self.velocity.x
    end
end

function FishBall:blocks()
    return false
end

-- FIXME can't collide with other pellets or pearl
function FishBall:on_collide_with(actor, collision)
    if actor and actor:isa(FishBall) then
        return true
    end

    self.velocity.x = 0
    self.velocity.y = 0
    self.sprite:set_pose('hit', function()
        worldscene:remove_actor(self)
    end)
    return false
end


local Pearl = Player:extend{
    --name = 'pearl',
    sprite_name = 'pearl',

    decision_shoot = 0,
}


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
            local d = Vector(24, -8)
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
