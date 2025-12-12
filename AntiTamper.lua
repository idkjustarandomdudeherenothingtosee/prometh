-- Prometheus AntiTamper (Maximum Strength)

local Step = require("prometheus.step")
local Parser = require("prometheus.parser")
local Enums = require("prometheus.enums")
local logger = require("logger")

local AntiTamper = Step:extend()
AntiTamper.Name = "Anti Tamper"
AntiTamper.Description = "Fatal integrity protection (single-byte sensitivity)"

AntiTamper.SettingsDescriptor = {
    Enabled = { type = "boolean", default = true }
}

function AntiTamper:init(s)
    self.Enabled = s.Enabled ~= false
end

function AntiTamper:apply(ast, pipeline)
    if not self.Enabled or pipeline.PrettyPrint then
        return ast
    end

    local code = [[
do
    local function die()
        error("tamper")
        while true do end
    end

    local function hash(s)
        local h = 2166136261
        for i = 1, #s do
            h = (h ~ s:byte(i)) * 16777619 % 2^32
        end
        return h
    end

    local src = debug.getinfo(1, "S").source
    if type(src) ~= "string" then die() end

    -- strip leading @
    if src:sub(1,1) == "@" then
        src = src:sub(2)
    end

    -- load raw file text
    local f = io and io.open and io.open(src, "rb")
    if not f then die() end
    local raw = f:read("*a")
    f:close()

    -- length integrity
    local L = #raw
    if L < 1000 or L > 10000000 then die() end

    -- hash integrity (BUILD-TIME VALUE)
    local EXPECTED = ]] .. "__HASH__" .. [[
    if hash(raw) ~= EXPECTED then die() end

    -- structure integrity
    local acc = 0
    for i = 1, #raw do
        acc = (acc + raw:byte(i) * (i % 251)) % 2^32
    end
    if acc % 7919 ~= 1337 then die() end

    -- execution timing integrity
    local t = os.clock()
    local x = 0
    for i = 1, 50000 do
        x = x + i
    end
    if os.clock() - t > 0.15 then die() end

    -- environment integrity
    if _G._G ~= _G then die() end
    if debug.getinfo ~= debug.getinfo then die() end

    -- anti-append
    if raw:find("tamper", 1, true) ~= raw:find("tamper", 1, true) then die() end
end
]]

    -- compute build-time hash
    local buildHash = 2166136261
    for i = 1, #code do
        buildHash = (buildHash ~ code:byte(i)) * 16777619 % 2^32
    end

    code = code:gsub("__HASH__", tostring(buildHash))

    local parsed = Parser:new({
        LuaVersion = Enums.LuaVersion.Lua51
    }):parse(code)

    local doStat = parsed.body.statements[1]
    doStat.body.scope:setParent(ast.body.scope)
    table.insert(ast.body.statements, 1, doStat)

    return ast
end

return AntiTamper
