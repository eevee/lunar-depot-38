local utf8 = require 'utf8'

local baton = require 'vendor.baton'
local Gamestate = require 'vendor.hump.gamestate'
local tick = require 'vendor.tick'

local ResourceManager = require 'klinklang.resources'
local DebugScene = require 'klinklang.scenes.debug'
local WorldScene = require 'klinklang.scenes.world'
local SpriteSet = require 'klinklang.sprite'
local tiledmap = require 'klinklang.tiledmap'
local util = require 'klinklang.util'


game = {
    VERSION = "0.1",
    TILE_SIZE = 32,

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
    for path in util.find_files{'assets/sounds'} do
        resource_manager:load(path)
    end

    -- Load all the graphics upfront
    for path in util.find_files{'data/tilesets', pattern = "%.tsx%.json$"} do
        local tileset = tiledmap.TiledTileset(path, nil, resource_manager)
        resource_manager:add(path, tileset)
    end

    -- FIXME probably want a way to specify fonts with named roles
    local fontscale = 2
    m5x7 = love.graphics.newFont('assets/fonts/m5x7.ttf', 16 * fontscale)
    --m5x7:setLineHeight(0.75)  -- TODO figure this out for sure
    love.graphics.setFont(m5x7)
    m5x7small = love.graphics.newFont('assets/fonts/m5x7.ttf', 16)

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

        accept = {'sc:e', 'sc:space', 'button:a'},
    }

    local map = resource_manager:load("data/maps/moon.tmx.json")
    worldscene = WorldScene()
    worldscene:load_map(map)

    Gamestate.registerEvents()
    Gamestate.switch(worldscene)

    -- ld38 stuff
    moon_sprite = love.graphics.newImage('moon.png')
    thing_sprite = love.graphics.newImage('testsprite.png')
    thing_angle = 6.28/4
    angle = 0

    local mw, mh = moon_sprite:getDimensions()

    polar_shader = love.graphics.newShader[[
        extern float rotation;
        extern float radius;
        extern float visible;

        vec4 effect(vec4 color, Image texture, vec2 tex_coords, vec2 screen_coords) {
            // FIXME this should probably not be based purely on the screen coordinates...?  right?  but what does it even mean to move the moon elsewhere?
            vec2 center = vec2(love_ScreenSize.x / 2.0, love_ScreenSize.y - visible + radius);
            float dx = screen_coords.x - center.x;
            float dy = screen_coords.y - center.y;

            float dist = length(vec2(dx, dy));
            if (dist > radius) {
                return vec4(0.0, 0.0, 0.0, 0.0);
            }
            // Note that x and y are switched because we want the angle from
            // the vertical, not horizontal!
            float angle = mod(atan(dx, dy) - rotation, 6.28);

            // FIXME scale to tex width, shift to center...?
            vec2 new_coords = vec2(
                angle / 6.28,
                (radius - dist) / visible);

            //return vec4(new_coords.x, new_coords.y, 0.0, 1.0);
            vec4 tex_color = Texel(texture, new_coords);
            return tex_color * color;
        }
    ]]
end

function love.update(dt)
    -- FIXME this should probably be expressed in terms of distance around the circumference, not angle
    local walk_speed = 0.25
    -- Moving left means the world rotates clockwise, which on a Cartesian
    -- plane is negative
    if love.keyboard.isDown('left') then
        angle = (angle - dt * walk_speed) % 1
    elseif love.keyboard.isDown('right') then
        angle = (angle + dt * walk_speed) % 1
    end

    tick.update(dt)
    game.input:update(dt)
end

function love.draw()
    local w, h = love.graphics.getDimensions()
    local epsilon = 4
    local visible = 128
    local radius = (visible + epsilon) / 2 + w * w / (8 * (visible - epsilon))
    local moon_r = radius
    love.graphics.clear()

    local sw, sh = moon_sprite:getDimensions()
    local moon_scale = visible / sh
    polar_shader:send('rotation', angle * 6.28)
    polar_shader:send('radius', radius)
    polar_shader:send('visible', visible)
    love.graphics.setShader(polar_shader)
    love.graphics.draw(moon_sprite, 0, h - sh * moon_scale, 0, moon_scale, moon_scale)
    love.graphics.setShader()
    love.graphics.translate(w/2, h + radius - visible)

    local lexy_h = radius + 20
    local lexy_rel_angle = thing_angle - angle * 6.28
    local lw, lh = thing_sprite:getDimensions()
    -- XXX i suspect the angles are all slightly backwards from what i think they should be...
    love.graphics.draw(thing_sprite, lexy_h * math.sin(lexy_rel_angle), lexy_h * -math.cos(lexy_rel_angle), lexy_rel_angle, 1, 1, lw/2, lh)

    love.graphics.reset()
    love.graphics.print(angle, 0, 0)
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
    end
end

function love.gamepadpressed(joystick, button)
    -- Tell baton to use whatever joystick was last used
    -- TODO until i can figure out a reliable way to pick a joystick, that
    -- doesn't end up grabbing my dang tablet
    game.input.joystick = joystick
end
