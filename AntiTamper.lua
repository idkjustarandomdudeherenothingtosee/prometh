-- This Script is Part of the Prometheus Obfuscator by narodi
-- AntiTamper.lua

local Step=require("prometheus.step")
local Ast=require("prometheus.ast")
local Scope=require("prometheus.scope")
local RandomStrings=require("prometheus.randomStrings")
local Parser=require("prometheus.parser")
local Enums=require("prometheus.enums")
local logger=require("logger")

local AntiTamper=Step:extend()
AntiTamper.Description="This Step Breaks your Script when it is modified. This is only effective when using the new VM."
AntiTamper.Name="Anti Tamper"

AntiTamper.SettingsDescriptor={
    UseDebug={type="boolean",default=true},
    UseEnvironmentCheck={type="boolean",default=true},
    UseConstantCheck={type="boolean",default=true},
    UseAntiDump={type="boolean",default=true},
    UseDeepIntegrity={type="boolean",default=true},
    UseInstructionPoison={type="boolean",default=true},
    UseProtoFingerprint={type="boolean",default=true},
    UseMetatablePoison={type="boolean",default=true},
    UseStackPoison={type="boolean",default=true},
    UseBytecodeCheck={type="boolean",default=true},
    UseRegShadow={type="boolean",default=true},
    UseContextTrap={type="boolean",default=true},
    UseDynamicConstantMap={type="boolean",default=true},
    UseVMDrift={type="boolean",default=true},
    UseRuntimeConfusion={type="boolean",default=true},
    UseOpcodePulse={type="boolean",default=true},
    UseTimePenalties={type="boolean",default=true},
    UseThreadPoison={type="boolean",default=true},
    UseSelfHash={type="boolean",default=true},
    UseClosureOriginCheck={type="boolean",default=true}
}

function AntiTamper:init(s)
    for k,v in pairs(self.SettingsDescriptor) do
        self[k]=s[k]~=false
    end
end

function AntiTamper:apply(ast,pipeline)
    if pipeline.PrettyPrint then
        logger:warn(string.format("\"%s\" cannot be used with PrettyPrint, ignoring \"%s\"",self.Name,self.Name))
        return ast
    end

    local code="do local valid=true local function bx() error(\"Tamper Detected\") end"

    code=code..[[
        math.randomseed(tostring({}):byte(1,1)*os.time())
        local dbg=debug
    ]]

    if self.UseSelfHash then
        code=code..[[
            local function h(s)
                local v=0
                for i=1,#s do v=(v*257+s:byte(i))%2^32 end
                return v
            end
            local sh=h(tostring(_G)..tostring(debug)..tostring(string)..tostring(math)..tostring(table))
        ]]
    end

    if self.UseClosureOriginCheck then
        code=code..[[
            local function oc(f)
                local i=dbg.getinfo(f)
                if not i then return false end
                return i.what=="Lua" or i.what=="C"
            end
            valid=valid and oc(function() end)
        ]]
    end

    if self.UseVMDrift then
        code=code..[[
            local a=0
            for i=1,5000 do
                local r=i*3%255
                a=a+r
            end
            if a%5~=0 then valid=false end
        ]]
    end

    if self.UseInstructionPoison then
        code=code..[[
            local function ip()
                local x={}
                for i=1,60000 do x[i]=i*11%255 end
                return x[math.random(1,60000)]~=x[math.random(1,60000)]
            end
            valid=valid and ip()
        ]]
    end

    if self.UseOpcodePulse then
        code=code..[[
            local function op()
                local r=0
                for i=1,20000 do r=(r+i*7)%255 end
                return r%2==0
            end
            valid=valid and op()
        ]]
    end

    if self.UseBytecodeCheck then
        code=code..[[
            local function bc()
                local f=function(x) return x+1 end
                local i=dbg.getinfo(f)
                if not i or i.what~="Lua" then return false end
                return true
            end
            valid=valid and bc()
        ]]
    end

    if self.UseDynamicConstantMap then
        code=code..[[
            local m={a=math.random(1,9999999),b=math.random(1,9999999)}
            local function mv()
                return m.a+m.b==(m.a+m.b)
            end
            valid=valid and mv()
        ]]
    end

    if self.UseRegShadow then
        code=code..[[
            local function rs(a,b,c)
                local r=a+b+c
                local x,y,z=a,b,c
                if r~=(x+y+z) then return false end
                return true
            end
            valid=valid and rs(7,11,19)
        ]]
    end

    if self.UseThreadPoison then
        code=code..[[
            local co=coroutine.create(function() return 1 end)
            if coroutine.status(co)~="suspended" then valid=false end
        ]]
    end

    if self.UseContextTrap then
        code=code..[[
            local function ctx()
                local i=dbg.getinfo(1)
                if not i or not i.currentline then return false end
                return true
            end
            valid=valid and ctx()
        ]]
    end

    if self.UseEnvironmentCheck then
        code=code..[[
            if _G._G~=_G then valid=false end
            local mt=getmetatable(_G)
            if mt and(mt.__index or mt.__newindex) then valid=false end
        ]]
    end

    if self.UseMetatablePoison then
        code=code..[[
            local p=setmetatable({},{__index=function() valid=false end,__newindex=function() valid=false end})
            local o=setmetatable({},p)
            valid=valid and pcall(function() return o.x end)==false
        ]]
    end

    if self.UseConstantCheck then
        code=code..[[
            if math.pi~=3.141592653589793 or math.huge~=math.huge then valid=false end
        ]]
    end

    if self.UseAntiDump then
        code=code..[[
            dbg.getinfo=function() valid=false return {what="C"} end
            dbg.getupvalue=function() valid=false return nil end
            string.dump=function() valid=false return "" end
            getgc=function() valid=false return {} end
        ]]
    end

    if self.UseStackPoison then
        code=code..[[
            local function sp(a,b,c)
                local i=dbg.getinfo(1,"l")
                if not i or not i.currentline then valid=false end
                return a+b+c
            end
            valid=valid and sp(1,2,3)==6
        ]]
    end

    if self.UseRuntimeConfusion then
        code=code..[[
            local function rc()
                local n=0
                for i=1,15000 do n=(n+i)%255 end
                return n%3==0
            end
            valid=valid and rc()
        ]]
    end

    if self.UseSelfHash then
        code=code..[[
            local function reh()
                local c=h(tostring(_G)..tostring(debug)..tostring(string)..tostring(math)..tostring(table))
                return c==sh
            end
            valid=valid and reh()
        ]]
    end

    if self.UseTimePenalties then
        code=code..[[
            local t=os.clock()
            local x=0
            for i=1,20000 do x=x+i end
            if os.clock()-t>1 then valid=false end
        ]]
    end

    code=code..[[
        if not valid then
            local function fail()
                while true do bx() end
            end
            pcall(fail)
            repeat until false
        end
    ]]

    local parsed=Parser:new({LuaVersion=Enums.LuaVersion.Lua51}):parse(code)
    local doStat=parsed.body.statements[1]
    doStat.body.scope:setParent(ast.body.scope)
    table.insert(ast.body.statements,1,doStat)
    return ast
end

return AntiTamper
