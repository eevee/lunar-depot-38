function love.load()
    love.graphics.setDefaultFilter('nearest', 'nearest')
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
            float angle = mod(rotation + atan(dx, dy), 6.28);

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
    if love.keyboard.isDown('left') then
        angle = (angle + dt * walk_speed) % 1
    elseif love.keyboard.isDown('right') then
        angle = (angle - dt * walk_speed) % 1
    end
end

function love.draw()
    local w, h = love.graphics.getDimensions()
    local epsilon = 4
    local visible = 128
    local radius = (visible + epsilon) / 2 + w * w / (8 * (visible - epsilon))
    local moon_r = radius
    love.graphics.clear()
    --love.graphics.translate(w/2, h + moon_r * 3/4)

    local sw, sh = moon_sprite:getDimensions()
    --love.graphics.draw(moon_sprite, 0, 0, angle, moon_r * 2 / sw, moon_r * 2 / sh, sw/2, sh/2)
    local moon_scale = visible / sh
    polar_shader:send('rotation', angle * 6.28)
    polar_shader:send('radius', radius)
    polar_shader:send('visible', visible)
    love.graphics.setShader(polar_shader)
    love.graphics.draw(moon_sprite, 0, h - sh * moon_scale, 0, moon_scale, moon_scale)
    love.graphics.setShader()

    local lexy_h = moon_r + 20
    local lexy_rel_angle = angle - thing_angle
    local lw, lh = thing_sprite:getDimensions()
    love.graphics.draw(thing_sprite, lexy_h * math.cos(lexy_rel_angle), lexy_h * math.sin(lexy_rel_angle), angle, 1, 1, lw/2, lh)

    love.graphics.print(angle, 0, 0)
end

