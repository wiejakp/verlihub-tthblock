-- TTH Block 0.0.3.8
-- Copyright (c) 2020-2026 RoLex & PWiAM
-- Modifications Copyright (c) 2026 RoLex & PWiAM
--
-- Licensed under the GNU General Public License v3.0.
-- See LICENSE for details.
-- Fork revision: configurable identity, HTTP user agent, and retained history.
--
-- INSTALLATION
-- Verlihub must have its Lua plugin enabled. Load Ledokol first for its search
-- filter and AVDB actions. Install curl and LuaSocket for the same Lua ABI as
-- the hub. Copy this file into <hub-config>/scripts/ and load it as a permitted
-- plugin administrator: !luaload /absolute/path/to/scripts/tthblock.lua
-- Use !lualist to find its script ID; !luareload <id> applies file changes.
-- !luaunload <id> stops it. Files in scripts/ also load on Lua plugin startup.
-- The hub account needs a writable config directory and database privileges
-- to CREATE, SELECT, INSERT and DELETE its two lua_tthblock_* tables.
--
-- COMMANDS (main chat or PM to Hub-Security; ! and + prefixes both work)
-- !tthblock                  Current in-memory hit statistics.
-- !tthblock help             Command syntax, permissions and export limits.
-- !tthblock class            Configured/effective notification class.
-- !tthblock class <class>    Save notification class: 0, 1-5, 10, or 11.
-- !tthblock logclass         Configured/effective history access class.
-- !tthblock logclass <class> Save history access class: 0, 1-5, or 10.
-- !tthblock logs [count]     Private UTC history, newest first; default 50,
--                           maximum 1000 entries per request.
-- Command names are case-insensitive. Replace tthblock with conf.comm if changed.
-- Statistics, help and settings views require conf.clas; class 10 always qualifies.
-- Only a class-10 master can change saved settings. History uses conf.logclass
-- independently, and class 10 always has access. Unknown subcommands show help.
--
-- Class 0 selects automatic configuration; notification class 11 mutes this
-- script's feed. Blocking and SQL history continue while the feed is muted.
-- Saved classes override defaults on reload. Retention is 10000 log entries;
-- exports allow 4 readers, 20 lines / 4096 bytes per batch, 1 second between
-- batches, and 30 seconds between requests by one user. See defaults below.
-- Logs/settings persist in MySQL; statistics and notification timers do not.
-- A failed settings read mutes the feed and restricts logs to masters. Failed
-- log storage disables history writes without disabling TTH filtering.
--
-- CONFIGURATION AND INTEGRATION
-- Edit defaults/conf below before loading. Auto mode reads lua_ledo_conf.
-- conf.user_agent configures curl's HTTP User-Agent; the default is a 2025
-- Windows Chrome 143 user agent. It is source configuration, not a hub command.
-- conf.bot defaults to TTHBlock for replies, help, and feed messages. Use
-- conf.from to override the feed sender, or "auto" for Ledokol's sender chain.
-- This script labels hub-generated messages; it does not register another bot.
-- conf.skip is an exclusive class ceiling before Main converts it to inclusive.
-- The UDP listener advertises conf.addr:conf.port to clients; set a reachable
-- local interface address and allow UDP port 20201 for active result scanning.
-- LuaSocket failure disables active probes/list refresh, but loaded-hash search
-- filtering, passive result handling and queued history delivery still work.
-- getlist downloads conf.list on load and every conf.mins while UDP is running.
-- Its temporary <hub-config>/<conf.comm>.tth file is removed after parsing.
-- A failed/empty refresh keeps the last in-memory list; reload starts a new list.
-- Ledokol receives sefi_user_block (tell nick TTH) and avdb_user_detect
-- (nick IPv4 path). Its enabled features/protection rules govern those actions;
-- it may emit its own notifications even when this script's feed is muted.
-- conf.kick applies to forbidden search requests; results follow Ledokol AVDB.
--
-- README: https://github.com/wiejakp/verlihub-tthblock
-- Original script: https://ledo.feardc.net/other/tthblock.lua
-- Original repository page: https://ledo.feardc.net/other/
-- Contracts and primary links: docs/architecture.md and docs/references.md.
-- Verlihub Lua API: https://github.com/Verlihub/verlihub/wiki/API-Lua-Methods
-- Ledokol: https://github.com/Verlihub/ledokol

local plugin = {
	version = "0.0.3.8",
	authors = "RoLex & PWiAM",
	homepage = "https://github.com/wiejakp/verlihub-tthblock",
	origin = "https://ledo.feardc.net/other/tthblock.lua"
}

