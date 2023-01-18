import 'util/oo'
local interface <const> = util.oo.interface

-- provided interface for UI screens to control which screens are shown
interface "UIController" {
    "openMenu", -- args: args of StackMenu, or a predefined menu (string key of ui.menus)
    "closeCurrent",
    "getOverlay",
}

-- required interface for UI screens to respond to lifecycle events
interface "UILifecycle" {
    "onOpen", -- called when UI is first shown, after previous is closed/suspended
    "onClose", -- called when a UI is closed
    "onSuspend", -- called when a UI is suspended, e.g. game paused or other UI opened on top
    "onResume", -- called when a suspended UI is resumed
    "update", -- called every frame the UI is on top and not suspended
}
