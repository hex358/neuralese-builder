extends Node


func spring(from:, to, t: float, frequency: float = 4.5, damping: float = 5.0):
	t = clamp(t, 0.0, 1.0)
	var omega = frequency * PI * 2.0
	var decay = exp(-damping * t)
	var factor = 1.0 - decay * (cos(omega * t) + (damping / omega) * sin(omega * t))
	return from + (to-from) * factor
