-- This Script is Part of the Prometheus Obfuscator by narodi
-- AntiTamper.lua
-- This Script provides an Obfuscation Step, that breaks the script, when someone tries to tamper with it.

local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local Scope = require("prometheus.scope");
local RandomStrings = require("prometheus.randomStrings")
local Parser = require("prometheus.parser");
local Enums = require("prometheus.enums");
local logger = require("logger");

local AntiTamper = Step:extend();

AntiTamper.Description = "This Step Breaks your Script when it is modified. This is only effective when using the new VM.";
AntiTamper.Name = "Anti Tamper";

AntiTamper.SettingsDescriptor = {
    UseDebug = { type = "boolean", default = true, description = "Use debug library. (Recommended, however scripts will not work without debug library.)" },
    UseEnvironmentCheck = { type = "boolean", default = true, description = "Add environment integrity checks." },
    UseConstantCheck = { type = "boolean", default = true, description = "Add constant modification detection." }
}

function AntiTamper:init(settings)
    self.UseEnvironmentCheck = settings.UseEnvironmentCheck ~= false;
    self.UseConstantCheck = settings.UseConstantCheck ~= false;
end

function AntiTamper:apply(ast, pipeline)
    if pipeline.PrettyPrint then
        logger:warn(string.format("\"%s\" cannot be used with PrettyPrint, ignoring \"%s\"", self.Name, self.Name));
        return ast;
    end

    local code = "do local valid = true;";
    
    -- Original debug-based checks
    if self.UseDebug then
        local string = RandomStrings.randomString();
        code = code .. [[
            -- Anti Beautify
            local sethook = debug and debug.sethook or function() end;
            local allowedLine = nil;
            local called = 0;
            sethook(function(s, line)
                if not line then return end
                called = called + 1;
                if allowedLine then
                    if allowedLine ~= line then sethook(error, "l", 5); end
                else
                    allowedLine = line;
                end
            end, "l", 5);
            (function() end)();
            (function() end)();
            sethook();
            if called < 2 then valid = false; end
            
            -- Anti Function Hook
            local funcs = {pcall, string.char, debug.getinfo, string.dump}
            for i = 1, #funcs do
                if debug.getinfo(funcs[i]).what ~= "C" then valid = false; end
                if debug.getlocal(funcs[i], 1) then valid = false; end
                if debug.getupvalue(funcs[i], 1) then valid = false; end
                if pcall(string.dump, funcs[i]) then valid = false; end
            end
            
            -- Anti Beautify
            local function getTraceback()
                local str = (function(arg) return debug.traceback(arg) end)("]] .. string .. [[");
                return str;
            end
            local traceback = getTraceback();
            valid = valid and traceback:sub(1, traceback:find("\n") - 1) == "]] .. string .. [[";
            local iter = traceback:gmatch(":(%d*):");
            local v, c = iter(), 1;
            for i in iter do
                valid = valid and i == v;
                c = c + 1;
            end
            valid = valid and c >= 2;
        ]]
    end

    -- New environment integrity checks
    if self.UseEnvironmentCheck then
        code = code .. [[
            -- Environment integrity check
            local envCheck = {
                _G = _G,
                string = string,
                math = math,
                table = table,
                debug = debug
            };
            for k, v in pairs(envCheck) do
                if _G[k] ~= v then valid = false; end
            end
            
            -- Global table protection
            local mt = getmetatable(_G);
            if mt and (mt.__newindex or mt.__index) then valid = false; end
        ]]
    end

    -- New constant modification detection
    if self.UseConstantCheck then
        code = code .. [[
            -- Constant modification detection
            local constants = {
                pi = math.pi,
                huge = math.huge
            };
            local function checkConstants()
                return math.pi == constants.pi and math.huge == constants.huge;
            end
            valid = valid and checkConstants();
        ]]
    end

    -- Enhanced main validation logic with more obfuscation
    code = code .. [[
        local gmatch = string.gmatch;
        local err = function() error("Tamper Detected!") end;
        local pcallIntact2 = false;
        local pcallIntact = pcall(function() pcallIntact2 = true; end) and pcallIntact2;
        local random = math.random;
        local tblconcat = table.concat;
        local unpkg = table and table.unpack or unpack;
        
        -- More complex validation with multiple checks
        local n = random(5, 100);  -- Increased range
        local acc1 = 0;
        local acc2 = 0;
        local acc3 = 0;  -- Third accumulator for complexity
        local pcallRet = {pcall(function()
            local a = ]] .. tostring(math.random(1, 2^1^)) .. [[ - "]] .. RandomStrings.randomString() .. [[" ^^ ]] .. tostring(math.random(1, 2^1^)) .. [[
            return "]] .. RandomStrings.randomString() .. [[" / a;
        end)};
        local origMsg = pcallRet[2];
        local line = tonumber(gmatch(tostring(origMsg), ':(%d*):')());
        
        -- Additional timing-based check
        local startTime = os and os.clock or function() return 0 end;
        local start = startTime();
        
        for i = 1, n do
            local len = math.random(1, 100);
            local n2 = random(0, 255);
            local pos = random(1, len);
            local shouldErr = random(1, 2) == 1;
            local msg = origMsg:gsub(':(%d*):', ':' .. tostring(random(0, 10000)) .. ':');
            
            local arr = {pcall(function()
                if random(1, 2) == 1 or i == n then
                    local line2 = tonumber(gmatch(tostring(({pcall(function()
                        local a = ]] .. tostring(math.random(1, 2^1^)) .. [[ - "]] .. RandomStrings.randomString() .. [[" ^^ ]] .. tostring(math.random(1, 2^1^)) .. [[
                        return "]] .. RandomStrings.randomString() .. [[" / a;
                    end)})[2]), ':(%d*):')());
                    valid = valid and line == line2;
                end
                if shouldErr then error(msg, 0); end
                local arr = {};
                for i = 1, len do arr[i] = random(0, 255); end
                arr[pos] = n2;
                return unpkg(arr);
            end)};
            
            if shouldErr then
                valid = valid and arr[1] == false and arr[2] == msg;
            else
                valid = valid and arr[1];
                acc1 = (acc1 + arr[pos + 1]) % 256;
                acc2 = (acc2 + n2) % 256;
                acc3 = (acc3 + (arr[pos + 1] - n2)) % 256;  -- New accumulator
            end
        end
        
        -- Timing check
        local elapsed = startTime() - start;
        valid = valid and (elapsed < 1.0);  -- Adjust threshold as needed
        
        valid = valid and acc1 == acc2 and acc3 == 0;  -- Additional condition
        
        -- More complex failure response
        if not valid then
            -- Multi-layer failure response
            local function failure()
                local function inner()
                    while true do
                        err();
                    end
                end
                pcall(inner);
                repeat until false;
            end
            pcall(failure);
            return;
        end
        
        -- Anti Function Arg Hook
        local obj = setmetatable({}, { __tostring = err, });
        obj[math.random(1, 100)] = obj;
        (function() end)(obj);
        
        -- Final validation with more checks
        repeat until valid and (acc1 + acc2 + acc3) % 2 == 0;
    ]]

    local parsed = Parser:new({LuaVersion = Enums.LuaVersion.Lua51}):parse(code);
    local doStat = parsed.body.statements[1];
    doStat.body.scope:setParent(ast.body.scope);
    table.insert(ast.body.statements, 1, doStat);
    return ast;
end

return AntiTamper;
