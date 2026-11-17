shader_type canvas_item;
render_mode unshaded;

// Generated source plates retain their original alpha on disk. At display size
// reject the soft extraction halo so the mounted pixel silhouette stays crisp.
void fragment() {
	// Cut extraction halos in the SOURCE, not node/vertex fade alpha. Using
	// COLOR.a made the entire rider blink out when an occlusion fade crossed .5.
	if (texture(TEXTURE, UV).a < 0.5) {
		discard;
	}
}
