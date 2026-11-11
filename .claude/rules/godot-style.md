# GDScript style
- Godot 4.4, GDScript only. Static typing on every function signature, member and local where the type is not obvious.
- Files and folders `snake_case`; classes `PascalCase` (`class_name` only when reused); constants `UPPER_SNAKE`; private members `_leading_underscore`; signals in past tense.
- `game/sim/` is plain GDScript: no Node, no scene tree, no `randf()`. Take a seed or a `RandomNumberGenerator` as input so results are reproducible.
- Scenes and `ui/` read simulation state and send input; they never hold rules.
- Design space is 1280×720, touch controls pinned to the screen corners. Test layouts at 1280×720 and one wider phone ratio.
- Use `tr("KEY")`; never put a user-facing string literal in a script.
