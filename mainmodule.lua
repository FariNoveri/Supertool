-- MainLoader.lua
-- Script Utama untuk memuat semua modul cheat

local GuiModule = require(script:WaitForChild("GuiModule"))
local FeaturesModule = require(script:WaitForChild("FeaturesModule"))
local PlayerActions = require(script:WaitForChild("PlayerActions"))
local FreecamModule = require(script:WaitForChild("FreecamModule"))
local Utilities = require(script:WaitForChild("Utilities"))

-- Inisialisasi semua fitur utama
Utilities.setup()
GuiModule.initUI()
FeaturesModule.initFeatures()
PlayerActions.initPlayerActions()
FreecamModule.initFreecam()

print("✅ SuperTool loaded from modules")
