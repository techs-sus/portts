-- port of RuntimeLib.lua
local HttpService = game:GetService("HttpService")

-- @inject
local url = "https://2e9cd360-1e55-4d0b-ac38-74184d2a8726.loca.lt"
-- @end_inject

local TS = {}
local Promise = loadstring(
	HttpService:GetAsync("https://raw.githubusercontent.com/evaera/roblox-lua-promise/master/lib/init.lua")
)() -- eryn's promise library
local binder = loadstring(
	HttpService:GetAsync("https://raw.githubusercontent.com/techs-sus/void-utils/main/src/server/binder.lua")
)()
local ts_caller = 0
local ts_path

local function load(file: string, _ts_path)
	local code = HttpService:GetAsync(string.format("%s/%s", url, file))
	local loaded = loadstring(code)
	ts_caller += 1
	ts_path = _ts_path
	setfenv(
		loaded,
		setmetatable({ _G = {
			[script] = TS,
		}, ts_caller = ts_caller, ts_path = file }, {
			__index = getfenv(0),
		})
	)
	return loaded
end

-- TS.Promise filler
TS.Promise = Promise

-- Implement TS::getModule and TS::import
function TS.getModule(caller: Script, ...): TSModule
	local args = { ... }
	local path = table.concat(args, "/")
	local pkg_json = HttpService:JSONDecode(
		HttpService:GetAsync(string.format("%s/node_modules/%s/package.json", url, path))
	)
	local _fix = string.split(pkg_json.main, "/")
	_fix[#_fix] = nil
	local loaded = load(
		string.format("node_modules/%s/%s", path, pkg_json.main),
		string.format("node_modules/%s/%s", path, table.concat(_fix, "/"))
	)
	local returned = {
		pkg_json = pkg_json,
		path = "node_modules/" .. path,
		loaded = loaded,
	}
	print("ts::getModule", path)
	local split = string.split(pkg_json.main, "/")
	if string.find(pkg_json.main, "/") ~= nil then
		local _ptr = {}
		local ptr = _ptr
		-- funny way to make a tree
		for i = 1, #split do
			local v = string.match(split[i], "%a+")
			ptr[v] = {}
			if i == #split then
				ptr[v] = returned
				break
			else
				ptr = ptr[v]
			end
		end

		return _ptr
	else
		return returned
	end
end

type TSModule = {
	path: string,
	pkg_json: any,
	loaded: (...any) -> (...any),
}

local function validateFilePath(path: string)
	local h = HttpService:RequestAsync({
		Url = url .. "/validate_fs",
		Method = "POST",
		Body = HttpService:JSONEncode({ path = path }),
		Headers = {
			["Content-Type"] = "application/json",
		},
	})
	return h.Body == "1"
end

function TS.import(_, module: Script | TSModule, moduleName: string)
	local calling_env = getfenv(1)
	print("ts::import", moduleName or (module and module.path))

	if calling_env.ts_caller then
		print(calling_env.ts_caller)
	end
	if module == script then
		if ts_path ~= nil then
			local whatToLoad = ts_path .. "/" .. moduleName
			local good = validateFilePath(whatToLoad .. ".lua")
			print(good, whatToLoad .. ".lua")
			if good then
				return load(whatToLoad .. ".lua")()
			else
				return load(whatToLoad .. "/init.lua", whatToLoad)()
			end
		end
		local good = validateFilePath("out/" .. moduleName .. ".lua")
		if good then
			return load("out/" .. moduleName .. ".lua")()
		else
			return load("out/" .. moduleName .. "/init.lua")()
		end
	end
	if typeof(module) == "table" then
		-- its a TSModule
		return module.loaded()
	end
end

-- Lets implement TS::async
function TS.async(f: (...any) -> (...any))
	return function(...)
		local args = { ... }
		return Promise.new(function(r, rj)
			task.spawn(function()
				local ok, result = pcall(f, table.unpack(args))
				local b = ok and r(result) or rj(result)
			end)
		end)
	end
end

-- Implement TS::await
function TS.await(promise: Promise)
	if not Promise.is(promise) then
		return promise
	end

	local status, value = promise:awaitStatus()
	if status == Promise.Status.Resolved then
		return value
	elseif status == Promise.Status.Rejected then
		error(value, 2)
	else
		error("The awaited Promise was cancelled", 2)
	end
end

function TS.bit_lrsh(a, b)
	local absA = math.abs(a)
	local result = bit32.rshift(absA, b)
	if a == absA then
		return result
	else
		return -result - 1
	end
end

function TS.try(func, catch, finally)
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

-- Generator support

function TS.generator(f)
	local co = coroutine.create(f)
	return {
		next = function(...)
			if coroutine.status(co) == "dead" then
				return { done = true }
			else
				local success, value = coroutine.resume(co, ...)
				if success == false then
					-- The error will be value
					error(value, 2)
				end
				return {
					value = value,
					done = coroutine.status(co) == "dead",
				}
			end
		end,
	}
end

-- Execute program
local _b = binder.new()
_b:bindKey(owner, Enum.KeyCode.R).keyEvents.onKeyDown:Connect(function()
	load("out/init.lua")()
end)
