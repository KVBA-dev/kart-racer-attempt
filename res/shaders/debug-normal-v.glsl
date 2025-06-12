#version 330 core

in vec3 vertexPosition;     // Vertex input attribute: position
in vec2 vertexTexCoord;     // Vertex input attribute: texture coordinate
in vec4 vertexColor;        // Vertex input attribute: color
in vec3 vertexNormal;

out vec2 fragTexCoord;      // To-fragment attribute: texture coordinate
out vec4 fragColor;         // To-fragment attribute: color
out vec3 fragPosition;
out vec3 fragNormal;

uniform mat4 mvp;           // Model-View-Projection matrix
uniform mat4 matModel;
uniform mat4 matNormal;
void main() {
	fragPosition = vec3(matModel * vec4(vertexPosition, 1.0));
	fragTexCoord = vertexTexCoord;
	fragColor = vertexColor;
	fragNormal = normalize(vec3(matNormal * vec4(vertexNormal, 1.0)));
	gl_Position = mvp * vec4(vertexPosition, 1.0);
}
