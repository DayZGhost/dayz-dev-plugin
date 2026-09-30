# Testing Mods on a Local Dedicated Server

A mod is only proven to work when a server has loaded it. Syntax checks and a successful PBO
build do not show that the scripts compile, that a `modded class` or `override` is legal, or
even that the engine loaded the scripts at all. A local dedicated server answers all three in
under a minute, with no client and no players.

Everything below was verified with the native Linux `DayZServer` binary of DayZ 1.29. The
Windows server (`DayZServer_x64.exe`) takes the same parameters; its lookup is described at the end.

## 1. Use the server the Steam client already installed

**Preferred:** the "DayZ Server" tool (Steam app **223350**) installed by the user's Steam client.
It is already authenticated and Steam keeps it at the current build, which a client must match.

**Fallback, avoid:** a separate `steamcmd` install:

```sh
steamcmd +force_install_dir <dir> +login <user> +app_update 223350 validate +quit
```

- It cannot log in anonymously. App 223350 needs an account that owns DayZ, so the user has to
  type a password and a Steam Guard code.
- You have to update it yourself, or it drifts from the client build.

Only use it when the user asks for an install they can break freely.

### Find the install

Ask Steam's own metadata instead of guessing paths. `scripts/find-dayzserver.sh` (in this skill;
`${CLAUDE_SKILL_DIR}` is the skill's directory):

1. reads `steamapps/libraryfolders.vdf` of every known Steam root (native, Debian/Ubuntu, Flatpak,
   Snap, macOS, or `$STEAM_ROOT`);
2. looks for `steamapps/appmanifest_223350.acf` in each library;
3. prints `steamapps/common/<installdir>`.

```sh
"${CLAUDE_SKILL_DIR}/scripts/find-dayzserver.sh" -v   # -v: buildid + StateFlags on stderr
```

- Exit 0 means found. `StateFlags` 4 means fully installed; anything else means Steam is still
  downloading or updating, and the script warns.
- Exit 1 means it is not installed, and the script prints how to install it.
- Trust the manifest, not the `"apps"` list inside `libraryfolders.vdf`, which can be stale.
  On the verification machine, 223350 was installed but missing from that list.

Manual equivalent:

```sh
grep '"path"' ~/.steam/steam/steamapps/libraryfolders.vdf        # the libraries
ls <library>/steamapps/appmanifest_223350.acf                     # the one that has it
grep installdir <library>/steamapps/appmanifest_223350.acf        # usually "DayZServer"
```

### Not installed: ask the user

Do not install it yourself: it needs the user's Steam session and several GB of disk. Tell the
user:

> The DayZ Server is not installed. In Steam, open the Library, enable the **Tools** filter and
> install **DayZ Server** (your account must own DayZ), or run
> `steam steam://install/223350` to open the install dialog. Tell me when it has finished.

After they confirm, run the script again. Continue only once it exits 0 with `StateFlags` 4.

## 2. Never write into the Steam install: build your own server tree

Steam owns the install directory: an update or a "Verify integrity" may overwrite what you put
there. The server also writes into it: running it from there leaves `storage_1/` persistence
in the mission folders and core dumps in the working directory.

**Do not copy, edit or create anything in the Steam directories.** Build a tree of your own
that symlinks into them, and run the server from that tree:

```sh
TREE=$("${CLAUDE_SKILL_DIR}/scripts/make-server-tree.sh" ~/dayz-testserver)   # any path outside Steam
```

`make-server-tree.sh [<tree>] [<steam server dir>]` finds the install with `find-dayzserver.sh`
and creates:

| In the tree | What it is |
|---|---|
| `DayZServer`, `addons/`, `dta/`, `sakhal/`, ... | one symlink per top-level entry of the Steam install |
| `serverDZ.cfg` | a copy, yours to edit (mission `template`, ports) |
| `mpmissions/<mission>/` | a real directory of per-file symlinks, so `storage_1/` is written into the tree |
| `keys/`, `battleye/` | real directories of per-file symlinks; add your own `.bikey` here (the `battleye/` here holds the BattlEye binaries, not the RCon config) |
| `profiles/` | for `-profiles=profiles` |

Rules for working with the tree:

- **Editing a Steam-provided file:** replace its symlink with a copy first. Editing through the
  symlink would change the Steam install:
  `cp --remove-destination "$(readlink "$TREE/mpmissions/<m>/init.c")" "$TREE/mpmissions/<m>/init.c"`
- **After a Steam update:** re-run the script. It refreshes the symlinks and keeps your real files.
- **The tree is disposable:** a real directory, never a git checkout. Delete it to start clean.
- **One tree per running server.** See the next section.

