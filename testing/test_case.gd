class_name TestCase
extends RefCounted
## Base of the test files: methods named `test_*` run in order, with `before_each` / `after_each` around them.
## Tests may `await` (frames, signals): they run inside the live SceneTree, autoloads included.

var tree: SceneTree
var failures: PackedStringArray = []
var _nodes: Array[Node] = []


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func eq(actual: Variant, expected: Variant, what: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s: expected %s, got %s" % [what, var_to_str(expected), var_to_str(actual)])


func ok(condition: bool, what: String) -> void:
	if not condition:
		failures.append(what)


## Instantiates `packed` under the root; freed after the test.
func add_scene(packed: PackedScene) -> Node:
	var node: Node = packed.instantiate()
	tree.root.add_child(node)
	_nodes.append(node)
	return node


## Waits `n` process frames (lets _ready, deferred calls and tweens run).
func frames(n: int = 1) -> void:
	for i: int in n:
		await tree.process_frame


## Waits `n` physics frames (movement, collisions). Headless runs make process frames much faster than physics ones.
func physics_frames(n: int = 1) -> void:
	for i: int in n:
		await tree.physics_frame


## Sends an input action press then release, like a key or button would.
func press(action: StringName) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await frames(1)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await frames(1)


func cleanup() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
