@everyone arbix cant stop getting leaked

print("Dupe working")
local _call4 = Instance.new("ScreenGui")
_call4.Name = "DupeNotif"
_call4.ResetOnSpawn = false
_call4.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local _call11 = Instance.new("TextLabel")
_call11.Size = UDim2.new(0, 200, 0, 50)
_call11.Position = UDim2.new(0.5, - 50, 0.9, 0)
_call11.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
_call11.BackgroundTransparency = 0.3
_call11.TextColor3 = Color3.fromRGB(0, 255, 0)
_call11.TextStrokeTransparency = 0.6
_call11.Font = Enum.Font.SourceSansBold
_call11.TextSize = 24
_call11.Text = "Dupe working"
_call11.Parent = _call4
task.delay(1, function(...)
end)

task.delay(1, function()
    local r = game:GetService("ReplicatedStorage")
    local p = r:WaitForChild("Packages"):WaitForChild("Net")
    local e = p:FindFirstChild("RE/StealService/Grab")

    local g = function(x)
        e:FireServer("Grab", x)
    end

    local m = {}
    m.__index = m

    function m.n(v)
        local t = setmetatable({}, m)
        t.x = v
        print(">> [Server] Grab Queued:", v)
        task.wait(0.25)
        return t
    end

    function m:d()
        print(">> [Server] Processing:", self.x)
        g(self.x)
    end

    local id = math.floor(os.clock() * 100000)
    local h = m.n(id)
    task.wait(0.5)
    h:d()

    ScreenGui:Destroy()
end)
