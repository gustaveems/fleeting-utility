class_name LockSet
extends RefCounted
## LOGIC — a set of named locks. Locked while ANY owner holds one.
##
## WHY NOT A BOOL
## --------------
## PlayerMovement.input_locked and InteractionController.is_locked used to be plain
## bools with six independent writers, and the last writer won. For example, the
## self-soothing compulsion ended with `is_locked = false` and so silently released
## the permanent post-climax interaction lock. With named owners, each system can only
## release its own lock:
##
##     locks.acquire(&"compulsion")   ...   locks.release(&"compulsion")
##
## Acquiring twice under one owner is idempotent; releasing a lock you never took is a
## no-op.

var _owners: Dictionary = {}


func acquire(lock_owner: StringName) -> void:
	_owners[lock_owner] = true


func release(lock_owner: StringName) -> void:
	_owners.erase(lock_owner)


func is_locked() -> bool:
	return not _owners.is_empty()


func holds(lock_owner: StringName) -> bool:
	return _owners.has(lock_owner)


## Snapshot of current owners (debugging, save system).
func owners() -> Array[StringName]:
	var out: Array[StringName] = []
	for o in _owners:
		out.append(o)
	return out
