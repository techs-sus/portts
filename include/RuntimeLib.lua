-- URL injection

-- @inject
local url = "https://01a444de-87cf-4097-abf6-bac31f82182a.loca.lt"
-- @end_inject

local HttpService = game:GetService("HttpService")
local ts = {}
ts.Promise = loadstring(
	HttpService:GetAsync("https://raw.githubusercontent.com/evaera/roblox-lua-promise/master/lib/init.lua")
)()
local Promise = ts.Promise
local proxy = setmetatable({
	_UNSAFE_G = _G, -- incase it does want unsafe _G
}, {
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
-- compiles {code} and executes setfenv() on the returned function
local function safeCompile(code: string, moduleName: string?, path: string?)
	local compiled, err = loadstring(code)
	if compiled then
		patched.path = path
		setfenv(compiled, patched)
	end
	if err then
		errorf(
			"[ts] %s (%s) failed compilation. Below is the stacktrace, and then the error.\n%s\n%s",
			moduleName ~= nil and "Module" or "Code",
			moduleName,
			debug.traceback(),
			err
		)
	end

	return compiled
end

local function createModule(code: string, moduleName: string, ...): Module
	local compiled = safeCompile(code, moduleName, ...)
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

type Package = {
	main: string,
}

-- example: TS.getModule(script, "@rbxts", "services")

function ts.getModule(caller: Script, scope: string, moduleName: string)
	local modulePath = string.format("/npm/%s/%s", scope, moduleName)
	-- local mod = createModule(code, scope .. "/" .. moduleName)
	-- Fetch the package.json and do the really funny hack
	local package: Package = HttpService:JSONDecode(get(modulePath .. "/package.json"))
	local main: string = get(modulePath .. "/" .. package.main)
	local module: Module = createModule(main, scope .. "/" .. moduleName, main)
	local split = string.split(package.main, "/")
	local spoofedTable = {}
	local ptr = spoofedTable
	for i = 1, #split do
		local v = string.match(split[i], "%a+")
		ptr[v] = {}
		if i == #split then
			ptr[v] = module
			break
		else
			ptr = ptr[v]
		end
	end
	ptr = module
	return spoofedTable
end

function ts.import(caller: Script, m: Script | Module, ...)
	local module: boolean = checkIsModule(m)
	-- todo: implement module loader
	if not module then
		-- m is useless
		local moduleName = table.concat({ ... }, "/")
		local code = get("/src/" .. moduleName .. ".lua")
		local mod = createModule(code, moduleName, "")
		return mod.compiledFunction()
	else
		-- This should work as it would access .lib.ts then .t
		return (m :: Module).compiledFunction()
	end
end

function ts.instanceof(obj: any, class: any)
	if type(class) == "table" and type(class.instanceof) == "function" then
		return class.instanceof(obj)
	end

	if type(obj) == "table" then
		obj = getmetatable(obj)
		while obj ~= nil do
			if obj == class then
				return true
			end
			local mt = getmetatable(obj)
			if mt then
				obj = mt.__index
			else
				obj = nil
			end
		end
	end

	return false
end

function ts.generator(callback: (...any) -> (...any))
	local generator = coroutine.create(callback)
	return {
		next = function(...)
			if coroutine.status(generator) == "dead" then
				return { done = true }
			else
				local success, value = coroutine.resume(generator, ...)
				if success == false then
					error(value, 2)
				end
				return {
					value = value,
					done = coroutine.status(generator) == "dead",
				}
			end
		end,
	}
end

function ts.async(callback)
	return function(...)
		local n = select("#", ...)
		local args = { ... }
		return Promise.new(function(resolve, reject)
			coroutine.wrap(function()
				local alive, result = pcall(callback, unpack(args, 1, n))
				if alive then
					resolve(result)
				else
					reject(result)
				end
			end)()
		end)
	end
end

function ts.await(promise)
	if not Promise.is(promise) then
		return promise
	end

	local status, value = promise:awaitStatus()
	if status == Promise.Status.Resolved then
		return value
	elseif status == Promise.Status.Rejected then
		return error(value, 2)
	else
		error("[ts-runtime] The awaited promise was cancelled", 2)
	end
end

function ts.bit_lrsh(a, b)
	local absA = math.abs(a)
	local result = bit32.rshift(absA, b)
	if a == absA then
		return result
	else
		return -result - 1
	end
end

function ts.try(func, catch, finally)
	local err, traceback
	local success, exitType, returns = xpcall(func, function(errInner)
		err = errInner
		traceback = debug.traceback()
	end)
	if not success and catch then
		local newExitType, newReturns = catch(err, traceback)
		if newExitType then
			exitType, returns = newExitType, newReturns
		end
	end
	if finally then
		local newExitType, newReturns = finally()
		if newExitType then
			exitType, returns = newExitType, newReturns
		end
	end
	return exitType, returns
end
local main = safeCompile(get("/src/init.lua"))
main()