-- Saved class settings override these defaults after the first load.
local defaults = {
	notification_class = 11, -- 0 = original auto mode; 1-5 or 10 = minimum class; 11 = mute
	log_class = 0, -- 0 = follow conf.clas; 1-5 or 10 = minimum class; master always has access
	log_retention = 10000, -- maximum stored entries
	log_default_count = 50, -- entries returned by !tthblock logs
	log_request_limit = 1000, -- maximum entries per request
	log_message_bytes = 1024, -- longer messages are truncated
	log_batch_lines = 20, -- maximum entries per private message
	log_batch_bytes = 4096, -- maximum private-message body size
	log_batch_interval = 1, -- seconds between batches per reader
	log_max_readers = 4, -- simultaneous log exports
	log_request_cooldown = 30 -- seconds between exports by the same user
}

list = {}
conf = {
	comm = "tthblock", -- statistics command
	bot = "TTHBlock", -- default message sender and display name
	user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " ..
		"(KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36", -- 2025 Chrome on Windows
	from = "", -- feed sender override; empty follows bot, "auto" follows Ledokol
	tell = 0, -- notification to user
	clas = 0, -- command usage class, zero for auto
	feed = defaults.notification_class, -- notification feed class, zero for auto
	logclass = defaults.log_class, -- log access is independent of the feed class
	skip = 0, -- skip user class, zero for auto
	wait = 10800, -- seconds before notification
	addr = "", -- server listen address, empty for auto
	port = 20201, -- server listen port
	secs = 5, -- search interval in seconds
	mins = 360, -- update interval in minutes
	kick = false, -- block or kick action
	text = "", -- kick action reason
	list = "https://te-home.net/tthblock.php?do=load" -- update tth list url
}
serv = {
	sock = nil,
	work = nil,
	last = 0,
	mins = 0,
	item = 0,
	vers = 0,
	list = {}
}

stat = {}

local MASTER_CLASS = 10
local settings = {feed = conf.feed, logclass = conf.logclass}
local auto_feed = 4
local storage = {settings = false, logs = false, count = 0}
local deliveries, requested = {}, {}

local function shellquote (value)
	-- Single quotes prevent expansion; an embedded quote needs its own escaped segment.
	return "'" .. value:gsub ("'", "'\\''") .. "'"
end

local function validnick (value)
	return type (value) == "string" and # value > 0 and # value <= 64 and
		not value:find ("[ %c$|<>]")
end

local function validclass (value, disabled)
	return type (value) == "number" and value == math.floor (value) and
		((value >= 0 and value <= 5) or value == MASTER_CLASS or (disabled and value == 11))
end

local function query (sql)
	local called, ok, rows = pcall (VH.SQLQuery, VH, sql)
	if called and ok and tonumber (rows) and tonumber (rows) >= 0 then
		return tonumber (rows)
	end
	return nil
end

local function writequery (sql)
	if query (sql) == nil or query ("select row_count()") ~= 1 then
		return false
	end
	-- SQLQuery can return true after a SQL error; check the affected-row count.
	local ok, count = VH:SQLFetch (0)
	count = tonumber (count)
	return ok and count ~= nil and count >= 0, count
end

local function storageerror (kind, message)
	storage [kind] = false
	print ("[" .. conf.bot .. "] " .. message ..
		" Repair the database permissions or connection, then reload this script.")
end

local function applysettings ()
	conf.feed = settings.feed == 0 and auto_feed or settings.feed
	conf.logclass = settings.logclass == 0 and conf.clas or settings.logclass
end

local function trimlogs ()
	local excess = storage.count - defaults.log_retention
	if excess <= 0 then return true end
	local ok, removed = writequery ("delete from `lua_tthblock_logs` order by `id` asc limit " ..
		_tostring (excess))
	if not ok or removed ~= excess then
		storageerror ("logs", "Log retention failed; further log writes are disabled.")
		return false
	end
	storage.count = storage.count - removed
	return true
end

