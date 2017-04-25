local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'
local tick = require 'vendor.tick'

local BaseScene = require 'klinklang.scenes.base'
local SceneFader = require 'klinklang.scenes.fader'
local util = require 'klinklang.util'

local TitleScene = BaseScene:extend{
    __tostring = function(self) return "titlescene" end,
}

function TitleScene:init(next_scene)
    TitleScene.__super.init(self)

    self.next_scene = next_scene

    self.music = love.audio.newSource('assets/music/sassbeat.ogg', 'stream')
    self.music:setLooping(true)

    self.image = love.graphics.newImage('assets/images/lunardepot38.png')
end

local pink = {0, 0, 0}
function TitleScene:do_continue()
    Gamestate.switch(SceneFader(self.next_scene, true, 1.0, pink, function()
        -- XXX
        self.next_scene.music:play()
    end))
end


--------------------------------------------------------------------------------
-- hump.gamestate hooks

function TitleScene:enter(next_scene)
    self.next_scene = next_scene
    self.music:play()

    self.controls_keyboard_text = love.graphics.newText(m5x7, "Move: arrow keys\nJump: space\nInteract: E\nFish: F\nPaint: D\n(gamepads work too!)")
    self.controls_gamepad_text = love.graphics.newText(m5x7, "Move: d-pad\nJump: A\nInteract: X\nFish: B\nPaint: Y\n(keyboards work too!)")

    self.key_hint_event = tick.delay(function()
        self.key_hint_text = love.graphics.newText(m5x7small, "(psst!  press a key/button!)")
    end, 5)
end

function TitleScene:update(dt)
    if game.input:pressed('accept') then
        self:do_continue()
    end
end

function TitleScene:draw()
    local sw, sh = love.graphics.getDimensions()
    local iw, ih = self.image:getDimensions()
    local scale = math.max(sw / iw, sh / ih)

    love.graphics.draw(
        self.image,
        (sw - iw * scale) / 2,
        (sh - ih * scale) / 2,
        0,
        scale)

    local w, h = game:getDimensions()
    local controls_text
    if game.input:getActiveDevice() == 'joystick' then
        controls_text = self.controls_gamepad_text
    else
        controls_text = self.controls_keyboard_text
    end
    local cw, ch = controls_text:getDimensions()
    love.graphics.setColor(0, 0, 0, 128)
    love.graphics.rectangle('fill', 16, h - 32 - ch, cw + 32, ch + 16)
    love.graphics.setColor(0, 0, 0, 128)
    love.graphics.draw(controls_text, 32, h - 24 - ch + 2)
    love.graphics.setColor(255, 255, 255)
    love.graphics.draw(controls_text, 32, h - 24 - ch)

    if self.key_hint_text then
        love.graphics.push('all')
        love.graphics.scale(game.scale, game.scale)
        local w, h = game:getDimensions()
        local tw, th = self.key_hint_text:getDimensions()
        love.graphics.setColor(0, 0, 0, 128)
        love.graphics.rectangle('fill', w - 12 - tw, h - 12 - th, tw + 8, th + 8)
        love.graphics.setColor(255, 255, 255)
        love.graphics.draw(self.key_hint_text, w - 8 - tw, h - 8 - th)
        love.graphics.pop()
    end
end


return TitleScene
