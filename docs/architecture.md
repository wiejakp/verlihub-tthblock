# Runtime contracts

This document describes fork version 0.0.3.8, based on supplied TTH Block 0.0.3.7,
including its saved class settings and history. Read it with `tthblock.lua` and
[the pinned primary sources](references.md). The script is hosted by Verlihub's
Lua plugin; `VH` is the plugin binding and Ledokol is a separate loaded Lua script.

## Lifecycle and state

`Main(file)` validates defaults, checks the hub version, reads Ledokol
configuration, resolves automatic values, initializes SQL storage, downloads
the hash list, and attempts to create a nonblocking LuaSocket UDP listener.
It returns `1`. `UnLoad()` closes the listener, records its shutdown through
`sendfeed`, and returns `1`.

`list` maps hashes to `1 + hit count`; `serv.list` is the rotating probe order.
`conf` holds effective runtime configuration. `serv` holds socket, timestamps,
probe position, and the compact version gate. `stat` tracks notification times
by nickname. Local `settings` preserves configured feed/log classes separately
from effective classes. `storage` tracks usable SQL tables and retained row count.
`deliveries` and `requested` track queued history and per-reader cooldown.

SQL settings/history survive a reload. Other state belongs to that Lua
interpreter instance and resets on reload. A list refresh preserves hit counts
for hashes still present. Removed hashes lose their statistics.

## Startup and auto configuration

`Main` reads `lua_ledo_conf` once. Missing values use the script's fallback
table; it does not continuously synchronize runtime defaults with Ledokol.

| Ledokol setting | TTHBlock use |
| --- | --- |
| `enablesearfilt`, `addsefifeed`, `sefifeednick` | First sender choice when `from = "auto"`. |
| `useextrafeed`, `extrafeednick` | Second automatic sender choice. |
| `addledobot`, `ledobotnick` | Third automatic sender choice, then `VH.OpChat`. |
| `avsearchint`, `avsearservaddr` | UDP address when AV scanning is configured. |
| `sefireason`, `thirdacttime` | Auto kick reason and ban-marker duration. |
| `mincommandclass` | Auto command permission, otherwise fallback 5. |
| `classnotisefi` | Auto notification threshold; invalid/mute-11 falls back to 4. |
| `scanbelowclass` | Exclusive scan ceiling; fallback 2. |

`conf.bot` defaults to `TTHBlock` for reply frames, display names, and diagnostics.
An empty `conf.from` follows it. An explicit nickname overrides the feed sender;
`conf.from = "auto"` selects the Ledokol chain above. There is no robot-registration
API call; hub commands still arrive through main chat or PM to `VH.HubSec`.
Nickname configuration rejects NMDC delimiters and control characters.

Automatic feed sender fallback uses the OpChat nickname as a PM sender; delivery still
uses `SendPMToAll` with explicit minimum/maximum classes. It does not broadcast
through OpChat, which would bypass this script's recipient filter.

Auto address may fall back to `0.0.0.0`. One address serves both bind and
advertisement, so a reachable/bindable IPv4 address must be selected for active
result scanning. Probe port is 20201. `conf.skip` is an exclusive ceiling before
startup subtracts one; runtime callbacks admit classes `0 <= class <= conf.skip`.
With fallback `scanbelowclass = 2`, guest/registered classes 0 and 1 are scanned.

`conf.clas = 0` selects Ledokol's command class. Saved/default `feed = 0` selects
the resolved auto feed class; saved/default `logclass = 0` follows effective
`conf.clas`. Feed class 11 is the mute sentinel. Only classes 0-5 and 10 are
valid setting values, plus 11 for feed. Master class 10 always reads commands/logs
and is the only class permitted to write settings.

The hub version is compressed into a decimal compatibility gate for delayed
protocol sends, including the legacy threshold `1.0.2.15`. It is not a general
semantic-version comparison. Check the binding before extending that gate.

## Hash acquisition and timer work

`getlist()` runs curl with redirect, retry and timeout limits. It writes
`<VH:GetVHCfgDir()>/<conf.comm>.tth`, strips CR/LF, and accepts lines of length 39.
The current loader does not independently enforce uppercase base32 on that
file. A usable new list replaces the map and preserves existing hit counts.
Missing/empty/unusable files leave the current map. The temporary file is
removed after a successful open/parse, and `serv.mins` records refresh time.

The downloader is synchronous. `conf.user_agent`, the download path, and
`conf.list` are individually single-quoted, including escaped embedded quotes.
`--` separates the URL from curl options. Configuration remains administrator-owned;
HTTP(S) URLs, safe command basenames, and printable user agents are validated on load.
The default is a Windows Chrome 143 user agent from late 2025.

`VH_OnTimer(msec)` first drains queued history, even if UDP is unavailable.
With a listener it consumes at most ten datagrams, each potentially containing
pipe-separated `$SR` frames. It then rotates one TTH probe every `conf.secs`
and refreshes the list after `conf.mins * 60`. No listener means no active
probe or periodic refresh after the initial load.

