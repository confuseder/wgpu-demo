struct ShaderUniforms {
    iTime: f32,
    padding: f32,
    iResolution: vec2<f32>,
};

@group(0) @binding(0) var<uniform> uniforms: ShaderUniforms;

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
};

@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> VertexOutput {
    var pos = array<vec2<f32>, 6>(
        vec2<f32>(-1.0, -1.0), vec2<f32>( 1.0, -1.0), vec2<f32>(-1.0,  1.0),
        vec2<f32>(-1.0,  1.0), vec2<f32>( 1.0, -1.0), vec2<f32>( 1.0,  1.0)
    );

    var out: VertexOutput;
    out.position = vec4<f32>(pos[vertex_index], 0.0, 1.0);
    return out;
}

const PI: f32 = 3.1415926;
const det: f32 = 0.001;

fn rotM(r: f32) -> mat2x2<f32> {
    let c = cos(r);
    let s = sin(r);
    return mat2x2<f32>(c, s, -s, c);
}

fn hash33(p: vec3<f32>) -> vec3<f32> {
    let k = vec3<f32>(443.8975, 397.2973, 491.1871);
    var p2 = fract(p * k);
    p2 = p2 + dot(p2.zxy, p2.yxz + 19.27);
    return fract(vec3<f32>(p2.x * p2.y, p2.z * p2.x, p2.y * p2.z));
}

fn stars(p_input: vec3<f32>) -> vec3<f32> {
    var c = vec3<f32>(0.0);
    let res = uniforms.iResolution.x * 0.8;
    var p = p_input;

    for (var i: f32 = 0.0; i < 4.0; i = i + 1.0) {
        var q = fract(p * (0.15 * res)) - 0.5;
        let id = floor(p * (0.15 * res));
        let rn = hash33(id).xy;
        let c2 = 1.0 - smoothstep(0.0, 0.6, length(q));
        let c2_mask = step(rn.x, 0.0005 + i * i * 0.001);
        c = c + c2_mask * c2 * (mix(vec3<f32>(1.0, 0.49, 0.1), vec3<f32>(0.75, 0.9, 1.0), rn.y) * 0.25 + 0.75);
        p = p * 1.4;
    }
    return c * c * 0.65;
}

fn getPlane(p: vec2<f32>) -> vec2<f32> {
    return p;
}

fn kset(it: i32, p: vec3<f32>, q: vec3<f32>, sc: f32, c: f32) -> f32 {
    var p2 = p;
    let rot1 = rotM(uniforms.iTime * 0.4) * p2.xz;
    p2.x = rot1.x;
    p2.z = rot1.y;
    let rot2 = rotM(uniforms.iTime * 0.12) * p2.xz;
    p2.x = rot2.x;
    p2.z = rot2.y;
    p2 = p2 + q;
    p2 = p2 * sc;

    var l: f32 = 0.0;
    var l2: f32 = 0.0;

    for (var i: i32 = 0; i < it; i = i + 1) {
        p2 = abs(p2) / dot(p2, p2) - c;
        l = l + exp(-1.0 * abs(length(p2) - l2));
        l2 = length(p2);
    }
    return l * 0.08;
}

fn clouds(p2: vec3<f32>, dir: vec3<f32>) -> f32 {
    var p3 = p2 - 0.1 * dir;
    p3.y = p3.y * 3.0;

    var cl1: f32 = 0.0;
    var cl2: f32 = 0.0;

    for (var i: i32 = 0; i < 15; i = i + 1) {
        p3 = p3 - 0.05 * dir;
        cl1 = cl1 + kset(20, p3, vec3<f32>(1.7, 3.0, 0.54), 0.3, 0.95);
        cl2 = cl2 + kset(18, p3, vec3<f32>(1.2, 1.7, 1.4), 0.2, 0.85);
    }

    cl1 = pow(cl1 * 0.045, 10.0);
    cl2 = pow(cl2 * 0.055, 15.0);
    return cl1 - cl2;
}

var<private> objid: f32 = 0.0;
var<private> objcol: f32 = 0.0;
var<private> coast: f32 = 0.0;

fn de(p: vec3<f32>) -> f32 {
    let surf1 = kset(6, p, vec3<f32>(0.523, 1.547, 0.754), 0.2, 0.9);
    let surf2 = kset(8, p, vec3<f32>(0.723, 1.247, 0.354), 0.2, 0.8) * 0.7;
    let surf3 = kset(10, p, vec3<f32>(1.723, 0.347, 0.754), 0.3, 0.6) * 0.5;
    objcol = pow(surf1 + surf2 + surf3, 5.0);

    // 调整：减小地形高度系数，确保水面可见
    let land = length(p) - 2.95 - surf1 * 0.25 - surf2 * 0.05;
    let water = length(p) - 3.05;
    let d = min(land, water);

    objid = step(water, d) + step(land, d) * 2.0;
    coast = max(0.0, 0.03 - abs(land - water)) / 0.03;

    return d * 0.8;
}

