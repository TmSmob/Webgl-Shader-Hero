/**
 * Premium hero WebGL background.
 *
 * Tuning quick guide:
 * - Animation speed: adjust DEFAULTS.speed
 * - Warp intensity: adjust DEFAULTS.intensity
 * - Color palette: edit constants in src/shaders/fragment.glsl
 * - Contrast: tweak final pow() and vignette in fragment shader
 * - Softness: lower FBM_OCTAVES or reduce intensity in fragment shader
 *
 * WordPress integration note:
 * - Enqueue style.css and this module script in your theme/plugin.
 * - Enqueue three from your plugin/theme local node_modules copy.
 * - Print hero markup via shortcode, block, or template part.
 * - Keep shader files beside this script and preserve relative paths.
 */

import * as THREE from "../node_modules/three/build/three.module.js";

const SHADER_PATHS = {
  vertex: "./shaders/vertex.glsl",
  fragment: "./shaders/fragment.glsl",
};

const DEFAULTS = {
  speed: 0.1,
  intensity: 0.42,
  maxPixelRatio: 2,
};

async function loadShader(url) {
  const shaderUrl = new URL(url, import.meta.url);
  const response = await fetch(shaderUrl, { cache: "no-store" });
  if (!response.ok) {
    throw new Error(`Shader could not be loaded: ${shaderUrl}`);
  }
  return response.text();
}

async function loadShaders() {
  const [vertexShader, fragmentShader] = await Promise.all([
    loadShader(SHADER_PATHS.vertex),
    loadShader(SHADER_PATHS.fragment),
  ]);
  return { vertexShader, fragmentShader };
}

class HeroBackground {
  constructor(canvas, shaders, options = {}) {
    this.canvas = canvas;
    this.shaders = shaders;
    this.rafId = null;
    this.destroyed = false;
    this.clock = new THREE.Clock();
    this.speed = options.speed ?? DEFAULTS.speed;
    this.intensity = options.intensity ?? DEFAULTS.intensity;
    this.maxPixelRatio = options.maxPixelRatio ?? DEFAULTS.maxPixelRatio;

    this.init();
    this.bindEvents();
    this.tick();
  }

  init() {
    this.renderer = new THREE.WebGLRenderer({
      canvas: this.canvas,
      antialias: false,
      alpha: false,
      powerPreference: "high-performance",
    });

    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, this.maxPixelRatio));
    this.renderer.setSize(window.innerWidth, window.innerHeight, false);

    this.scene = new THREE.Scene();
    this.camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);

    this.uniforms = {
      uTime: { value: 0 },
      uResolution: { value: new THREE.Vector2(window.innerWidth, window.innerHeight) },
      uSpeed: { value: this.speed },
      uIntensity: { value: this.intensity },
    };

    const material = new THREE.RawShaderMaterial({
      vertexShader: this.shaders.vertexShader,
      fragmentShader: this.shaders.fragmentShader,
      uniforms: this.uniforms,
      glslVersion: THREE.GLSL1,
    });

    this.geometry = new THREE.PlaneGeometry(2, 2);
    this.mesh = new THREE.Mesh(this.geometry, material);
    this.scene.add(this.mesh);
  }

  bindEvents() {
    this.onResize = () => {
      const width = window.innerWidth;
      const height = window.innerHeight;
      this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, this.maxPixelRatio));
      this.renderer.setSize(width, height, false);
      this.uniforms.uResolution.value.set(width, height);
    };

    this.onVisibilityChange = () => {
      if (document.hidden) {
        this.pause();
        return;
      }
      this.resume();
    };

    window.addEventListener("resize", this.onResize);
    document.addEventListener("visibilitychange", this.onVisibilityChange);
  }

  tick() {
    if (this.destroyed) return;
    this.uniforms.uTime.value = this.clock.getElapsedTime();
    this.renderer.render(this.scene, this.camera);
    this.rafId = requestAnimationFrame(() => this.tick());
  }

  setSpeed(value) {
    this.speed = value;
    this.uniforms.uSpeed.value = value;
  }

  setIntensity(value) {
    this.intensity = value;
    this.uniforms.uIntensity.value = value;
  }

  pause() {
    if (this.rafId !== null) {
      cancelAnimationFrame(this.rafId);
      this.rafId = null;
    }
  }

  resume() {
    if (this.rafId === null && !this.destroyed) {
      this.tick();
    }
  }

  destroy() {
    this.destroyed = true;
    this.pause();
    window.removeEventListener("resize", this.onResize);
    document.removeEventListener("visibilitychange", this.onVisibilityChange);
    this.geometry.dispose();
    this.mesh.material.dispose();
    this.renderer.dispose();
  }
}

function isWebGLAvailable() {
  try {
    const canvas = document.createElement("canvas");
    return Boolean(
      window.WebGLRenderingContext &&
        (canvas.getContext("webgl") || canvas.getContext("experimental-webgl"))
    );
  } catch {
    return false;
  }
}

async function init() {
  const canvas = document.getElementById("hero-canvas");
  const fallback = document.getElementById("webgl-fallback");

  if (!canvas || !fallback) return;

  if (!isWebGLAvailable()) {
    canvas.hidden = true;
    fallback.hidden = false;
    return;
  }

  try {
    const shaders = await loadShaders();
    window.heroBg = new HeroBackground(canvas, shaders, DEFAULTS);
  } catch (error) {
    console.error("Falling back to CSS background. Reason:", error);
    canvas.hidden = true;
    fallback.hidden = false;
  }
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", init);
} else {
  init();
}
