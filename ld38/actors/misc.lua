local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local DialogueScene = require 'klinklang.scenes.dialogue'

local actors_angels = require 'ld38.actors.angels'


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

function AndrePainting:update_pose()
    self.sprite:set_pose(("%d-%d"):format(game.wave, self.stage))
end

function AndrePainting:on_wave_complete()
    self.stage = 0
    self.progress = 0
    game.andre_painting_progress = 0
    self:update_pose()
end

function AndrePainting:on_wave_failed()
    self.stage = 0
    self.progress = 0
    game.andre_painting_progress = 0
    self:update_pose()
end

function AndrePainting:paint(dt)
    self.progress = self.progress + dt
    game.andre_painting_progress = self.progress
    self.stage = math.floor(self.progress / (game.time_to_finish_painting / 5))
    self:update_pose()
    if self.stage == 5 then
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
    dialogue_chatter_sound = {
        'assets/sfx/speckle1.ogg',
        'assets/sfx/speckle2.ogg',
        'assets/sfx/speckle3.ogg',
        'assets/sfx/speckle4.ogg',
    },
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

function Speckle:on_wave_begin()
    self.sprite:set_pose('paint')
end

function Speckle:on_wave_complete()
    self.sprite:set_pose('idle')
    self.annoyance_timer = 0
end

function Speckle:on_wave_failed()
    self.sprite:set_pose('idle')
    self.annoyance_timer = 0
end

