@tool
class_name LuaHighlighter
extends CodeHighlighter

# Lua-ish palette
const C_KW     := Color8(220, 50, 47)    # crimson keywords
const C_BUILTIN:= Color8(38, 139, 210)   # blue builtins
const C_TYPES  := Color8(42, 161, 152)   # cyan/teal libs
const C_NUM    := Color8(211, 54, 130)   # magenta numbers
const C_STR    := Color8(133, 153, 0)    # green strings
const C_COMM   := Color8(88, 110, 117)   # grey comments
const C_SYM    := Color8(220, 220, 220)  # light grey symbols
const C_TEXT   := Color8(240, 240, 240)  # default text
const C_FUNC   := Color8(181, 137, 0)    # yellow functions
const C_MEMBER := Color8(108, 113, 196)  # violet table members

func _init() -> void:
	number_color = C_NUM
	symbol_color = C_SYM
	function_color = C_FUNC
	member_variable_color = C_MEMBER

	# Lua reserved words
	_add_keywords_color([
		"and","break","do","else","elseif","end","false","for","function","goto",
		"if","in","local","nil","not","or","repeat","return","then","true",
		"until","while"
	], C_KW)

	# Builtins
	_add_keywords_color([
		"print","pairs","ipairs","next","type","tonumber","tostring","error",
		"pcall","xpcall","select","require","dofile","load","loadfile","rawget",
		"rawset","rawequal","setmetatable","getmetatable"
	], C_BUILTIN)

	# Standard libs
	_add_keywords_color([
		"math","table","string","utf8","os","debug","coroutine"
	], C_TYPES)

	# Comments
	add_color_region("--", "", C_COMM, true)
	add_color_region("--[[", "]]", C_COMM, false)

	# Strings
	add_color_region("'", "'", C_STR, false)
	add_color_region("\"", "\"", C_STR, false)
	add_color_region("[[", "]]", C_STR, false)

func _add_keywords_color(words: PackedStringArray, color: Color) -> void:
	for w in words:
		add_keyword_color(w, color)
