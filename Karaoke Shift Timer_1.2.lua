--[[
	Script: Karaoke Shift Timer
	Autor: Trota
	Version: 1.2
	Description: Shifts the timings of the selected lines without altering the internal text block.
	             This preserves relative animations like \t, \move, and \fad.
                 Optionally, snaps all new times (line start/end and internal tags) individually 
                 to the NEAREST video frame boundary. Handles VFR correctly for large batches.
                 NEW: Optionally re-calculates \k durations to snap syllable changes to frame boundaries,
                 preventing flickering in complex KFX.
]]

script_name = "Karaoke Shift Timer"
script_description = "Shifts line times and snaps all timings to the nearest frame boundary."
script_author = "Trota"
script_version = "1.2"

function snap_to_nearest_frame_boundary(ms)
	if not ms then return 0 end
	local video_loaded = aegisub.project_properties().video_file
	if not video_loaded or video_loaded == "" then return ms end

	local frame_num = aegisub.frame_from_ms(ms)
	if not frame_num then return ms end

	local t_start_curr = aegisub.ms_from_frame(frame_num)
	if not t_start_curr then return ms end

	local t_start_next = aegisub.ms_from_frame(frame_num + 1)

	if not t_start_next then
		return t_start_curr
	end

	local midpoint_between_frames = t_start_curr + (t_start_next - t_start_curr) / 2

	if ms < midpoint_between_frames then
		return t_start_curr
	else
		return t_start_next
	end
end

