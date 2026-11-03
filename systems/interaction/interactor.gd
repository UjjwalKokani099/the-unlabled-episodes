class_name Interactor
extends RayCast3D
## Lives on the player's camera. Every physics frame it casts a ray forward, finds the
## Interactable being looked at, and triggers it on E (instantly, or after holding).
## Walls block the ray, so you can't use things through them.

signal focus_changed(target: Interactable)

## How far the player can reach, in metres.
@export var reach: float = 2.2

## What the player is looking at right now (null = nothing usable).
var focused: Interactable = null
## 0..1 while holding E on a hold-to-use target, otherwise 0.
var hold_ratio: float = 0.0

var _holding: bool = false
var _hold_elapsed: float = 0.0


func _ready() -> void:
	target_position = Vector3(0.0, 0.0, -reach)
	collide_with_areas = true
	collide_with_bodies = true
	collision_mask = 1 | Interactable.LAYER  # world blocks the ray, player layer is ignored


func _physics_process(delta: float) -> void:
	var target: Interactable = _find_target() if _can_act() else null
	if target != focused:
		_set_focus(target)

	if not _holding:
		return
	if focused == null or not Input.is_action_pressed("interact"):
		_cancel_hold()
		return
	_hold_elapsed += delta
	hold_ratio = minf(_hold_elapsed / focused.hold_time, 1.0)
	if _hold_elapsed >= focused.hold_time:
		var used := focused
		_cancel_hold()
		used.interact(owner)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or focused == null or not _can_act():
		return
	get_viewport().set_input_as_handled()
	if focused.hold_time <= 0.0:
		focused.interact(owner)
	else:
		_holding = true
		_hold_elapsed = 0.0


func _find_target() -> Interactable:
	if not is_colliding():
		return null
	var hit := get_collider()
	var found := hit as Interactable
	# Also accept a body that has an Interactable as a direct child.
	if found == null and hit is Node:
		for child in (hit as Node).get_children():
			if child is Interactable:
				found = child
				break
	if found and found.enabled:
		return found
	return null


func _set_focus(target: Interactable) -> void:
	_cancel_hold()
	if is_instance_valid(focused):
		focused.focus_exited.emit()
	focused = target
	if focused:
		focused.focus_entered.emit()
	focus_changed.emit(focused)


func _cancel_hold() -> void:
	_holding = false
	_hold_elapsed = 0.0
	hold_ratio = 0.0


func _can_act() -> bool:
	var player := owner as Player
	return player == null or player.can_act()
