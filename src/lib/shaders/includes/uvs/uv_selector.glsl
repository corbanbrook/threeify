
vec2 uvSelector( in int uvIndex, in vec2 uv0, in vec2 uv1, in vec2 uv2 ) {
    switch( uvIndex ) {
        case 0: return uv0;
        case 1: return uv1;
        case 2: return uv2;
    }
    return vec2(0,0);
}