### Never run two servers on the same tree

A running server locks its `profiles/` directory (log files) and the `storage_1/` persistence in
its mission folder. Two servers started against the same `-profiles=` or the same
`mpmissions/<mission>/` collide: one fails to start, or both corrupt each other's logs and
persistence, and the logs you read afterwards belong to neither. This holds even when the
second server "only" runs for a minute.

To debug several configurations in parallel (with and without a mod, two mods against each other,
a baseline next to a change), give every server a tree of its own:

```sh
TREE_A=$("${CLAUDE_SKILL_DIR}/scripts/make-server-tree.sh" ~/dayz-testserver-a)
TREE_B=$("${CLAUDE_SKILL_DIR}/scripts/make-server-tree.sh" ~/dayz-testserver-b)
```

Every tree has its own `profiles/`, `mpmissions/` and `battleye/`, so nothing is shared except
the read-only symlinks into Steam. Mods can be symlinked into several trees. Do not point a
second `-profiles=` at a directory inside the first tree as a shortcut: `mpmissions/` would still
be shared, and its `storage_1/` is the other lock. Sequential runs may reuse one tree.

### Never leave a port at its default

Every server needs its own **game, Steam query and RCon port**, none of them a default. The
defaults (game 2302, query 2303, RCon 2306) are what a real server, a DayZ client on the same
machine, or the previous test run is most likely still holding. A collision may not produce an
error: the server starts and answers on the wrong socket, or RCon silently does not come up.
Take random free ports instead:

```sh
set -- $("${CLAUDE_SKILL_DIR}/scripts/free-ports.sh" 3)
GAME=$1 QUERY=$2 RCON=$3
```

`free-ports.sh [N]` prints N ports that are unused for both UDP and TCP right now, avoid
2302-2306 and 27015-27017, and differ from each other by at least 10, because the server also
uses the ports next to its game port. Apply them in the tree before the first start:

| Port | Where to set it |
|---|---|
| game | `-port=$GAME` on the command line |
| Steam query | `steamQueryPort = $QUERY;` in the tree's `serverDZ.cfg` (add the line if the file has none) |
| RCon | `RConPort $RCON` in the BattlEye seed config `$TREE/profiles/battleye/beserver_x64.cfg` (see below) |

The Steam install's `serverDZ.cfg` has no port lines, so a fresh tree runs on the built-in
defaults until you add them. Pick new ports for every tree and every run: they are only free at
the moment `free-ports.sh` checks them.

**The RCon config lives in the profile directory, not in `battleye/`.** With
`-profiles=profiles` the server reads `$TREE/profiles/battleye/beserver_x64.cfg` once, writes
its working copy `beserver_x64_active_<hex>.cfg` (lowercase hex suffix) next to it, and uses only
that copy from then on. So a seed file is ignored as soon as an active file exists:

```sh
mkdir -p "$TREE/profiles/battleye"
rm -f "$TREE"/profiles/battleye/beserver_x64_active_*.cfg     # stale copy would keep the old port
printf 'RConPassword %s\nRestrictRCon 0\nRConPort %s\n' \
    "$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c10)" "$RCON" > "$TREE/profiles/battleye/beserver_x64.cfg"
```

Generate a random RCon password too; never use a fixed one. Only create the seed when the test
needs RCon. To read the password or port of a run that already happened, look in the
`beserver_x64_active_*.cfg` file (the seed may be absent).

### Mods are symlinks in the tree too

```sh
ln -sfn "$PWD/build/@MyMod" "$TREE/@MyMod"          # your build output: rebuild, rerun, no copy step
W=$("${CLAUDE_SKILL_DIR}/scripts/find-dayzserver.sh" -w)   # workshop items the DayZ client downloaded
grep -h '^name' "$W"/*/mod.cpp "$W"/*/meta.cpp       # find the id of a mod by name
ln -sfn "$W/1559212036" "$TREE/@CF"                  # Community Framework
ln -sfn "$W/1559212036/keys/"*.bikey "$TREE/keys/"   # only for -mod= with signature checks
```

The workshop directory is `<library>/steamapps/workshop/content/221100/<publishedid>`, in the
library that holds the DayZ client (221100). It only contains the items the user subscribed to.
If a needed mod is missing, ask the user to subscribe to it in the Steam Workshop and start the
DayZ launcher once so Steam downloads it. Never `steamcmd +workshop_download_item` into the
Steam directories.

## 3. Run it headless

```sh
cd "$TREE" && ulimit -c 0 && timeout -k 15 60 ./DayZServer \
    -config=serverDZ.cfg -profiles=profiles \
    -servermod=@MyMod "-mod=@CF" -port=$GAME -nosplash -nopause -dologs
```