local function initstorage ()
	local ok = writequery ("create table if not exists `lua_tthblock_settings` (" ..
		"`variable` varchar(32) not null primary key, `value` int not null) engine=InnoDB")
	if ok then
		local rows = query ("select `variable`, `value` from `lua_tthblock_settings`")
		local saved = {}
		ok = rows ~= nil
		for row = 0, (rows or 0) - 1 do
			local fetched, name, value = VH:SQLFetch (row)
			if not fetched then ok = false; break end
			saved [name] = tonumber (value)
		end
		for _, name in ipairs ({"feed", "logclass"}) do
			if saved [name] ~= nil then
				if validclass (saved [name], name == "feed") then
					settings [name] = saved [name]
				else
					ok = false
				end
			elseif ok then
				ok = writequery ("insert into `lua_tthblock_settings` (`variable`, `value`) values ('" ..
					name .. "', " .. _tostring (settings [name]) .. ")")
			end
		end
	end
	storage.settings = not not ok
	if not storage.settings then
		-- A failed settings read must not reopen a previously muted feed.
		settings.feed, settings.logclass = 11, MASTER_CLASS
		storageerror ("settings",
			"Settings unavailable; notifications are muted and log access is master-only.")
	end
	applysettings ()

	ok = writequery ("create table if not exists `lua_tthblock_logs` (" ..
		"`id` bigint unsigned not null auto_increment primary key, " ..
		"`created_at` bigint unsigned not null, `message` blob not null) engine=InnoDB")
	if ok and query ("select count(*) from `lua_tthblock_logs`") == 1 then
		local fetched, count = VH:SQLFetch (0)
		storage.count = tonumber (count) or -1
		storage.logs = fetched and storage.count >= 0
	end
	if not storage.logs then
		storageerror ("logs", "Log storage unavailable; blocking remains enabled.")
	else
		trimlogs ()
	end
end

local function logtext (data)
	local text = nmdcsafe (data):gsub ("[%z\1-\31\127]", " ")
	if # text > defaults.log_message_bytes then
		text = text:sub (1, defaults.log_message_bytes - 3) .. "..."
	end
	return text
end

local function writelog (data)
	if not storage.logs then return false end
	local message = logtext (data)
	-- Hex literals preserve hub-encoded text without depending on SQL escape mode.
	local hex = message:gsub (".", function (char)
		return string.format ("%02X", string.byte (char))
	end)
	local ok, added = writequery (
		"insert into `lua_tthblock_logs` (`created_at`, `message`) values (" ..
		_tostring (os.time ()) .. ", X'" .. hex .. "')")
	if not ok or added ~= 1 then
		storageerror ("logs", "Log write failed; blocking remains enabled.")
		return false
	end
	storage.count = storage.count + 1
	return trimlogs ()
end

local function reply (nick, data, pm)
	local text = nmdcsafe (data)
	if tonumber (pm) == 1 then
		return VH:SendToUser ("$To: " .. nick .. " From: " .. conf.bot ..
			" $<" .. conf.bot .. "> " .. text .. "|", nick)
	end
	return VH:SendToUser ("<" .. conf.bot .. "> " .. text .. "|", nick)
end

local function canreadlogs (clas)
	return clas == MASTER_CLASS or (clas >= 0 and clas <= MASTER_CLASS and clas >= conf.logclass)
end

