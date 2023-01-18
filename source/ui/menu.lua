import 'util/gfx'
local gfx <const> = playdate.graphics
local geom <const> = playdate.geometry
import 'ui/lifecycle'
import 'engine/ui/stackmenu'
import 'util/string'
import 'util/table'
local readonly <const> = util.table.readonly
import 'util/oo'
local typeGuard <const> = util.oo.typeGuard
local typeGuardElements <const> = util.oo.typeGuardElements
local instanceOf <const> = util.oo.instanceOf

class "MenuUI" extends "UILifecycle" {
    public {
        __construct = function(self, args)
            args = args or {}
            if args.title ~= nil then
                self.title = typeGuard('string', args.title)
            end
            self.closeCallback = typeGuard('function', args.onClose or function() end)
            self.controller = typeGuard('UIController', args.controller or error('controller required'))

            if type(args.items) == 'function' then
                self.items = args.items
            elseif args.items ~= nil then
                local items = typeGuardElements('StackMenuItem', args.items or {})
                self.items = function() return items end
            end
        end,

        -- begin UILifecycle
        
        onOpen = function(self)
            local controller = self.controller
            self.view = StackMenu.new{
                title = self.title,
                onClose = function()
                    controller:closeCurrent()
                end,
                items = self.items
            }
            self.controller:getOverlay():enableMenu(self.view)
        end,

        onClose = function(self) 
            self.view = nil
            self.controller:getOverlay():disable()
        end,

        onSuspend = function(self) end,

        onResume = function(self) end,

        update = function(self)
            self.view:update()
        end,

        -- end UILifecycle
    },
    private {
        controller = null, -- UIController
        closeCallback = function() end,
        title = null, -- string|nil
        items = function() return {} end, -- function returning []StackMenuItem
        view = null, -- StackMenu
    }
}

ui = ui or {}
ui.menus = readonly{

    mainMenu = function(args)
        args = args or {}
        local game = typeGuard('GameState', args.game or error('game required'))

        local items = {}
        if game.phase == 'PLAYER_ACTIONS' then
            table.insert(items, StackMenuItem.new{
                label = 'End turn',
                title = 'Are you sure?',
                children = {
                    StackMenuItem.new{
                        label = 'No',
                        back = true,
                    },
                    StackMenuItem.new{
                        label = 'Yes',
                        callback = function()
                            game:endPlayerActions()
                        end,
                        close = true,
                    },
                }
            })
        end

        table.insert(items, StackMenuItem.new{
            label = 'Tasks',
            children = function()
                local children = {}
                for _, task in ipairs(game:getActiveTasks()) do
                    table.insert(children, taskItem(task, game))
                end
                return children
            end,
        })

        return {
            title = 'Main menu',
            items = items
        }
    end,

}
