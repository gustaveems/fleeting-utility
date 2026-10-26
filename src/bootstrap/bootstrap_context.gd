class_name BootstrapContext
extends RefCounted
## BOOTSTRAP — typed registry of every node the composition root builds.
##
## Modules fill this during their create() phase and read it during wire(). Because
## every module creates before any module wires, a module may reference a node another
## module owns regardless of module order. That ordering independence is the point: the
## old single-file bootstrap handed CoreHud its InteractionController and
## EndgameLoopManager before they existed, so the interaction prompt and the loop
## flavor text silently never appeared.
##
## Adding a system (audio, VFX, persistence) = a new module plus its fields here.

## The composition root itself (workspace.tscn's Node3D).
var root: Node3D

## --- data ----------------------------------------------------------------------------
var grid: WorkspaceGridData
var state_data: PlayerStateData
var entropy_data: WorkspaceEntropyData
var state_machine: PlayerStateMachine

## --- environment ---------------------------------------------------------------------
var world_env: WorldEnvironment
var apartment_environment: Environment

## --- apartment world -----------------------------------------------------------------
var apartment: WorldRoot
var key_light: DirectionalLight3D
var lamp: OmniLight3D
var clutter: VisualClutterManager
var decals: SurfaceDegradation
var atmosphere: AtmosphereController
var bench_area: Node3D
var spatial_grid: SpatialGrid
var bench: CraftingBench
var trivial_object: TrivialObject
var easel: Easel
var cot: Cot
var door: ApartmentDoor

## --- runtime-packed stand-ins for real .tscn assets ----------------------------------
var raw_compound_scene: PackedScene
var pill_scene: PackedScene
var clutter_scene: PackedScene

## --- player --------------------------------------------------------------------------
var player: PlayerMovement
var camera: WorkspaceCamera
var screen_effects: ScreenEffects

## --- dreamscape ----------------------------------------------------------------------
var valley: DreamscapeEnvironment
var dreamscape_manager: DreamscapeManager
var dreamscape_hud: DreamscapeHud
var ambulance: AmbulanceInterception
var statue_narratives: Array[StatueNarrative] = []

## --- narrative systems ---------------------------------------------------------------
var interaction: InteractionController
var endgame: EndgameLoopManager
var self_soothing: SelfSoothingController
var park: CorporateParkManager
var ransacked: RansackedStateManager
var dual_vision: DualVisionController
var hesitation: HesitationController
var game_flow: GameFlow
var day_cycle: DayCycle

## --- audio + vfx ---------------------------------------------------------------------
var audio_director: AudioDirector
var vfx_director: VfxDirector

## --- persistence -----------------------------------------------------------------------
var persistence: Persistence

## --- ui ------------------------------------------------------------------------------
var core_hud: CoreHud
var settings_applier: SettingsApplier
var fader: ScreenFader
var end_card: EndCard
var lease_renewal: LeaseRenewal
var pause_menu: PauseMenu
var lease_signing: LeaseSigning
var head_call: HeadCall
var night_zero: NightZero
var choices: ChoicePanel
var dialogue: DialogueRunner
var act_one: ActOne
var bench_station: BenchStation
var metro_carriage: MetroCarriage
var metro_ride: MetroRide
var promises: Promises
var ad_screen: AdScreen
