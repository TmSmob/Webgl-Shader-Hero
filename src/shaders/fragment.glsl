// ─────────────────────────────────────────────────────────────────────────────
// PREMIUM HERO BACKGROUND — Fragment Shader
// ─────────────────────────────────────────────────────────────────────────────
//
// TUNING GUIDE
// ─────────────────────────────────────────────────────────────────────────────
//  SPEED       → lower uSpeed  (0.05–0.15) = slower / more meditative
//                higher uSpeed (0.3–0.6)   = faster / more energetic
//
//  SOFTNESS    → increase SMOOTH_STEP range in color mixing calls
//                or reduce FBM_OCTAVES (2–3 = softer, 6–8 = more detailed)
//
//  INTENSITY   → uIntensity controls warp displacement amplitude
//                0.3 = very subtle / 0.8 = dramatic
//
//  CONTRAST    → adjust the pow() gamma curve near the bottom
//                pow(col, vec3(0.9)) = lighter / pow(col, vec3(1.2)) = darker
//
//  COLOR       → edit COLOR_A … COLOR_E to change the palette
//                All values are linear sRGB (0.0–1.0)
//
// ─────────────────────────────────────────────────────────────────────────────

precision highp float;

uniform float uTime;
uniform vec2  uResolution;
uniform float uSpeed;      // recommended 0.06 - 0.14 for this style
uniform float uIntensity;  // recommended 0.25 - 0.55

// Light premium palette inspired by layered glass-like blue waves.
const vec3 BASE_LIGHT   = vec3(0.93, 0.95, 0.99);
const vec3 SKY_TINT     = vec3(0.80, 0.88, 0.99);
const vec3 BLUE_DEEP    = vec3(0.29, 0.54, 0.96);
const vec3 BLUE_MID     = vec3(0.48, 0.69, 0.98);
const vec3 BLUE_SOFT    = vec3(0.72, 0.84, 1.00);
const vec3 HIGHLIGHT    = vec3(0.96, 0.985, 1.0);

// Low-frequency noise only for micro-organic movement.
float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  float a = hash(i + vec2(0.0, 0.0));
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 4; i++) {
    v += a * noise(p);
    p = p * 2.02 + vec2(17.0, 11.0);
    a *= 0.5;
  }
  return v;
}

void main() {
  vec2 st = gl_FragCoord.xy / uResolution;
  float aspect = uResolution.x / uResolution.y;
  vec2 uv = vec2((st.x - 0.5) * aspect, st.y - 0.5);

  float t = uTime * uSpeed;

  // Curved wave center near top-right like the reference.
  vec2 center = vec2(0.58 * aspect, 0.32);

  // Gentle drift; keeps shape alive without chaos.
  center += 0.03 * vec2(sin(t * 0.9), cos(t * 0.7));

  vec2 p = uv - center;
  float r = length(p);
  vec2 pn = p / max(r, 0.0001);

  // Seam-free deformation (avoids atan discontinuity split line).
  float dir1 = dot(pn, vec2(0.88, 0.47));
  float dir2 = dot(pn, vec2(-0.56, 0.83));
  float deform = 0.045 * sin(dir1 * 5.8 - t * 1.5)
               + 0.020 * sin(dir2 * 10.6 + t * 1.0)
               + (fbm(p * 2.2 + t * 0.22) - 0.5) * 0.028 * uIntensity;
  float rw = r + deform;

  // 3 smooth wave layers (no hard split).
  float m1 = 1.0 - smoothstep(0.88, 1.02, rw); // outer
  float m2 = 1.0 - smoothstep(0.68, 0.80, rw); // middle
  float m3 = 1.0 - smoothstep(0.47, 0.59, rw); // inner

  float bandOuter = clamp(m1 - m2, 0.0, 1.0);
  float bandMid   = clamp(m2 - m3, 0.0, 1.0);
  float bandInner = m3;

  // Rim highlight to mimic premium glossy edge.
  float rimOuter = exp(-180.0 * abs(rw - 0.81));
  float rimMid   = exp(-200.0 * abs(rw - 0.62));
  float rimInner = exp(-220.0 * abs(rw - 0.44));
  float rim = rimOuter * 0.7 + rimMid * 0.5 + rimInner * 0.45;

  // Very soft full-screen background gradient (continuous to avoid division lines).
  float bgX = smoothstep(-0.85 * aspect, 0.85 * aspect, uv.x);
  float bgY = smoothstep(0.65, -0.75, uv.y);
  float bgMix = clamp(bgX * 0.65 + bgY * 0.45, 0.0, 1.0);

  vec3 col = BASE_LIGHT;
  col = mix(col, SKY_TINT, bgMix * 0.50);
  col = mix(col, BLUE_SOFT, bandOuter * 0.42);
  col = mix(col, BLUE_MID,  bandMid   * 0.52);
  col = mix(col, BLUE_DEEP, bandInner * (0.34 + 0.22 * uIntensity));
  col = mix(col, HIGHLIGHT, rim * 0.55);

  // Keep center-left readable for dark typography.
  float centerLift = smoothstep(0.85, 0.05, length(uv - vec2(-0.06 * aspect, -0.03)));
  col = mix(col, vec3(0.98, 0.985, 1.0), centerLift * 0.24);

  // Very gentle top-right accent bloom.
  float bloom = exp(-2.3 * r * r);
  col += vec3(0.03, 0.06, 0.11) * bloom * 0.45;

  col = clamp(col, 0.0, 1.0);
  gl_FragColor = vec4(col, 1.0);
}
