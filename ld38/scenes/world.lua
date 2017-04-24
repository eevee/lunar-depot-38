local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'

local WorldScene = require 'klinklang.scenes.world'

local actors_angels = require 'ld38.actors.angels'
local Pearl = require 'ld38.actors.pearl'

local TAU = math.pi * 2

local ANGEL_PROPORTION_SPEED = 0.125

local MoonWorldScene = WorldScene:extend{}

function MoonWorldScene:init(...)
    MoonWorldScene.__super.init(self, ...)

    -- WorldScene hardcodes the Player class, but only creates a player if one
    -- doesn't already exist, so sneak this in here
    self.player = Pearl(Vector(0, 0))

    local moon_sprite = love.graphics.newImage('assets/images/catmoon.png')
    local w, h = love.graphics.getDimensions()
    local sw, sh = moon_sprite:getDimensions()
    local epsilon = 128 * 2 * 1.5
    local visible = 256 * 2
    local radius = (visible + epsilon) / 2 + w * w / (8 * (visible - epsilon))
    self.moon = {
        epsilon = epsilon,
        visible = visible,
        radius = radius,
        circumference = radius * TAU,
        sprite = moon_sprite,
        scale = visible / sh,
        surface = 224 * 2,
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
            float angle = mod(rotation + atan(dx, -dy), 6.283);

            vec2 new_coords = vec2(
                angle / 6.283,
                (radius - dist) / visible);
            vec4 tex_color = Texel(texture, new_coords);
            return tex_color * color;
        }
    ]]
    self.polar_shader:send('rotation', 0)
    self.polar_shader:send('radius', radius)
    self.polar_shader:send('visible', visible)

    -- Shader used for drawing the ground texture bent into a circle
    self.polar_background_shader = love.graphics.newShader[[
        extern float rotation;
        extern float radius;
        extern float visible;
        extern float surface;

        // Background layers
        // base sky -- this is the texture passed in
        extern Image gradient_base;     // lighten
        extern Image top_sky;           // normal
        extern Image top_sky2;          // normal
        extern Image sky_exclusion;     // exclusion
        extern Image big_stars;         // soft light
        extern Image stars;             // hard light

        // Parallax distance (compounded for each layer)
        extern float parallax;

        vec4 blend_normal(vec4 bottom, vec4 top) {
            if (top.a == 0.0) {
                return bottom;
            }
            if (bottom.a == 0.0) {
                return top;
            }

            float alpha = bottom.a + top.a - bottom.a * top.a;
            return vec4(mix(bottom.rgb, top.rgb, top.a / alpha), alpha);
        }

        float blend_soft_light_channel(float bottom, float top) {
            if (top <= 0.5) {
                return bottom - (1.0 * 2.0 * top) * bottom * (1.0 - bottom);
            }
            else {
                float d;
                if (bottom <= 0.25) {
                    d = ((16.0 * bottom - 12.0) * bottom + 4.0) * bottom;
                }
                else {
                    d = sqrt(bottom);
                }

                return bottom + (2.0 * top - 1.0) * (d - bottom);
            }
        }
        vec4 blend_soft_light(vec4 bottom, vec4 top) {
            vec4 blended_top = vec4(
                blend_soft_light_channel(bottom.r, top.r),
                blend_soft_light_channel(bottom.g, top.g),
                blend_soft_light_channel(bottom.b, top.b),
                top.a);
            return blend_normal(bottom, blended_top);
        }

        float blend_hard_light_channel(float bottom, float top) {
            if (top < 0.5) {
                top = top * 2.0;
                return bottom * top;
            }
            else {
                top = top * 2.0 - 1.0;
                return bottom + top - bottom * top;
            }
        }
        vec4 blend_hard_light(vec4 bottom, vec4 top) {
            vec4 blended_top = vec4(
                blend_hard_light_channel(bottom.r, top.r),
                blend_hard_light_channel(bottom.g, top.g),
                blend_hard_light_channel(bottom.b, top.b),
                top.a);
            return blend_normal(bottom, blended_top);
        }

        vec4 effect(vec4 color, Image texture, vec2 tex_coords, vec2 screen_coords) {
            // FIXME this should probably not be based purely on the screen coordinates...?  right?  but what does it even mean to move the moon elsewhere?
            vec2 center = vec2(love_ScreenSize.x / 2.0, love_ScreenSize.y - visible + radius);
            float dx = screen_coords.x - center.x;
            float dy = screen_coords.y - center.y;

            float dist = length(vec2(dx, dy));
            // Note that x and y are switched because we want the angle from
            // the vertical, not horizontal!
            float angle = rotation + atan(dx, -dy);

            vec2 new_coords = vec2(
                angle / 6.283,
                1.0 - (dist - (radius - visible)) / love_ScreenSize.y);
            if (dist > (radius - surface)) {
                vec2 orig_coords = vec2(rotation / 6.283 + (screen_coords.x / love_ScreenSize.x - 0.5) * 800.0 / 4096.0, screen_coords.y / love_ScreenSize.y);
                float q = (dist - (radius - surface)) / (love_ScreenSize.y - (visible - surface));
                new_coords = mix(new_coords, orig_coords, mix(0.75, 1.0, q));
            }
            //return vec4(new_coords.x, new_coords.x, new_coords.x, 1.0);
            new_coords = mod(new_coords, 1.0);
            vec4 pixel = Texel(texture, new_coords);

            vec4 next_pixel;
            float alpha;
            // gradient_base -- lighten
            new_coords.x = mod(new_coords.x - parallax, 1.0);
            next_pixel = Texel(gradient_base, new_coords);
            next_pixel = vec4(max(pixel.rgb, next_pixel.rgb), next_pixel.a);
            pixel = blend_normal(pixel, next_pixel);

            // top_sky -- normal
            new_coords.x = mod(new_coords.x - parallax, 1.0);
            next_pixel = Texel(top_sky, new_coords);
            pixel = blend_normal(pixel, next_pixel);

            // top_sky2 -- normal
            new_coords.x = mod(new_coords.x - parallax, 1.0);
            next_pixel = Texel(top_sky2, new_coords);
            pixel = blend_normal(pixel, next_pixel);

            // sky_exclusion -- exclusion (difference squared)
            // doesn't get parallax since it's just a solid color, no texture
            next_pixel = Texel(sky_exclusion, new_coords);
            next_pixel = vec4(pixel.rgb + next_pixel.rgb - 2 * pixel.rgb * next_pixel.rgb, next_pixel.a);
            pixel = blend_normal(pixel, next_pixel);

            // big_stars -- soft light
            new_coords.x = mod(new_coords.x - parallax, 1.0);
            next_pixel = Texel(big_stars, new_coords);
            pixel = blend_soft_light(pixel, next_pixel);

            // stars -- hard light
            new_coords.x = mod(new_coords.x - parallax, 1.0);
            next_pixel = Texel(stars, new_coords);
            pixel = blend_hard_light(pixel, next_pixel);

            return pixel * color;
        }
    ]]
    self.polar_background_shader:send('rotation', 0)
    self.polar_background_shader:send('radius', radius)
    self.polar_background_shader:send('visible', visible)
    self.polar_background_shader:send('surface', self.moon.surface)
    self.background_image_base = love.graphics.newImage('assets/images/background-base.png')
    self.polar_background_shader:send('gradient_base', love.graphics.newImage('assets/images/background-gradient-base.png'))
    self.polar_background_shader:send('top_sky', love.graphics.newImage('assets/images/background-top-sky.png'))
    self.polar_background_shader:send('top_sky2', love.graphics.newImage('assets/images/background-top-sky2.png'))
    self.polar_background_shader:send('sky_exclusion', love.graphics.newImage('assets/images/background-sky-exclusion.png'))
    self.polar_background_shader:send('big_stars', love.graphics.newImage('assets/images/background-big-stars.png'))
    self.polar_background_shader:send('stars', love.graphics.newImage('assets/images/background-stars.png'))
    self.parallax = 0
    self.polar_background_shader:send('parallax', self.parallax)

    -- Shader used for desaturating the world depending on the number of angels
    self.angel_texture = love.graphics.newImage('assets/images/angeltexture.png')
    self.desaturation_shader = love.graphics.newShader[[
        extern float amount;  // 0 to 1

        vec4 effect(vec4 color, Image texture, vec2 tex_coords, vec2 screen_coords) {
            vec4 tex_color = Texel(texture, tex_coords);
            float gray = (tex_color.r + tex_color.g + tex_color.b) / 3;
            vec3 desaturated = mix(tex_color.rgb, vec3(gray), amount);
            return vec4(desaturated, tex_color.a) * color;
        }
    ]]

    self.angel_count = 0
    self.angel_proportion = 0
