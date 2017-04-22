local WorldScene = require 'klinklang.scenes.world'
local Vector = require 'vendor.hump.vector'

local Pearl = require 'ld38.actors.pearl'

local MoonWorldScene = WorldScene:extend{}

local TAU = math.pi * 2

function MoonWorldScene:init(...)
    MoonWorldScene.__super.init(self, ...)

    -- WorldScene hardcodes the Player class, but only creates a player if one
    -- doesn't already exist, so sneak this in here
    self.player = Pearl(Vector(0, 0))

    local moon_sprite = love.graphics.newImage('moon.png')
    local w, h = love.graphics.getDimensions()
    local sw, sh = moon_sprite:getDimensions()
    local epsilon = 4
    local visible = 128
    local radius = (visible + epsilon) / 2 + w * w / (8 * (visible - epsilon))
    self.moon = {
        epsilon = epsilon,
        visible = visible,
        radius = radius,
        circumference = radius * TAU,
        sprite = moon_sprite,
        scale = visible / sh,
    }
    -- 0 to 1, indicating how far around the moon the player is
    self.turned = 0

    -- Shader used for drawing the ground texture bent into a circle
    self.polar_shader = love.graphics.newShader[[
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
    self.polar_shader:send('rotation', 0)
    self.polar_shader:send('radius', radius)
    self.polar_shader:send('visible', visible)
end

function MoonWorldScene:load_map(map)
    MoonWorldScene.__super.load_map(self, map)

    -- Remove the barriers on the left and right
    -- Slightly invasive, but, whatever
    self.collider:remove(map.shapes.border[3])
    self.collider:remove(map.shapes.border[4])
    -- Add extra barriers extending beyond the left and right edges of the map
end

function MoonWorldScene:update_camera()
    if self.player then
        local w, h = love.graphics.getDimensions()
        self.camera.x = self.player.pos.x - w / 2
        self.camera.y = self.map.height - h + self.moon.visible - self.moon.epsilon
    end
end

function MoonWorldScene:update(dt)
    if game.input:down('shoot') then
        self.player:decide_shoot()
    end

    MoonWorldScene.__super.update(self, dt)
    self.turned = self.player.pos.x / self.map.width

    -- If any actors left the map, teleport them around to the other side
    local wrap = Vector(self.map.width, 0)
    for _, actor in ipairs(self.actors) do
        if actor.pos.x < 0 then
            actor:move_to(actor.pos + wrap)
        elseif actor.pos.x > self.map.width then
            actor:move_to(actor.pos - wrap)
        end
    end
end

function MoonWorldScene:draw()
    local w, h = love.graphics.getDimensions()
    self.polar_shader:send('rotation', self.turned * TAU)
    love.graphics.setShader(self.polar_shader)
    love.graphics.draw(self.moon.sprite, 0, h - self.moon.sprite:getHeight() * self.moon.scale, 0, self.moon.scale, self.moon.scale)
    love.graphics.setShader()

    MoonWorldScene.__super.draw(self)

    love.graphics.print(self.turned, 0, 0)
end

function MoonWorldScene:_draw_actors(actors)
    local sorted_actors = {}
    for k, v in ipairs(actors) do
        sorted_actors[k] = v
    end

    table.sort(sorted_actors, function(actor1, actor2)
        return (actor1.z or 0) < (actor2.z or 0)
    end)

    local w, h = love.graphics.getDimensions()
    love.graphics.push()
    -- Cancelling out the camera makes this even more complicated, so we'll
    -- just start from scratch
    love.graphics.origin()
    -- We want to rotate around the center of the moon.  The player is in the
    -- center of the screen, and thus so is the moon.  Its center is (radius -
    -- visible) below the bottom edge.
    love.graphics.translate(w / 2, h + self.moon.radius - self.moon.visible)
    for _, actor in ipairs(sorted_actors) do
        love.graphics.push()
        local dx = actor.pos.x - self.player.pos.x
        local angle = dx / self.map.width * TAU
        love.graphics.rotate(angle)
        -- This rotation already moves x = 0 to the correct angular position
        -- for the actor, so move the axes away by x to get them to draw at 0.
        -- It also assumes the actor's y is the distance from the center, but
        -- it's actually the distance from the top of the map, so adjust for
        -- that to put the bottom of the map on the surface.
        love.graphics.translate(-actor.pos.x, -self.map.height - self.moon.radius + self.moon.epsilon)
        actor:draw()
        love.graphics.pop()
    end
    love.graphics.pop()
end

return MoonWorldScene
