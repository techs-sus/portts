-- port of RuntimeLib.lua
local HttpService = game:GetService("HttpService")

-- @inject
local url = "https://77d88618-ddca-4997-99fc-c06b26209d17.loca.lt"
-- @end_inject

local queue = {}
local TS = {}
local Promise = loadstring(HttpService:GetAsync("promise"))() -- eryn's promise library
local ts_caller = 0

local function load(file: string)
	local code = HttpService:GetAsync(string.format("%s/%s", url, file))
	local loaded = loadstring(code)
	ts_caller += 1
	setfenv(
		loaded,
		setmetatable({ ts_caller = ts_caller }, {
			__index = getfenv(0),
		})
	)
	return loaded
end

-- TS.Promise filler
TS.Promise = Promise

-- Implement TS::getModule and TS::import
function TS.getModule(caller: Script, ...)
	local args = { ... }
	local path = table.concat(args, "/")
	local loaded = load(path)
	return {
		path = path,
		loaded = loaded,
	}
end

type TSModule = {
	path: string,
	loaded: (...any) -> (...any),
}

function TS.import(_, module: Script | TSModule, moduleName: string)
	if module == script then
		return load("out/" .. moduleName)()
	end
	if not moduleName and typeof(module) == "table" and module.path ~= nil then
		-- its a TSModule
		local constructed = {}
		local ptr = constructed
		local pkg_json = HttpService:JSONDecode(HttpService:GetAsync(url .. module.path .. "/package.json"))
		local main: string = pkg_json.main
		local value = module.loaded()
		if string.find(main, "/") == nil then
			return value
		else
			local split = string.split(main, "/")
			for i = 1, #split do
				local v = string.match(split[i], "%a+")
				ptr[v] = {}
				if i == #split then
					ptr[v] = value
					break
				end
				ptr = ptr[v]
			end
			return constructed
		end
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
