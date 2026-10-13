# Challenge campaign

Layouts and exact bird queues are in `scripts/CampaignLevels.gd`. These levels
are balanced around separate targets, material mass, protected approach angles,
and limited ammunition. Normal pig health and the existing material damage
rules are retained. There are no scripted kills or hidden invulnerable pigs.

| Level | Birds, in order | Challenge |
| --- | --- | --- |
| Stone Farm | Medium, small, large, small | Three separated shelters with thick stone fronts. Use the large bird deliberately; the final small bird provides limited cleanup if a damaged pig survives. |
| Bridge Keep | Small, medium | The bridge can collapse into the ravine, but the elevated stone keep is a separate objective. Both shots must contribute. |
| Quarry Siege | Small, medium, medium | A direct hit releases the boulder against the lower shelter. A stone divider prevents that collapse from also clearing the elevated keep. High shots must clear its protection. |
| Counterweight Fort | Small, medium | A stone guard separates the low guardhouse from the latch. A precise shot through the clearance below the beam releases the counterweight and drops the platform occupants into a pit. The guardhouse still needs another shot. A direct high shot at the platform is an alternative. |
| Double Keep | Small, medium, large | Clear the upper structure and its left support, breach the low front entrance, then use the large bird on an arcing approach to the far entrance. Fixed rock overhangs protect both lower rooms from upper debris. |

The farm permits a small cleanup allowance. The later levels intentionally have
no spare bird in the validated routes. Strong shots aimed at the wrong object
can consume ammunition without advancing another objective. Rare successful
collateral damage is still allowed; there is no artificial minimum shot count.

## Physics and ammunition

- Campaign chickens can be shot for the original bonus: seven birds matching the
  projectile's type and size, or three birds when hit by a bonus bird.
  Once shot, contact with a structure or terrain releases those birds at the
  impact position, even during the shot animation. Swept collision catches thin
  beams during fast falls; each chicken rewards only once.
- The quarry stopper is a frozen, bolted body. Only an actual bird contact (or
  explicit blast damage) can damage it. Boulder's resting pressure cannot release
  it when an unrelated shot enables collision damage.
- The counterweight uses its existing rigid assembly and pin joint. Its protected,
  visibly notched release timber has 30 health; precise placement matters more
  than repeatedly hitting a long exposed column.
- Terrain is visible and uses matching collision polygons. The bridge and the
  counterweight landing pit have actual gaps in the ground.
- Pig health, launch power, bird mass, and global material strengths have not been
  increased or decreased for this difficulty revision.

## Validation

Use Godot 4.7 from the project directory:

```text
godot --headless --path . --script res://tests/puzzles.gd --fixed-fps 60
godot --headless --path . --script res://tests/chickens.gd --fixed-fps 60
godot --headless --path . --script res://tests/campaign_completion.gd --fixed-fps 60
godot --headless --path . --script res://tests/materials_scoring.gd
godot --headless --path . --script res://tests/enhancements.gd
godot --path . --script res://tests/capture_puzzles.gd
```

The challenge test checks untouched stability, no damage after a complete miss,
actual legal shot sequences, the counterweight release, the effect of wasting a
bird on levels 2-5, and repeated unplanned shots. It also checks reset cleanup.
It uses the production 60 Hz physics step. It never deletes targets or grants
extra birds to obtain a win; spent projectiles are retired after settling.
Chicken collisions are disabled only in the balance test harness to isolate
structural difficulty. Gameplay retains chicken rewards; the balance figures
below exclude those optional bonus birds. `tests/chickens.gd` checks this mechanic
separately using actual bird collisions.

`tests/challenge-solutions.json` records the validated shot sequences. The farm's
cleanup shots aim at the surviving pig's current position, accounting for its
movement during the collapse. These are regression fixtures, not an assertion
that a unique solution or minimum possible shot count exists.

For exploratory balance sweeps, use `tests/balance_search.gd` with `-- level=0`
through `-- level=4`. Add `openings-only` to sample opening shots at three speeds.
The search is bounded; failure to find a route does not prove a level impossible.
The screenshot script saves `tests/puzzle-level-1.jpg` through `puzzle-level-5.jpg`.

## Balance check, 2026-10-13

- All five validated routes completed inside their actual queues (4, 2, 3, 2, 3).
- None of 112 sampled targeted opening shots cleared a complete level: 27 farm,
  21 bridge, 18 quarry, 21 counterweight, and 25 fortress samples.
- Fourteen of fifteen repeated-shot trials failed to clear the level with the
  full queue. Occasional successful collateral damage remains possible.
- Wasting the opening bird prevented the validated routes on levels 2-5 from
  clearing within their budgets. The farm intentionally allows a small cleanup
  reserve.
- Challenge, material/scoring, and enhancement regression suites passed.

These are finite automated balance checks, not estimates of human win rates.

## Campaign completion

Clearing the final level shows a congratulations dialog with the committed total
score, completed levels, player-launched birds (including failed attempts),
retries, and active play time. Bonus birds are not counted as slingshot launches.
Confirming returns to the original title screen with an empty board and reset
camera. PLAY starts a fresh campaign. Sound preferences are preserved.
Launched projectiles are marked used immediately so they cannot receive an
unused-bird score bonus while still airborne.

The completion test exercises progression, a retry, final victory, confirmation,
cleanup, delayed callbacks, and starting another campaign. Add `-- capture` when
running with graphics to save the congratulations and returned-title previews.
