import 'util/oo'
local typeGuard <const> = util.oo.typeGuard
local instanceOf <const> = util.oo.instanceOf
import 'ui/lifecycle'
import 'ui/overlay'
import 'ui/world'
import 'ui/menu'

-- manages UILifecycle instances via a stack structure, and provides itself as the UIController
class "UIStackController" extends "UIController" {
    public {
        __construct = function(self, args)
            args = args or {}
            self.game = typeGuard("GameState", args.game or error('game required'))
            self.overlay = typeGuard("OverlayUI", args.overlay or OverlayUI.new{game = self.game})
            
            self:push(WorldUI.new{
                game = self.game,
                controller = self,
            })
        end,

        -- BEGIN UIController interface 

        closeCurrent = function(self)
            self:pop()
        end,

        openNarrative = function(self, script)
            self:push(ChatUI.new{
                vars = self.game:getNarrativeVars(),
                script = script,
                controller = self,
            })
        end,

        openRig = function(self, rig)
            typeGuard("Rig", rig)
            self:push(RigUI.new{
                game = self.game,
                controller = self,
                rig = typeGuard("Rig", rig),
            })
        end,

        openMenu = function(self, argsOrString)
            local args = {}
            if type(argsOrString) == 'string' then
                local menuFactory = ui.menus[argsOrString]
                if menuFactory == nil then
                    error('not a pre-defined menu: '..argsOrString)
                end
                args = menuFactory{game = self.game}
            else
                args = typeGuard('table', argsOrString)
            end

            args.controller = self
            self:push(MenuUI.new(args))
        end,

        openHacking = function(self, hackable, scriptAvailability)
            typeGuard('Hackable', hackable)
            local puzzle = hackable:getHackingPuzzle()
            if puzzle == nil then
                error('openHacking called but hackable has no puzzle: '..tostring(hackable))
            end
            local availableScripts = {}
            for _, availableScript in ipairs(scriptAvailability.available) do
                table.insert(availableScripts, availableScript.script)
            end

            self:push(HackingUI.new{
                controller = self,
                puzzle = puzzle,
                scripts = availableScripts,
                onWin = function()
                    hackable:onSuccessfulHack()
                    self:pop()
                end,
                onLose = function()
                    hackable:onUnsuccessfulHack()
                    self:pop()
                end,
            })
        end,

        getOverlay = function(self)
            return self.overlay
        end,

        -- END UIControl interface 

        update = function(self)
            self:top():update()
            self.overlay:update()
        end,
        
        top = function(self)
            return self.stack[#self.stack]
        end,

        pop = function(self)
            if #self.stack == 1 then
                error('cannot pop last remaining screen')
            end
            local popped = table.remove(self.stack)
            popped:onClose()
            self:top():onResume()
        end,

        push = function(self, screen)
            typeGuard("UILifecycle", screen)

            local prev = self:top()
            if prev ~= nil then
                prev:onSuspend()
            end
            table.insert(self.stack, screen)
            screen:onOpen()
        end,
    },

    private {
        game = null, -- GameState
        stack = {}, -- UIState[]
        overlay = null, -- OverlayUI
    }
}
