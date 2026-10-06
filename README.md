# Offroads

**Play in the browser: <https://ran1979.github.io/offroad/>**

A 3D off-road racing prototype built with **Godot 4** (GDScript), targeting Android phones and playable on desktop.

Pick a car in the showroom, choose **Time Trial** or **AI Race**, and race 3 laps around a dirt circuit with jump ramps, nitro boosts and mid-air control.

## Requirements

- **Godot 4.7** (standard build, not .NET). Other 4.x versions from 4.3 up should work; the project was built and tested on 4.7.2.
  - macOS: `brew install --cask godot` or download from <https://godotengine.org/download>
- For Android builds: Android SDK + OpenJDK 17, configured in Godot under *Editor → Editor Settings → Export → Android*, and Godot's export templates (*Editor → Manage Export Templates*).

## Running locally

```bash
./run.sh          # play (starts at the car-select menu)
./run.sh race     # skip the menu, go straight to the track
./run.sh test     # headless smoke test
./run.sh editor   # open the project in the Godot editor
./run.sh web      # export the web build to build/web
./run.sh deploy   # export and publish to GitHub Pages (gh-pages branch)
```

`run.sh` looks for `godot`, then `godot4` on your `PATH`, then `/Applications/Godot.app`. To use a different binary, set `GODOT=/path/to/godot ./run.sh`.

You can also open `project.godot` in the Godot editor and press **F5**.

## How to play

### Modes

| Mode | Goal |
|------|------|
| **Time Trial** | Solo. Finish 3 laps before the 3:00 countdown runs out. Your best lap is tracked. |
| **AI Race** | Race 3 AI opponents over 3 laps. Your live position is shown; the results screen gives your final rank. |

### Controls

| Action | Keyboard | Touch |
|--------|----------|-------|
| Steer | ← → / A D | ◀ ▶ pads (bottom left) |
| Accelerate | ↑ / W | GAS (bottom right) |
| Brake / Reverse | ↓ / S | BRAKE |
| Nitro | Space / Shift | NITRO |
| Back to menu | Esc | Android back button |

The touch pads also respond to the mouse, so you can try them on desktop.

### Tips

- **Nitro** gives 1.5× power and top speed while held, and drains the blue bar. It refills when you drive fast or drift.
- **In the air**, gas tips the nose down, brake lifts it, and steering rolls the car, so you can line up your landings.
- **Checkpoints** sit at every corner and must be hit in order, so shortcuts don't count.
- **Auto-reset**: if you flip, get stuck, or leave the track for a couple of seconds, you respawn at your last checkpoint.

### Cars

| Car | Acceleration | Top speed | Handling |
|-----|--------------|-----------|----------|
| Dune Buggy | high | medium | high |
| Trophy Truck | medium | high | low |

## Engine and architecture

The game uses Godot's built-in physics: `VehicleBody3D` with four driven `VehicleWheel3D` raycast wheels. The track geometry is generated in code from a list of waypoints, so editing the layout means changing a single array.

```
autoloads/global.gd        Singleton: car roster, selected car, race mode, back-button handling
resources/car_data.gd      CarData resource: id, name, mesh scene, stats (0..1), colour
scripts/car_base.gd        Vehicle physics: engine/brake/steer, nitro, air control, dust/flame, respawn
scripts/ai_car.gd          AI driver node, added to opponent cars; steers to the next required checkpoint
scripts/race_manager.gd    Spawning, countdown, checkpoint/lap validation, positions, results
scripts/offroad_track.gd   Builds road mesh, walls, ramps and checkpoint areas from WAYPOINTS
scripts/chase_camera.gd    Smooth follow camera with a speed-based field-of-view kick
scripts/hud.gd             Speed, nitro bar, lap, timer, position, minimap, results overlay
scripts/touch_controls.gd  Multi-touch pads that press the same InputMap actions as the keyboard
scripts/car_select.gd      Showroom: rotating pedestal, prev/next, mode select

scenes/ui/car_select.tscn        Main scene (menu)
scenes/ui/hud.tscn               Race HUD
scenes/ui/touch_controls.tscn    On-screen controls
scenes/cars/car_base.tscn        Vehicle body, wheels and particles
scenes/cars/buggy_mesh.tscn      Buggy body mesh (parts named Paint* get the car colour)
scenes/cars/truck_mesh.tscn      Trophy truck body mesh
scenes/tracks/offroad_track.tscn Track: environment, ground, camera, race manager, HUD, touch controls
tests/smoke_test.tscn            Headless smoke test
```

### Project settings

- Renderer: **Mobile**
- Base resolution 1280×720, stretch mode `canvas_items` with aspect `expand`, so wide phones (19.5:9 and similar) get extra width while the UI stays anchored to the corners
- Orientation: sensor landscape
- Input actions: `steer_left`, `steer_right`, `accelerate`, `brake`, `nitro`

### Tuning

| What | Where |
|------|-------|
| Car stats | `CarData.create(...)` calls in `autoloads/global.gd` |
| Stat → physics mapping | `apply_data()` in `scripts/car_base.gd` |
| Base physics (suspension, air control, nitro rates) | exports and constants at the top of `scripts/car_base.gd` |
| Track layout, width, ramps | `WAYPOINTS`, `WIDTH`, `RAMPS` in `scripts/offroad_track.gd` |
| Laps, time limit, AI colours | constants at the top of `scripts/race_manager.gd` |
| AI speed and spread | `setup()` in `scripts/race_manager.gd` (`top_speed *= randf_range(...)`, `lane`) |

### Adding a car

1. Build a body scene in `scenes/cars/`. Face it toward **+Z** and name the coloured parts `Paint...`.
2. Add a `CarData.create(...)` entry to `cars` in `autoloads/global.gd`.

## Testing

```bash
./run.sh test
```

This runs an AI race at a fixed 60 fps with no window and checks that:

- the player car passes 60 km/h when holding gas;
- every AI car completes a lap within 60 seconds;
- a checkpoint hit out of order is ignored;
- the final lap brings up the results screen.

It prints `SMOKE OK` on success, or `SMOKE FAIL: ...` and exits with code 1.

## Web build (GitHub Pages)

`./run.sh deploy` exports the **Web** preset and force-pushes the result to the `gh-pages` branch, which GitHub Pages serves at <https://ran1979.github.io/offroad/>. It needs the Godot web export templates installed. The preset has thread support turned off because GitHub Pages can't send the COOP/COEP headers that threaded builds need. In the browser, Godot uses the Compatibility (WebGL 2) renderer.

## Android export

1. Set up the Android SDK and export templates (see Requirements).
2. *Project → Export → Android*. A preset is included (`export_presets.cfg`, package `com.offroads.game`, arm64).
3. Click **Export Project** to build `build/offroads.apk`, or use **Remote Debug** to run on a USB-connected phone.

The Android export has not yet been tested on a real device.
