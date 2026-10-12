# Angry Birds in Godot
![Screenshot](assets/GameplayScreenshot.jpg)
Game play video: https://x.com/VacekvVita/status/2055355105428275361?s=20

## Graphics and impact update

- Outlined characters, beveled wood and stone, reflective glass, and detailed sling bindings.
- Material-specific debris, dust, impact rings, score popups, and brief impact-scaled camera shake.
- Ten synthesized sound effects with randomized pitch, limited simultaneous voices, mute, and volume controls. No downloaded audio assets are required.
- Red warning crates explode when struck and can trigger nearby crates. Blast damage falls off with distance.
- Heavy boulders appear from level 3 onward: hit them or break their wooden supports to send them into structures. Pigs remain the level objective.

Drag a bird from the sling and release to fire. Open **MENU** in the upper right to access **SOUND ON/OFF** and the **Sound volume** slider. Press **CLOSE**, **MENU**, or outside the panel to dismiss it.

Run `godot --headless --path . --script res://tests/enhancements.gd` to check level stability, chain reactions, scoring, completion, and boulder collisions. `tests/capture.gd` saves a rendered level preview when run with a graphical renderer.

