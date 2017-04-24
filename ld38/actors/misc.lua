local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local DialogueScene = require 'klinklang.scenes.dialogue'


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
        -- FIXME this would be nice to have happen at the beginning of a wave or something
        self.wave = self.wave + 1
        self.stage = 0
        self.progress = 0
        game:wave_complete()
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
    dialogue_position = 'right',
    dialogue_color = {0, 0, 0},
    dialogue_shadow = {192, 192, 192},
    dialogue_sprites = {
        { name = 'base', sprite_name = 'speckle portrait' },
        { name = 'eyes', sprite_name = 'speckle portrait - eyes', default = false },
    },
    z = -1000,
    is_usable = true,

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

function Speckle:on_use(activator)
    local convo = {
        {
            jump = 'annoyed',
            condition = function() return self.annoyance_timer > 0 end,
        },
        {
            "Paint paint paint.",
            speaker = 'speckle',
        },
        { bail = true },

        { label = 'annoyed' },
        {
            "I cannot work under these conditions!",
            pose = { eyes = 'annoyed' },
            speaker = 'speckle',
        },
    }
    Gamestate.push(DialogueScene({
        purrl = activator,
        speckle = self,
    }, convo))
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
    elseif game.wave_begun then
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


local Marble = actors_base.Actor:extend{
    name = 'marble',
    sprite_name = 'marble',
    dialogue_position = 'right',
    --dialogue_chatter_sound = 'assets/sounds/chatter-lop.ogg',
    dialogue_color = {0, 0, 0},
    dialogue_shadow = {192, 192, 192},
    dialogue_sprites = {
        { name = 'base', sprite_name = 'marble portrait', while_talking = { default = 'talking' } },
    },

    is_usable = true,
}

function Marble:init(...)
    Marble.__super.init(self, ...)

    self.sprite:set_facing_right(false)
end

function Marble:update(dt)
    -- FIXME stupid hack to do this cutscene when the world first becomes available
    if self.timer == 0 and dt > 0 then
        -- Call this FIRST, so the dialogue scene goes on top of it
        game:wave_begin()

        local convo = {
            { "We shall talk of carrots later. Are you ready? The angels are coming to play.", speaker = 'marble' },
            { "Meweow! I'm ready!", speaker = 'purrl' },
        }
        Gamestate.push(DialogueScene({
            purrl = worldscene.player,
            marble = self,
        }, convo))
    end

    Marble.__super.update(self, dt)
end

function Marble:on_use(activator)
    local convo = {
        {
            jump = 'midwave',
            condition = function() return game.wave_begun end,
        },
        {
            "Ready?",
            speaker = 'marble',
        },
        {
            speaker = 'purrl',
            menu = {
                { 'yes', "Mew bet!" },
                { 'no', "Mewoh no!" },
            }
        },

        { label = 'yes' },
        { execute = function()
            -- FIXME this is because switching states within dialogue is janky,
            -- so just do it as soon as we return to the world; this will make
            -- the world advance by one frame though
            worldscene.tick:delay(function()
                game:wave_begin()
            end, 0)
        end },
        { label = 'no' },
        { bail = true },

        { label = 'midwave' },
        {
            "I can't fix the door now!  It's not safe!",
            speaker = 'marble',
        },
    }
    Gamestate.push(DialogueScene({
        purrl = activator,
        marble = self,
    }, convo))
end


local Anise = actors_base.Actor:extend{
    name = 'anise',
    sprite_name = 'anise',
    dialogue_position = 'right',
    dialogue_chatter_sound = {
        'assets/sfx/anise1.ogg',
        'assets/sfx/anise2.ogg',
    },
    --dialogue_background = 'assets/images/dialoguebox-lop.png',
    dialogue_color = {34, 32, 52},
    dialogue_shadow = {137, 137, 137},
    dialogue_sprites = {
        { name = 'base', sprite_name = 'anise portrait' },
        { name = 'eyes', sprite_name = 'anise portrait - eyes', default = false },
        { name = 'mouth', sprite_name = 'anise portrait - mouth', while_talking = { default = 'talking' } },
        { name = 'tail', sprite_name = 'anise portrait - tail' },
        mysterious = { base = 'mysterious', eyes = false, mouth = false, tail = false },
        default = { base = 'default', eyes = false, mouth = 'default', tail = 'wiggle' },
        o_o = { eyes = 'o_o' },
        ['^_^'] = { eyes = '^_^' },
    },

    is_usable = true,
}

function Anise:on_use(activator)
    local convo = {
        {
            "AOOWWRRR!!",
            "Welcome to Anise's Moon Emporium!!  Anise's...  Emporimoon!!!  I'm STAR ANISE and--",
            speaker = 'anise',
        },
        {
            "Mewwo!  I know who you are!",
            speaker = 'purrl',
            pose = '>_<',
        },
        {
            speaker = 'purrl',
            pose = 'default',
        },
        {
            "Hey!  Please don't interrupt!!  It's rude!!",
            "But yeah hi Purrl!!  Check it out, I'm the only store on this whole moon!!!  I've really hit the big time now!!",
            speaker = 'anise',
        },
        {
            "Mewwow!",
            speaker = 'purrl',
        },
        {
            "Yeah!!  Look at all this stuff I found just lying around on the floor too!!",
            speaker = 'anise',
        },
        {
            speaker = 'anise',
            menu = {
                { 'dummy', "Floor kibble - Increase max HP (5 CP)" },
                { 'dummy', "Mesh bag - INT +2, CHR +4 (10 CP)" },
                { 'dummy', "Bigger fish gun (20 CP)" },
                { 'bye', "Never mind" },
            }
        },

        { label = 'dummy' },
        {
            "Hey you gotta pay up!!  Gimme that space cash!!",
            speaker = 'anise',
        },
        {
            "Mewoh no!  I don't have any space cash...",
            speaker = 'purrl',
        },
        {
            "Oh well too bad!!  I'll have to keep all this amazing stuff to myself!!",
            speaker = 'anise',
        },
        {
            "Mewwwaaauuughh!",
            speaker = 'purrl',
        },
        { bail = true },

        { label = 'bye' },
        {
            "I have to go shoot aliens with fish now.",
            speaker = 'purrl',
        },
        {
            "Oh good luck!!  Come by if you need anything!!!!",
            speaker = 'anise',
        },
        { bail = true },
    }
    Gamestate.push(DialogueScene({
        purrl = activator,
        anise = self,
    }, convo))
end


return {
    Anise = Anise,
    Speckle = Speckle,
    Marble = Marble,
}
