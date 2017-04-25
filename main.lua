local utf8 = require 'utf8'

local baton = require 'vendor.baton'
local Gamestate = require 'vendor.hump.gamestate'
local tick = require 'vendor.tick'

local ResourceManager = require 'klinklang.resources'
local DialogueScene = require 'klinklang.scenes.dialogue'
local DebugScene = require 'klinklang.scenes.debug'
local SpriteSet = require 'klinklang.sprite'
local tiledmap = require 'klinklang.tiledmap'
local util = require 'klinklang.util'

local Pearl = require 'ld38.actors.pearl'
local actors_misc = require 'ld38.actors.misc'

local IntroScene = require 'ld38.scenes.intro'
local MoonWorldScene = require 'ld38.scenes.world'
local TransitionScene = require 'ld38.scenes.transition'
local TitleScene = require 'ld38.scenes.title'
local EndingScene = require 'ld38.scenes.ending'


local _SPEAKERS = {
    purrl = Pearl,
    anise = actors_misc.Anise,
    speckle = actors_misc.Speckle,
    marble = actors_misc.Marble,
}

local WAVE_TRACKS = {
    'assets/music/eminorthing_2.ogg',
    'assets/music/angelbeattwoWAVE2.ogg',
    'assets/music/angelbeat.ogg',
    'assets/music/angelbeattwoWAVE4.ogg',
    'assets/music/alienmonster_2.ogg',
}

game = {
    VERSION = "0.1",
    TILE_SIZE = 32,

    -- Gameplay twiddles
    time_to_finish_painting = 60,
    speckle_annoyance_duration = 5,
    angel_attack_frequency = 1,
    total_door_health = 200,
    -- State
    andre_painting_progress = 0,
    space_cash = 0,

    wave = 1,
    wave_begun = false,
    wave_begin = function(self)
        self.wave_music = love.audio.newSource(WAVE_TRACKS[self.wave], 'stream')
        self.wave_music:setLooping(true)
        self.wave_music:play()

        self.wave_begun = true
        Gamestate.push(TransitionScene(("Wave %d"):format(self.wave)))

        -- TODO this is the kind of thing i want events for i guess
        for _, actor in ipairs(worldscene.actors) do
            if actor.on_wave_begin then
                actor:on_wave_begin()
            end
        end
    end,
    wave_complete = function(self)
        self.wave_music:stop()
        if self.wave == 5 then
            Gamestate.switch(EndingScene())
            return
        end
        Gamestate.push(TransitionScene(("Wave %d complete"):format(self.wave)))
        Gamestate.push(DialogueScene(_SPEAKERS, {
            { "Yes, that will do.  I need a moment for this layer to dry.", speaker = 'speckle' },
            { "Well done, Luneko!  I believe I have some time to fix up the door.  Let me know when you're ready for the next wave.", speaker = 'marble' },
        }))
        self.wave_begun = false
        self.wave = self.wave + 1

        for _, actor in ipairs(worldscene.actors) do
            if actor.on_wave_complete then
                actor:on_wave_complete()
            end
        end
    end,
    wave_failed = function(self)
        self.wave_music:stop()
        Gamestate.push(TransitionScene(("Wave %d failed"):format(self.wave)))
        Gamestate.push(DialogueScene(_SPEAKERS, {
            { "The door!  It has fallen!  Speckle, help me restore it, urgently!", speaker = 'marble' },
            { "If I must.  I doubt my mural will survive unattended.", speaker = 'speckle', pose = { eyes = 'annoyed' } },
            { "Luneko, let us know when you'd like to try again.", speaker = 'marble' },
        }))
        self.wave_begun = false

        for _, actor in ipairs(worldscene.actors) do
            if actor.on_wave_failed then
                actor:on_wave_failed()
            end
        end
    end,

    input = nil,

    progress = {
        flags = {},
    },

    debug = false,
    debug_twiddles = {
        show_blockmap = true,
        show_collision = true,
        show_shapes = true,
    },
    debug_hits = {},
    resource_manager = nil,
    -- FIXME this seems ugly, but the alternative is to have sprite.lua implicitly depend here
    sprites = SpriteSet._all_sprites,

    scale = 1,

    _determine_scale = function(self)
        -- Default resolution is 640 × 360, which is half of 720p and a third
        -- of 1080p and equal to 40 × 22.5 tiles.  With some padding, I get
        -- these as the max viewport size.
        local w, h = love.graphics.getDimensions()
        local MAX_WIDTH = 50 * 16
        local MAX_HEIGHT = 30 * 16
        self.scale = math.ceil(math.max(w / MAX_WIDTH, h / MAX_HEIGHT))
    end,

    getDimensions = function(self)
        return math.ceil(love.graphics.getWidth() / self.scale), math.ceil(love.graphics.getHeight() / self.scale)
    end,
}


--------------------------------------------------------------------------------

