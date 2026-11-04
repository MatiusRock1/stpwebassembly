shader_type spatial;

uniform sampler2D full_tex;

uniform float percentage;

void fragment() {
	if(UV.x < percentage) {
		ALBEDO = texture(full_tex, UV).rgb;
	} else {
		ALBEDO = vec3(0, 0, 0);
		ALPHA = 0.0;
	}
	
	ivec2 size = textureSize(full_tex, 1);
	float aspect = float(size.y) / float(size.x);
	
	float ydim = 0.15;
	float xdim = ydim * aspect;
	
	if (UV.x < xdim || UV.y < ydim || UV.x > 1.0 - xdim || UV.y > 1.0 - ydim) {
		ALBEDO = vec3(1, 1, 1);
		ALPHA = 1.0;
	}
}
