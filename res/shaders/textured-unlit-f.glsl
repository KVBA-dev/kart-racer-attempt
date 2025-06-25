#version 330 core

in vec2 fragTexCoord;
in vec4 fragColor;
out vec4 finalColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

void main() {
	vec2 uv = fract(fragTexCoord);

	finalColor = colDiffuse * texture(texture0, uv);
}