function love.load(args)
    for i, arg in ipairs(args) do
        if arg == '--xyzzy' then
            print('Nothing happens.')
            game.debug = true
        end
    end

    love.graphics.setDefaultFilter('nearest', 'nearest', 1)

    -- Eagerly load all actor modules, so we can access them by name
    for path in util.find_files{'klinklang/actors', 'ld38/actors', pattern = '%.lua$'} do
        module = path:sub(1, #path - 4):gsub('/', '.')
        require(module)
    end

    local resource_manager = ResourceManager()
    resource_manager:register_default_loaders()
    resource_manager:register_loader('tmx.json', function(path)
        return tiledmap.TiledMap(path, resource_manager)
    end)
    resource_manager.locked = false  -- TODO make an api for this lol
    game.resource_manager = resource_manager

    -- Eagerly load all sound effects, which we will surely be needing
    for path in util.find_files{'assets/sfx'} do
        resource_manager:load(path)
    end

    -- Load all the graphics upfront
    for path in util.find_files{'data/tilesets', pattern = "%.tsx%.json$"} do
        local tileset = tiledmap.TiledTileset(path, nil, resource_manager)
        resource_manager:add(path, tileset)
    end

    DialogueScene.default_background = game.resource_manager:load('assets/images/dialoguebackground.png')

    -- FIXME probably want a way to specify fonts with named roles
    local fontscale = 2
    m5x7 = love.graphics.newFont('assets/fonts/glip.ttf', 16 * fontscale)
    --m5x7:setLineHeight(0.75)  -- TODO figure this out for sure
    love.graphics.setFont(m5x7)
    m5x7small = love.graphics.newFont('assets/fonts/glip.ttf', 16)
    glipfontbig = love.graphics.newFont('assets/fonts/glip.ttf', 72)

    love.joystick.loadGamepadMappings("vendor/gamecontrollerdb.txt")

    -- FIXME things i would like to have here:
    -- - cleverly scale axis inputs like that other thing, and limit them to a circular range as well?
    -- - use scancodes by default!!!  the examples use keys
    -- - get the most appropriate control for an input (first matching current device type)
    -- - mutually exclusive controls
    -- - distinguish between edge-flip and receiving an actual event
    -- - aliases or something?  so i can say "accept" means "use", or even "either use or jump"
    -- - take repeats into account?
    game.input = baton.new{
        left = {'key:left', 'axis:leftx-', 'button:dpleft'},
        right = {'key:right', 'axis:leftx+', 'button:dpright'},
        up = {'key:up', 'axis:lefty-', 'button:dpup'},
        down = {'key:down', 'axis:lefty+', 'button:dpdown'},
        jump = {'key:space', 'button:a'},
        use = {'sc:e', 'button:x'},
        shoot_fish = {'sc:f', 'button:b'},
        shoot_paint = {'sc:d', 'button:y'},

        accept = {'sc:e', 'sc:space', 'button:a'},
    }

    local map = resource_manager:load("data/maps/moon.tmx.json")
    worldscene = MoonWorldScene()
    worldscene:load_map(map)

    Gamestate.registerEvents()
    Gamestate.switch(worldscene)
    Gamestate.push(IntroScene())
    Gamestate.push(TitleScene())
end

function love.update(dt)
    tick.update(dt)
    game.input:update(dt)
end

function love.draw()
end

local _previous_size

function love.resize(w, h)
    game:_determine_scale()
end

function love.keypressed(key, scancode, isrepeat)
    if scancode == 'return' and not isrepeat and love.keyboard.isDown('lalt', 'ralt') then
        -- FIXME disabled until i can figure out how to scale this larger game
        do return end
        if love.window.getFullscreen() then
            love.window.setFullscreen(false)
            -- FIXME this freezes X for me until i ssh in and killall love, so.
            --love.window.setMode(_previous_size[1], _previous_size[2])
            -- This isn't called for resizes caused by code, but worldscene
            -- etc. sort of rely on knowing this
            love.resize(love.graphics.getDimensions())
        else
            -- LOVE claims to do this for me, but it lies
            _previous_size = {love.window.getMode()}
            love.window.setFullscreen(true)
        end
    elseif scancode == 'pause' and not isrepeat and game.debug then
        if not game.debug_scene then
            game.debug_scene = DebugScene(m5x7)
        end
        -- FIXME this is incredibly stupid
        if Gamestate.current() ~= game.debug_scene then
            Gamestate.push(game.debug_scene)
        end
    elseif scancode == 'q' and not isrepeat and game.debug then
        game:wave_complete()
    elseif scancode == 'w' and not isrepeat and game.debug then
        game:wave_failed()
    elseif scancode == 'c' and not isrepeat and game.debug then
        game.space_cash = game.space_cash + 10
    end
end

function love.gamepadpressed(joystick, button)
    -- Tell baton to use whatever joystick was last used
    -- TODO until i can figure out a reliable way to pick a joystick, that
    -- doesn't end up grabbing my dang tablet
    game.input.joystick = joystick
end
