# Asset Recommendations & Placeholders

For this premium "Angry Birds-style" game, you'll want high-quality vector or clean cartoon-style sprites.
Currently, the game uses the default Godot `icon.svg` scaled and tinted as placeholders for all visual elements.

## Replaceable Placeholder Sprites
- **Bird Sprites (`Bird.tscn`)**: Currently `icon.svg` (white). You need `bird_red.png`, `bird_yellow.png`, and `bird_black.png`.
- **Pig Sprites (`Pig.tscn`)**: Currently `icon.svg` (green). You need `pig_normal.png`, `pig_damaged.png`.
- **Block Sprites (`Block.tscn`)**: Currently `icon.svg` (brown/grey/cyan). You need:
  - `wood_block_long.png`, `wood_block_square.png`
  - `stone_block_long.png`, `stone_block_square.png`
  - `glass_block_long.png`, `glass_block_square.png`
- **Slingshot (`LevelTemplate.tscn`)**: Needs `slingshot_base.png`, `slingshot_fork.png`.
- **Background (`LevelTemplate.tscn`)**: Needs `sky_bg.png`, `hills_bg.png`, `clouds_parallax.png`.

## Recommended Free Asset Packs
1. **Kenney.nl Physics Pack**: https://kenney.nl/assets/physics-assets
   - Great for wood, stone, glass blocks, and simple character shapes.
2. **Kenney.nl Animal Pack**: https://kenney.nl/assets/animal-pack-redux
   - Can be used for various bird and pig alternatives.
3. **OpenGameArt.org "Angry Birds clone" collections**: 
   - Search for "angry birds" on OpenGameArt to find full drop-in replacement kits with slingshots, birds, pigs, and blocks.

## Audio Assets
Placeholders are noted in code. Use **Kenney.nl UI Audio** and **Impact Sounds** for:
- `launch.wav` (bird launched)
- `wood_crash.wav`, `stone_crash.wav`, `glass_shatter.wav`
- `pig_pop.wav`
- `victory.ogg`, `fail.ogg`