end

function MoonWorldScene:load_map(map)
    MoonWorldScene.__super.load_map(self, map)

    -- Remove the barriers on the left and right
    -- Slightly invasive, but, whatever
    self.collider:remove(map.shapes.border[3])
    self.collider:remove(map.shapes.border[4])
end

function MoonWorldScene:_update_angel_count(delta)
    self.angel_count = self.angel_count + delta
    if self.angel_proportion_timer then
        self.angel_proportion_timer:stop()
        self.angel_proportion_timer = nil
    end
    local new_proportion = self.angel_count / (self.angel_count + 9)
    local t = math.abs(new_proportion - self.angel_proportion) / ANGEL_PROPORTION_SPEED
    self.angel_proportion_timer = self.fluct
        :to(self, t, { angel_proportion = new_proportion })
        :ease('linear')
        :onupdate(function()
            self.desaturation_shader:send('amount', self.angel_proportion)
        end)
        :oncomplete(function()
            self.angel_proportion_timer = nil
        end)
end

function MoonWorldScene:add_actor(actor)
    if actor.is_angel then
        self:_update_angel_count(1)
    end

    MoonWorldScene.__super.add_actor(self, actor)
end

function MoonWorldScene:remove_actor(actor)
    if actor.is_angel then
        self:_update_angel_count(-1)
    end

    MoonWorldScene.__super.remove_actor(self, actor)