function shift_lines_final(subs, sel)
	if #sel == 0 then return end

	local dialog_config = {
		{ class = "label", label = "Shift by:", x = 0, y = 0, width = 1, height = 1 },
		{ name = "shift_mode", class = "dropdown", x = 1, y = 0, width = 1, height = 1, items = {"Frames", "Milliseconds"}, value = "Frames" },
		{ name = "shift_val", class = "intedit", value = 0, x = 2, y = 0, width = 1, height = 1 },
		{ name = "snap_frames", class = "checkbox", label = "Snap new line times to nearest frame boundaries", value = true, x = 0, y = 1, width = 4, height = 1 },
		{ name = "sanitize_k", class = "checkbox", label = "Sanitize \\k timings (snaps syllable changes to frames)", value = false, x = 0, y = 2, width = 4, height = 1, hint = "This alters \\k durations to prevent flicker in complex effects. Use only if needed." }
	}
	
	local pressed, result = aegisub.dialog.display(dialog_config, {"OK", "Cancel"})
	if pressed ~= "OK" then aegisub.cancel() end
	
	local shift_val = result.shift_val
	local shift_mode = result.shift_mode
	local should_snap = result.snap_frames
	local should_sanitize_k = result.sanitize_k -- Nueva opción
	
	-- Si no hay desplazamiento y ninguna opción de snap está activa, no hacer nada.
	if shift_val == 0 and not should_snap and not should_sanitize_k then return end
	
	aegisub.progress.title("Karaoke Shift Timer")

	for i, line_idx in ipairs(sel) do
		local line = subs[line_idx]
		if line.class == "dialogue" and not line.comment then
			local original_start_time = line.start_time
			local shift_ms = 0

			if shift_mode == "Frames" then
				local start_frame = aegisub.frame_from_ms(original_start_time)
				if start_frame then
					local target_frame_start_ms = aegisub.ms_from_frame(start_frame + shift_val)
					if target_frame_start_ms then
						shift_ms = target_frame_start_ms - original_start_time
					end
				end
			else
				shift_ms = shift_val
			end
			
			local new_start_time = original_start_time + shift_ms
			local new_end_time = line.end_time + shift_ms
			
			if should_snap or should_sanitize_k then -- La sanitización requiere un start_time ajustado
				new_start_time = snap_to_nearest_frame_boundary(new_start_time)
				new_end_time = snap_to_nearest_frame_boundary(new_end_time)
			end
			
			local texto_modificado = line.text

			local function process_time(relative_time_str)
				local relative_time = tonumber(relative_time_str)
				if not relative_time then return relative_time_str end

				local absolute_time = original_start_time + relative_time
				local shifted_absolute_time = absolute_time + shift_ms
				
				local final_absolute_time = shifted_absolute_time
				if should_snap or should_sanitize_k then
					final_absolute_time = snap_to_nearest_frame_boundary(shifted_absolute_time)
				end
				
				local new_relative_time = final_absolute_time - new_start_time
				return new_relative_time
			end

			-- Procesamiento de tags con tiempos relativos (\t, \move, \fad)
			texto_modificado = texto_modificado:gsub("(\\[%d]*t)%((%-?%d+%.?%d*),%s*(%-?%d+%.?%d*),?(.-)%)", function(tag, t1, t2, rest)
				local new_t1 = process_time(t1)
				local new_t2 = process_time(t2)
				if rest and rest ~= "" then
					return string.format("%s(%d,%d,%s)", tag, new_t1, new_t2, rest)
				else
					return string.format("%s(%d,%d)", tag, new_t1, new_t2)
				end
			end)
			texto_modificado = texto_modificado:gsub("(\\move)%((.-,.-,.-,.-,)(%-?%d+%.?%d*),%s*(%-?%d+%.?%d*)%)", function(tag, first_four_params, t1, t2)
				local new_t1 = process_time(t1)
				local new_t2 = process_time(t2)
				return string.format("%s(%s%d,%d)", tag, first_four_params, new_t1, new_t2)
			end)
			texto_modificado = texto_modificado:gsub("(\\fad)%((%-?%d+%.?%d*),%s*(%-?%d+%.?%d*)%)", function(tag, t1, t2)
				local new_t1 = process_time(t1)
				local new_t2 = process_time(t2)
				return string.format("%s(%d,%d)", tag, new_t1, new_t2)
			end)
			texto_modificado = texto_modificado:gsub("(\\fad)%((.-,.-,.-,)(%-?%d+%.?%d*),%s*(%-?%d+%.?%d*),%s*(%-?%d+%.?%d*),%s*(%-?%d+%.?%d*)%)", function(tag, first_three_params, t1, t2, t3, t4)
				local new_t1 = process_time(t1); local new_t2 = process_time(t2); local new_t3 = process_time(t3); local new_t4 = process_time(t4)
				return string.format("%s(%s%d,%d,%d,%d)", tag, first_three_params, new_t1, new_t2, new_t3, new_t4)
			end)
			
			-- Lógica de sanitización
			if should_sanitize_k then
				local cumulative_time_ms_relative = 0
				
				texto_modificado = texto_modificado:gsub("(\\[kK][f]?)(%d+)", function(tag, duration_cs)
					local original_duration_ms = tonumber(duration_cs) * 10
					
					-- Calcular el punto final absoluto teórico de esta sílaba.
					local absolute_end_point = new_start_time + cumulative_time_ms_relative + original_duration_ms
					
					-- Ajustar (snap) este punto final al fotograma más cercano.
					local snapped_absolute_end_point = snap_to_nearest_frame_boundary(absolute_end_point)
					
					-- Calcular la nueva duración real en milisegundos.
					local new_duration_ms = snapped_absolute_end_point - (new_start_time + cumulative_time_ms_relative)
					
					-- Asegurarse de que la duración no sea negativa por errores de redondeo.
					if new_duration_ms < 0 then new_duration_ms = 0 end
					
					-- Actualizar el cursor de tiempo para la siguiente sílaba.
					cumulative_time_ms_relative = cumulative_time_ms_relative + new_duration_ms
					
					-- Convertir la nueva duración a centisegundos (redondeando) y reconstruir el tag.
					local new_duration_cs = math.floor(new_duration_ms / 10 + 0.5)
					
					return tag .. new_duration_cs
				end)
			end
			
			line.text = texto_modificado
			line.start_time = new_start_time
			line.end_time = new_end_time

			subs[line_idx] = line
		end
		
		if aegisub.progress.is_cancelled() then break end
		aegisub.progress.set(i / #sel * 100)
	end
	
	aegisub.set_undo_point("Karaoke Shift Timer 1.2")
end

aegisub.register_macro(script_name, script_description, shift_lines_final)