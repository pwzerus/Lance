shader_type canvas_item;
render_mode unshaded;

// Generated source plates retain their original alpha on disk. At display size
// reject the soft extraction halo so the mounted pixel silhouette stays crisp.
void fragment() {
	if (COLOR.a < 0.5) {
		discard;
	}
}
