extends TextEdit

func _ready() -> void :
	text_changed.connect(_on_text_changed)

func _on_text_changed():
	if "\n" in text:
		text = text.replace("\n", "")
