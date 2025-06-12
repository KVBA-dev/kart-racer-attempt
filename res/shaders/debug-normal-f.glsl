#version 330 core

in vec3 fragPosition;
in vec2 fragTexCoord;
in vec4 fragColor;
in vec3 fragNormal;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

out vec4 finalColor;

void main() {
	vec2 uv = fract(fragTexCoord);
	vec3 norm = fragNormal;

	finalColor = vec4(norm, 1.0);
}
