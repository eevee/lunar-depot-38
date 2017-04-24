local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'


local AndrePainting = actors_base.Actor:extend{
    name = 'andre painting',
    sprite_name = 'andre painting',

    z = -9999,
    is_angel_target = true,
}

function AndrePainting:init(...)
    AndrePainting.__super.init(self, ...)

    self.sprite:set_pose('5-5')
end

function AndrePainting:draw()
    love.graphics.push()
    -- TODO this is a silly minor hack and might be nice to have as
    -- first-class.  note that it requires that the anchor be in the center for
    -- correct display, and also doesn't adjust the collision box in any way,
    -- so that has to be physically double-sized
    love.graphics.scale(2, 2)
    love.graphics.translate(-self.pos.x / 2, -self.pos.y / 2)
    AndrePainting.__super.draw(self)
    love.graphics.pop()
end


local Speckle = actors_base.Actor:extend{
    name = 'speckle',
    sprite_name = 'speckle',

    z = -1000,
    annoyance_timer = 0,
}

function Speckle:init(...)
    Speckle.__super.init(self, ...)
    self.sprite:set_facing_right(false)
end

function Speckle:damage(amount, kind, source)
    self.annoyance_timer = 5
    self.sprite:set_pose('annoyed')
end

function Speckle:update(dt)
    if self.annoyance_timer > 0 then
        self.annoyance_timer = self.annoyance_timer - dt
        if self.annoyance_timer <= 0 then
            self.sprite:set_pose('paint')
        end
    end

    Speckle.__super.update(self, dt)
end


-- Does nothing, just decoration
local Ladder = actors_base.Actor:extend{
    name = 'ladder',
    sprite_name = 'ladder',

    z = -1001,  -- behind speckle
}


local DoorPlanks = actors_base.Actor:extend{
    name = 'door planks',
    sprite_name = 'door planks',

    planks = 5,
    z = -1000,
    is_angel_target = true,
}

function DoorPlanks:init(...)
    DoorPlanks.__super.init(self, ...)
    self.sprite:set_pose("" .. self.planks)
end
