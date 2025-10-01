
extends Node

var processes: Dictionary = {}

func _ready() -> void:
	pass
"""
-- Player rect
local player
local blocks = {}
local spawn_timer = 0

function createScene()
    player = Rectangle(140, 20, 28, 12) -- centered bottom
    set_color(player, 0, 0, 1)  -- blue
end

function spawn_block()
    local x = math.random(10, 270)
    local b = Rectangle(x, 180, 14, 14) -- small square block
    set_color(b, 1, 0, 0) -- red
    table.insert(blocks, b)
end

function newFrame(dt)
    -- player movement
    if get_key("left") then
        move(player, -100 * dt, 0) -- slower because smaller screen
    end
    if get_key("right") then
        move(player, 100 * dt, 0)
    end

    -- clamp player inside screen
    if get_x(player) < 0 then set_pos(player, 0, get_y(player)) end
    if get_x(player) > 280 - get_width(player) then
        set_pos(player, 280 - get_width(player), get_y(player))
    end

    -- spawn blocks
    spawn_timer = spawn_timer + dt
    if spawn_timer > 1.0 then
        spawn_block()
        spawn_timer = 0
    end

    -- move blocks downward
    local alive = {}
    for i, b in ipairs(blocks) do
        move(b, 0, -60 * dt) -- slower fall
        if get_y(b) > -20 then
            table.insert(alive, b) -- still visible
        else
            delete(b) -- remove from engine
        end
    end
    blocks = alive
end

"""

func create_process(name: String, code: String) -> LuaProcess:
	remove_process(name)
	var proc = LuaProcess.new(name, code)
	processes[name] = proc
	return proc

func remove_process(name: String) -> void:
	if processes.has(name):
		var proc: LuaProcess = processes[name]
		proc.stop()
		processes.erase(name)

var _accum_time: float = 0.0
func _process(delta: float) -> void:
	_accum_time += delta
	var frame_step: float = 1 / 30.0
	while _accum_time >= frame_step:
		for p in processes.values():
			p.update(frame_step)
			p.queue_redraw()
		_accum_time -= frame_step
