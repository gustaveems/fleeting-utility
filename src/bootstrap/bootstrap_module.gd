class_name BootstrapModule
extends RefCounted
## BOOTSTRAP — base for one slice of the composition root.
##
## WorkspaceBootstrap runs each phase across ALL modules before starting the next:
##
##   create(ctx)       .new() and configure this module's nodes; register them in ctx.
##                     No add_child, no cross-module references.
##   wire(ctx)         assign @export references and connect signals. Every node of
##                     every module already exists in ctx.
##   attach(ctx)       add_child into the tree. Each node's _ready therefore sees fully
##                     wired exports.
##   post_attach(ctx)  work that needs the live tree or children a node built in its own
##                     _ready (statue narratives, camera placement, seed items).
##
## Override only the phases a module needs.


func create(_ctx: BootstrapContext) -> void:
	pass


func wire(_ctx: BootstrapContext) -> void:
	pass


func attach(_ctx: BootstrapContext) -> void:
	pass


func post_attach(_ctx: BootstrapContext) -> void:
	pass
