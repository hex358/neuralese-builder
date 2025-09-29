# LuaEnv.gd
class_name LuaEnv
extends Node

var processes: Dictionary = {}

func _ready() -> void:
	create_process(
		"test1",
"""
-- Player rect
local player
local blocks = {}
local spawn_timer = 0

function createScene()
    player = Rectangle(200, 50, 40, 20)
    set_color(player, 0, 0, 1)  -- blue
end

function spawn_block()
    local x = math.random(20, 380)
    local b = Rectangle(x, 300, 20, 20)
    set_color(b, 1, 0, 0) -- red
    table.insert(blocks, b)
end

function newFrame(dt)
    -- player movement
    if get_key("left") then
        move(player, -200 * dt, 0)
    end
    if get_key("right") then
        move(player, 200 * dt, 0)
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
        move(b, 0, -100 * dt)
        if get_y(b) > -20 then
            table.insert(alive, b) -- still visible
        else
            delete(b) -- remove from engine
        end
    end
    blocks = alive
end

"""
	)

func create_process(name: String, code: String) -> LuaProcess:
	var proc = LuaProcess.new(name, code)
	add_child(proc)
	processes[name] = proc
	return proc

func remove_process(name: String) -> void:
	processes.erase(name)

func _process(delta: float) -> void:
	for p in processes.values():
		p.update(delta)
		p.queue_redraw()