function Speckle:on_use(activator)
    local convo = {
        {
            jump = 'annoyed',
            condition = function() return self.annoyance_timer > 0 end,
        },
        {
            "Please do not disturb me whilst I paint.",
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
    self.sprite:set_pose('5')
end

function DoorPlanks:on_wave_begin()
    self.health = game.total_door_health
    self.sprite:set_pose('5')
end

function DoorPlanks:on_wave_complete()
    self.health = game.total_door_health
    self.sprite:set_pose('5')
end

function DoorPlanks:on_wave_failed()
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
            self.sprite:update(0)  -- so they redraw even if we immediately do a cutscene
            actors_angels.play_positional_sound(
                game.resource_manager:get('assets/sfx/plank.ogg'), self)
            if new_planks == 0 then
                game:wave_failed()
            end
        end
        return true
    end
end


local Marble = actors_base.Actor:extend{
    name = 'marble',
    sprite_name = 'marble',
    dialogue_position = 'right',
    dialogue_chatter_sound = {
        'assets/sfx/marble1.ogg',
        'assets/sfx/marble2.ogg',
        'assets/sfx/marble3.ogg',
        'assets/sfx/marble4.ogg',
    },
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

local function _check_space_cash(value)
    return {
        jump = 'insufficient space cash',
        condition = function()
            if game.space_cash < value then
                return true
            else
                game.space_cash = game.space_cash - value
            end
        end,
    }
end

function Anise:on_use(activator)
    local convo = {
        { "AOOWWRRR!!", speaker = 'anise' },
        { jump = 'menu', condition = 'seen anise intro' },
        { set = 'seen anise intro' },
        {
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
        { label = 'menu' },
        {
            speaker = 'anise',
            menu = {
                { 'firing range', "Increase firing range (5 SC)", condition = function() return activator.firing_range == 1 end },
                { 'firing range 2', "Increase firing range (10 SC)", condition = function() return activator.firing_range == 2 end },
                { 'firing range 3', "Increase firing range (15 SC)", condition = function() return activator.firing_range == 4 end },
                { 'firing speed', "Increase firing speed (5 SC)", condition = function() return activator.firing_speed == 1 end },
                { 'firing speed 2', "Increase firing speed (10 SC)", condition = function() return activator.firing_speed == 2 end },
                { 'big gun', "Bigger fish gun (10 CP)", condition = function() return activator.fish_weapon == 'gun' end },
                { 'spraypaint', "Spraypaint (20 CP)", condition = function() return activator.paint_weapon == 'bucket' end },
                { 'big spraypaint', "Bigger spraypaint (30 CP)", condition = function() return activator.paint_weapon == 'spraypaint' end },
                { 'floor kibble', "Floor kibble (100000000000000 CP)" },
                { 'bye', "Never mind" },
            }
        },

        { label = 'floor kibble' },
        { "Hey you gotta pay up if you want my floor kibble!!  Gimme that Space Cash!!", speaker = 'anise' },
        { "Mewoh no!  I don't have anywhere near enough space cash...", speaker = 'purrl' },
        { "Oh well too bad!!  I'll have to keep all this floor kibble to myself!!  Fresh off the ground too!!!", speaker = 'anise' },
        { "Mewwwaaauuughh!", speaker = 'purrl' },
        { jump = 'menu' },

        { label = 'firing range' },
        _check_space_cash(5),
        {
            execute = function()
                activator.firing_range = activator.firing_range * 2
            end,
        },
        { "If you make a big meow like this...", speaker = 'anise' },
        {
            "AAAOOOOOWWWRRRRRR!!!!",
            speaker = 'anise',
            pose = 'o_o',
        },
        {
            "Then the fish will go further to get away from you!!",
            speaker = 'anise',
            pose = 'default',
        },
        {
            "That's the worst thing I ever heard!",
            "I only meow nicely!",
            "Mewoo!!",
            speaker = 'purrl',
            pose = '>:|',
        },
        {
            speaker = 'purrl',
            pose = 'default',
        },
        { jump = 'menu' },

        { label = 'firing range 2' },
        _check_space_cash(10),
        {
            execute = function()
                activator.firing_range = activator.firing_range * 2
            end,
        },
        { "Okay so!!  Hot tip number two coming through!!  I hope you're ready.", speaker = 'anise' },
        { "This better be better than the last one, mewo!", speaker = 'purrl' },
        { "OK what you do is...", speaker = 'anise' },
        {
            "Make a scary face!!  AOOWWRRR!!!!!",
            speaker = 'anise',
            pose = 'o_o',
        },
        { speaker = 'anise', pose = 'default' },
        {
            "That's the same thing as before!!",
            speaker = 'purrl',
            pose = '>:|',
        },
        {
            speaker = 'purrl',
            pose = 'default',
        },
        { jump = 'menu' },

        { label = 'firing range 3' },
        _check_space_cash(15),
        {
            execute = function()
                activator.firing_range = activator.firing_range * 4
            end,
        },
        {
            "Aw geez I'm running out of advice!!",
            speaker = 'anise',
        },
        {
            "You didn't have any advice to start with!!",
            speaker = 'purrl',
        },
        {
            "Have you tried going \"aowr\"?",
            speaker = 'anise',
        },
        {
            "Hm.  No, I haven't.  I'll give that a shot.",
            speaker = 'purrl',
        },
        { jump = 'menu' },

        { label = 'firing speed' },
        _check_space_cash(5),
        {
            execute = function()
                activator.firing_speed = activator.firing_speed + 1
            end,
        },
        {
            "Hey Purrl!!  Did you know if you pull the trigger more, you fire faster??  Try it!!",
            "You can't buy this kind of sage wisdom in stores, you know!!",
            speaker = 'anise',
        },
        { "Mewoew, but I just did?", speaker = 'purrl' },
        { "First one's free!!", speaker = 'anise' },
        { "What??", speaker = 'purrl' },
        { "AOWWRRR!!", speaker = 'anise', pose = 'o_o' },
        { speaker = 'anise', pose = 'default' },
        { jump = 'menu' },

        { label = 'firing speed 2' },
        _check_space_cash(10),
        {
            execute = function()
                activator.firing_speed = activator.firing_speed + 1
            end,
        },
        { "How's my shooting faster advice going??", speaker = 'anise' },
        { "Um...  it's dumb, but it works, somehow?  Mewoww...", speaker = 'purrl' },
        { "Oh!!  In that case, here's some more, on the house!!  Try shooting faster!!", speaker = 'anise' },
        { "Anise!!", speaker = 'purrl', pose = '>_<' },
        { speaker = 'purrl', pose = 'default' },
        { jump = 'menu' },

        { label = 'big gun' },
        _check_space_cash(10),
        {
            execute = function()
                activator.fish_weapon = 'big gun'
            end,
        },
        { "A fine choice!!  This enhanced gun shoots bigger fish!!", speaker = 'anise' },
        { "What?!  The fish are bigger?  Not the gun???", speaker = 'purrl' },
        { "NO REFUNDS!  AOWWWRR!!", speaker = 'anise', pose = 'o_o' },
        { jump = 'menu' },

        { label = 'spraypaint' },
        _check_space_cash(20),
        {
            execute = function()
                activator.paint_weapon = 'spraypaint'
            end,
        },
        { "Hey check this out!!  Now you can paint on the go!!  With Star Anise's patented Spraypaint Thing He Found In The Trash!!", speaker = 'anise' },
        { "Don't sell me trash!!  It does look much nicer than my bucket, though.", speaker = 'purrl' },
        { jump = 'menu' },

        { label = 'big spraypaint' },
        _check_space_cash(30),
        {
            execute = function()
                activator.paint_weapon = 'big spraypaint'
            end,
        },
        { "With this bigger spraygun, you can graffiti even faster than before!!", speaker = 'anise' },
        { "I don't want to graffiti!  That's rude!", speaker = 'purrl' },
        { jump = 'menu' },

        { label = 'insufficient space cash' },
        {
            "Sorry Purrl!  Looks like you need some more Space Cash!!  Maybe there's an ATM around here??",
            speaker = 'anise',
        },
        { jump = 'menu' },

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