end

function MoonWorldScene:update_camera()
    if self.player then
        local w, h = love.graphics.getDimensions()
        self.camera.x = self.player.pos.x - w / 2
        self.camera.y = self.map.height - h + self.moon.visible - self.moon.surface
    end
end

function MoonWorldScene:update(dt)
    if game.input:down('shoot_fish') then
        self.player:decide_shoot_fish()
    elseif game.input:down('shoot_paint') then
        self.player:decide_shoot_paint()
    end

    MoonWorldScene.__super.update(self, dt)
    self.turned = self.player.pos.x / self.map.width

    self.parallax = (self.parallax + dt / 2048) % 1
    self.polar_background_shader:send('parallax', self.parallax)

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
    local w, h = self.canvas:getDimensions()
    love.graphics.setCanvas(self.canvas)
    love.graphics.clear()

    -- Draw complicated ass fucking background
    self.polar_background_shader:send('rotation', self.turned * TAU)
    love.graphics.setShader(self.polar_background_shader)
    love.graphics.draw(self.background_image_base, 0, 0)
    -- And moon ground thing
    self.polar_shader:send('rotation', self.turned * TAU)
    love.graphics.setShader(self.polar_shader)
    love.graphics.draw(self.moon.sprite, 0, h - self.moon.sprite:getHeight() * self.moon.scale, 0, self.moon.scale, self.moon.scale)
    love.graphics.setShader()
    love.graphics.setCanvas()

    -- Draw the background to the screen separately, since WorldScene:draw will
    -- clear it (boo)
    self:_draw_final_canvas()

    MoonWorldScene.__super.draw(self)

    love.graphics.print(self.turned, 0, 0)
    love.graphics.print(love.timer.getFPS(), 0, 16)
end

function MoonWorldScene:_draw_final_canvas()
    love.graphics.setShader(self.desaturation_shader)
    MoonWorldScene.__super._draw_final_canvas(self)
    love.graphics.setShader()
    love.graphics.setColor(255, 255, 255, 255 * 0.125 * self.angel_proportion)
    love.graphics.draw(self.angel_texture, 0, 0)
    love.graphics.setColor(255, 255, 255)
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
        love.graphics.translate(-actor.pos.x, -self.map.height - self.moon.radius + self.moon.surface)
        actor:draw()
        love.graphics.pop()
    end
    love.graphics.pop()
end

return MoonWorldScene
