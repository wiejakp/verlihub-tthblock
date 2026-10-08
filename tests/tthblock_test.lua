-- Offline callbacks: no real hub, filesystem writes, sockets, SQL or downloads.
local unpack_values = table.unpack or unpack
local tth = string.rep ("A", 39)
local other = string.rep ("B", 39)
local separator = string.char (5)
local passed = 0

local function expect (condition, message)
	assert (condition, message or "expectation failed")
end

local function contains (text, part)
	return text and text:find (part, 1, true) ~= nil
end

local function newhub (options)
	options = options or {}
	local state = {
		db = options.db or {settings = {}, logs = {}}, cursor = {}, affected = 0,
		messages = {}, feeds = {}, events = {}, kicks = {}, queries = {},
		classes = {guest = 0, registered = 1, operator = 3, admin = 5, master = 10},
		cache = {tth}, packets = {}, now = 1700000000, downloads = 0, removed = 0
	}
	local hub = {HubSec = "Hub-Security", OpChat = "OpChat", ConfName = "config"}
	function hub:SQLQuery (sql)
		state.queries [# state.queries + 1] = sql
		state.cursor = {}
		if state.fail and contains (sql, state.fail) then
			state.affected = -1
			return true, 0 -- Verlihub can report success even when MySQL rejects a query.
		end
		if sql == "select row_count()" then
			state.cursor = {{state.affected}}
		elseif contains (sql, "create table") then
			state.affected = 0
		elseif contains (sql, "from `lua_ledo_conf`") then
			for name, value in pairs (options.ledokol or {}) do
				state.cursor [# state.cursor + 1] = {name, value}
			end
		elseif contains (sql, "select `variable`, `value`") then
			for name, value in pairs (state.db.settings) do
				state.cursor [# state.cursor + 1] = {name, value}
			end
		elseif contains (sql, "into `lua_tthblock_settings`") then
			local name, value = sql:match ("values %('([^']+)', (%d+)%)")
			expect (name and value, "malformed setting SQL")
			state.db.settings [name] = tonumber (value)
			state.affected = 1
		elseif contains (sql, "into `lua_tthblock_logs`") then
			local created, hex = sql:match ("values %((%d+), X'([A-F0-9]*)'%)")
			expect (created and hex, "malformed log SQL")
			local message = hex:gsub ("..", function (pair)
				return string.char (tonumber (pair, 16))
			end)
			local last = state.db.logs [# state.db.logs]
			local id = last and last [1] + 1 or 1
			state.db.logs [# state.db.logs + 1] = {id, tonumber (created), message}
			state.affected = 1
		elseif contains (sql, "select count(*)") then
			state.cursor = {{# state.db.logs}}
		elseif contains (sql, "delete from `lua_tthblock_logs`") then
			local count = tonumber (sql:match ("limit (%d+)$"))
			state.affected = math.min (count, # state.db.logs)
			for _ = 1, state.affected do table.remove (state.db.logs, 1) end
		elseif contains (sql, "select `id`, `created_at`, `message`") then
			local count = tonumber (sql:match ("limit (%d+)$"))
			for i = # state.db.logs, math.max (1, # state.db.logs - count + 1), -1 do
				state.cursor [# state.cursor + 1] = state.db.logs [i]
			end
		else
			error ("unexpected SQL: " .. sql)
		end
		return true, # state.cursor
	end
	function hub:SQLFetch (index)
		local row = state.cursor [index + 1]
		if not row then return false end
		return true, unpack_values (row)
	end
	function hub:GetConfig (_, name)
		return true, name == "hub_version" and "1.6.0.0" or "1"
	end
	function hub:GetUserClass (nick) return true, state.classes [nick] or -1 end
	function hub:GetUserIP () return true, "192.0.2.10" end
	function hub:GetUserCC () return true, "ZZ" end
	function hub:GetVHCfgDir () return true, "/offline/hub" end
	function hub:SendToUser (message, nick)
		state.messages [# state.messages + 1] = {text = message, nick = nick}
		return true
	end
	function hub:SendPMToAll (message, from, minimum, maximum)
		state.feeds [# state.feeds + 1] = {message, from, minimum, maximum}
		return true
	end
	function hub:SendToClass () return true end
	function hub:ScriptCommand (name, data)
		state.events [# state.events + 1] = {name, data}
		return true
	end
	function hub:KickUser (from, nick, reason)
		state.kicks [# state.kicks + 1] = {from, nick, reason}
		return true
	end
	local udp = {}
	function udp:settimeout () end
	function udp:setsockname () return true end
	function udp:close () state.closed = true end
	function udp:receivefrom ()
		local packet = table.remove (state.packets, 1)
		if packet then return unpack_values (packet) end
		return nil, "timeout"
	end
	local env = setmetatable ({VH = hub}, {__index = _G})
	env.os = setmetatable ({
		time = function () return state.now end,
		execute = function () state.downloads = state.downloads + 1; return 0 end,
		remove = function () state.removed = state.removed + 1; return true end
	}, {__index = os})
	env.io = {
		open = function ()
			if state.cache then return {close = function () end} end
		end,
		lines = function ()
			local index = 0
			return function () index = index + 1; return state.cache [index] end
		end
	}
	env.print = function () end
	env.require = function (name)
		expect (name == "socket", "unexpected module")
		if options.no_socket then error ("LuaSocket unavailable") end
		return {_VERSION = "offline", udp = function () return udp end, sleep = function () end}
	end
	local chunk, err
	if setfenv then
		chunk, err = loadfile ("tthblock.lua")
		if chunk then setfenv (chunk, env) end
	else
		chunk, err = loadfile ("tthblock.lua", "t", env)
	end
	expect (chunk, err)
	chunk ()
	state.fail = options.fail
	expect (env.Main ("tthblock.lua") == 1, "Main must allow hub processing")
	env.conf.secs = math.huge
	return env, state
end

local function command (env, nick, text)
	return env.VH_OnHubCommand (nick, text, 0, 0)
end

local function lastmessage (state)
	return state.messages [# state.messages].text
end

local function search (env, nick, hash)
	return env.VH_OnParsedMsgSearch (nick, "$Search Hub:" .. nick .. " F?F?0?9?TTH:" .. hash)
end

local function result (nick, hash, passive)
	return "$SR " .. nick .. " file.bin" .. separator .. "1234 1/1" .. separator ..
		"TTH:" .. hash .. " (hub:411)" .. (passive and separator .. "master" or "|")
end

local function test (name, run)
	local ok, err = pcall (run)
	if not ok then error ("FAIL " .. name .. ": " .. tostring (err), 0) end
	passed = passed + 1
	print ("PASS " .. name)
end

test ("help follows command name and exposes permissions and export limits", function ()
	local env, state = newhub ()
	env.conf.comm = "hashguard"
	expect (command (env, "master", "+HASHGUARD HELP") == 0)
	local text = lastmessage (state)
	for _, part in ipairs ({"Rolex & PWiAM", "!hashguard class", "!hashguard logclass",
		"!hashguard logs", "1000", "10000", "Class 10", "4096", "30s"}) do
		expect (contains (text, part), "missing help information: " .. part)
	end
	expect (contains (text, "$To: master"), "help must be private")
	expect (command (env, "guest", "!hashguard help") == 0)
	expect (contains (lastmessage (state), "permission"))
	expect (command (env, "master", "!unrelated") == 1)
end)

test ("only masters change valid saved classes and values survive reload", function ()
	local env, state = newhub ()
	command (env, "admin", "!tthblock class 4")
	expect (env.conf.feed == 11 and state.db.settings.feed == 11)
	command (env, "master", "!tthblock class 4")
	command (env, "master", "!tthblock logclass 3")
	expect (env.conf.feed == 4 and env.conf.logclass == 3)
	command (env, "master", "!tthblock logclass 11")
	command (env, "master", "!tthblock class 4.5")
	expect (env.conf.logclass == 3 and env.conf.feed == 4)
	local reloaded = newhub ({db = state.db})
	expect (reloaded.conf.feed == 4 and reloaded.conf.logclass == 3)
end)

test ("automatic classes use Ledokol while its mute value falls back safely", function ()
	local env = newhub ({ledokol = {
		mincommandclass = 3, classnotisefi = 11, scanbelowclass = 3
	}})
	command (env, "master", "!tthblock class 0")
	command (env, "master", "!tthblock logclass 0")
	expect (env.conf.feed == 4 and env.conf.logclass == 3 and env.conf.skip == 2)
end)

test ("muted detections still block, record every hit and trigger Ledokol", function ()
	local env, state = newhub ()
	local before = # state.db.logs
	expect (search (env, "guest", tth) == 0)
	expect (search (env, "guest", tth) == 0)
	expect (# state.db.logs == before + 2 and # state.feeds == 0)
	expect (state.events [1][1] == "sefi_user_block")
	expect (state.events [1][2] == "0 guest " .. tth)
	expect (env.list [tth] == 3)
	expect (search (env, "operator", tth) == 1)
	expect (search (env, "guest", other) == 1)
end)

test ("notification throttling leaves the complete history and class bounds", function ()
	local env, state = newhub ()
	command (env, "master", "!tthblock class 4")
	local before = # state.db.logs
	search (env, "guest", tth)
	search (env, "guest", tth)
	expect (# state.db.logs == before + 2 and # state.feeds == 1)
	expect (state.feeds [1][3] == 4 and state.feeds [1][4] == 10)
end)

test ("passive results and verified UDP packets produce AVDB events", function ()
	local env, state = newhub ()
	expect (env.VH_OnParsedMsgSR ("guest", result ("guest", tth, true)) == 0)
	expect (state.events [1][1] == "avdb_user_detect")
	expect (state.events [1][2] == "guest 192.0.2.10 file.bin")
	state.packets = {{result ("guest", tth), "192.0.2.99", 20201}}
	env.VH_OnTimer (0)
	expect (# state.events == 1, "mismatched source IP must be ignored")
	state.packets = {{result ("guest", tth), "192.0.2.10", 20201}}
	env.VH_OnTimer (0)
	expect (# state.events == 2 and env.list [tth] == 3)
	expect (env.VH_OnParsedMsgSR ("guest", result ("guest", other, true)) == 1)
end)

test ("history is independent of command permission and works without UDP", function ()
	local env, state = newhub ({no_socket = true})
	command (env, "master", "!tthblock logclass 1")
	command (env, "registered", "!tthblock")
	expect (contains (lastmessage (state), "permission"))
	command (env, "registered", "!tthblock logs 2")
	expect (contains (lastmessage (state), "private batches"))
	env.VH_OnTimer (0)
	expect (contains (lastmessage (state), "newest first, UTC"))
	expect (contains (lastmessage (state), "$To: registered") and # state.feeds == 0)
end)

test ("demotions and logout cancel history already queued", function ()
	local env, state = newhub ()
	command (env, "master", "!tthblock logclass 3")
	command (env, "operator", "!tthblock logs")
	local count = # state.messages
	state.classes.operator = 1
	env.VH_OnTimer (0)
	expect (# state.messages == count)
	command (env, "admin", "!tthblock logs")
	count = # state.messages
	expect (env.VH_OnUserLogout ("admin", "192.0.2.10") == 1)
	env.VH_OnTimer (0)
	expect (# state.messages == count)
end)

test ("export count, reader cap, cooldown and batch size are bounded", function ()
	local env, state = newhub ()
	for i = 1, 30 do search (env, "guest", tth) end
	for _, count in ipairs ({"0", "1001", "-1", "2.5", "1 extra"}) do
		command (env, "master", "!tthblock logs " .. count)
		expect (contains (lastmessage (state), "Usage:"))
	end
	for i = 1, 5 do
		state.classes ["reader" .. i] = 5
		command (env, "reader" .. i, "!tthblock logs 30")
	end
	expect (contains (lastmessage (state), "busy"))
	env.VH_OnTimer (0)
	local text = lastmessage (state)
	local _, count = text:gsub ("\r\n#", "")
	expect (count == 20 and # text < 4096)
	state.now = state.now + 1
	env.VH_OnTimer (0)
	expect (contains (lastmessage (state), "End of history."))
	command (env, "reader1", "!tthblock logs")
	expect (contains (lastmessage (state), "Wait before"))
end)

test ("SQL errors never reopen settings or claim a failed setting was saved", function ()
	local env, state = newhub ({fail = "create table if not exists `lua_tthblock_settings`"})
	expect (env.conf.feed == 11 and env.conf.logclass == 10)
	expect (search (env, "guest", tth) == 0)
	command (env, "master", "!tthblock class 4")
	expect (env.conf.feed == 11 and contains (lastmessage (state), "unavailable"))
	local ready, db = newhub ()
	db.fail = "replace into"
	command (ready, "master", "!tthblock class 4")
	expect (ready.conf.feed == 11 and db.db.settings.feed == 11)
	expect (contains (lastmessage (db), "Failed to save"))
end)

test ("failed log storage keeps blocking and failed reads do not fake emptiness", function ()
	local env, state = newhub ({fail = "create table if not exists `lua_tthblock_logs`"})
	expect (search (env, "guest", tth) == 0)
	command (env, "master", "!tthblock logs")
	expect (contains (lastmessage (state), "unavailable"))
	local ready, db = newhub ()
	db.fail = "select `id`, `created_at`, `message`"
	command (ready, "master", "!tthblock logs")
	expect (contains (lastmessage (db), "Failed to read"))
end)

test ("retention deletes oldest entries and log text cannot inject NMDC frames", function ()
	local db = {settings = {}, logs = {}}
	for i = 1, 10002 do db.logs [i] = {i, 1700000000, "retained " .. i} end
	local env, state = newhub ({db = db})
	expect (# state.db.logs == 10000 and state.db.logs [1][1] == 4)
	env.sendfeed ("unsafe $|\n" .. string.rep ("x", 2000))
	local text = state.db.logs [# state.db.logs][3]
	expect (# text <= 1024 and not text:find ("[$|\n]"))
	expect (contains (text, "&#36;&#124;") and text:sub (-3) == "...")
end)

test ("refresh preserves hit counts, keeps an old list on failure and cleans cache", function ()
	local env, state = newhub ()
	search (env, "guest", tth)
	state.cache = {tth .. "\r", other}
	env.getlist ()
	expect (env.list [tth] == 2 and env.list [other] == 1)
	state.cache = {"invalid"}
	env.getlist ()
	expect (env.list [tth] == 2 and state.removed == 3)
	state.cache = nil
	env.getlist ()
	expect (env.list [tth] == 2 and state.downloads == 4)
end)

test ("kick mode applies to requests and unload closes the active listener", function ()
	local env, state = newhub ()
	env.conf.kick, env.conf.text = true, "Forbidden: *"
	expect (search (env, "guest", tth) == 0)
	expect (# state.kicks == 1 and contains (state.kicks [1][3], tth))
	expect (# state.events == 0)
	expect (env.VH_OnParsedMsgSR ("guest", result ("guest", tth, true)) == 0)
	expect (# state.kicks == 1 and state.events [1][1] == "avdb_user_detect")
	expect (env.UnLoad () == 1 and state.closed and env.serv.work == nil)
end)

print ("Passed " .. passed .. " offline callback tests on " .. _VERSION)
