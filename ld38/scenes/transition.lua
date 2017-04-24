local flux = require 'vendor.flux'
local Gamestate = require 'vendor.hump.gamestate'

local BaseScene = require 'klinklang.scenes.base'

local TransitionScene = BaseScene:extend{
    __tostring = function(self) return "transitionscene" end,
}

function TransitionScene:init(text)
    TransitionScene.__super.init(self)

    self.text = text
end

--------------------------------------------------------------------------------
-- hump.gamestate hooks

function TransitionScene:enter(previous_scene)
    self.wrapped = previous_scene

    local text = love.graphics.newText(glipfontbig, self.text)
    local tw, th = text:getDimensions()
    self.canvas = love.graphics.newCanvas(tw, th + 4)
    love.graphics.push('all')
    love.graphics.setCanvas(self.canvas)
    love.graphics.setColor(0, 0, 0, 64)
    love.graphics.draw(text, 0, 4)
    love.graphics.setColor(255, 255, 255)
    love.graphics.draw(text, 0, 0)
    love.graphics.pop()

    local w, h = game:getDimensions()
    self.x0 = -tw
    self.x1 = (w - tw) / 2
    self.x2 = w
    self.x = self.x0
    self.y = (h - th) / 2
    self.time = 0.75

    self.flux = flux.group()
    self.flux:to(self, self.time, { x = self.x1 })
        :ease('cubicout')
        :after(self.time, { x = self.x2 })
        :ease('cubicin')
        :delay(self.time)
        :oncomplete(function()
            Gamestate.pop()
        end)
end

function TransitionScene:update(dt)
    self.flux:update(dt)
end

function TransitionScene:draw()
    self.wrapped:draw()

    love.graphics.draw(self.canvas, self.x, self.y)
end


return TransitionScene
