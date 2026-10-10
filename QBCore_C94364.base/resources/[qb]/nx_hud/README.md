# nx_hud

3D-style HUD for FiveM. Works with QBCore, ESX, or standalone.

## Install
1. Drop the `nx_hud` folder into `resources/`.
2. Add `ensure nx_hud` to `server.cfg`, after your framework (`qb-core` or `es_extended`).
3. Remove or disable your old HUD resource so the two don't overlap.
4. Edit `config.lua`: job names, labels, max speed, seatbelt options.
5. In game, press **U** (rebindable under Settings > Key Bindings > FiveM).

## Files
```
nx_hud/
  fxmanifest.lua
  config.lua          shared settings
  client/main.lua     stats loop, vehicle loop, seatbelt, KVP persistence
  server/main.lua     on-duty counts per job
  html/index.html     markup
  html/style.css      themes + 3D look
  html/script.js      rendering, menu, drag-to-move
```

## Features
- **Status rings:** health, armor, hunger, thirst, stamina. They pulse red when health is under 30% or hunger/thirst are under 20%. Rings fade at 100% (toggle in the U menu).
- **Vehicle:** Digital, Racing Arc, or 3D Gauge styles, KMH/MPH, RPM, gear, fuel, seatbelt, engine and body condition (white, yellow, red).
- **Seatbelt:** press `B` to buckle. While unbuckled above 25 km/h the icon blinks red and a beep sounds. While buckled, the exit-vehicle control is blocked. `exports['nx_hud']:IsSeatbeltOn()` is available to other scripts.
- **Duty badge:** shows `Active LSPD: 5` for on-duty police, EMS or mechanics. It is hidden for civilians and off-duty players.
- **U menu:** four themes, speedometer style, units, scale, opacity, per-widget toggles, cinematic bars, drag-to-move, reset layout.
- **Cinematic mode:** the `/cinematic` command or the menu toggle. It also hides the minimap.
- **Persistence:** settings are saved to the player's KVP (`nx_hud:settings`) and loaded on join.

## Framework notes
| Framework | Hunger/thirst | Job and duty |
|---|---|---|
| QBCore | `PlayerData.metadata` | `job.onduty` |
| ESX | `esx_status:onTick` | jobs named `offpolice` etc. count as off duty (`Config.ESXOffDutyPrefix`) |
| Standalone | `exports['nx_hud']:SetNeeds(hunger, thirst)` (client) | `exports['nx_hud']:SetPlayerJob(src, 'police', true)` (server) |

Fuel is read from `Entity(veh).state.fuel` (ox_fuel), falling back to `GetVehicleFuelLevel` (LegacyFuel and similar).

## Optimization notes
- **Change-only updates.** Each loop builds a key string and only calls `SendNUIMessage` when it changes. Standing still costs almost nothing.
- **Loop speed.** On foot the loop runs every 250 ms, in a vehicle every 60 ms, and while out of a vehicle the vehicle loop sleeps 500 ms. Raise `Config.StatusInterval` and `Config.VehicleInterval` if you want to save more.
- **No per-frame Lua loop.** The only `Wait(0)` loop runs while the seatbelt is buckled, and it stops when unbuckled.
- **GPU-friendly CSS.** The UI animates only `transform`, `opacity`, and SVG stroke values on small elements. The pulse and blink effects use `transform` and `opacity` only.
- **Blur kept to a minimum.** `backdrop-filter` is used only in the menu (rarely open) and the Glass theme. Switch off Glass if you see NUI cost on low-end PCs.
- **Server traffic.** Job counts are recomputed every 15 s (and on job or duty changes, debounced 500 ms). They are sent only to on-duty players in configured jobs.
- **No dependencies and no build step.** There is no React or Vue bundle to load or parse.

## Honest performance note
Idle resmon should be about 0.00 to 0.02 ms. Driving will read slightly higher because of the 60 ms vehicle loop. Browser-side (NUI) cost doesn't appear in resmon. Check it with the `nui_devtools` command.

## Customizing
- **Add a job:** add an entry in `Config.Jobs`.
- **Add a theme:** copy a `#app[data-theme=...]` block in `style.css`, add a button in the menu's Theme section in `index.html`.
- **Default layout:** edit `DEFAULTS` at the top of `html/script.js` (positions are percentages of the screen).
