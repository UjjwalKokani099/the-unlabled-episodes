# Skills (Claude Code)

Reference skills from [MonumentalSystems/atlas-agent-teams](https://github.com/MonumentalSystems/atlas-agent-teams)
(MIT, see LICENSE-atlas-agent-teams), commit 826a409, installed Nov 2026:

| Skill | From team | Used for |
|---|---|---|
| blender | 3d-design | Blender workflow; we drive Blender headless from Python (tools/blender/) |
| modeling | 3d-design | topology, edge flow, poly budgets for characters and architecture |
| rigging | 3d-design | armatures, weights, naming for the character skeletons |
| texturing | 3d-design | UVs, PBR maps, texel density |
| asset-optimization | 3d-design | LODs, poly/draw-call budgets (RTX 3050 Ti + iPad web build) |
| animation | 3d-design | animation principles (procedural CharacterLife still drives motion) |
| godot | game-dev | general Godot patterns (this project's CLAUDE.md wins on conflicts) |

Only the SKILL.md texts were copied. The teams' telemetry hooks and MCP server configs
(disabled npm packages for Blender/Maya/Unity) were left out on purpose.
