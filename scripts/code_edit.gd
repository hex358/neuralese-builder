extends CodeEdit

const WORDS := [
	"and","break","do","else","elseif","end","false","for","function","goto",
	"if","in","local","nil","not","or","repeat","return","then","true",
	"until","while",
	"pairs","ipairs","next","type","tonumber","tostring",
	"math","table","string"
]

func _ready() -> void:
	text_changed.connect(_on_request_code_completion)
	code_completion_prefixes = ["_", ".", ":", "a","b","c","d","e","f","g","h",
		"i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"]

func _on_request_code_completion(...args) -> void:
	for word in WORDS:
		add_code_completion_option(CodeEdit.KIND_PLAIN_TEXT, word, word, Color(1,1,1,1))
	update_code_completion_options(true)
	
