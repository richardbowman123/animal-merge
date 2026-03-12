# Animal Merge — Session Notes

## What this game is
A Suika-style "drop and merge" game built in Godot 4.6, exported to web and hosted on GitHub Pages for mobile play. Drop animals into a container — when two of the same type touch, they merge into the next tier up (Mouse → Frog → Rabbit → Cat → Fox → Penguin → Zebra → Lion → Bear → Elephant → Whale).

## Live link
https://richardbowman123.github.io/animal-merge/

## GitHub repo
https://github.com/richardbowman123/animal-merge

---

## What was done in the last session (Round 3)

### 1. Drop targeting indicator (drop_system.gd)
- Blue target reticle shows where the animal will land
- Uses a physics raycast straight down from the cursor
- Three concentric glowing blue discs that scale with animal size
- Drop line now ends at the actual landing point (floor or another animal)

### 2. Warning lines (container.gd)
- Replaced single red death line with three graduated warning lines
- Yellow at height 7.0, orange at 7.75, red at 8.5
- Lines start dim and pulse when animals reach that height
- Pulse speed increases with urgency (yellow=gentle, orange=moderate, red=panic)

### 3. Warning logic (game.gd)
- Checks all animal positions each frame against the three warning heights
- Skips animals that are still falling (velocity check)
- Only triggers game over when animals stay above red line for 3 seconds
- Resets warning level on game restart

### 4. Stadium crowd (crowd.gd)
- Full circular amphitheatre with 11 sections (one per animal tier)
- 3 rows of stepped seating with wooden bench strips
- Uses real frozen Animal models (not plain spheres)
- Animals face inward toward the arena
- "TEAM [NAME]" labels in front of each section
- Crowd section bounces and shows speech bubble when their animal merges

### 5. Main menu demo (main_menu.gd)
- Cinematic orbiting camera around the arena
- Animated coloured lights
- Smart demo drops that target same-tier animals for merge demonstrations
- Pulsing title with tagline

---

## Outstanding tasks for next session

### Crowd tweaks (still needs work)
The stadium crowd looks better with benches but still needs refinement:
- Some bigger animals may still look cramped in places
- General appearance could be improved — needs to feel more like a real crowd
- Consider adjusting spacing, row heights, or number of animals per section
- Key constants to tweak are at the top of `crowd.gd`:
  - `INNER_RADIUS` (currently 9.0) — how far the first row is from centre
  - `ROW_GAP` (currently 3.0) — distance between rows
  - `ROW_HEIGHT_STEP` (currently 3.0) — how much higher each back row is
  - `SPACING_MULTIPLIER` (currently 2.5) — gap between animals along the row

### Animals move around too much (gameplay issue)
Animals roll and wander too freely after landing, which means same-tier animals frequently bump into each other by accident and merge without the player doing anything. This makes the game too easy — merges should feel like something the player achieves, not something that happens on its own. Needs more friction/damping on the animals so they settle quickly after landing. Relevant code is in `animal.gd` (RigidBody3D properties like linear_damp, angular_damp, friction, physics material) and possibly `animal_data.gd` if per-tier tuning is needed.

### Move folder to experiments/games/
The game currently lives at `experiments/animal-merge/` but other games are in `experiments/games/`. Should move it there for consistency. This needs care because:
- The folder has its own git repo
- GitHub Pages URL would need checking
- CLAUDE.md project index should be updated

---

## Project structure

```
animal-merge/
  docs/                    -- Web export for GitHub Pages
    index.html             -- Entry point (renamed from "Animal Merge.html")
    index.js               -- Engine code
    index.pck              -- Game package
    index.wasm             -- WebAssembly binary
    index.png              -- Splash screen
    index.icon.png         -- Favicon
    index.apple-touch-icon.png
    index.audio.worklet.js
    index.audio.position.worklet.js
  scripts/                 -- All game logic (GDScript)
    animal.gd              -- Animal node (RigidBody3D with visual features)
    animal_data.gd         -- Tier data (names, sizes, colours, scores)
    camera_rig.gd          -- Gameplay camera
    container.gd           -- Glass container with warning lines
    crowd.gd               -- Stadium amphitheatre crowd
    drop_system.gd         -- Aiming, ghost preview, drop targeting
    game.gd                -- Main game loop, scoring, game over
    input_setup.gd         -- Input action setup
    main_menu.gd           -- Cinematic main menu with demo
    merge_system.gd        -- Merge detection, animations, particles
  scenes/
    game.tscn              -- Game scene
    main_menu.tscn         -- Menu scene
  project.godot            -- Godot project file
  export_presets.cfg       -- Web export settings
  Animal Merge.*           -- Raw export files (source for docs/)
```

## How to deploy updates

1. Make changes to scripts in Godot
2. Export the project (Project → Export → Web)
3. Copy the exported "Animal Merge.*" files to the `docs/` folder, renaming them to "index.*"
4. Update `docs/index.html` to replace all "Animal Merge" references with "index"
5. Save to GitHub (git add, commit, push)
6. Wait 1-2 minutes for GitHub Pages to update

## Key technical notes

- **GDScript type inference:** When accessing properties from untyped nodes (like `_container.yellow_line_y`), use explicit types (`var x: float = ...`) not `:=` inference, as GDScript can't infer from Variant
- **Animal facing direction:** Animal eyes/features are on the +Z axis. After `look_at()`, add `rotate_y(PI)` to make them face the target
- **OneDrive + Godot cache:** If Godot shows errors after external edits, close Godot, delete the `.godot` folder, reopen
- **Warning line flicker fix:** Skip animals with `linear_velocity.y < -2.0` to avoid false triggers from falling animals
