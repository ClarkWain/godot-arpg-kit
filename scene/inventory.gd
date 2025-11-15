class_name Inventory
extends Control

@onready var inventory_manager: InventoryManager = $InventoryManager

const ITEM_SLOT = preload("uid://de8u1d380t7ll")

func _ready() -> void:
	
	init_data()
	
	init_ui()
	
func init_data() -> void:
	var item_data = preload("res://data/items/generated/fb1597.tres")
	var item_instance = ItemInstance.create(item_data, 10)
	inventory_manager.add_item(item_instance)
	
	item_data = preload("res://data/items/generated/fb1577.tres")
	item_instance = ItemInstance.create(item_data, 10)
	inventory_manager.add_item(item_instance)
	
	item_data = preload("res://data/items/generated/fb1578.tres")
	item_instance = ItemInstance.create(item_data, 10)
	inventory_manager.add_item(item_instance)
	
	item_data = preload("res://data/items/generated/fb1579.tres")
	item_instance = ItemInstance.create(item_data, 10)
	inventory_manager.add_item(item_instance)
	
	item_data = preload("res://data/items/generated/fb1580.tres")
	item_instance = ItemInstance.create(item_data, 10)
	inventory_manager.add_item(item_instance)
	
	item_data = preload("res://data/items/generated/fb1581.tres")
	item_instance = ItemInstance.create(item_data, 10)
	inventory_manager.add_item(item_instance)

func init_ui():
		
	for i in range(inventory_manager.slot_count):
		var slot = ITEM_SLOT.instantiate() as ItemSlot
		var item_instance = inventory_manager.get_item(i)
		slot.item_instance = item_instance
		$%SlotGrid.add_child(slot)
		