When APIs exist, probes iterate the nick list, skip bots and zero-share users,
and use `$SA` for supported TTHS clients or `$Search` otherwise. Older API paths
send `$Search` to the eligible class range. Delayed sends use the configured
`delayed_search` and the compatibility version gate.
Lua numeric zero is truthy. TTHS support therefore requires boolean `true` or
numeric/string value `1`; `0`, `"0"`, `false`, and nil select the ordinary `$Search`.
The offline suite checks the previously incorrect numeric-zero path.

## NMDC and detection paths

NMDC frames end with `|`; the event data for parsed search/passive-result
callbacks omits that final pipe. `$SR` uses byte 5 between filename, size/slots,
TTH/hub, and passive recipient fields. Hash comparisons are case-sensitive.
Search/result parsing admits `[A-Z2-7]` hashes exactly 39 characters long.

| Path | Local outcome | Ledokol event |
| --- | --- | --- |
| `VH_OnParsedMsgSearch` | Drop matched request (`0`); optionally kick. | `sefi_user_block` |
| `VH_OnParsedMsgSR` | Drop matched passive result (`0`). | `avdb_user_detect` |
| UDP `$SR` in timer | Verify hub class/IP; record matched result. | `avdb_user_detect` |

Unmatched, malformed, or excluded-class parsed messages return `1`.
The UDP path also requires the packet IP to equal `VH:GetUserIP(nick)`.
The callback nickname, rather than a claimed passive frame nickname, identifies
the passive sender. Active UDP has no encrypted/authenticated transport layer;
the script's matching source-IP check is the existing trust boundary.

`sefi_user_block` carries `conf.tell nick TTH`. Ledokol parses a 0/1 flag,
nickname, and remaining request text. Its search filter must be enabled, and
its protection and existing-block rules govern adding the user to its list.
TTHBlock has already rejected that matched request locally regardless.

`avdb_user_detect` carries `nick IPv4 path`. The pinned Ledokol handler requires
an IPv4-shaped address, applies protection/share checks, reports to AVDB,
and chooses a connection block or kick using its own settings. Those actions
can create separate operator notifications; TTHBlock feed muting does not
change them. TTHBlock's `conf.kick` only controls search requests.

Matched detections increment the hash count and log every event. `conf.wait`
limits repeated feed notices per searching nickname; it does not rate-limit
history. Logout removes that nickname's feed time and export/cooldown state.

## SQL contracts and failure behavior

`VH:SQLQuery(sql)` returns `(boolean, row count)`; its implementation can push
`true, 0` even after the underlying SQL operation fails. `SQLFetch` uses zero-based
rows from the plugin's shared query object. A subsequent query or another
script's query replaces that result.

The local `query` helper catches API errors and validates row counts.
`writequery` follows a write with `SELECT ROW_COUNT()` and fetches that single
row; nonnegative affected count is required. Inserts/settings/retention then
check the expected affected count where applicable. Do not replace these checks
with the success boolean. Copy query rows before sends or `ScriptCommand`.

| Table | Fields | Purpose |
| --- | --- | --- |
| `lua_tthblock_settings` | `variable` PK, `value` int | Saved `feed` / `logclass`. |
| `lua_tthblock_logs` | `id`, `created_at`, `message` BLOB | Bounded retained history. |

Both tables use InnoDB. A setting write uses REPLACE, updates in-memory values
only after a confirmed write, and logs the change. Saved settings override
defaults. Failed settings initialization selects feed 11 and log class 10.
Further setting commands fail without changing the effective value.

Log messages are converted to NMDC-safe text, control characters are replaced,
and byte length is capped (1024 by default). Hex SQL literals preserve encoded
bytes and avoid dependence on MySQL backslash-escape mode. Retention deletes
oldest IDs above the limit and checks the deletion count.

Log initialization/write/retention failure disables later log writes for that
instance; local TTH filtering continues. Failed SELECT cannot be assumed to
mean an empty history: a zero-row result is cross-checked against COUNT.
Repair permissions/connection and reload; there is no automatic storage-retry loop.

## Commands and exports

`VH_OnHubCommand` recognizes `!`/`+`, matches the configured command exactly
ignoring case, and returns `1` for unrelated commands. Recognized commands
return `0`. Statistics follow the original chat/PM context. Help, setting
responses, and history are private and NMDC-safe.

Setting actions check class 10 before any SQL write. View permission is the
effective command class or master. Logs check their independent threshold
before accepting a count. Counts are decimal integers within 1..1000 by default.
There is no clear/delete/reset/refresh subcommand; unknown actions show help.

An export copies newest SQL rows immediately, formats UTC timestamps, and queues
the result. Limits default to 4 readers, 30 seconds between a user's requests,
20 entries / 4096 body bytes per batch, and 1 second between batches. The actual
line budget reserves room for headers; long messages are already truncated.
Every timer batch rechecks the user's class and stops on demotion, failed send,
completion, or logout. History delivery works with the feed muted or socket down.

## Verification boundaries

`tests/tthblock_test.lua` models callback frames, SQL cursor/affected-row behavior,
class changes, retained rows, failed storage, UDP IP checks, exports, refreshes,
and listener unload. It fakes every external operation and does not test a live
server. Deployments still need actual LuaSocket loading, DB privileges, the
advertised UDP address, and Ledokol policy checked on their installed versions.
Source inspection covers the contracts used by this script, not every feature
of Verlihub, Ledokol, or every possible hub configuration.