local function drainlogs (now)
	for nick, job in pairs (deliveries) do
		local _, clas = VH:GetUserClass (nick)
		clas = tonumber (clas) or -1
		-- A demotion or permission change also applies to an export already in progress.
		if not canreadlogs (clas) then
			deliveries [nick] = nil
		elseif now >= job.next then
			local lines, bytes = {}, 0
			while job.pos <= # job.rows and # lines < defaults.log_batch_lines do
				local line = job.rows [job.pos]
				if bytes + # line + 2 > defaults.log_batch_bytes - 128 then break end
				lines [# lines + 1] = line
				bytes = bytes + # line + 2
				job.pos = job.pos + 1
			end
			local text = conf.bot .. " logs (newest first, UTC):\r\n" .. table.concat (lines, "\r\n")
			local done = job.pos > # job.rows
			if done then text = text .. "\r\nEnd of history." end
			if not reply (nick, text, 1) or done then
				deliveries [nick] = nil
			else
				job.next = now + defaults.log_batch_interval
			end
		end
	end
end

local function requestlogs (nick, count)
	if not storage.logs then
		reply (nick,
			conf.bot .. " log storage is unavailable. Check the hub log and reload after repair.", 1)
		return
	end
	local now, active = os.time (), 0
	if deliveries [nick] then
		reply (nick, "A " .. conf.bot .. " log export is already in progress.", 1)
		return
	end
	if requested [nick] and now - requested [nick] < defaults.log_request_cooldown then
		reply (nick, "Wait before requesting another " .. conf.bot .. " log export.", 1)
		return
	end
	for _ in pairs (deliveries) do active = active + 1 end
	if active >= defaults.log_max_readers then
		reply (nick, conf.bot .. " log exports are busy. Try after an export finishes.", 1)
		return
	end
	local rows = query ("select `id`, `created_at`, `message` from `lua_tthblock_logs` " ..
		"order by `id` desc limit " .. _tostring (count))
	if rows == 0 then
		-- A zero-row SQL result can also mean failure in Verlihub's Lua API.
		if query ("select count(*) from `lua_tthblock_logs`") == 1 then
			local ok, count = VH:SQLFetch (0)
			if not ok or tonumber (count) ~= 0 then rows = nil end
		else
			rows = nil
		end
	end
	if rows == nil then
		reply (nick, "Failed to read " .. conf.bot .. " logs.", 1)
		return
	end
	local result = {}
	-- Copy the result before sending messages; other Lua scripts share the SQL cursor.
	for row = 0, rows - 1 do
		local ok, id, created, message = VH:SQLFetch (row)
		if not ok or not tonumber (created) then
			reply (nick, "Failed to read a " .. conf.bot .. " log entry.", 1)
			return
		end
		result [# result + 1] = "#" .. id .. " " ..
			os.date ("!%Y-%m-%d %H:%M:%S", tonumber (created)) .. " " .. logtext (message)
	end
	requested [nick] = now
	if # result == 0 then
		reply (nick, "No " .. conf.bot .. " logs are available yet.", 1)
		return
	end
	deliveries [nick] = {rows = result, pos = 1, next = now}
	reply (nick, "Sending the latest " .. _tostring (# result) ..
		" " .. conf.bot .. " log entries in private batches.", 1)
end

local function setclass (nick, name, value)
	if not storage.settings then
		reply (nick, conf.bot .. " settings storage is unavailable; the setting was not changed.", 1)
		return
	end
	local ok, changed = writequery (
		"replace into `lua_tthblock_settings` (`variable`, `value`) values ('" ..
		name .. "', " .. _tostring (value) .. ")")
	if not ok or changed < 1 then
		reply (nick, "Failed to save the " .. conf.bot .. " setting; its value is unchanged.", 1)
		return
	end
	settings [name] = value
	applysettings ()
	writelog ("Setting " .. name .. " changed to " .. _tostring (value) .. " by " .. nick)
	local effective = name == "feed" and conf.feed or conf.logclass
	reply (nick, conf.bot .. " " .. name .. " = " .. _tostring (value) ..
		(value == 0 and " (auto; effective class " .. _tostring (effective) .. ")" or "") ..
		(name == "feed" and effective == 11 and
			"; automatic notifications disabled. Blocking and logging are unchanged." or "."), 1)
end

local function checkdefaults ()
	assert (validnick (conf.bot), "Invalid bot nickname: use 1-64 bytes without NMDC delimiters")
	assert (type (conf.from) == "string" and
		(conf.from == "" or conf.from == "auto" or validnick (conf.from)), "Invalid feed sender")
	assert (type (conf.user_agent) == "string" and # conf.user_agent > 0 and
		# conf.user_agent <= 1024 and not conf.user_agent:find ("[%z\1-\31\127]"),
		"Invalid user_agent: use 1-1024 printable bytes without control characters")
	assert (type (conf.comm) == "string" and conf.comm:match ("^[%w_-]+$"),
		"Invalid command name: use letters, numbers, underscore or hyphen")
	assert (type (conf.list) == "string" and conf.list:match ("^https?://") and
		not conf.list:find ("[%z\1-\31\127]"), "Invalid blocklist HTTP(S) URL")
	assert (validclass (defaults.notification_class, true), "Invalid notification_class default")
	assert (validclass (defaults.log_class, false), "Invalid log_class default")
	local ranges = {
		log_retention = {1, 1000000}, log_default_count = {1, 10000},
		log_request_limit = {1, 10000}, log_message_bytes = {64, 4096},
		log_batch_lines = {1, 100}, log_batch_bytes = {512, 16384},
		log_batch_interval = {1, 60}, log_max_readers = {1, 20},
		log_request_cooldown = {1, 3600}
	}
	for key, range in pairs (ranges) do
		local value = defaults [key]
		assert (type (value) == "number" and value == math.floor (value) and
			value >= range [1] and value <= range [2], "Invalid " .. key .. " default")
	end
	assert (defaults.log_default_count <= defaults.log_request_limit,
		"Default log count exceeds request limit")
	assert (defaults.log_message_bytes + 256 <= defaults.log_batch_bytes,
		"Log batch is too small for one entry")
end

function Main (file)
	checkdefaults ()
	local _, vers = VH:GetConfig ((VH.ConfName or "config"), "hub_version")

	if vers and # vers >= 7 then
		local v1, v2, v3, v4 = vers:match ("^(%d+)%.(%d+)%.(%d+)%.(%d+)$") -- 1.2.3.4

		if v1 and v2 and v3 and v4 then
			serv.vers = tonumber (tostring ("0.") .. tostring (v1) .. tostring (v2) ..
				tostring (v3) .. tostring (v4)) or 0
		end
	end
	local _, rows = VH:SQLQuery (
		"select `variable`, `value` from `lua_ledo_conf` where " ..
		"`variable` = 'enablesearfilt' or " ..
		"`variable` = 'addsefifeed' or " ..
		"`variable` = 'sefifeednick' or " ..
		"`variable` = 'addledobot' or " ..
		"`variable` = 'ledobotnick' or " ..
		"`variable` = 'useextrafeed' or " ..
		"`variable` = 'extrafeednick' or " ..
		"`variable` = 'avsearchint' or " ..
		"`variable` = 'avsearservaddr' or " ..
		"`variable` = 'sefireason' or " ..
		"`variable` = 'thirdacttime' or " ..
		"`variable` = 'mincommandclass' or " ..
		"`variable` = 'classnotisefi' or " ..
		"`variable` = 'scanbelowclass'"
	)
	local test = {
		enablesearfilt = 0, addsefifeed = 0, sefifeednick = "", addledobot = 0,
		ledobotnick = "", useextrafeed = 0, extrafeednick = "", avsearchint = 0,
		avsearservaddr = "", sefireason = "", thirdacttime = "", mincommandclass = 5,
		classnotisefi = 4, scanbelowclass = 2
	}

	for row = 0, (tonumber (rows) or 0) - 1 do
		local _, var, val = VH:SQLFetch (row)
		if var then test [var] = (tonumber (val) or val or "") end
	end
	for _, key in ipairs ({"sefifeednick", "ledobotnick", "extrafeednick",
		"avsearservaddr", "sefireason", "thirdacttime"}) do
		test [key] = tostring (test [key])
	end
	if # conf.from == 0 then -- feed nick
		conf.from = conf.bot
	elseif conf.from == "auto" then
		if test.enablesearfilt == 1 and test.addsefifeed == 1 and # test.sefifeednick > 0 then
			conf.from = test.sefifeednick
		elseif test.useextrafeed == 1 and # test.extrafeednick > 0 then
			conf.from = test.extrafeednick
		elseif test.addledobot == 1 and # test.ledobotnick > 0 then
			conf.from = test.ledobotnick
		else
			conf.from = VH.OpChat
		end
	end
	if # conf.addr == 0 then -- server address
		if test.avsearchint > 0 and # test.avsearservaddr > 0 then
			conf.addr = test.avsearservaddr
		else
			conf.addr = "0.0.0.0"
		end
	end

	if conf.kick and # conf.text == 0 then -- kick reason
		if # test.sefireason > 0 then
			conf.text = test.sefireason
		else
			conf.text = "Forbidden search request or result detected: *"
		end

		conf.text = conf.text .. "     #_ban_"
		if # test.thirdacttime > 0 then
			conf.text = conf.text .. test.thirdacttime
		else
			conf.text = conf.text .. "1d"
		end
	end

	if conf.clas == 0 then -- command class
		if validclass (test.mincommandclass, false) then
			conf.clas = test.mincommandclass
		else
			conf.clas = 5
		end
	end

	-- Preserve the original auto-mode fallback when Ledokol uses class 11.
	auto_feed = validclass (test.classnotisefi, false) and test.classnotisefi or 4
	if conf.skip == 0 then -- skip class
		if test.scanbelowclass < 11 then
			conf.skip = test.scanbelowclass
		else
			conf.skip = 2
		end
	end

	conf.skip = conf.skip - 1
	initstorage ()
	getlist () -- create lists

	local res, err = pcall ( -- start server
		function ()
			serv.sock = require ("socket")
		end
	)

	if res and serv.sock then
		local udp, err = serv.sock.udp ()

		if udp then
			udp:settimeout (0)
			local res, err = udp:setsockname (conf.addr, conf.port)
			if res then
				serv.work = udp
				sendfeed ("TTH server running using " .. nmdcsafe (serv.sock._VERSION) ..
					": " .. conf.addr .. ":" .. _tostring (conf.port))

			else
				udp:close ()
				sendfeed ("Failed starting TTH server: " .. nmdcsafe (err or "Unknown"))
			end

		else
			sendfeed ("Failed creating TTH server: " .. nmdcsafe (err or "Unknown"))
		end

	else
		sendfeed ("Failed loading LuaSocket module: " .. nmdcsafe (err or "Unknown"))
	end

	return 1
end
function UnLoad ()
	if serv.work then -- stop server
		serv.work:close ()
		serv.work = nil
		sendfeed ("TTH server stopped: " .. conf.addr .. ":" .. _tostring (conf.port))
	end

	return 1
end

function VH_OnTimer (msec)
	drainlogs (os.time ()) -- log exports also work when the search socket is down
	if not serv.work then -- nothing to do
		return 1
	end

	for tot = 1, 10 do -- active result, client sends 10
		local data, addr, port = serv.work:receivefrom ()

		if not data or not addr or not port or # data == 0 or # addr == 0 or addr == "timeout" then
			break
		end
		for part in data:gmatch ("[^|]+") do
			local nick, path, tth = part:match ("%$SR ([^ ]+) ([^" .. string.char (5) ..
				"]+)" .. string.char (5) .. "%d+ %d+/%d+" .. string.char (5) ..
				"TTH:([A-Z2-7]+) %(.+%)$")

			if nick and path and tth and # tth == 39 and list [tth] then -- check tth
				local _, clas = VH:GetUserClass (nick) -- check class

				if clas < 0 or clas > conf.skip then
					break
				end

				local _, uddr = VH:GetUserIP (nick) -- check source

				if uddr ~= addr then
					break
				end
				VH:ScriptCommand ("avdb_user_detect", nick .. " " .. addr .. " " .. path) -- to catch in ledokol
				list [tth] = list [tth] + 1
				writelog ("TTH active result from " .. nick .. " with IP " .. addr ..
					": " .. tth .. " " .. path)
				break
			end

			serv.sock.sleep (0.001) -- unload cpu
		end

		serv.sock.sleep (0.001) -- unload cpu
	end

	local now = os.time ()

	if os.difftime (now, serv.last) >= conf.secs then -- search interval
		local tot = # serv.list

		if tot > 0 then
			if serv.item >= tot then -- next item
				serv.item = 1
			else
				serv.item = serv.item + 1
			end
			local _, wait = VH:GetConfig (VH.ConfName, "delayed_search")
			wait = tonumber (wait or 1) or 1

			if VH.GetNickList and VH.IsBot and VH.InUserSupports then
				local _, full = VH:GetNickList ()

				for nick in full:sub (11):gmatch ("[^ %$]+") do
					local _, clas = VH:GetUserClass (nick)

					if clas >= 0 and clas <= conf.skip and not VH:IsBot (nick) then
						local _, info = VH:GetMyINFO (nick)

						if not info:match ("%$0%$$") then
							local _, tths = VH:InUserSupports (nick, "TTHS")
							-- The binding can return numeric 0; Lua treats that value as truthy.
							if tths == true or tonumber (tths) == 1 then
								info = "$SA " .. serv.list [serv.item] .. " " .. conf.addr ..
									":" .. _tostring (conf.port) .. "|"
							else
								info = "$Search " .. conf.addr .. ":" .. _tostring (conf.port) ..
									" F?F?0?9?TTH:" .. serv.list [serv.item] .. "|"
							end

							if serv.vers >= 0.10215 then
								VH:SendToUser (info, nick, wait)
							else
								VH:SendToUser (info, nick)
							end
						end
					end
				end
			elseif serv.vers >= 0.10215 then
				VH:SendToClass ("$Search " .. conf.addr .. ":" .. _tostring (conf.port) ..
					" F?F?0?9?TTH:" .. serv.list [serv.item] .. "|", 0, conf.skip, wait)
			else
				VH:SendToClass ("$Search " .. conf.addr .. ":" .. _tostring (conf.port) ..
					" F?F?0?9?TTH:" .. serv.list [serv.item] .. "|", 0, conf.skip)
			end
		end

		serv.last = now
	end

	if os.difftime (now, serv.mins) >= conf.mins * 60 then -- update interval
		getlist ()
	end

	return 1
end
function VH_OnParsedMsgSR (nick, data) -- passive result
	local _, clas = VH:GetUserClass (nick) -- check class

	if clas < 0 or clas > conf.skip then
		return 1
	end

	local path, tth = data:match ("%$SR [^ ]+ ([^" .. string.char (5) .. "]+)" ..
		string.char (5) .. "%d+ %d+/%d+" .. string.char (5) .. "TTH:([A-Z2-7]+) %(.+%)" ..
		string.char (5) .. "[^ ]+$")

	if not path or not tth or # tth ~= 39 or not list [tth] then -- check tth
		return 1
	end
	local _, addr = VH:GetUserIP (nick)
	VH:ScriptCommand ("avdb_user_detect", nick .. " " .. addr .. " " .. path) -- to catch in ledokol
	list [tth] = list [tth] + 1
	writelog ("TTH passive result from " .. nick .. " with IP " .. addr .. ": " .. tth .. " " .. path)
	return 0
end

function VH_OnParsedMsgSearch (nick, data) -- search request
	local _, clas = VH:GetUserClass (nick) -- check class

	if clas < 0 or clas > conf.skip then
		return 1
	end

	local tth = data:match ("^%$Search [^ ]+ [TF]%?[TF]%?%d+%?9%?TTH:([A-Z2-7]+)$")
	if not tth or # tth ~= 39 or not list [tth] then -- check tth
		return 1
	end

	local _, addr = VH:GetUserIP (nick)
	local _, code = VH:GetUserCC (nick)
	addr = addr or "unknown"
	if code and # code == 2 then addr = addr .. "." .. code end
	local message = "TTH " .. (conf.kick and "kick" or "block") .. " from " .. nick ..
		" with IP " .. addr .. " and class " .. _tostring (clas) .. ": " .. tth

	if conf.kick then
		local text = conf.text:gsub ("%*", tth)
		VH:KickUser (VH.HubSec, nick, text)

	else
		VH:ScriptCommand ("sefi_user_block", _tostring (conf.tell) .. " " .. nick .. " " .. tth)
	end

	list [tth] = list [tth] + 1
	-- Record every detection; conf.wait limits notifications, not history.
	writelog (message)
	local now = os.time ()
	if conf.feed ~= 11 and (not stat [nick] or os.difftime (now, stat [nick]) >= conf.wait) then
		stat [nick] = now
		sendfeed (message, true)
	end

	return 0
end

function VH_OnUserLogout (nick, addr)
	stat [nick] = nil
	deliveries [nick], requested [nick] = nil, nil
	return 1
end
local function commandhelp ()
	local cmd = "!" .. conf.comm
	return table.concat ({
		conf.bot .. " " .. plugin.version .. " - " .. plugin.authors,
		"Use ! or + in main chat or a PM to " .. VH.HubSec .. "; command names ignore case.",
		cmd .. " - current in-memory hit statistics",
		cmd .. " help - commands and permissions (unknown subcommands also show help)",
		cmd .. " class - show configured/effective notification class",
		cmd .. " class <0|1-5|10|11> - save notification class; 11 mutes this feed",
		cmd .. " logclass - show configured/effective history access class",
		cmd .. " logclass <0|1-5|10> - save history access class",
		cmd .. " logs [count] - private UTC history, newest first; default " ..
			_tostring (defaults.log_default_count) .. ", maximum " ..
			_tostring (defaults.log_request_limit),
		"Statistics, help and settings views need class " .. _tostring (conf.clas) ..
			"; history needs class " .. _tostring (conf.logclass) .. ". Class 10 always qualifies.",
		"Only class 10 may change settings. Saved classes survive reloads; 0 selects auto mode.",
		"Muting this feed keeps blocking and retained logs active; Ledokol has its own feeds.",
		"Retained entries: " .. _tostring (defaults.log_retention) .. "; export readers: " ..
			_tostring (defaults.log_max_readers) .. "; request cooldown: " ..
			_tostring (defaults.log_request_cooldown) .. "s; batch interval: " ..
			_tostring (defaults.log_batch_interval) .. "s.",
		"Each private batch has at most " .. _tostring (defaults.log_batch_lines) ..
			" entries and " .. _tostring (defaults.log_batch_bytes) .. " body bytes.",
		"Project: " .. plugin.homepage,
		"Original script: " .. plugin.origin
	}, "\r\n")
end

function VH_OnHubCommand (nick, data, op, pm)
	local name, args = data:match ("^[!+](%S+)%s*(.-)%s*$")
	if not name or name:lower () ~= conf.comm:lower () then return 1 end
	local _, clas = VH:GetUserClass (nick)
	clas = tonumber (clas) or -1
	local action, value = args:match ("^(%S+)%s*(.-)%s*$")
	action = action and action:lower () or ""

	if action == "class" or action == "logclass" then
		local key = action == "class" and "feed" or "logclass"
		if value ~= "" then
			if clas ~= MASTER_CLASS then
				reply (nick, "Only a class-10 master may change " .. conf.bot .. " settings.", 1)
				return 0
			end
			local number = value:match ("^%d+$") and tonumber (value) or nil
			if not validclass (number, key == "feed") then
				reply (nick, "Allowed classes: 0 (auto), 1-5, 10" ..
					(key == "feed" and ", 11 (mute)." or "."), 1)
				return 0
			end
			setclass (nick, key, number)
		elseif clas == MASTER_CLASS or (clas >= 0 and clas >= conf.clas) then
			local effective = key == "feed" and conf.feed or conf.logclass
			reply (nick, conf.bot .. " " .. action .. ": configured " .. _tostring (settings [key]) ..
				", effective " .. _tostring (effective) ..
				(key == "feed" and effective == 11 and " (muted)" or "") ..
				(storage.settings and "." or "; settings storage unavailable."), 1)
		else
			reply (nick, "You do not have permission to view " .. conf.bot .. " settings.", 1)
		end
		return 0
	end

	if action == "logs" then
		if not canreadlogs (clas) then
			reply (nick, "You do not have permission to read " .. conf.bot .. " logs.", 1)
			return 0
		end
		local count = value == "" and defaults.log_default_count or
			(value:match ("^%d+$") and tonumber (value) or nil)
		if not count or count < 1 or count > defaults.log_request_limit then
			reply (nick, "Usage: !" .. conf.comm .. " logs <1-" ..
				_tostring (defaults.log_request_limit) .. ">", 1)
		else
			requestlogs (nick, count)
		end
		return 0
	end

	if clas ~= MASTER_CLASS and (clas < 0 or clas < conf.clas) then
		reply (nick, "You do not have permission to use this " .. conf.bot .. " command.", 1)
		return 0
	end
	if action ~= "" then
		reply (nick, commandhelp (), 1)
		return 0
	end

	local sort, line = {}, ""

	for tth, hit in pairs (list) do
		if hit > 1 then
			table.insert (sort, {hit - 1, tth})
		end
	end

	if # sort > 0 then
		table.sort (sort,
			function (one, two)
				return one [1] > two [1]
			end
		)
		for pos, tth in pairs (sort) do
			line = line .. " " .. _tostring (pos) .. ". " .. tth [2] ..
				" = " .. _tostring (tth [1]) .. "\r\n"
		end

	else
		line = " Nothing yet.\r\n"
	end

	line = conf.bot .. " statistics:\r\n\r\n" .. line
	reply (nick, line, pm)
	return 0
end
function getlist ()
	local _, path = VH:GetVHCfgDir ()
	path = path .. "/" .. conf.comm .. ".tth"
	os.execute ("curl --get --location --max-redirs 1 --retry 2 --connect-timeout 5 " ..
		"--max-time 10 --user-agent " .. shellquote (conf.user_agent) ..
		" --silent --output " .. shellquote (path) .. " -- " .. shellquote (conf.list))
	local file = io.open (path, "r")

	if file then
		file:close ()
		local temp, have = {}, false
		for tth in io.lines (path) do
			local lth = tth:gsub ("\r", "") -- get rid of newline
			lth = lth:gsub ("\n", "")

			if # lth == 39 then
				temp [lth] = 1
				have = true
			end
		end

		if have then
			serv.list = {}

			for tth, _ in pairs (temp) do
				temp [tth] = list [tth] or 1
				table.insert (serv.list, tth)
			end

			list = temp
		end

		os.remove (path)
	end

	serv.mins = os.time () -- keep the refresh timestamp separate from the configured interval
end
function sendfeed (data, logged)
	if not logged then writelog (data) end
	if conf.feed == 11 then return end
	-- OpChat broadcasts and its relay hook bypass this script's recipient filter.
	VH:SendPMToAll ("[" .. string.format ("%02d", conf.feed) .. "] " .. nmdcsafe (data),
		conf.from, conf.feed, MASTER_CLASS)
end

function nmdcsafe (data)
	local safe = _tostring (data)
	safe = safe:gsub ("%$", "&#36;")
	safe = safe:gsub ("|", "&#124;")
	return safe
end
function _tostring (data)
	if type (data) == "number" then
		return string.format ("%d", data)
	end

	return tostring (data)
end

-- end of file
