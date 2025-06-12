#version 330 core

in vec2 fragTexCoord;       // Fragment input attribute: texture coordinate
in vec4 fragColor;          // Fragment input attribute: color
out vec4 finalColor;        // Fragment output: color

uniform sampler2D texture0; // Fragment input texture (always required, could be a white pixel)
uniform vec4 colDiffuse;    // Fragment input color diffuse (multiplied by texture color)

void main() {
	vec2 uv = fract(fragTexCoord);

	uv.x -= .5;
	if (uv.x == 0) {
		finalColor = vec4(0.3, 0.6, 1.0, 1.0);
		return;
	}
	if (uv.x < 0) {
		finalColor = mix(vec4(0.3, 0.6, 1.0, 1.0), vec4(0.5, 1.0, 1.0, 1.0), -uv.x * 3);
		return;
	}
	finalColor = mix(vec4(0.3, 0.6, 1.0, 1.0), vec4(0.1, 0.1, 0.1, 1.0), uv.x * 3);
}
