// ─────────────────────────────────────────────────────────────────────────────
// PREMIUM HERO BACKGROUND — Vertex Shader
// ─────────────────────────────────────────────────────────────────────────────
// The plane geometry is kept flat — all visual work happens in the
// fragment shader. This vertex shader simply passes through position.
// ─────────────────────────────────────────────────────────────────────────────

precision highp float;

attribute vec3 position;

void main() {
  // Standard full-screen quad pass-through.
  // PlaneGeometry covers NDC [-1, 1] on both axes when scaled to fill viewport.
  gl_Position = vec4(position, 1.0);
}
