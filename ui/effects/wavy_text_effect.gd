extends RichTextEffect
class_name WavyTextEffect

var bbcode: String = "wavy"


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var index: int = char_fx.relative_index
	var elapsed_time: float = char_fx.elapsed_time
	var influence: float = _get_step_influence(char_fx, index, elapsed_time)

	var amp: float = _get_float_param(char_fx, "amp", 3.0)
	var speed: float = _get_float_param(char_fx, "speed", 2.2)
	var phase: float = _get_float_param(char_fx, "phase", 0.45)
	var wave: float = sin(elapsed_time * speed + float(index) * phase)
	char_fx.offset.y += wave * amp * influence

	var x_amp: float = _get_float_param(char_fx, "x_amp", 0.0)
	if not is_zero_approx(x_amp):
		var x_speed: float = _get_float_param(char_fx, "x_speed", speed)
		char_fx.offset.x += cos(elapsed_time * x_speed + float(index) * phase) * x_amp * influence

	var pulse: float = _get_float_param(char_fx, "pulse", 0.0)
	if not is_zero_approx(pulse):
		var pulse_speed: float = _get_float_param(char_fx, "pulse_speed", speed)
		char_fx.offset.y += sin(elapsed_time * pulse_speed) * pulse * influence

	_apply_color_fx(char_fx, index, elapsed_time, influence)
	return true


func _get_step_influence(char_fx: CharFXTransform, index: int, elapsed_time: float) -> float:
	var sequence_len: int = maxi(0, int(_get_float_param(char_fx, "len", 0.0)))
	if sequence_len <= 0:
		return 1.0

	var step_duration: float = maxf(0.01, _get_float_param(char_fx, "step_duration", 0.08))
	var step_gap: float = maxf(0.0, _get_float_param(char_fx, "step_gap", 0.02))
	var step_total: float = step_duration + step_gap
	var cycle_time: float = step_total * float(sequence_len)
	var cycle_position: float = fmod(elapsed_time, cycle_time)
	var active_index: int = int(floor(cycle_position / step_total))
	var is_active_step: bool = index % sequence_len == active_index
	var step_position: float = fmod(cycle_position, step_total)
	if is_active_step and step_position <= step_duration:
		return 1.0
	return 0.0


func _apply_color_fx(char_fx: CharFXTransform, index: int, elapsed_time: float, influence: float) -> void:
	var hue_amp: float = _get_float_param(char_fx, "hue_amp", 0.0)
	var glow_amp: float = _get_float_param(char_fx, "glow_amp", 0.0)
	if is_zero_approx(hue_amp) and is_zero_approx(glow_amp):
		return

	var source_color: Color = char_fx.color
	var target_hue: float = source_color.h
	var target_saturation: float = source_color.s
	var target_value: float = source_color.v

	if not is_zero_approx(hue_amp):
		var hue_speed: float = _get_float_param(char_fx, "hue_speed", 1.0)
		var hue_phase: float = _get_float_param(char_fx, "hue_phase", 0.2)
		var hue_offset: float = sin(elapsed_time * hue_speed + float(index) * hue_phase) * hue_amp * influence
		target_hue = wrapf(target_hue + hue_offset, 0.0, 1.0)

	if not is_zero_approx(glow_amp):
		var glow_speed: float = _get_float_param(char_fx, "glow_speed", 1.0)
		var glow: float = (sin(elapsed_time * glow_speed + float(index) * 0.15) * 0.5 + 0.5) * glow_amp * influence
		target_saturation = clampf(target_saturation + glow * 0.25, 0.0, 1.0)
		target_value = clampf(target_value + glow, 0.0, 1.0)

	char_fx.color = Color.from_hsv(target_hue, target_saturation, target_value, source_color.a)


func _get_float_param(char_fx: CharFXTransform, key: String, fallback: float) -> float:
	var value: Variant = char_fx.env.get(key, fallback)
	return float(value)
