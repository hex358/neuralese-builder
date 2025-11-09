extends CodeEdit


var parser := Commands.CommandParser.new()

var ct: int = 0
@export var console: RichTextLabel
func debug_print(text: String):
	ct += 1
	console.append_text("[" + str(ct) + "] " + text + "\n")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and event.keycode == KEY_ENTER:
		var line = text.strip_edges().strip_escapes()
		var result = parser.parse(line)
		if result.has("error"):
			debug_print("[color=coral]" + result["error"] + "[/color]")
		else:
			var cmd_name = result["command"]
			var def: Commands.CommandDef = parser.registry[cmd_name]
			def.handler.call(result)
		await get_tree().process_frame
		clear()


func _ready():
	syntax_highlighter.define_group("commands", syntax_highlighter.C_CMD, 
	["load", "save", "drop", "rename", "filter"])
	syntax_highlighter.define_group("meta", syntax_highlighter.C_META, 
	["begin", "commit", "undo", "redo"])
	syntax_highlighter.define_group("arguments", syntax_highlighter.C_ARG, 
	["col", "row", "as", "by", "on"])
	parser.register(Commands.CommandDef.new(
		"filter",
		_on_filter_command,
		[
			Commands.CommandArg.new("action", false),
			Commands.CommandArg.new("condition", false)
		],
		["keep-even", "drop-empty"],
		"Filters rows by an optional condition. Examples:\n   filter if row > 5\n   filter keep if row > 5\n   filter drop if col == 0",
		false
	))


func _on_filter_command(data: Dictionary):
	print("Filter command:", data)


func _on_train_2_released() -> void:
	console.clear()
