# The House of Fighting

A Roblox game, in early setup.

> **Status: scaffold only.** The stage in `src/` is a placeholder circular
> arena that exists so the project is playable end to end while the design is
> settled. It is meant to be replaced, not extended.

## Layout

Source of truth is this repo. The `.rbxl` place file is a build artifact and is
never committed.

```
default.project.json     maps folders onto Studio services
src/shared/              -> ReplicatedStorage
src/server/              -> ServerScriptService
src/client/              -> StarterPlayer/StarterPlayerScripts
```

The filename suffix decides the instance type: `.server.luau` becomes a
`Script`, `.client.luau` a `LocalScript`, and a bare `.luau` a `ModuleScript`.
Renaming a file renames the instance.

## Working on it

Requires [Rojo](https://rojo.space) 7.7+. From the repo root:

```bash
rojo serve
```

Open Roblox Studio on a Baseplate, click the **Rojo** tab, and Connect. Edits
to any file under `src/` reach Studio in about a second. Press Play to test.

Delete the Baseplate's default `SpawnLocation` the first time — the arena
builds its own.

To produce a place file without opening Studio:

```bash
rojo build -o build/TheHouseOfFighting.rbxlx
```

## Placeholder stage

`src/shared/StageConfig.luau` holds every tunable value:

| Setting | Effect |
| --- | --- |
| `Radius` | Size of the arena floor |
| `WallHeight` | `0` for a ring-out arena; raise it to enclose the space as a room |
| `SpawnCount` | Spawn pads, spread evenly around a circle |
| `FallGrace` | How far you fall before you are placed back on a pad |

Falling off puts you straight back on a spawn pad rather than running the death
and respawn cycle, and increments a `Falls` stat.
