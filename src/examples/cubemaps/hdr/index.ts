import { convertToInterleavedGeometry } from "../../../lib/geometry/Geometry.Functions";
import { icosahedronGeometry } from "../../../lib/geometry/primitives/polyhedronGeometry";
import { ShaderMaterial } from "../../../lib/materials/ShaderMaterial";
import { Euler } from "../../../lib/math/Euler";
import { Matrix4 } from "../../../lib/math/Matrix4";
import {
  makeMatrix4PerspectiveFov,
  makeMatrix4RotationFromEuler,
  makeMatrix4Translation,
} from "../../../lib/math/Matrix4.Functions";
import { Vector3 } from "../../../lib/math/Vector3";
import { makeBufferGeometryFromGeometry } from "../../../lib/renderers/webgl/buffers/BufferGeometry";
import { DepthTestFunc, DepthTestState } from "../../../lib/renderers/webgl/DepthTestState";
import { renderBufferGeometry } from "../../../lib/renderers/webgl/framebuffers/VirtualFramebuffer";
import { makeProgramFromShaderMaterial } from "../../../lib/renderers/webgl/programs/Program";
import { RenderingContext } from "../../../lib/renderers/webgl/RenderingContext";
import { makeTexImage2DFromCubeTexture } from "../../../lib/renderers/webgl/textures/TexImage2D";
import { CubeMapTexture } from "../../../lib/textures/CubeTexture";
import { fetchCubeHDRs } from "../../../lib/textures/loaders/HDR";
import fragmentSource from "./fragment.glsl";
import vertexSource from "./vertex.glsl";

async function init(): Promise<null> {
  const geometry = convertToInterleavedGeometry(icosahedronGeometry(0.75, 2));
  const material = new ShaderMaterial(vertexSource, fragmentSource);
  const cubeTexture = new CubeMapTexture(await fetchCubeHDRs("/assets/textures/cube/pisa/*.hdr"));

  const context = new RenderingContext(document.getElementById("framebuffer") as HTMLCanvasElement);
  const canvasFramebuffer = context.canvasFramebuffer;
  window.addEventListener("resize", () => canvasFramebuffer.resize());

  const program = makeProgramFromShaderMaterial(context, material);
  const uniforms = {
    localToWorld: new Matrix4(),
    worldToView: makeMatrix4Translation(new Vector3(0, 0, -3.0)),
    viewToScreen: makeMatrix4PerspectiveFov(25, 0.1, 4.0, 1.0, canvasFramebuffer.aspectRatio),
    perceptualRoughness: 0,
    mipCount: cubeTexture.mipCount,
    cubeMap: makeTexImage2DFromCubeTexture(context, cubeTexture),
  };
  const bufferGeometry = makeBufferGeometryFromGeometry(context, geometry);
  const depthTestState = new DepthTestState(true, DepthTestFunc.Less);

  function animate(): void {
    const now = Date.now();
    uniforms.localToWorld = makeMatrix4RotationFromEuler(
      new Euler(now * 0.0001, now * 0.00033, now * 0.000077),
      uniforms.localToWorld,
    );
    uniforms.perceptualRoughness = Math.sin(now * 0.001) * 0.5 + 0.5;
    renderBufferGeometry(canvasFramebuffer, program, uniforms, bufferGeometry, depthTestState);

    requestAnimationFrame(animate);
  }

  animate();

  return null;
}

init();
