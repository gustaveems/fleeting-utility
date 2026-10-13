extends BootstrapModule
## The player body, the fixed iso camera and the screen-space post pass (which also
## draws the soft-boundary vignette).
## These persist across every world, so they live outside any WorldRoot.

## Tunneling safety clamp, inset past the wall faces. With free roam (2026-10-11 pivot)
## the WorkspaceBlockout wall colliders do the real containment.
const WALL_INSET := 0.35


func create(ctx: BootstrapContext) -> void:
	ctx.player = PlayerMovement.new()
	ctx.player.name = "Player"

	ctx.camera = WorkspaceCamera.new()
	ctx.camera.name = "WorkspaceCamera"

	ctx.screen_effects = ScreenEffects.new()
	ctx.screen_effects.name = "ScreenEffects"


func wire(ctx: BootstrapContext) -> void:
	ctx.player.room_half_extents = Vector2(
		float(ctx.grid.width_cells) * ctx.grid.cell_size * 0.5 - WALL_INSET,
		float(ctx.grid.depth_cells) * ctx.grid.cell_size * 0.5 - WALL_INSET
	)
	ctx.player.state_machine = ctx.state_machine
	ctx.camera.state_machine = ctx.state_machine
	ctx.screen_effects.state_machine = ctx.state_machine
	ctx.screen_effects.player_movement = ctx.player


func attach(ctx: BootstrapContext) -> void:
	ctx.root.add_child(ctx.player)
	ctx.root.add_child(ctx.camera)
	ctx.root.add_child(ctx.screen_effects)


func post_attach(ctx: BootstrapContext) -> void:
	# Seed the fixed iso standoff BEFORE binding the target: WorkspaceCamera lerps, so
	# starting at the resting position prevents a slide-in from the origin on frame 1.
	ctx.camera.global_position = (
		ctx.player.global_position
		+ ctx.camera.camera_offset
		+ Vector3(0.0, ctx.camera.framing_lift, 0.0)
	)
	ctx.camera.set_target(ctx.player)
