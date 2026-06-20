# Ghost Tag

Playable Godot 4 prototype for a top-down horror ghost-tag game. The project is self-contained and uses only built-in shapes, editor scenes, and procedural lighting.

## Folder structure

```text
CodexDemo2/
├── project.godot
├── README.md
├── scenes/
│   ├── Main.tscn
│   ├── Player.tscn
│   ├── Ghost.tscn
│   ├── Key.tscn
│   ├── ExitDoor.tscn
│   ├── HidingSpot.tscn
│   └── UI.tscn
└── scripts/
    ├── Main.gd
    ├── Player.gd
    ├── Ghost.gd
    ├── Key.gd
    ├── ExitDoor.gd
    ├── HidingSpot.gd
    └── UI.gd
```

## What is implemented

- WASD top-down movement
- `Shift` sprint with stamina drain and regeneration
- Mouse-aimed flashlight with battery drain and recharge
- `E` to enter and exit hiding spots
- Three collectible keys
- Locked exit that opens after all keys are collected
- Ghost AI with `PATROL`, `INVESTIGATE`, `CHASE`, and `SEARCH`
- Basic line-of-sight using wall raycasts
- Noise-based hearing for walking and sprinting
- Fear meter, warning UI, paranormal fake-out events, screen tinting, and mild camera shake
- Flashlight slowing effect when the ghost is inside the cone
- Restart flow for game over or victory

## Setup in Godot 4

1. Open Godot 4.x.
2. Choose **Import** and select [project.godot](/Users/ddh/Downloads/CodexDemo2/project.godot).
3. Let Godot re-save imported scene metadata if prompted.
4. Open [scenes/Main.tscn](/Users/ddh/Downloads/CodexDemo2/scenes/Main.tscn) and run the scene.

## GitHub Pages

- The repo includes [export_presets.cfg](/Users/ddh/Downloads/CodexDemo2/export_presets.cfg) with a `Web` export preset.
- The Pages workflow at [.github/workflows/deploy-pages.yml](/Users/ddh/Downloads/CodexDemo2/.github/workflows/deploy-pages.yml) downloads Godot 4.2.2, exports the project to Web, and deploys it with GitHub Pages.
- After enabling Pages with **Source = GitHub Actions**, the published project URL should be `https://dd-ching.github.io/CodexDemo2/`.

## How each scene is set up

### Main.tscn

- Root `Node2D` with [scripts/Main.gd](/Users/ddh/Downloads/CodexDemo2/scripts/Main.gd)
- Child nodes:
  - `World`
  - `Map`
  - `Props`
  - `Actors`
  - `CanvasModulate`
- The script builds the building layout in code, spawns the player, ghost, keys, hiding spots, exit, and UI, then wires signals.

### Player.tscn

- Root `CharacterBody2D` with [scripts/Player.gd](/Users/ddh/Downloads/CodexDemo2/scripts/Player.gd)
- Child nodes:
  - `CollisionShape2D`
  - `Body`
  - `PersonalLight`
  - `FlashlightCone`
  - `InteractionArea`
  - `Camera2D`

### Ghost.tscn

- Root `CharacterBody2D` with [scripts/Ghost.gd](/Users/ddh/Downloads/CodexDemo2/scripts/Ghost.gd)
- Child nodes:
  - `CollisionShape2D`
  - `Body`

### Key.tscn

- Root `Area2D` with [scripts/Key.gd](/Users/ddh/Downloads/CodexDemo2/scripts/Key.gd)
- Child nodes:
  - `CollisionShape2D`
  - `Visual`

### ExitDoor.tscn

- Root `Area2D` with [scripts/ExitDoor.gd](/Users/ddh/Downloads/CodexDemo2/scripts/ExitDoor.gd)
- Child nodes:
  - `CollisionShape2D`
  - `Visual`

### HidingSpot.tscn

- Root `Area2D` with [scripts/HidingSpot.gd](/Users/ddh/Downloads/CodexDemo2/scripts/HidingSpot.gd)
- Child nodes:
  - `CollisionShape2D`
  - `Visual`

### UI.tscn

- Root `CanvasLayer` with [scripts/UI.gd](/Users/ddh/Downloads/CodexDemo2/scripts/UI.gd)
- Child nodes:
  - HUD labels for keys, ghost state, warnings, and fear
  - stamina and battery bars
  - center event message label
  - overlays for heartbeat, flicker, and silhouette fake-outs
  - end screen panel with restart button

## Controls

- `WASD`: move
- `Shift`: sprint
- Mouse: aim flashlight
- Left mouse button: toggle flashlight
- `E`: enter or exit a hiding spot

## Testing checklist

1. Start the scene and confirm the player spawns in the upper-left room.
2. Walk and sprint to verify stamina drains and regenerates.
3. Toggle the flashlight and verify the battery bar drains and recharges.
4. Enter a hiding spot with `E`, then leave it with `E` again.
5. Collect all three keys and verify the exit changes from locked to unlocked.
6. Walk near the ghost to trigger `INVESTIGATE` and `CHASE`.
7. Touch the ghost to confirm game over.
8. Reach the exit with all keys to confirm victory.

## Version 0.2 ideas

- Replace procedural geometry with a TileMap and authored room dressing
- Add actual audio for heartbeat, whispers, and proximity stingers
- Give the ghost pathfinding with `NavigationAgent2D`
- Add flashlight pickups or finite batteries
- Add multiple ghost archetypes with different senses
- Add doors, room-specific interactions, and a larger map with randomized key spawns
