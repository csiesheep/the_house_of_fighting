--!strict
-- ===========================================================
--  Theme
--
--  Every colour the interface uses, in one place. The three
--  client scripts had their own copies of these, which meant
--  "make it lighter" was a change in three files that could
--  drift apart. Now it is a change here.
-- ===========================================================

local Theme = {}

-- Surfaces
Theme.Panel            = Color3.fromRGB(250, 249, 246)
Theme.Row              = Color3.fromRGB(238, 236, 231)
Theme.Control          = Color3.fromRGB(224, 221, 214)
Theme.PanelTransparency = 0.06

-- Text
Theme.Ink   = Color3.fromRGB(34, 32, 36)
Theme.Muted = Color3.fromRGB(118, 114, 120)

-- Actions
Theme.Accent      = Color3.fromRGB(214, 84, 74)
Theme.AccentInk   = Color3.fromRGB(255, 251, 250)
Theme.Ready       = Color3.fromRGB(52, 148, 84)
Theme.ReadyInk    = Color3.fromRGB(252, 255, 252)
Theme.Owned       = Color3.fromRGB(52, 148, 84)
Theme.Disabled    = Color3.fromRGB(219, 216, 210)
Theme.DisabledInk = Color3.fromRGB(146, 142, 146)

-- Highlights
Theme.Flash = Color3.fromRGB(226, 152, 44)

return Theme
