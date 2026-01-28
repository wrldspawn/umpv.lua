local uv = require("uv")
local ffi = require("ffi")
local isWindows = ffi.os == "Windows"

local function split(str, sep)
	local ret = {}
	local pos = 1

	for i = 1, string.len(str) do
		local s, e = string.find(str, sep, pos)
		if not s then break end

		ret[i] = string.sub(str, pos, s - 1)
		pos = e + 1
	end

	ret[#ret + 1] = string.sub(str, pos)

	return ret
end

local sockPath
local configDir = os.getenv("MPV_HOME")
if isWindows then
	sockPath = "\\\\.\\pipe\\umpv"

	-- scan for mpv in path and check for portable_config
	if configDir == nil then
		for _, path in ipairs(split(os.getenv("PATH"), ";")) do
			local f = uv.fs_stat(path .. "/mpv.exe")
			if f ~= nil then
				local f2 = uv.fs_stat(path .. "/portable_config/umpv.conf")
				if f2 ~= nil then
					configDir = path .. "/portable_config"
					break
				end
			end
		end
	end

	-- check global
	if configDir == nil then
		local path = os.getenv("APPDATA") .. "/mpv"
		local f = uv.fs_stat(path .. "/umpv.conf")
		if f ~= nil then
			configDir = path
		end
	end
else
	local sockDir = os.getenv("UMPV_SOCKET_DIR") or os.getenv("XDG_RUNTIME_DIR") or os.getenv("HOME") or
			os.getenv("TMPDIR")
	if sockDir == nil then
		print("Could not determine a base directory for the socket. " ..
			"Ensure that one of the following environment variables is set: " ..
			"UMPV_SOCKET_DIR, XDG_RUNTIME_DIR, HOME or TMPDIR.")
		os.exit(1)
		return
	end

	sockPath = sockDir .. "/.umpv"

	-- check global
	if configDir == nil then
		local confDir = os.getenv("XDG_CONFIG_DIR")
		if confDir == nil then
			confDir = os.getenv("HOME") .. "/.config"
		end
		local path = confDir .. "/mpv"
		local f = uv.fs_stat(path .. "/umpv.conf")
		if f ~= nil then
			configDir = path
		end
	end
end

-- check next to exe
if configDir == nil then
	local path = uv.cwd()
	local f = uv.fs_stat(path .. "/umpv.conf")
	if f ~= nil then
		configDir = path
	end
end

local sock = uv.new_pipe(false)
local function canSend()
	local stat = uv.fs_stat(sockPath)

	return stat ~= nil
end

local function send(data)
	sock:connect(sockPath, function(err)
		assert(not err, err)

		if type(data) == "table" then
			for _, d in pairs(data) do
				sock:write(d .. "\n")
			end
		else
			sock:write(data .. "\n")
		end
		sock:close()
	end)
end

local function sanitize(str)
	return str:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n")
end

local loadFlag = "append-play"
local function formatFile(path, args)
	local msg = string.format('raw loadfile "%s" %s', sanitize(path), loadFlag)
	if #args > 0 then
		msg = msg .. string.format(' 0 "%s"', sanitize(table.concat(args, ",")))
	end

	return msg
end

local function sendFile(path, args)
	for i, v in ipairs(args) do
		args[i] = v:sub(3)
	end

	if type(path) == "table" then
		local commands = {}
		for _, p in ipairs(path) do
			commands[#commands + 1] = formatFile(p, args)
		end
		send(commands)
	else
		send(formatFile(path, args))
	end
end

local function merge(...)
	local tbl = {}
	for _, t in ipairs({...}) do
		if type(t) == "table" then
			for _, v in ipairs(t) do
				tbl[#tbl + 1] = v
			end
		else
			tbl[#tbl + 1] = t
		end
	end

	return tbl
end

local mpvArgs = {}
local keepProcess = false
local function start(files)
	local exe = os.getenv("MPV") or "mpv"
	mpvArgs[#mpvArgs + 1] = "--input-ipc-server=" .. sockPath
	mpvArgs[#mpvArgs + 1] = "--"

	if keepProcess then
		os.execute(table.concat(merge(exe, mpvArgs, files), " "))
	else
		uv.spawn(exe, {
			args = merge(mpvArgs, files),
			verbatim = true,
			detached = true,
			hide = true
		})
	end
end

local validLoadFlags = {
	replace = true,
	append = true,
	["append-play"] = true,
	["insert-next"] = true,
	["insert-next-play"] = true,
}

local parseLocalArg = function(arg, isConfig) end
local argSwitch = {
	["ipc-server"] = function(v)
		sockPath = v
	end,
	["loadfile-flag"] = function(v)
		if validLoadFlags[v] then
			loadFlag = v
		end
	end,
	["config"] = function(v)
		for line in io.lines(v) do
			if line:match("^#") then goto continue end
			parseLocalArg(line, true)

			::continue::
		end
	end,
	["keep-process"] = function(v)
		keepProcess = v == "yes"
	end,
}
parseLocalArg = function(arg, isConfig)
	local eq = split(arg, "=")
	local k, v = eq[1], eq[2]
	if isConfig == true and k == "config" then return end

	local cb = argSwitch[k]

	if cb then
		pcall(cb, v)
	end
end

if configDir ~= nil then
	pcall(argSwitch.config, configDir .. "/umpv.conf")
end

local argsLocal = true
local hasFlags = table.concat(args, " "):find("%-%-") ~= nil
local paths = {}
for _, arg in ipairs(args) do
	if hasFlags then
		if arg:match("^%-%-") then
			if arg == "--" then
				argsLocal = false
			elseif argsLocal then
				parseLocalArg(arg:sub(3), false)
			else
				mpvArgs[#mpvArgs + 1] = arg
			end
		else
			paths[#paths + 1] = arg
		end
	else
		paths[#paths + 1] = arg
	end
end

local hasSocket = canSend()
if hasSocket then
	pcall(sendFile, paths, mpvArgs)
	if keepProcess then
		-- NB: process exits if nothing is sent to stdout whyyyyyyy
		print("")
		uv.new_idle():start(function()
			if not canSend() then
				os.exit(0)
			else
				uv.sleep(1000)
			end
		end)
	end
	uv.run()
else
	pcall(start, paths)
end
