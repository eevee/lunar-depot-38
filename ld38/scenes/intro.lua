local flux = require 'vendor.flux'
local Gamestate = require 'vendor.hump.gamestate'

local BaseScene = require 'klinklang.scenes.base'
local DialogueScene = require 'klinklang.scenes.dialogue'

local Pearl = require 'ld38.actors.pearl'
local actors_misc = require 'ld38.actors.misc'


local DIALOGUE_PARTS = {
    {
        { "How close is the door?", speaker = 'speckle' },
        { "We are nearly there. With any luck, the boards I've placed should still be--", speaker = 'marble' },
    },
    {
        { "Ah! How is this possible?!", speaker = 'speckle' },
        { "A Luneko! The culprit, surely!", speaker = 'marble' },
        { "You there, space kitten! Halt, at once!", speaker = 'speckle' },
        { "It is much too dangerous in there. Return whence you came! ", speaker = 'marble' },
    },
    {
        { "No!", speaker = 'purrl' },
        { "N...no? You must! We are to seal the door tight.", speaker = 'speckle' },
        {
            "Do you not see how the angels flock to the door? We must cut them off.",
            "So please, return!",
            speaker = 'marble',
        },
    },
    {
        { "Are you straying further, space kitten? Do not do it!", speaker = 'speckle' },
        { "Don't scold me! Mweo!", speaker = 'purrl' },
        { "We are wasting precious time! Let us seal the door.", speaker = 'marble' },
        { "You can't! Mewo! Then how will everyone else go away from my moon?!", speaker = 'purrl' },
        { "Everyone else? There are others?", speaker = 'speckle' },
        { "Meowowo. Yeah! Uncle Twig and Nyapo-Ion. Mewo!", speaker = 'purrl' },
        { "Did someone say...", speaker = 'anise', pose = 'mysterious' },
    },
    {
        { "ANISE?", speaker = 'anise', pose = { 'default', 'o_o' } },
        { "No! Nobody did! Why are you on my moon, Star Anise!", speaker = 'purrl' },
        { "AOOOORRRWWWW!! If I don't run the shop, who will?!", speaker = 'anise', pose = 'default' },
        { "Oh, yeah. Mewoo! I guess you can stay.", speaker = 'purrl' },
        { "Wrong! Fallacious! Incorrect! No one may stay. No one at all! Where are Twig and Nyapo-Ion? We must usher everyone out at once.", speaker = 'speckle' },
        { "They're on a space journey. Mweeow! ", speaker = 'purrl' },
        { "Oh, no. When will they be back?", speaker = 'marble' },
        { "I don't know! I don't care! Mewo... ", speaker = 'purrl' },
    },
    {
        { "I cannot understand... The angels have no effect on them?", speaker = 'speckle' },
        { "It appears not.  ", speaker = 'marble' },
        { "Hm. Then, Marble, you know what we must do. We know not when the other Lunekos are to return. But, we DO know that the angels are coming from the ship orbiting this moon.", speaker = 'speckle' },
        { "Ah, yes. Then I shall take to boarding the door up during this lull.", speaker = 'marble' },
        { "And I shall take to starting the mural. We may not be able to reach the ship, ourselves, but with help...", speaker = 'speckle' },
    },
    {
        { "Luneko! If we offer you one Cosmic Catnip Carrot, would you lend us your assistance?", speaker = 'marble' },
        { "Hmm... Mewo... You want to play with me?", speaker = 'purrl' },
        { "Uh... ", speaker = 'marble' },
        { "Ah, no. The... angels would like to play.", speaker = 'speckle' },
        { "Oh! Yes. The... the game is that the angels will try to go through the door.", speaker = 'marble' },
        { "And too will try to ruin my mural.", speaker = 'speckle' },
        { "So you must stun them.", speaker = 'marble' },
        { "And then paint them.", speaker = 'speckle' },
        { "Meweow... okay. But I won't share my carrot with Anise!", speaker = 'purrl' },
        { "We will provide two carrots.", speaker = 'speckle' },
        { "I'm not sharing two carrots with Anise!", speaker = 'purrl' },
        { "...", speaker = 'marble' },
    },
}


local IntroScene = BaseScene:extend{
    __tostring = function(self) return "introscene" end,
}

function IntroScene:init(text)
    IntroScene.__super.init(self)

    self.images = {}
    for i = 1, 7 do
        self.images[i] = love.graphics.newImage(("assets/images/intro%d.png"):format(i))
    end

    self.part = 0
end

--------------------------------------------------------------------------------
-- hump.gamestate hooks

function IntroScene:enter(previous_scene)
    self:_advance()
end

function IntroScene:resume()
    self:_advance()
end

function IntroScene:_advance()
    self.part = self.part + 1
    if self.part > 7 then
        Gamestate.pop()
    else
        Gamestate.push(DialogueScene({
            purrl = Pearl,
            anise = actors_misc.Anise,
            speckle = actors_misc.Speckle,
            marble = actors_misc.Marble,
        }, DIALOGUE_PARTS[self.part], true))
    end
end

function IntroScene:draw()
    love.graphics.draw(self.images[self.part], (800 - 150 * 3) / 2, (600 - 200 - 100 * 3) / 2, 0, 3)
end


return IntroScene
