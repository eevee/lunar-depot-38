local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'
local flux = require 'vendor.flux'

local BaseScene = require 'klinklang.scenes.base'
local SceneFader = require 'klinklang.scenes.fader'
local util = require 'klinklang.util'

local EndingScene = BaseScene:extend{
    __tostring = function(self) return "endingscene" end,
}

function EndingScene:init(next_scene)
    EndingScene.__super.init(self)

    self.opacity = 0

    self.images = {}
    for i = 1, 5 do
        self.images[i] = love.graphics.newImage(("assets/images/ending%d.png"):format(i))
    end
    self.done = false

    self.music = love.audio.newSource('assets/music/desolate_3.ogg', 'stream')
    self.music:setLooping(true)

    self.image = 1

    self.flux = flux.group()

    self.flux:to(self, 1, { opacity = 1 })
        :after(1, { opacity = 0 })
        :delay(3)
        :ease('quadout')
        :oncomplete(function() self.image = self.image + 1 end)
        :after(1, { opacity = 1 })
        :after(1, { opacity = 0 })
        :delay(3)
        :ease('quadout')
        :oncomplete(function() self.image = self.image + 1 end)
        :after(1, { opacity = 1 })
        :after(1, { opacity = 0 })
        :delay(3)
        :ease('quadout')
        :oncomplete(function() self.image = self.image + 1 end)
        :after(1, { opacity = 1 })
        :after(1, { opacity = 0 })
        :delay(3)
        :ease('quadout')
        :oncomplete(function() self.image = self.image + 1 end)
        :after(1, { opacity = 1 })
        :after(1, { opacity = 0.25 })
        :delay(3)
        :ease('quadout')
        :oncomplete(function() self.done = true end)
end


--------------------------------------------------------------------------------
-- hump.gamestate hooks

function EndingScene:enter(next_scene)
    self.next_scene = next_scene
    love.audio.stop()  -- XXX fixes spraypaint or whatever
    self.music:play()
end

function EndingScene:update(dt)
    self.flux:update(dt)
end

function EndingScene:draw()
    local image = self.images[self.image]
    love.graphics.push('all')
    love.graphics.setColor(255, 255, 255, self.opacity * 255)
    love.graphics.draw(image, 100, 100, 0, 4, 4)
    love.graphics.pop()

    if self.done then
        love.graphics.printf("Lunar Depot 38\n\na game by glip and eevee\n\nfor Ludum Dare 38\n\nthanks for playing!\n\n@glitchedpuppet / @eevee\nfloraverse.com", 0, 150, 800, 'center')
    end
end


return EndingScene
