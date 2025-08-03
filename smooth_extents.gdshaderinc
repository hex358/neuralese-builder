
instance uniform vec2 extents = vec2(0.0, 0.0);
const float smoothness = 20.0;

float alphamult(vec2 v){
	float a = 1.0;
	if (extents.x != 0.0 || extents.y != 0.0){
	a *= smoothstep(extents.x-smoothness*0.35, extents.x+smoothness*0.65, v.y);
	if (extents.y != 0.0){
	a *= 1.0-smoothstep(extents.y-smoothness, extents.y, v.y);}}
	return a;
	}