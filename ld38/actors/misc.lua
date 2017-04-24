local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'


local AndrePainting = actors_base.Actor:extend{
    name = 'andre painting',
    sprite_name = 'andre painting',

    z = -9999,
    is_angel_target = true,
    wave = 1,
    stage = 0,
    progress = 0,
}

-- NOTE: speckle assigns itself to self.ptrs.painter
function AndrePainting:init(...)
    AndrePainting.__super.init(self, ...)

    self.sprite:set_pose('5-5')
end

function AndrePainting:damage(amount, kind, source)
    if kind == 'angel' then
        self.ptrs.painter:annoy()
        return true
    end
end

function AndrePainting:paint(dt)
    self.progress = self.progress + dt
    self.stage = math.floor(self.progress / (game.time_to_finish_painting / 5))
    self.sprite:set_pose(("%d-%d"):format(self.wave, self.stage))
    if self.stage == 5 then
        print("you win!!")
    end
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

function Speckle:on_enter()
    -- Can't do this right now because the world is still being loaded and the
    -- painting might not exist yet, but it's safe to do after the first update
    -- TODO would be awful nice to have a better way of linking map actors
    -- together ahead of time
    worldscene.tick:delay(function()
        local painting
        for _, actor in ipairs(worldscene.actors) do
            if actor:isa(AndrePainting) then
                painting = actor
                break
            end
        end
        assert(painting, "speckle can't find its painting")
        self.ptrs.painting = painting
        painting.ptrs.painter = self
    end, 0)
end

function Speckle:annoy()
    self.annoyance_timer = game.speckle_annoyance_duration
    self.sprite:set_pose('annoyed')
end

function Speckle:damage(amount, kind, source)
    self:annoy()
    return true
end

function Speckle:update(dt)
    -- TODO this seems like a common thing i want too.  aim for a goal
    -- (position or time both) and do something when i get there?
    if self.annoyance_timer > 0 then
        self.annoyance_timer = self.annoyance_timer - dt
        if self.annoyance_timer <= 0 then
            self.sprite:set_pose('paint')
        end
    else
        self.ptrs.painting:paint(dt)
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

    health = 0,
    z = -1000,
    is_angel_target = true,
}

function DoorPlanks:init(...)
    DoorPlanks.__super.init(self, ...)
    self.health = game.total_door_health
    self.sprite:set_pose('5')
end

function DoorPlanks:damage(amount, kind, source)
    if kind == 'angel' then
        local old_planks = math.ceil(self.health / (game.total_door_health / 5))
        self.health = math.max(0, self.health - amount)
        local new_planks = math.ceil(self.health / (game.total_door_health / 5))
        if new_planks ~= old_planks then
            self.sprite:set_pose('' .. new_planks)
            if new_planks == 0 then
                -- FIXME obviously.
                error("you lose!!")
            end
        end
        return true
    end
end
