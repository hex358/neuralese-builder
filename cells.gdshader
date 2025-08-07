shader_type canvas_item;

render_mode world_vertex_coords;



uniform float width = 2;

uniform float spacing = 10;

uniform vec4 grid_color: source_color;

uniform vec4 bg_color: source_color;



varying vec2 vert;

void vertex() {

vert = VERTEX;

}



const int extents = 4294967296;



void fragment() {

vec2 outline = mod(vert, spacing);

if (outline.x < width || outline.y < width){

COLOR = grid_color;

}

else{COLOR = bg_color;}


}