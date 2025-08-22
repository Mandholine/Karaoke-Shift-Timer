## Script Documentation: Karaoke Shift Timer v1.0

### Script Metadata

*   **Name:** Karaoke Shift Timer
*   **Version:** 1.0
*   **Author:** Trota
*   **Description:** An advanced tool for shifting the timings of subtitle lines (by frames or milliseconds) that preserves relative animations (`\t`, `\move`, `\fad`) and offers precision snapping to video frame boundaries to eliminate flickering, especially in variable framerate (VFR) videos.

---

### Purpose and Motivation

Timing complex karaoke effects is a high-precision task. A common problem, especially with variable framerate (VFR) videos, is the "flickering" or "jittering" of animations. This occurs when a calculated time falls an instant after the start of a frame, causing the renderer to display the effect one frame later than intended. I sought to apply automated effects that detect whether a line is romaji or a translation and apply a universal effect that greatly simplifies the creation of identical effects. These effects use alpha transformations to hide syllables as they are sung and then show them again, synchronizing with the highlight.

The built-in `Shift Timer` in Aegisub, while useful for simple shifts, has two main limitations for this type of work:
* 1.  It only shifts the start and end times of the line, without adjusting the relative timings of transformations (`\t`, `\move`, etc.) within the text, which can break internal synchronization.
* 2.  Its frame-snapping method is not precise enough to prevent flickering in all VFR cases.

This script was created to solve these problems, providing a time-shifting tool that is both **frame-accurate** and **respectful of internal animations**. It adjusts both the start and end of the line and rewrites the internal transformations.

---

### Main Features

*   **Shift by Frames or Milliseconds:** Allows the user to choose the most convenient unit of displacement for their workflow.
*   **Precise Snapping to Frame Boundaries:** This is the core feature. Instead of snapping to the "center" of a frame, the script snaps each time to the start boundary of the visually nearest frame. This completely eliminates the risk of flickering and provides a **safe range** for future adjustments.
*   **Preservation of Relative Animations:** The script intelligently recalculates all timings within the `\t`, `\move`, and `\fad` tags. It maintains the duration and cadence of the original animations, simply relocating them relative to the line's new `start_time`.
*   **Batch and VFR Safety:** The script calculates the millisecond shift for each line individually, avoiding the "drift error" that occurs in VFR videos when processing large numbers of lines. This ensures that even when shifting a large number of frames, it is accurate for both the first and last lines of a large selection.

---

### User Guide

1.  **Select the Lines:** In the Aegisub grid, select one or more dialogue lines you wish to shift.
2.  **Run the Script:** Go to `Automation > Karaoke Shift Timer`.
3.  **Configure the Shift:**
    *   **Shift by:** Choose whether you want to shift by `Frames` or `Milliseconds`.
    *   **Value:** Enter the shift value. Use a negative number to move the lines backward in time and a positive number to move them forward.
    *   **Snap new times to nearest frame boundaries:** This option is enabled by default and is highly recommended. It performs the precision adjustment that prevents flickering. Disable it only if you need an exact mathematical shift without snapping.
4.  **Apply:** Click "OK". The script will process all selected lines.

---

### Technical Analysis (For Developers)

The script solves three key technical problems:

#### Frame Boundary Snapping

The `snap_to_nearest_frame_boundary(ms)` function is the core of the script's precision. Its logic is:
1.  Given a time `ms`, it gets the frame number that contains it (`frame_num`) and the start times of that frame (`t_start_curr`) and the next one (`t_start_next`).
2.  It calculates the temporal midpoint between these two boundaries: `midpoint = t_start_curr + (t_start_next - t_start_curr) / 2`.
3.  This midpoint acts as a threshold. If `ms` is less than `midpoint`, it snaps to `t_start_curr`. If it is greater than or equal, it snaps to `t_start_next`.
4.  This method ensures that the final time always falls on the nearest frame boundary, which is the visually desired behavior to avoid flickering.

#### Preservation of Relative Timings

The native `Shift Timer` only modifies `line.start_time` and `line.end_time`. Our script goes further:
1.  It saves the `original_start_time` of the line.
2.  It calculates the `new_start_time` (shifted and snapped).
3.  Inside the `process_time` function, each relative time (`t1`, `t2`...) from a tag is converted to an absolute time: `absolute_time = original_start_time + relative_time`.
4.  This `absolute_time` is then shifted and snapped.
5.  Finally, it is converted back to a relative time based on the new anchor: `new_relative_time = final_absolute_time - new_start_time`.
This process ensures that an animation that started 100ms after the line's start will continue to start 100ms (snapped to a frame) after the new line start.

#### VFR Batch Safety

To avoid drift error, the millisecond shift calculation (`shift_ms`) when working with `Frames` has been moved **inside the main loop**. For each line, the script:
1.  Gets its `original_start_time`.
2.  Calculates its `start_frame`.
3.  Calculates the `target_frame` (`start_frame + shift_val`).
4.  Gets the `target_ms` for that `target_frame`.
5.  The `shift_ms` for that specific line is `target_ms - original_start_time`.
This guarantees that a shift of N frames is accurate for each line's position on the timeline, regardless of variations in the frame rate.

---

### Comparison: Karaoke Shift Timer vs. Aegisub "Shift Times"

| Feature | **Karaoke Shift Timer (This Script)** | **Aegisub "Shift Times" (Native)** |
| :--- | :--- | :--- |
| **Shift Target** | `start_time`, `end_time` **AND** all timings in `\t`, `\move`, `\fad`. | Only `start_time` and `end_time`. |
| **Shift Units** | Frames, Milliseconds. | Time (hh:mm:ss.cs), Frames, Seconds. |
| **Frame Snapping** | **Snaps to the nearest frame boundary.** Designed to eliminate flickering in VFR. Affects all timings, internal and external. | Simple snap to the start of the frame. Can cause flickering if a time falls very close to the end of a frame. |
| **VFR Safety** | **Very High.** The "Frames" mode calculates the shift per line, avoiding drift errors in large batches. | **Low.** Uses a global ms-per-frame calculation, which causes significant drift errors in large batches on VFR videos. |
| **Animation Integrity** | **Preserved.** Recalculates all relative timings to keep the animation intact. | **Broken.** Does not modify relative timings, desynchronizing internal animations from the line's start time. |
| **Ideal Use Case** | **Karaoke, complex effects (FX), and any timing that requires absolute precision in VFR.** Essential for "sanitizing" timings. | Simple shifts for dialogue or lines without complex internal animations, preferably on CFR videos. |