fn de_clouds(p: vec3<f32>, dir: vec3<f32>) -> f32 {
    return length(p) - clouds(p, dir) * 0.05;
}

fn normal(p: vec3<f32>) -> vec3<f32> {
    let eps = vec3<f32>(0.0, det, 0.0);
    let n = vec3<f32>(
        de(p + eps.yxx),
        de(p + eps.xyx),
        de(p + eps.xxy)
    ) - de(p);
    return normalize(n);
}

fn normal_clouds(p: vec3<f32>, dir: vec3<f32>) -> vec3<f32> {
    let eps = vec3<f32>(0.0, 0.05, 0.0);
    let n = vec3<f32>(
        de_clouds(p + eps.yxx, dir),
        de_clouds(p + eps.xyx, dir),
        de_clouds(p + eps.xxy, dir)
    ) - de_clouds(p, dir);
    return normalize(n);
}

fn shadow(desde: vec3<f32>) -> f32 {
    let ldir = normalize(vec3<f32>(2.0, 0.5, -0.5));
    var td: f32 = 0.1;
    var sh: f32 = 1.0;

    for (var i: i32 = 0; i < 10; i = i + 1) {
        let p = desde + ldir * td;
        let d = de(p);
        td = td + d;
        sh = min(sh, 20.0 * d / td);
        if (sh < 0.001) { break; }
    }

    return clamp(sh, 0.0, 1.0);
}

fn color(id: f32, p: vec3<f32>) -> vec3<f32> {
    let water_color = vec3<f32>(0.0, 0.4, 0.8);
    let land_color1 = vec3<f32>(0.6, 1.0, 0.5);
    let land_color2 = vec3<f32>(0.6, 0.2, 0.0);

    let k = smoothstep(0.0, 0.7, kset(9, p, vec3<f32>(0.63, 0.7, 0.54), 0.1, 0.8));
    let land = mix(land_color1, land_color2, k);
    let water = water_color * (objcol + 0.5) + coast * 0.7;

    let polar = pow(min(1.0, abs(p.y * 0.4 + k * 0.3 - 0.1)), 10.0);
    let land_polar = mix(land, vec3<f32>(1.0), polar);
    let water_polar = mix(water, vec3<f32>(1.5), polar);

    var c = vec3<f32>(0.0);
    c = c + water_polar * step(abs(id - 1.0), 0.1);
    c = c + land_polar * step(abs(id - 2.0), 0.1) * objcol * 3.0;

    return c;
}

fn shade(p: vec3<f32>, dir: vec3<f32>, n: vec3<f32>, col: vec3<f32>, id: f32) -> vec3<f32> {
    let ldir = normalize(vec3<f32>(2.0, 0.5, -0.5));
    let amb = 0.05;
    let sh = shadow(p);
    let dif = max(0.0, dot(ldir, n)) * 0.7 * sh;
    let refl = reflect(ldir, n) * sh;
    let spe = pow(max(0.0, dot(refl, dir)), 10.0) * 0.5 * (0.3 + step(abs(id - 1.0), 0.1));

    return (amb + dif) * col + spe;
}

fn march(ro: vec3<f32>, dir: vec3<f32>) -> vec3<f32> {
    var td: f32 = 0.0;
    var d: f32 = 0.0;
    var g: f32 = 0.0;
    var c = vec3<f32>(0.0);
    var p: vec3<f32>;

    for (var i: i32 = 0; i < 60; i = i + 1) {
        p = ro + dir * td;
        d = de(p);
        td = td + d;
        if (td > 50.0 || d < det) { break; }
        g = g + smoothstep(-4.0, 1.0, p.x);
    }

    if (d < det) {
        p = p - det * dir * 2.0;
        let col = color(objid, p);
        let n = normal(p);
        c = shade(p, dir, n, col, objid);

        let cl1 = clouds(p, dir);
        let nc = normal_clouds(p, dir);
        c = mix(c, 0.1 + vec3<f32>(1.3) * max(0.0, dot(normalize(vec3<f32>(2.0, 0.5, -0.5)), nc)), clamp(cl1, 0.0, 1.0));
    } else {
        let bg = stars(dir) * 1.0;
        c = c + bg;
    }

    g = g / 60.0;
    let atmo_color = vec3<f32>(0.4, 0.65, 0.9);
    return c + (pow(g, 1.3) + pow(g, 1.7) * 0.5) * atmo_color * 0.5;
}

@fragment
fn fs_main(@builtin(position) fragCoord: vec4<f32>) -> @location(0) vec4<f32> {
    let iResolution = uniforms.iResolution;
    let iTime = uniforms.iTime;

    var uv = (fragCoord.xy - iResolution.xy * 0.5) / iResolution.y;
    uv = getPlane(uv);

    // 固定中远视角 (z 值越小，视角越远)
    var ray_origin = vec3<f32>(0.0, 0.0, -10.0);
    var dir = normalize(vec3<f32>(uv, 0.5));

    let col = march(ray_origin, dir);

    return vec4<f32>(col * 0.85, 1.0);
}
