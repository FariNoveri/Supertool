local AntiAdminInfo = {}

function AntiAdminInfo.loadButtons(scrollFrame, utils)
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "AntiAdminInfo"
    infoLabel.Parent = scrollFrame
    infoLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    infoLabel.BorderSizePixel = 0
    infoLabel.Size = UDim2.new(1, 0, 0, 300)
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.Text = [[
ANTI ADMIN PROTECTION - ULTIMATE SHIELD

This bad boy protects you from admin or exploiter shenanigans (kill, teleport, you name it). Try to mess with us? We'll bounce it right back! If they got their own "anti-anti" shield, we'll keep tossing the effect to other players until it sticks. No one messes with Unknown Block members!

- Always active, no turning it off.
- Effects reversed to the attacker or some random unprotected fool.
- Keeps going until it lands on someone without a shield. Hot potato, baby!

Created by Fari Noveri - Use it, don't abuse it!
]]
    infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    infoLabel.TextSize = 10
    infoLabel.TextWrapped = true
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.TextYAlignment = Enum.TextYAlignment.Top

    if utils.notify then
        utils.notify("Anti Admin Info loaded - By Fari Noveri")
    else
        print("Anti Admin Info loaded - By Fari Noveri")
    end
end

return AntiAdminInfo