Launch rules:

- **Mod paths must be relative to the server directory** (the tree). Absolute paths in
  `-servermod=` or `-mod=` are silently ignored: the engine probes the folder but loads no PBO
  from it, and prints no error. Relative paths through symlinks, or with `../`, work. `-config`
  and `-profiles` accept absolute paths.
- **Run from the tree.** The engine resolves `addons/` and `mpmissions/` against the working
  directory.
- **Set `ulimit -c 0`.** A crashing server writes a core file of up to ~5 GB into the working
  directory.
- **Stop it with `timeout -k 15 60`.** The server is ready within seconds (mission loaded after
  ~10 s) and then idles forever without players, so 60 s is plenty. A quiet log is not a slow
  server; it means your code did not run.
  - Keep the `-k`. After a clean shutdown (`Termination successfully completed` in the RPT), the
    process can hang forever in Steam API threads, and only the follow-up SIGKILL ends it.
- **Don't `pkill -f DayZServer` in the same command line.** The pattern matches the shell
  running the pkill. Use the PID, or `timeout`. The process shows up as `enfMain` in `ps`, not
  `DayZServer`.
- **Never use the default ports.** Pass `-port=$GAME` from `free-ports.sh` and set the query and
  RCon ports in the tree too (see above). A fixed "spare" port such as 2402 works for one run
  and fails the moment a second server or a leftover process is around.
- **One tree per concurrent server.** Never start two servers on the same `profiles/` or
  `mpmissions/`; build a second tree instead.
- **`-mod=`** is for mods the client must load too. A headless test still only proves the
  server side.

## 4. Read the result

The profile directory (`$TREE/profiles`) gets `script_<date>.log`, `DayZServer_<date>.RPT` and `error.log`.

```sh
grep -h 'Module: Game; loaded' "$TREE"/profiles/script_*.log # file/class count per script module
grep -h 'SCRIPT.*(E)' "$TREE"/profiles/script_*.log          # compile errors
grep -h 'MyMod' "$TREE"/profiles/script_*.log                # your own Print() lines
```

1. **Did the scripts load at all?** First run the same command without `-servermod` to get the
   vanilla baseline: 416 Game-module files on 1.29. With the mod, the count must be higher, by the
   number of script files in that module. **An unchanged count means the mod's scripts were not
   loaded**, even though the server started fine and printed no error.

   Common silent causes:
   - an absolute mod path;
   - a PBO without the prefix header that `config.cpp`'s script paths expect. Packing with
     dayz-dev-tools needs `pbo -H prefix=<prefix> ...`; AddonBuilder uses `-prefix=`. Without it,
     the defines from `CfgMods` show up in the log, but no scripts do.
2. **Did they compile?** `SCRIPT    (E)` lines are compile errors. The tag is space-padded, so
   grepping for the literal `SCRIPT (E)` never matches.
3. **Did your code run?** Add a `Print("MyMod: loaded ...")` to a mission or init hook. It is the
   cheapest proof. Debug prints in a scratch copy of the mod are fine.

Only a boot catches some errors that pass every static check:

- engine classes that cannot be `modded` (for example `DayZPlayerInventory`);
- `proto native` methods that cannot be overridden (for example `SendSyncJuncture`);
- wrong override signatures.

## 5. Code that needs players

There is no client, so hooks that players drive (actions, inventory, damage, vitals) never fire
on their own. Drive them from a scratch copy of the mod, outside the repository, with a debug
call. For example, from a mission hook:

- spawn a player with `g_Game.CreatePlayer(null, "SurvivorM_Mirek", pos, 0, "NONE")`;
- give it an item with `CreateInHands`;
- call the method under test.

A player spawned this way has no `PlayerIdentity`, so code that filters on `GetIdentity()` skips
it. Mark such runs as partial, and say what the headless run did not cover (real client input,
networking, BattlEye).

## Windows

- The Steam root is in the registry: `HKCU\Software\Valve\Steam`, value `SteamPath` (by default
  `C:\Program Files (x86)\Steam`).
- `libraryfolders.vdf` and `appmanifest_223350.acf` have the same format as on Linux, and the
  binary is `DayZServer_x64.exe`.
- The launch parameters are the same. The `ulimit` and `timeout` advice does not apply; stop the
  server with `Stop-Process`.
- `make-server-tree.sh` is POSIX sh. On Windows, build the same tree with `New-Item -ItemType
  SymbolicLink` (needs Developer Mode or an elevated shell), or with `mklink /J` for directories.
  Not verified on Windows.
