-- @inject
local url = ""
-- @end_inject

-- spoof a ts object
-- url will be filled in by a development server

local HttpService = game:GetService("HttpService")
local ts = {}
ts.Promise = loadstring(
	HttpService:GetAsync("https://raw.githubusercontent.com/evaera/roblox-lua-promise/master/lib/init.lua")
)()
local proxy = setmetatable({}, {
	__index = function(self, i)
		if i == script then
			-- return the ts object
			return ts
		else
			-- we still DO NOT want this proxy object to be near _G
			return rawget(self, i)
		end
	end,
	__newindex = function(self, ...)
		return rawset(self, ...)
	end,
	__metatable = "This metatable is locked (_G spoofing)",
})
local patched = setmetatable({
	["_G"] = proxy,
}, {
	__index = getfenv(0),
})

type Module = {
	compiledFunction: (...any) -> (...any), -- this is what loadstring should return (2nd arg ret)
	moduleName: string,
}

local function errorf(s, ...)
	return error(string.format(s, ...))
end

local function safeCompile(code: string, path: string?)
	local err, compiled = loadstring(code)
	if compiled then
		setfenv(compiled, patched)
	end
	return err, patched
end

local function createModule(code: string, moduleName: string): Module
	local err, compiled = safeCompile(code)
	if err then
		errorf(
			"[ts] Module (%s) failed compilation. Below is the stacktrace, and then the error.\n%s\n%s",
			moduleName,
			debug.traceback(),
			err
		)
	end
	return {
		compiledFunction = compiled,
		moduleName = moduleName,
		__type = "Module",
	}
end

local function get(m: string)
	return HttpService:GetAsync(url .. m)
end

local function checkIsModule(v: any): boolean
	if type(v) == "table" and v.__type == "Module" then
		return true
	end
	return false
end

-- example: TS.getModule(script, "@rbxts", "services")

function ts.getModule(caller: Script, scope: string, moduleName: string)
	local code = get("npm/" .. scope .. "/" .. moduleName)
	local mod = createModule(code, scope .. "/" .. moduleName)
	return mod
end

function ts.import(caller: Script, m: Script | Module, moduleName: string?)
	local module: Module = checkIsModule() and m
	-- todo: implement module loader
	if not module then
		-- m is useless
		local code = get(moduleName)
		local mod = createModule(code)
		return mod.compiledFunction()
	else
		-- Why!!!!!!!!!!!!!
		return (m :: Module).compiledFunction()
	end
end
