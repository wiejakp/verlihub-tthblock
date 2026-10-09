# Verlihub TTHBlock

[![Lua tests (local)](docs/badges/tests.svg)](docs/testing.md)
[![Line coverage (local)](docs/badges/coverage.svg)](docs/testing.md)
[![GitHub CI](https://github.com/wiejakp/verlihub-tthblock/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/wiejakp/verlihub-tthblock/actions/workflows/tests.yml)
[![Lua runtimes](https://img.shields.io/badge/Lua-5.1%20%7C%205.4-blue)](docs/testing.md)
[![License](https://img.shields.io/github/license/wiejakp/verlihub-tthblock)](LICENSE)

TTHBlock filters NMDC searches and search results for hashes from a configured
blocklist. It runs inside Verlihub's Lua plugin and sends search-filter and AVDB
events to Ledokol. Fork version **0.0.3.8** retains saved notification/log classes
and SQL history, adds configurable identity and HTTP headers, and corrects
numeric TTHS support handling. Credits: **RoLex & PWiAM**.

Project: [wiejakp/verlihub-tthblock](https://github.com/wiejakp/verlihub-tthblock).
Original script: [tthblock.lua](https://ledo.feardc.net/other/tthblock.lua), from
[Ledokol's distribution page](https://ledo.feardc.net/other/).

Notifications start muted. Blocking and history remain active. A class-10 master
can enable notifications, set history access, and inspect retained detections.
Ledokol applies its own protection/action rules and can send its own notifications.

## Requirements

- Verlihub with its Lua plugin loaded, and an account permitted to manage scripts.
- Ledokol loaded first for search-filter block-list and AVDB actions. Local
  rejection of a forbidden search/passive result also happens in TTHBlock itself.
- LuaSocket installed for the exact Lua version/ABI used by the Verlihub plugin.
- `curl` on the hub process's PATH and access to the configured blocklist URL.
- A writable hub configuration directory for the temporary `.tth` download.
- Hub database privileges to CREATE, SELECT, INSERT, and DELETE TTHBlock's tables,
  plus SELECT on Ledokol's `lua_ledo_conf`. REPLACE uses INSERT and DELETE privileges.
- A reachable IPv4 address and UDP port for active-result scanning; default port 20201.

Source syntax is compatible with Lua 5.1 through 5.4. Use the hub's actual Lua
build when checking LuaSocket. Lua 5.5 is a newer language release, not a verified
deployment target for this script. [References](docs/references.md) records the
upstream versions and source commits checked on 2026-10-08.

## Installation

1. Back up an existing `tthblock.lua` before replacing it. Keep only one loaded
   copy of this script, and load Ledokol before it.
2. Install `curl` and the matching LuaSocket package. On a Debian/Ubuntu system
   using distro Lua packages, this commonly means `curl` and `lua-socket`.
   Confirm the module is available to the Lua interpreter embedded in Verlihub;
   successful import from a different system Lua version is insufficient.
3. Edit `defaults` and `conf` near the top of `tthblock.lua` for your hub. Set
   `conf.addr` to an address that this host can bind and clients can reach.
4. Copy the file into your hub's configuration `scripts/` directory. The Lua
   plugin derives this directory from the hub config path; it is not a fixed
   system-wide installation directory.

   ```sh
   cp tthblock.lua /absolute/path/to/hub-config/scripts/tthblock.lua
   ```

5. As a permitted plugin administrator in the hub, inspect and load the script:

   ```text
   !lualist
   !luaload /absolute/path/to/hub-config/scripts/tthblock.lua
   !lualist
   ```

   If already loaded, use `!luareload <script-id>` from `!lualist` instead of
   loading a second instance. The Lua plugin also loads `.lua` files in this
   directory on startup. Script-management commands use Verlihub's configured
   `plugin_mod_class`, independently of TTHBlock's command permission.
6. Verify through a class-10 master account:

   ```text
   !tthblock help
   !tthblock class
   !tthblock logclass
   !tthblock logs 10
   ```

The script creates `lua_tthblock_settings` and `lua_tthblock_logs` with InnoDB.
No separate SQL import is required. The default muted feed will not announce
listener startup; check private history and the hub process log instead.

## Commands

Use main chat or a PM to Hub-Security. Both `!` and `+` prefixes work, and
command/subcommand names ignore case. Changing `conf.comm` changes the command
name everywhere in runtime help; the default is `tthblock`.
Replies use `conf.bot`, default `TTHBlock`. The script labels hub-generated
messages but does not register another bot, so send PM commands to the hub's
configured Hub-Security nickname rather than assuming the reply sender is a user.

| Command | Result |
| --- | --- |
| `!tthblock` | Current in-memory TTH hit statistics. |
| `!tthblock help` | All commands, permissions, classes, and export limits. |
| `!tthblock class` | Configured and effective notification class. |
| `!tthblock class <class>` | Save notification class: 0, 1-5, 10, or 11. |
| `!tthblock logclass` | Configured and effective history access class. |
| `!tthblock logclass <class>` | Save history access class: 0, 1-5, or 10. |
| `!tthblock logs [count]` | Private UTC history, newest first; default 50, max 1000. |

Statistics, help, and setting views require `conf.clas`; a class-10 master always
qualifies. Only class 10 may change settings. History permission uses
`conf.logclass` independently, and class 10 always retains history access.
Unknown subcommands show help to authorized command users.

Class 0 selects auto mode. Notification class 11 mutes this script's feed.
Classes 1-5 and 10 set the minimum notification or log-access class.
Log class 11 is invalid. The muting command preserves filtering and retained
logs; it does not disable Ledokol's separate notifications.

```text
!tthblock class 4
!tthblock logclass 3
!tthblock logs 100
!tthblock class 11
!tthblock class 0
```

Setting writes are saved to SQL and take effect immediately. Reloading the
script preserves them, so editing a default does not replace an existing saved
value. Use the commands to change saved notification/history classes.

Log exports use private batches: at most 20 entries and a 4096-byte body budget,
one second between batches, four simultaneous readers, and a 30-second per-user
request cooldown. Access is checked again before each batch; demotion or logout
cancels an export. These limits are configurable in `defaults`.

## Configuration

Only notification and log-access classes are saved to SQL. Other settings are
source-level configuration and require a script reload after editing.

| `conf` key | Default | Meaning |
| --- | --- | --- |
| `comm` | `tthblock` | Command name and temporary list-file basename. |
| `bot` | `TTHBlock` | Reply sender, default feed sender, display name and diagnostic prefix. |
| `from` | empty | Empty follows `bot`; override with a nick, or `auto` for Ledokol selection. |
| `user_agent` | Chrome 143 / Windows | HTTP User-Agent used by curl; full default below. |
| `tell` | 0 | Ledokol search-block payload flag; 0 silent, 1 notify user. |
| `clas` | 0 | Command permission; auto uses Ledokol, fallback 5. |
| `feed` | 11 | Derived from the saved/default notification class. |
| `logclass` | 0 | Derived from the saved/default history class. |
| `skip` | 0 | Auto scan ceiling; explicit N scans classes 0 through N-1. |
| `wait` | 10800 | Seconds between feed notices for one searching user. |
| `addr` | empty | Bind/advertised UDP IPv4 address; auto may become `0.0.0.0`. |
| `port` | 20201 | UDP listener/advertised port. |
| `secs` | 5 | Interval in seconds between rotating TTH probes. |
| `mins` | 360 | Blocklist refresh interval in minutes. |
| `kick` | false | Kick forbidden search request senders instead of the block event. |
| `text` | empty | Kick reason; auto reads Ledokol and adds its ban marker. |
| `list` | remote URL | Blocklist endpoint; see the source and references. |

The default list URL is
[`https://te-home.net/tthblock.php?do=load`](https://te-home.net/tthblock.php?do=load).
The downloader quotes the URL, file path, and user agent as individual shell
arguments and separates the URL from options with `--`. Keep configuration
administrator-owned and never include credentials in URLs. The expected file
has one uppercase 39-character base32
TTH per line; the current loader checks line width and strips CR/LF.

Change identity and HTTP headers in `conf`, then reload the script:

```lua
bot = "TTHBlock",
from = "", -- follows bot; "auto" restores Ledokol's feed-sender selection
user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " ..
    "(KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36",
```

This is a conventional late-2025 Windows Chrome user agent. Chrome was the
leading browser family; browser share does not establish one universally most
common full user-agent string. [The sources](docs/references.md#http-user-agent)
record the 2025 browser/release references. User agents must contain 1-1024
printable bytes without control characters. Nicknames must contain 1-64 bytes
without spaces, control characters, `$`, `|`, `<`, or `>`.

Runtime version, credits, project URL, and origin URL live in the local `plugin`
metadata table. Update the version there and in the protected source header
together; validation rejects a mismatch or removed copyright/license notices.

| `defaults` key | Default |
| --- | --- |
| `notification_class` | 11 (muted) |
| `log_class` | 0 (follow effective command class) |
| `log_retention` | 10000 entries |
| `log_default_count` | 50 entries |
| `log_request_limit` | 1000 entries |
| `log_message_bytes` | 1024 bytes |
| `log_batch_lines` | 20 entries |
| `log_batch_bytes` | 4096 bytes |
| `log_batch_interval` | 1 second |
| `log_max_readers` | 4 |
| `log_request_cooldown` | 30 seconds |

Defaults are range-checked during load. Invalid defaults stop initialization
with an assertion. Auto mode reads Ledokol's `lua_ledo_conf`; the full mapping
and fallback rules are in [architecture.md](docs/architecture.md#startup-and-auto-configuration).

The same `conf.addr` is used to bind and advertise the UDP listener. `0.0.0.0`
binds interfaces but is not a usable advertised address for ordinary remote
clients. A public NAT address that is not assigned locally cannot be bound
directly. Deploy on a bindable/reachable address or adapt the listener/advertised
address design for that network. TTHBlock does not configure NAT or firewalls.

## Detection, history, and reloads

Forbidden TTH searches are dropped and produce `sefi_user_block`, or invoke
Verlihub's kick API when configured. Passive results are dropped and produce
`avdb_user_detect`. Active UDP results produce the same AVDB event after checking
the hash, class, and source IP against the hub user. Ledokol chooses its action.
This checks known TTHs; it does not inspect file contents or prove a file is safe.

Every detection is logged even when a notification is muted or rate-limited.
Oldest entries are deleted above the retention limit. History also includes
saved setting changes and listener lifecycle/failure messages. Logs contain
nicknames, IPs, hashes, and paths, so grant access to the intended operator class.

The blocklist is downloaded on load, then periodically while the UDP listener
is running. Curl runs synchronously and its retries/timeouts can stall the hub
event loop. The temporary `<hub-config>/<conf.comm>.tth` file is removed after
parsing. A failed/empty refresh keeps the last in-memory list; a fresh reload
does not retain an old in-memory list. There is no manual refresh subcommand.

Reload with `!luareload <script-id>`. SQL settings/history survive; hit counters,
notification cooldowns, and export queues reset. Stop with `!luaunload <script-id>`.
Unload closes the UDP socket and leaves the SQL tables intact.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| No automatic feed | `class` is 11 by default; enable a class as master if wanted. |
| History denied | `logclass`, actual user class, and master-only fallback after DB errors. |
| Settings cannot save | Hub process log, DB connection and table privileges, then reload. |
| No history available | Log storage startup errors or no recorded entries; inspect hub log. |
| Listener cannot start | Matching LuaSocket ABI, bindable address, port collision, UDP reachability. |
| Loaded hashes do not update | Curl/endpoint access and an active UDP listener; refresh is timer-driven. |
| Ledokol still sends notices | Its AVDB/search-filter feeds are controlled separately. |
| Script appears twice | Use `!lualist`; unload the duplicate before reloading the intended copy. |

If settings storage fails, this script mutes the feed and restricts history to
masters. If log storage fails, it disables further log writes but continues
TTH filtering. Missing LuaSocket/listener disables active probes and periodic
list refresh; loaded-hash search/passive filtering and queued history delivery
continue. Repair the cause and reload. The script does not retry failed storage
indefinitely during callbacks.

## Development and AI agents

```sh
make setup
make check
```

`make setup` installs checksum-verified LuaCov 0.17.0 and pinned PyYAML 6.0.3
inside ignored `.tools/`. Development checks need Python 3.11+ with pip, make,
and Lua. `make check` checks syntax, runs the offline suite with a strict 100%
executable-line coverage gate, validates skills/configuration/header integrity,
and runs the local sensitive-data guard and its tests.
Override `LUA`/`LUAC` to use another installed interpreter, for example
`make check LUA=lua5.1 LUAC=luac5.1`. Tests fake VH, SQL, sockets, clock, files and
downloads; they do not connect to a hub or run the real downloader.

`make test`, `make coverage`, and `make check` regenerate the local test and
coverage badges from that run. To regenerate them explicitly:

```sh
make badges
git diff -- docs/badges/
```

Commit `docs/badges/tests.svg` and `docs/badges/coverage.svg` with your changes
after reviewing the results. GitHub displays the updated local badges once you
push them. These badges record the last local run with its Lua version and a
digest of the script, suite, and coverage configuration. Failures replace old
passing results; an unavailable coverage measurement clears the old percentage.

The GitHub workflow runs the same gate on Lua 5.1 and 5.4 with read-only
permissions and no retained checkout credentials. The separate GitHub CI badge
reports actual workflow runs on `main`; local commands do not change its status.
[Testing details](docs/testing.md) explain reports and the limits of offline coverage.

[Repository laws](RULES.md) prohibit agents from pushing or otherwise publishing
code to GitHub, committing sensitive information, or removing the script's
copyright/license header. A human reviews and publishes changes. The local
pre-commit guard scans staged content and reports paths/rules without exposing
matched values; manual review is still required.

[AGENTS.md](AGENTS.md) contains shared instructions for any AI agent.
Claude, Gemini, Codex, Copilot and Cursor have small adapters. Relevant Lua,
Verlihub/Ledokol, testing, writing, privacy, CCE, and task-management skills live
in `.agents/skills`. The pinned no-ai-slop rules and MIT notice are copied from
the reference project's skill system; [provenance](docs/ai/provenance.json)
distinguishes exact copies from adapted practices.

For optional local CCE/CTX dependencies and provider configuration, follow
[the agent setup](docs/ai/README.md). Run `make ai-init`, then restart the agent.
These development tools are not required on the production hub.

## Sources and licensing

[Architecture](docs/architecture.md) records callback, SQL, class and Ledokol
contracts. [References](docs/references.md) lists primary documentation and
pinned source links. This repository includes the GNU General Public License
version 3 in [LICENSE](LICENSE), preserved from its existing GitHub history.
The copied no-ai-slop material retains Peter Yang's MIT notice in its source copy.
