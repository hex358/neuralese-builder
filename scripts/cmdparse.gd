extends Node
class_name Commands

class CommandArg:
	var name: String
	var required: bool
	func _init(_name: String, _required: bool = true):
		name = _name
		required = _required


class CommandDef:
	var name: String
	var args: Array[CommandArg]
	var flags: Array
	var handler: Callable
	var description: String
	var strict: bool

	func _init(_name: String, _handler: Callable, _args := [], _flags := [], _description := "", _strict := true):
		name = _name
		handler = _handler
		args.clear()
		for i in _args:
			args.append(i)
		flags = _flags
		description = _description
		strict = _strict

	func get_usage() -> String:
		var usage = name
		for a in args:
			if a.required:
				usage += " <" + a.name + ">"
			else:
				usage += " [" + a.name + "]"
		for fl in flags:
			usage += " [--" + fl + "]"
		return usage


class CommandParser:
	var registry: Dictionary = {}

	func register(cmd: CommandDef):
		registry[cmd.name] = cmd

	func parse(line: String) -> Dictionary:
		var tokens = _tokenize(line)
		if tokens.is_empty():
			return _err("empty")

		var cmd_name = tokens[0]
		if not registry.has(cmd_name):
			return _err("unknown_cmd", cmd_name)

		# forbid more than one command token per line
		for t in tokens.slice(1, tokens.size()):
			if registry.has(t):
				return _err("multi_cmd", t)

		var def: CommandDef = registry[cmd_name]
		return _parse_tokens(tokens, def)

	func _tokenize(line: String) -> Array:
		var tokens: Array = []
		var curr = ""
		var in_quotes = false
		for ch in line:
			if ch == '"':
				in_quotes = not in_quotes
			elif ch == " " and not in_quotes:
				if curr != "":
					tokens.append(curr)
					curr = ""
			else:
				curr += ch
		if curr != "":
			tokens.append(curr)
		return tokens

	func _parse_tokens(tokens: Array, def: CommandDef) -> Dictionary:
		var data = {"command": tokens[0], "args": {}, "flags": []}
		var i = 1
		var arg_index = 0
		var args_total = def.args.size()

		while i < tokens.size():
			var tok = tokens[i]

			# Handle flags
			if tok.begins_with("--"):
				var flag_name = tok.substr(2)
				if flag_name not in def.flags:
					return _err("unknown_flag", flag_name, def)
				data["flags"].append(flag_name)
				i += 1
				continue

			# --- STRICT MODE ---
			if def.strict:
				if arg_index < args_total:
					var arg = def.args[arg_index]
					# if this is the last arg -> greedy absorb
					if arg_index == args_total - 1:
						var remaining: Array = []
						while i < tokens.size() and not tokens[i].begins_with("--"):
							remaining.append(tokens[i])
							i += 1
						data["args"][arg.name] = " ".join(remaining)
						break
					else:
						data["args"][arg.name] = tok
						arg_index += 1
						i += 1
				else:
					return _err("too_many_args", tok, def)

			# --- NON-STRICT MODE ---
			else:
				# in non-strict, first arg is treated as optional keyword (e.g. keep/drop/if)
				if arg_index < args_total:
					var arg = def.args[arg_index]
					if arg_index == args_total - 1:
						var remaining: Array = []
						while i < tokens.size() and not tokens[i].begins_with("--"):
							remaining.append(tokens[i])
							i += 1
						data["args"][arg.name] = " ".join(remaining)
						break
					else:
						data["args"][arg.name] = tok
						arg_index += 1
						i += 1
				else:
					# extra tokens become part of last arg text
					data["args"]["condition"] = (data["args"].get("condition", "") + " " + tok).strip_edges()
					i += 1

		# validate required args
		for a in def.args:
			if a.required and not data["args"].has(a.name):
				return _err("missing_args", [a.name], def)

		return data

	func _err(code: String, extra = null, def: CommandDef = null) -> Dictionary:
		var msg = ""
		match code:
			"empty":
				msg = "No command entered."
			"unknown_cmd":
				msg = "Unknown command: '%s'" % extra
			"multi_cmd":
				msg = "Multiple commands not allowed: '%s'" % extra
			"unknown_flag":
				msg = "Unknown flag '--%s'" % extra
			"too_many_args":
				msg = "Unexpected argument '%s'" % extra
			"missing_args":
				msg = "Missing required arguments: %s" % str(extra)
			_:
				msg = "Parse error"

		if def:
			msg += "\nUsage:\n   %s\n%s" % [def.get_usage(), def.description]
		elif code == "unknown_cmd":
			msg += "\n\nAvailable commands:"
			for c in registry.values():
				msg += "\n  - %-12s" % [c.name]
		return {"error": msg}
