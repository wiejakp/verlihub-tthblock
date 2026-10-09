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
		cache = {tth}, packets = {}, now = 1700000000, downloads = 0, removed = 0,
		commands = {}, probes = {}, diagnostics = {}, sleeps = 0
	}
	local hub = {HubSec = "Hub-Security", OpChat = "OpChat", ConfName = "config"}
	function hub:SQLQuery (sql)
		state.queries [# state.queries + 1] = sql
		state.current_query = sql
		state.cursor = {}
		if state.before_query then
			local override = state.before_query (sql)
			if override then return unpack_values (override) end
		end
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
		if state.bad_fetch and contains (state.current_query, state.bad_fetch) then return false end
		local row = state.cursor [index + 1]
		if not row then return false end
		return true, unpack_values (row)
	end
	function hub:GetConfig (_, name)
		if name == "hub_version" then return true, options.version or "1.6.0.0" end
		return true, options.delayed or "1"
	end
	function hub:GetUserClass (nick) return true, state.classes [nick] or -1 end
	function hub:GetUserIP () return true, "192.0.2.10" end
	function hub:GetUserCC () return true, "ZZ" end
	function hub:GetVHCfgDir () return true, "/offline/hub" end
	function hub:SendToUser (message, nick, delay)
		state.messages [# state.messages + 1] = {text = message, nick = nick, delay = delay}
		return not state.send_fail
	end
	function hub:SendPMToAll (message, from, minimum, maximum)
		state.feeds [# state.feeds + 1] = {message, from, minimum, maximum}
		return true
	end
	function hub:SendToClass (message, minimum, maximum, delay)
		state.probes [# state.probes + 1] = {message, minimum, maximum, delay}
		return true
	end
	if options.modern then
		state.nicklist = {"guest", "registered", "bot", "empty", "operator", "gone"}
		state.classes.bot, state.classes.empty = 0, 0
		state.supports = {guest = true, registered = false}
		function hub:GetNickList ()
			return true, "$NickList " .. table.concat (state.nicklist, "$$") .. "$$"
		end
		function hub:IsBot (nick) return nick == "bot" end
		function hub:GetMyINFO (nick)
			return true, "$MyINFO $ALL " .. nick .. " description$ $DSL$mail@example.invalid$" ..
				(nick == "empty" and "0" or "1234") .. "$"
		end
		function hub:InUserSupports (nick) return true, state.supports [nick] end
	end
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
	function udp:setsockname ()
		if options.bind_error then return nil, options.bind_error end
		return true
	end
	function udp:close () state.closed = true end
	function udp:receivefrom ()
		local packet = table.remove (state.packets, 1)
		if packet then return unpack_values (packet) end
		return nil, "timeout"
	end
	local env = setmetatable ({VH = hub}, {__index = _G})
	env.os = setmetatable ({
		time = function () return state.now end,
		execute = function (text)
			state.downloads = state.downloads + 1
			state.commands [# state.commands + 1] = text
			return 0
		end,
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
	env.print = function (message) state.diagnostics [# state.diagnostics + 1] = message end
	env.require = function (name)
		expect (name == "socket", "unexpected module")
		if options.no_socket then error ("LuaSocket unavailable") end
		return {
			_VERSION = "offline",
			udp = function ()
				if options.no_udp then return nil, "synthetic UDP error" end
				return udp
			end,
			sleep = function () state.sleeps = state.sleeps + 1 end
		}
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
	for name, value in pairs (options.conf or {}) do env.conf [name] = value end
	if options.configure then options.configure (env, state, hub, udp) end
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
	for _, part in ipairs ({"RoLex & PWiAM", "!hashguard class", "!hashguard logclass",
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

test ("configured user agent remains one literal curl argument", function ()
	local agent = "Browser's \"quoted\" $(touch never) `never`"
	local env, state = newhub ({conf = {user_agent = agent}})
	local curl = state.commands [1]
	expect (contains (curl, "--user-agent 'Browser'\\''s \"quoted\" $(touch never) `never`'"))
	expect (contains (curl, "--output '/offline/hub/tthblock.tth'"))
	expect (contains (curl, " -- 'https://te-home.net/tthblock.php?do=load'"))
	expect (env.conf.user_agent == agent)
end)

test ("configured bot identity controls replies and notification sender", function ()
	local env, state = newhub ({conf = {bot = "HashGuard"}})
	command (env, "master", "!tthblock help")
	local text = lastmessage (state)
	expect (contains (text, "From: HashGuard $<HashGuard>"))
	expect (contains (text, "HashGuard 0.0.3.8 - RoLex & PWiAM"))
	command (env, "master", "!tthblock class 4")
	search (env, "guest", tth)
	expect (state.feeds [1][2] == "HashGuard")
end)

test ("numeric zero TTHS support uses the standard Search probe", function ()
	local env, state = newhub ({modern = true})
	state.supports.guest, state.supports.registered = 0, 1
	env.conf.secs = 5
	env.VH_OnTimer (0)
	expect (# state.messages == 2, "bots, excluded users and empty shares must be skipped")
	expect (contains (state.messages [1].text, "$Search "))
	expect (contains (state.messages [2].text, "$SA "))
end)

test ("statistics preserve chat versus private replies and sort hit counts", function ()
	local env, state = newhub ()
	command (env, "master", "!tthblock")
	expect (contains (lastmessage (state), "<TTHBlock> TTHBlock statistics:"))
	expect (contains (lastmessage (state), "Nothing yet."))
	env.list [tth], env.list [other] = 2, 4
	expect (env.VH_OnHubCommand ("master", "!tthblock", 0, 1) == 0)
	local text = lastmessage (state)
	expect (contains (text, "$To: master From: TTHBlock"))
	expect (contains (text, "1. " .. other .. " = 3"))
	expect (contains (text, "2. " .. tth .. " = 1"))
end)

test ("settings views and history denial respect independent permissions", function ()
	local env, state = newhub ()
	command (env, "master", "!tthblock class")
	expect (contains (lastmessage (state), "configured 11, effective 11 (muted)"))
	command (env, "master", "!tthblock logclass")
	expect (contains (lastmessage (state), "configured 0, effective 5"))
	command (env, "guest", "!tthblock class")
	expect (contains (lastmessage (state), "permission to view"))
	command (env, "guest", "!tthblock logs")
	expect (contains (lastmessage (state), "permission to read"))
	local count = # state.messages
	expect (command (env, "master", "ordinary chat") == 1 and # state.messages == count)
end)

test ("SQL exceptions and invalid row counts keep settings closed", function ()
	for _, response in ipairs ({{false, 0}, {true, -1}, {true, "invalid"}}) do
		local env, state = newhub ({configure = function (_, db)
			db.before_query = function (sql)
				if contains (sql, "select `variable`, `value`") then return response end
			end
		end})
		expect (env.conf.feed == 11 and env.conf.logclass == 10)
		expect (# state.diagnostics > 0)
	end
	local env = newhub ({configure = function (_, db)
		db.before_query = function (sql)
			if contains (sql, "lua_tthblock_settings") then error ("synthetic SQL exception") end
		end
	end})
	expect (env.conf.logclass == 10)
	local unavailable = newhub ({configure = function (_, db)
		db.before_query = function (sql)
			if sql == "select row_count()" then return {false, 0} end
		end
	end})
	expect (unavailable.conf.feed == 11 and unavailable.conf.logclass == 10)
end)

test ("invalid saved settings and failed cursor fetches never reopen access", function ()
	local env = newhub ({db = {settings = {feed = 99}, logs = {}}})
	expect (env.conf.feed == 11 and env.conf.logclass == 10)
	local broken = newhub ({
		db = {settings = {feed = 4}, logs = {}},
		configure = function (_, db) db.bad_fetch = "select `variable`, `value`" end
	})
	expect (broken.conf.feed == 11 and broken.conf.logclass == 10)
end)

test ("retention and later insert failures disable writes while blocking remains", function ()
	local db = {settings = {}, logs = {}}
	for i = 1, 10001 do db.logs [i] = {i, 1700000000, "synthetic history"} end
	local env, state = newhub ({db = db, fail = "delete from `lua_tthblock_logs`"})
	expect (# state.db.logs == 10001)
	expect (contains (state.diagnostics [1], "retention failed"))
	expect (search (env, "guest", tth) == 0 and # state.db.logs == 10001)
	local ready, logs = newhub ()
	logs.fail = "insert into `lua_tthblock_logs`"
	local count = # logs.db.logs
	expect (search (ready, "guest", tth) == 0)
	expect (# logs.db.logs == count and contains (logs.diagnostics [1], "Log write failed"))
	command (ready, "master", "!tthblock logs")
	expect (contains (lastmessage (logs), "unavailable"))
end)

test ("empty history, count failure and corrupt rows return distinct errors", function ()
	local empty, state = newhub ()
	state.db.logs = {}
	command (empty, "master", "!tthblock logs")
	expect (contains (lastmessage (state), "No TTHBlock logs"))
	local failed, db = newhub ()
	db.fail = "select `id`, `created_at`, `message`"
	db.before_query = function (sql)
		if contains (sql, "select count(*)") then return {true, 0} end
	end
	command (failed, "master", "!tthblock logs")
	expect (contains (lastmessage (db), "Failed to read TTHBlock logs"))
	for _, corrupt in ipairs ({"fetch", "timestamp"}) do
		local env, data = newhub ()
		if corrupt == "fetch" then
			data.bad_fetch = "select `id`, `created_at`, `message`"
		else
			data.db.logs [1][2] = "not-a-timestamp"
		end
		command (env, "master", "!tthblock logs")
		expect (contains (lastmessage (data), "Failed to read a TTHBlock log entry"))
	end
end)

test ("duplicate exports and failed sends cannot leave a reader stuck", function ()
	local env, state = newhub ()
	command (env, "master", "!tthblock logs")
	command (env, "master", "!tthblock logs")
	expect (contains (lastmessage (state), "already in progress"))
	state.send_fail = true
	env.VH_OnTimer (0)
	local count = # state.messages
	state.now = state.now + 2
	env.VH_OnTimer (0)
	expect (# state.messages == count)
end)

test ("long history entries obey the byte budget and per-reader interval", function ()
	local env, state = newhub ()
	for _ = 1, 5 do env.sendfeed (string.rep ("x", 1024)) end
	command (env, "master", "!tthblock logs 5")
	env.VH_OnTimer (0)
	local text = lastmessage (state)
	local _, count = text:gsub ("\r\n#", "")
	expect (count == 3 and # text < 4096)
	local messages = # state.messages
	env.VH_OnTimer (0)
	expect (# state.messages == messages)
	state.now = state.now + 1
	env.VH_OnTimer (0)
	expect (contains (lastmessage (state), "End of history."))
end)

test ("explicit feed override and each Ledokol automatic sender resolve predictably", function ()
	local cases = {
		{expected = "SearchFeed", enablesearfilt = 1, addsefifeed = 1, sefifeednick = "SearchFeed"},
		{expected = "ExtraFeed", useextrafeed = 1, extrafeednick = "ExtraFeed"},
		{expected = "LedoBot", addledobot = 1, ledobotnick = "LedoBot"},
		{expected = "OpChat"}
	}
	for _, data in ipairs (cases) do
		local env, state = newhub ({conf = {from = "auto"}, ledokol = data})
		expect (env.conf.from == data.expected)
		command (env, "master", "!tthblock class 4")
		search (env, "guest", tth)
		expect (state.feeds [1][2] == data.expected)
	end
	local fixed = newhub ({conf = {from = "FixedFeed"}})
	expect (fixed.conf.from == "FixedFeed")
end)

test ("startup address, ban reason, invalid classes and legacy versions have fallbacks", function ()
	local custom = newhub ({conf = {kick = true}, ledokol = {
		avsearchint = 1, avsearservaddr = "192.0.2.20", sefireason = "Blocked *", thirdacttime = 12
	}})
	expect (custom.conf.addr == "192.0.2.20" and contains (custom.conf.text, "Blocked *"))
	expect (custom.conf.text:sub (-2) == "12")
	local fallback = newhub ({conf = {kick = true}, ledokol = {
		mincommandclass = 99, scanbelowclass = 11, classnotisefi = 99
	}, version = "invalid-version"})
	expect (fallback.conf.clas == 5 and fallback.conf.skip == 1)
	expect (fallback.serv.vers == 0 and contains (fallback.conf.text, "#_ban_1d"))
	local short = newhub ({version = "1.2"})
	expect (short.serv.vers == 0)
end)

test ("UDP creation and bind failures leave the listener closed and history usable", function ()
	for _, options in ipairs ({{no_udp = true}, {bind_error = "synthetic bind error"}}) do
		local env, state = newhub (options)
		expect (env.serv.work == nil and # state.db.logs == 1)
		if options.bind_error then expect (state.closed) end
		expect (env.UnLoad () == 1)
		command (env, "master", "!tthblock logs")
		env.VH_OnTimer (0)
		expect (contains (lastmessage (state), "End of history"))
	end
end)

test ("legacy probes rotate hashes, honor delayed sends and schedule refreshes", function ()
	for _, version in ipairs ({"1.6.0.0", "1.0.2.14"}) do
		local env, state = newhub ({version = version, delayed = "2"})
		env.conf.secs = 5
		env.VH_OnTimer (0)
		expect (# state.probes == 1 and contains (state.probes [1][1], tth))
		expect (state.probes [1][2] == 0 and state.probes [1][3] == 1)
		expect (state.probes [1][4] == (version == "1.6.0.0" and 2 or nil))
		state.now = state.now + 5
		env.VH_OnTimer (0)
		expect (env.serv.item == 1 and # state.probes == 2)
		state.now = state.now + env.conf.mins * 60
		env.VH_OnTimer (0)
		expect (state.downloads == 2)
		env.serv.list = {}
		state.now = state.now + 5
		local count = # state.probes
		env.VH_OnTimer (0)
		expect (# state.probes == count and env.serv.last == state.now)
	end
end)

test ("modern legacy-version probes handle boolean support and invalid delay values", function ()
	local env, state = newhub ({modern = true, version = "1.0.2.14", delayed = "invalid"})
	env.conf.secs = 5
	env.VH_OnTimer (0)
	expect (contains (state.messages [1].text, "$SA "))
	expect (contains (state.messages [2].text, "$Search ") and state.messages [2].delay == nil)
end)

test ("TTHS flags accept true or one and reject all false representations", function ()
	local cases = {
		{flag = true, prefix = "$SA "}, {flag = 1, prefix = "$SA "},
		{flag = "1", prefix = "$SA "}, {flag = false, prefix = "$Search "},
		{flag = 0, prefix = "$Search "}, {flag = "0", prefix = "$Search "},
		{prefix = "$Search "}
	}
	for _, data in ipairs (cases) do
		local env, state = newhub ({modern = true})
		state.supports.guest = data.flag
		env.conf.secs = 5
		env.VH_OnTimer (0)
		expect (contains (state.messages [1].text, data.prefix))
	end
end)

test ("malformed and excluded-class results leave valid traffic untouched", function ()
	local env, state = newhub ()
	expect (env.VH_OnParsedMsgSR ("operator", result ("operator", tth, true)) == 1)
	expect (env.VH_OnParsedMsgSR ("guest", "malformed frame") == 1)
	expect (search (env, "missing", tth) == 1)
	state.packets = {
		{"malformed|still malformed|", "192.0.2.10", 20201},
		{result ("operator", tth), "192.0.2.10", 20201}
	}
	env.VH_OnTimer (0)
	expect (# state.events == 0 and state.sleeps >= 3)
end)

test ("unsafe nickname, command, URL and HTTP header settings stop before download", function ()
	local cases = {
		{bot = "bad|nick"}, {bot = ""}, {bot = string.rep ("x", 65)}, {from = "bad nick"},
		{comm = "../outside"}, {list = "file:///offline/never"},
		{user_agent = ""}, {user_agent = "bad\r\nheader"}, {user_agent = string.rep ("x", 1025)}
	}
	for _, conf in ipairs (cases) do
		local ok, error = pcall (newhub, {conf = conf})
		expect (not ok and contains (error, "Invalid"))
	end
end)

print ("Passed " .. passed .. " offline callback tests on " .. _VERSION)
