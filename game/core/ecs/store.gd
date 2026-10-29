extends RefCounted
## Component storage (plan 48): one Dictionary per component type, entity id -> record. A record is a
## plain data object (a RefCounted with typed fields, game/core/components/). Each component type has
## exactly one owning system, the only one that adds, replaces, or removes it (`owner`); any system
## may read it. The store does not enforce ownership at runtime: tests do (owner_of, owners).

## Component name -> {entity id: record}.
var _tables: Dictionary = {}
## Component name -> the system that owns it.
var _owners: Dictionary = {}


## Declares a component type and the system that owns it. False if it is already declared.
func declare(component: String, owner: String) -> bool:
	if _tables.has(component):
		return false
	_tables[component] = {}
	_owners[component] = owner
	return true


func declared(component: String) -> bool:
	return _tables.has(component)


func owner_of(component: String) -> String:
	return _owners.get(component, "")


## Every declared component and its owner.
func owners() -> Dictionary:
	return _owners.duplicate()


## Sets an entity's record of a declared component (adding or replacing it).
func put(id: int, component: String, record: RefCounted) -> void:
	assert(_tables.has(component), "undeclared component " + component)
	_tables[component][id] = record


## An entity's record of a component, or null.
func get_record(id: int, component: String) -> RefCounted:
	return _tables.get(component, {}).get(id, null)


func has_record(id: int, component: String) -> bool:
	return _tables.get(component, {}).has(id)


func remove(id: int, component: String) -> void:
	_tables.get(component, {}).erase(id)


## Removes every record an entity has (when it is destroyed).
func remove_all(id: int) -> void:
	for table: Dictionary in _tables.values():
		table.erase(id)


## The ids that have a component, in the order their records were first added.
func ids_with(component: String) -> Array[int]:
	var ids: Array[int] = []
	ids.assign(_tables.get(component, {}).keys())
	return ids


## The ids that have every one of `components`.
func ids_with_all(components: Array[String]) -> Array[int]:
	var found: Array[int] = []
	if components.is_empty():
		return found
	for id: int in ids_with(components[0]):
		var complete: bool = true
		for component: String in components.slice(1):
			complete = complete and has_record(id, component)
		if complete:
			found.append(id)
	return found
