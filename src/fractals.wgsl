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

@fragment
fn fs_main(@builtin(position) fragCoord: vec4<f32>) -> @location(0) vec4<f32> {
    let iResolution = uniforms.iResolution;
    let iTime = uniforms.iTime;

    var col = vec3<f32>(0.0);

    let AA: i32 = 2;
    for (var j: i32 = 0; j < AA; j++) {
        for (var i: i32 = 0; i < AA; i++) {

            let offset = vec2<f32>(f32(i), f32(j)) / f32(AA);
            var p = (vec2<f32>(fragCoord.x, fragCoord.y) + offset - iResolution.xy * 0.5) / iResolution.y;

            let ttm = cos(sin(iTime / 8.0)) * 6.2831;
            let rot = mat2x2<f32>(cos(ttm), sin(ttm), -sin(ttm), cos(ttm));
            p = rot * p;
            p = p - vec2<f32>(cos(iTime / 2.0) / 2.0, sin(iTime / 3.0) / 5.0);

            let zm = 200.0 + sin(iTime / 7.0) * 50.0;
            let cc = vec2<f32>(-0.57735 + 0.004, 0.57735) + p / zm;

            var z = vec2<f32>(0.0);
            var dz = vec2<f32>(0.0);

            let iter: i32 = 128;
            var ik: i32 = 128;

            for (var k: i32 = 0; k < iter; k++) {
                dz = mat2x2<f32>(z.x, z.y, -z.y, z.x) * dz * 2.0 + vec2<f32>(1.0, 0.0);
                z = mat2x2<f32>(z.x, z.y, -z.y, z.x) * z + cc;

                if (dot(z, z) > 200.0) {
                    ik = k;
                    break;
                }
            }

            let ln = step(0.0, length(z) / 15.5 - 1.0);
            var d = sqrt(1.0 / max(length(dz), 0.0001)) * log(dot(z, z));
            d = clamp(d * 50.0, 0.0, 1.0);

            let dir = select(1.0, -1.0, (f32(ik) % 2.0) < 0.5);
            let sh = f32(iter - ik) / f32(iter);

            var tuv = z / 320.0;
            let tm = -ttm * sh * sh * 16.0;
            tuv = mat2x2<f32>(cos(tm), sin(tm), -sin(tm), cos(tm)) * tuv;
            tuv = abs((tuv % (1.0 / 8.0)) - 1.0 / 16.0);

            var pat = smoothstep(0.0, 1.0 / length(dz), length(tuv) - 1.0 / 32.0);
            pat = min(pat, smoothstep(0.0, 1.0 / length(dz), abs(max(tuv.x, tuv.y) - 1.0 / 16.0) - 0.04 / 16.0));

            var lCol = pow(min(vec3<f32>(1.5, 1.0, 1.0) * min(d * 0.85, 0.96), vec3<f32>(1.0)), vec3<f32>(1.0, 3.0, 16.0)) * 1.15;

            if (dir < 0.0) {
                lCol = lCol * min(pat, ln);
            } else {
                lCol = (sqrt(lCol) * 0.5 + 0.7) * max(1.0 - pat, 1.0 - ln);
            }

            let rd = normalize(vec3<f32>(p, 1.0));
            let refl = reflect(rd, vec3<f32>(0.0, 0.0, -1.0));
            let diff = clamp(dot(z * 0.5 + 0.5, refl.xy), 0.0, 1.0) * d;

            var tuv2 = z / 200.0;
            let tm2 = -tm / 1.5 + 0.5;
            tuv2 = mat2x2<f32>(cos(tm2), sin(tm2), -sin(tm2), cos(tm2)) * tuv2;
            tuv2 = abs((tuv2 % (1.0 / 8.0)) - 1.0 / 16.0);

            var pat2 = smoothstep(0.0, 1.0 / length(dz), length(tuv2) - 1.0 / 32.0);
            pat2 = min(pat2, smoothstep(0.0, 1.0 / length(dz), abs(max(tuv2.x, tuv2.y) - 1.0 / 16.0) - 0.04 / 16.0));

            lCol += mix(lCol, vec3<f32>(1.0) * ln, 0.5) * diff * diff * 0.5 * (pat2 * 0.6 + 0.6);

            if (f32(ik) % 6.0 < 0.5) { lCol = lCol.yxz; }
            lCol = mix(lCol.xzy, lCol, d / 1.2);
            lCol = mix(lCol, vec3<f32>(0.0), (1.0 - step(0.0, -(length(z) * 0.05 * f32(ik) / f32(iter) - 1.0))) * 0.95);
            lCol = mix(vec3<f32>(0.0), lCol, sh * d);

            col += min(lCol, vec3<f32>(1.0));
        }
    }

    col /= f32(AA * AA);

    let uv_vignette = fragCoord.xy / iResolution.xy;
    col *= pow(16.0 * (1.0 - uv_vignette.x) * (1.0 - uv_vignette.y) * uv_vignette.x * uv_vignette.y, 1.0 / 8.0) * 1.15;

    return vec4<f32>(sqrt(max(col, vec3<f32>(0.0))), 1.0);
}
