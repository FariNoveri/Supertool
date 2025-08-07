local Info = {}

-- Store GUI elements from mainloader.lua
local guiElements = {
    InfoFrame = nil,
    InfoScrollFrame = nil,
    InfoLayout = nil
}

-- Store created GUI objects for cleanup
local createdGuiObjects = {}

-- Set GUI elements passed from mainloader.lua
function Info.setGuiElements(elements)
    guiElements.InfoFrame = elements.InfoFrame
    guiElements.InfoScrollFrame = elements.InfoScrollFrame
    guiElements.InfoLayout = elements.InfoLayout
end

-- Update GUI to display watermark
function Info.updateGui()
    -- Clear existing content in ScrollFrame
    for _, child in pairs(guiElements.InfoScrollFrame:GetChildren()) do
        if child:IsA("TextLabel") or child:IsA("Frame") then
            child:Destroy()
        end
    end

    -- Create watermark label
    local watermarkLabel = Instance.new("TextLabel")
    watermarkLabel.Name = "WatermarkLabel"
    watermarkLabel.Parent = guiElements.InfoScrollFrame
    watermarkLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    watermarkLabel.BorderSizePixel = 0
    watermarkLabel.Size = UDim2.new(1, 0, 0, 300)
    watermarkLabel.Font = Enum.Font.Gotham
    watermarkLabel.Text = [[
--[ NOTICE BEFORE USING ]--

Created by Fari Noveri for Unknown Block members.
Not for sale, not for showing off, not for tampering.

- Rules of Use:
- Do not sell this script. It's not for profit.
- Keep the creator's name as "by Fari Noveri".
- Do not re-upload to public platforms without permission.
- Do not combine with other scripts and claim as your own.
- Only get updates from the original source to avoid errors.

- If you find this script outside the group:
It may have been leaked. Please don't share it further.

- Purpose:
This script is made to help fellow members, not for profit.
Please use it responsibly and respect its purpose.

- For suggestions, questions, or feedback:
Contact:
- Instagram: @fariinoveri
- TikTok: @fari_noveri

Thank you for reading. Use it wisely.

- Fari Noveri
]]
    watermarkLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    watermarkLabel.TextSize = 10
    watermarkLabel.TextWrapped = true
    watermarkLabel.TextXAlignment = Enum.TextXAlignment.Left
    watermarkLabel.TextYAlignment = Enum.TextYAlignment.Top
    table.insert(createdGuiObjects, watermarkLabel)

    -- Update ScrollFrame CanvasSize
    wait(0.1)
    local contentSize = guiElements.InfoLayout.AbsoluteContentSize
    guiElements.InfoScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 20)
end

-- Cleanup function to release resources
function Info.cleanup()
    -- Destroy created GUI objects
    for _, obj in pairs(createdGuiObjects) do
        if obj and obj.Parent then
            obj:Destroy()
        end
    end
    createdGuiObjects = {}
    print("Info module cleaned up")
end

return Info