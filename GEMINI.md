# LeBonBon — "Grow Up to be LeBron" — Project Context

## Overview
A **Roblox idle/tycoon basketball game** built with [Rojo](https://rojo.space/) 7.6.1.
Players earn **Cash** by manually shooting basketballs and by hiring automated **Shooter NPCs** that fire on their own cooldown loops.
Cash is spent in the **Shop** on more shooters, hoop upgrades (score multipliers), and **Rebirths** (permanent earnings boost).

**Build:** `rojo build -o "LeBonBon.rbxlx"`
**Serve:** `rojo serve`
**DataStore key:** `GrowUpLeBron_v1`

---

## Directory Structure

```
src/
  client/
    init.client.luau       -- Entry point; initializes all client managers & builds HUD
    PlacementManager.luau  -- Drag-to-place shooter repositioning (raycast + server sync)
    ShopUI.luau            -- Programmatic shop panel (shooters, hoop upgrades, rebirths)
    VisualManager.luau     -- Shot arc (Bezier), particles, floating text, sounds
  server/
    init.server.luau       -- Entry point; initializes all server managers
    DataManager.luau       -- DataStore persistence, session data, attribute syncing
    NetworkManager.luau    -- Player manual SHOOT button handler (click → cash)
    PlotManager.luau       -- Procedural court generation, plot assignment/release
    ShooterManager.luau    -- NPC shooter spawning, autonomous shot loops, move handling
    ShopManager.luau       -- BuyUpgrade & RebirthRequest RemoteFunction handlers
  shared/
    Config.luau            -- Single source of truth for all game balancing values
    Hello.luau             -- (Unused stub)
```

---

## Roblox Service Mapping (`default.project.json`)

| Source Path   | Roblox Location                          |
|---------------|------------------------------------------|
| `src/shared`  | `ReplicatedStorage.Shared`               |
| `src/server`  | `ServerScriptService.Server`             |
| `src/client`  | `StarterPlayer.StarterPlayerScripts.Client` |

---

## Remotes (all under `ReplicatedStorage.Remotes`)

| Name             | Type             | Direction         | Purpose                                      |
|------------------|------------------|-------------------|----------------------------------------------|
| `ShootRequest`   | RemoteEvent      | Client → Server   | Player clicks SHOOT button                   |
| `MoveShooter`    | RemoteEvent      | Client → Server   | Drag-to-place: "Start", "Cancel", or Vector3 |
| `RenderShot`     | RemoteEvent      | Server → All Clients | Trigger ball arc animation                |
| `BuyUpgrade`     | RemoteFunction   | Client → Server   | Buy shooter tier or hoop upgrade             |
| `RebirthRequest` | RemoteFunction   | Client → Server   | Trigger rebirth reset                        |

---

## Shared Config (`src/shared/Config.luau`)

### Player Starting Stats
```lua
Cash = 0, Rebirths = 0, HoopUpgradeLevel = 1
OwnedShooters = { Rookie=0, College=0, Pro=0, AllStar=0, LeBron=0 }
ShooterPositions = {} -- { Id, Tier, Pos={x,y,z} }
```

### Shooter Tiers
| Tier     | Display Name     | Cooldown | BaseYield | BaseCost | ScaleFactor | Attribute         |
|----------|------------------|----------|-----------|----------|-------------|-------------------|
| Rookie   | Rookie           | 5.0s     | 10        | 50       | 1.30        | Slasher           |
| College  | College Player   | 4.0s     | 40        | 250      | 1.35        | MidRangeDeadeye   |
| Pro      | Pro Player       | 3.0s     | 150       | 1200     | 1.40        | LimitlessRange    |
| AllStar  | All-Star Player  | 2.0s     | 600       | 6000     | 1.45        | LimitlessRange    |
| LeBron   | LeBron James     | 1.5s     | 2500      | 30000    | 1.50        | LimitlessRange    |

Cost scaling: `BaseCost * (ScaleFactor ^ ownedCount)`

### Distance Zones
| Zone        | Max Distance | BaseAccuracy | Multiplier |
|-------------|-------------|--------------|------------|
| Paint       | 15 studs    | 95%          | 1.0x       |
| Mid-Range   | 30 studs    | 70%          | 1.5x       |
| 3-Point     | ∞           | 45%          | 3.0x       |

### Shooter Attributes (zone bonuses)
| Attribute         | Zone Bonus                              |
|-------------------|-----------------------------------------|
| Slasher           | +5% accuracy in Paint, 1.5x multiplier  |
| MidRangeDeadeye   | +15% accuracy Mid-Range, 1.5x multiplier|
| LimitlessRange    | +25% accuracy 3-Point, 2.0x multiplier  |

### Hoop Upgrades (global score multiplier)
| Level | Name                  | Multiplier | Cost    |
|-------|-----------------------|------------|---------|
| 1     | Wooden Hoop           | 1x         | free    |
| 2     | Chain Net Hoop        | 1.5x       | 150     |
| 3     | Glass Backboard Hoop  | 3x         | 750     |
| 4     | Pro Rim Hoop          | 7x         | 3,500   |
| 5     | Golden Hoop           | 20x        | 15,000  |
| 6     | Diamond LeBron Rim    | 100x       | 100,000 |

### Rebirth
- `BaseCost = 50,000`, scales by `2.5 ^ rebirths`
- Each rebirth: `+50% earnings multiplier` (all cash sources)

### Player Manual Shot
- Cooldown: `0.5s` (2 clicks/sec max), BaseYield: `5`

---

## Server Systems

### DataManager
- Stores per-player session data in `sessionData[player]`
- Syncs primitive values to `Player` attributes (for client reads without RemoteFunctions)
- Syncs `Cash` and `Rebirths` to `leaderstats` folder (Roblox leaderboard)
- Shooter counts stored as `Shooter_{Tier}` attributes
- `BindToClose` saves all players on server shutdown
- Key functions: `Get`, `Set`, `AddShooter`, `AddShooterPosition`, `UpdateShooterPosition`

### PlotManager
- Creates **4 plots** procedurally at startup, spaced 80 studs apart
- Each plot: Floor, Court (wood, orange), 3-point line mock, SpawnLocation, SignPost/BillboardGui, Hoop model (Pole, Backboard, Rim, ScoringZone), Shooters folder
- Assigns plots to players on join; releases and clears shooters on leave
- Player is teleported to plot's `Spawn` part on `CharacterAdded`
- Plot attributes: `OwnerId` (0 = unclaimed), `Index`, `CenterPosition`

### ShooterManager
- Spawns blocky NPC models with Torso (jersey color per tier), Head, Headband, Humanoid, face Decal
- Each shooter runs a `task.spawn` loop firing every `cooldown` seconds
- `IsPlacing` attribute pauses the shot loop during drag-to-place
- On shot: calculates zone, applies attribute bonuses, rolls make/miss, awards cash, fires `RenderShot`
- Jump animation on shot (server-side CFrame offsets)
- Model attributes: `ShooterTier`, `OwnerUserId`, `ShooterId`
- `SpawnShootersForPlayer` — full respawn (used on load & rebirth)
- `SpawnSingleShooter` — adds one shooter without disrupting others (used on purchase)

### NetworkManager
- Handles `ShootRequest` with per-player `os.clock()` cooldown cache
- Finds player's plot hoop Rim, measures distance, calculates zone + make/miss + payout
- Fires `RenderShot` to all clients on every shot attempt

### ShopManager
- `BuyUpgrade("Shooter", tier)` — deducts cash, increments owned count, picks a grid position, calls `SpawnSingleShooter`
- `BuyUpgrade("Hoop", "")` — upgrades hoop level
- `RebirthRequest()` — resets Cash/HoopLevel/Shooters/ShooterPositions, increments Rebirths, respawns empty court
- Note: `cloneTable` is defined at module scope (not local) — potential minor code smell

---

## Client Systems

### init.client.luau
- Initializes VisualManager, PlacementManager, ShopUI
- Builds the **SHOOT button** HUD programmatically (orange, FredokaOne, hover/press tweens)
- Fires `ShootRequest` to server on click

### VisualManager
- Listens to `RenderShot` event
- Animates ball along **quadratic Bezier curve** (`RunService.Heartbeat`)
- **Make:** swish sound → gold particles → "SWISH! +Score" floating text → ball falls through net
- **Miss:** offset target to rim edge → clang sound → "MISS!" text → ball bounces away
- Ball rotates during flight for spin effect

### PlacementManager
- Click on own shooter model → enters placement mode
- `RunService.RenderStepped` loop raycasts mouse → snaps shooter to Court/Floor parts
- Left-click to confirm (sends `Vector3` to server), Right-click to cancel
- Shows floating billboard "Relocating... Click Court to Place / Right-Click to Cancel"
- Server clamps final position to court bounds: X ∈ [-18, 18], Z ∈ [-35, 25]

### ShopUI
- Toggle button (left-center screen) opens/closes shop panel
- Glassmorphism dark panel, basketball orange accents, FredokaOne font
- Scrollable list of cards: 5 shooter tiers + Hoop Upgrade + Rebirth
- Cards show title, description, cost, owned count, BUY/LOCK/MAX/UPGRADE button
- Refreshes reactively on `localPlayer.AttributeChanged`

---

## Known Issues / Notes
- `cloneTable` in `ShopManager.luau` is declared as a global-scope function (not `local`) — should be made `local`
- `ShooterManager` waits for `DataManager.Get(player)` in a polling loop on `PlayerAdded` — works but a callback/event approach would be cleaner
- Plot count is hardcoded to 4; adding more players requires increasing this
- `Hello.luau` in shared is an unused stub
