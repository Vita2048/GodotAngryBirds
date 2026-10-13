# Angry Birds in Godot
![Screenshot](assets/GameplayScreenshot.jpg)
Play: https://vita2048.github.io/GodotAngryBirds/

<<<<<<< HEAD
Game play video: https://x.com/VacekvVita/status/2055355105428275361?s=20

## Graphics and impact update

- Outlined characters, beveled wood and stone, reflective glass, and detailed sling bindings.
- Material-specific debris, dust, impact rings, score popups, and brief impact-scaled camera shake.
- Ten synthesized sound effects with randomized pitch, limited simultaneous voices, mute, and volume controls. No downloaded audio assets are required.
- Red warning crates explode when struck and can trigger nearby crates. Blast damage falls off with distance.
- Heavy boulders appear from level 3 onward: hit them or break their wooden supports to send them into structures. Pigs remain the level objective.

Drag a bird from the sling and release to fire. Open **MENU** in the upper right to access **SOUND ON/OFF** and the **Sound volume** slider. Press **CLOSE**, **MENU**, or outside the panel to dismiss it.

Run `godot --headless --path . --script res://tests/enhancements.gd` to check level stability, chain reactions, scoring, completion, and boulder collisions. `tests/capture.gd` saves a rendered level preview when run with a graphical renderer.


## Scoring and material damage

The HUD shows a prominent Level score and a secondary Total score for completed
levels. Win results break down destruction and unused-bird points and animate the
level points into the total. Loss results retain the Level score with "Not added
to total" and leave the Total score unchanged. Only winning
banks an attempt, including 100 points for each unused bird (also one waiting
in the sling). Losing or restarting discards attempt points; result screens cannot
receive further points. A new campaign resets the bank. Blocks award 7 points,
pigs award 50 (including fallen pigs), and explosive crates award 10.

Block impacts use normal contact speed, solver impulse, and reduced mass, with
separate glass, wood, and stone damage thresholds. Blocks settle without collision
damage until the first launch. Existing cracks progressively deepen as health
falls: grain splits in wood, connected radial fractures in glass, and irregular
cracks and corner scuffs in stone. Small debris remains cosmetic.

Run `godot --headless --path . --script res://tests/materials_scoring.gd` for retry,
result locking, duplicate scoring, unused-bird bonus, stale timer, campaign settling,
launch, physical mass-response, and progressive-fracture regression checks.
Run `godot --path . --script res://tests/capture_materials.gd` to regenerate
`tests/material-damage-preview.png` with three damage stages for each material.

Run `godot --path . --script res://tests/capture_scores.gd` to regenerate the HUD,
win, transfer, and loss score previews in `tests/score-*.jpg`.
=======
>>>>>>> c85cf36d0f93dc248b23e75535ed017450f7459c
