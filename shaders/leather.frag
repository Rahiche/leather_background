// This shader code was adapted from an original metal shader by @dejager.
// Original source: https://github.com/dejager/wallpaper/
// Follow the creator on Twitter: https://twitter.com/dejager

#include <flutter/runtime_effect.glsl>

uniform vec2 resolution;
uniform vec2 u_lightPosition;

vec2 hash(vec2 p) {
    p = vec2(dot(p, vec2(127.1,311.7)), dot(p,vec2(269.5,183.3)));
    return fract(p);
}

vec3 voronoi(vec2 x) {
    vec2 n = floor(x);
    vec2 f = fract(x);

    vec2 mg, mr;

    vec3 m = vec3(8.0);
    for(int j = -1; j <= 1; j++) {
        for(int i = -1; i <= 1; i++) {
            vec2 g = vec2(float(i), float(j));
            vec2 o = hash(n + g);

            vec2 r = g - f + o;
            float d = dot(r, r);

            if(d < m.x) {
                mr = r;
                mg = g;
                m = vec3(d, o.x, o.y);
            }
        }
    }

    float md = 8.0;
    for(int j = -2; j <= 2; j++) {
        for(int i = -2; i <= 2; i++) {
            vec2 g = mg + vec2(float(i), float(j));
            vec2 o = hash(n + g);
            vec2 r = g - f + o;

            if(dot(mr - r, mr - r) > 0.00001) {
                md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
            }
        }
    }
    return vec3(sqrt(m.x), m.y * m.z, md);
}

vec2 doubleAngleIdentities(vec2 n) {
    return vec2(n.x * n.x - n.y * n.y, 2.0 * n.x * n.y);
}

void fourierAdd(vec3 delta, vec3 color, inout vec3 vibeA0, inout vec3 vibeA1, inout vec3 vibeB1, inout vec3 vibeA2, inout vec3 vibeB2) {
    vec3 direction = normalize(delta);
    float distRatio = min(1.0, 0.1 / length(delta.xy));
    float distFactor = sqrt(1.0 - distRatio * distRatio);

    const float c0 = 0.318309886184;
    vibeA0 += mix(c0, 1.0, direction.z) * color;

    float c1 = 0.3183 + 0.1817 * distFactor;
    vec2 g1 = -c1 * direction.xy;
    vibeA1 += g1.x * color;
    vibeB1 += g1.y * color;

    float c2 = 0.2122 * distFactor;
    vec2 g2 = c2 * doubleAngleIdentities(-direction.xy);
    vibeA2 += g2.x * color;
    vibeB2 += g2.y * color;
}
vec3 fourierApply(vec3 n, vec3 vibeA0, vec3 vibeA1, vec3 vibeB1, vec3 vibeA2, vec3 vibeB2) {
    vec2 g1 = n.xy;
    vec2 g2 = doubleAngleIdentities(g1);
    return vibeA0 + vibeA1 * g1.xxx + vibeB1 * g1.yyy + vibeA2 * g2.xxx + vibeB2 * g2.yyy;
}

vec2 transformGradient(vec2 basis, float h) {
    vec2 m1 = dFdx(basis), m2 = dFdy(basis);
    mat2 adjoint = mat2(m2.y, -m2.x, -m1.y, m1.x);

    float eps = 1e-7;
    float det = m2.x * m1.y - m1.x * m2.y + eps;
    return vec2(dFdx(h), dFdy(h)) * adjoint / det;
}

vec3 bumpMap(vec2 uv, float height, vec4 col) {
    float value = height * col.r;
    vec2 gradient = transformGradient(uv, value);
    return vec3(gradient, 1.0 - dot(gradient, gradient));
}

float f(float val, float amt) {
    return mod(val, amt);
}

out vec4 fragColor;

void main() {
    vec2 position = FlutterFragCoord();
    vec4 bounds = vec4(0.0, 0.0, resolution.x, resolution.y);
    vec4 color = vec4(1.0);

    vec2 p = position / max(bounds.z, bounds.w);
    vec2 coords = position / bounds.zw;

    vec3 c = voronoi(30.0 * p);
    vec3 d = voronoi(20.0 * p);

    vec2 hashing = hash(vec2(0.0, c.y)) * 30.0;
    c.y *= hashing.x * hashing.y;
    c.y = fract(c.y);

    hashing = hash(vec2(0.0, d.y)) * 30.0;
    d.y *= hashing.x * hashing.y;
    d.y = fract(d.y);

    vec4 col = vec4(1);

    float strength = 20.0;

    float x = (p.x + 4.0 ) * (coords.y + 4.0 ) * 10.0;
    vec4 grain = vec4(f((f(x, 13.0) + 1.0) * (f(x, 123.0) + 1.0), 0.01) - 0.005);

    col += min(col, grain);

    vec4 edge = vec4(vec3(smoothstep( 0.04, 0.17, c.z)), 1.0) * 0.6;
    vec4 secondaryEdge = vec4(vec3(smoothstep( 0.04, 0.17, d.z)), 1.0) + 0.6;
    edge *= secondaryEdge;
    col = col * edge;

    vec3 vibeA0 = vec3(0.01, 0.01, 0.01); // Ambient
    vec3 vibeA1 = vec3(0.0);
    vec3 vibeB1 = vec3(0.0);
    vec3 vibeA2 = vec3(0.0);
    vec3 vibeB2 = vec3(0.0);

    // Fourier add function calls
    vec3 dir = vec3(1.0, 1.0, 0.0);
    fourierAdd(dir, vec3(0.2, 0.2, 0.2), vibeA0, vibeA1, vibeB1, vibeA2, vibeB2);

    vec2 light = u_lightPosition;
    vec2 delta = coords - light;
    vec3 lightInt = vec3(delta, 0.2);
    vec3 lightColor = vec3(color.xyz) * 0.4 * max(0.0, 0.7 - length(delta) / 2.75);
    fourierAdd(lightInt, lightColor, vibeA0, vibeA1, vibeB1, vibeA2, vibeB2);

    // Bump map and color application
    vec3 n = bumpMap(coords, 0.014, col * 0.15);
    col.xyz = vec3(fourierApply(n, vibeA0, vibeA1, vibeB1, vibeA2, vibeB2));

    fragColor = col;
}


