class_name ItemSlot
extends TextureRect

var item_instance: ItemInstance

func _ready() -> void:
	update_item_data()
	
func update_item_data() -> void:
	if not item_instance:
		$%ItemLabel.text = ""
		return
		
	$%ItemTexture.texture = item_instance.item_data.icon
	if item_instance.stack_count <= 0:
		$%ItemLabel.text = ""
	else:
		$%ItemLabel.text = str(item_instance.stack_count)
