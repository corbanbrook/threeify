precision highp float;

varying vec3 v_viewSurfacePosition;
varying vec3 v_viewSurfaceNormal;
varying vec2 v_uv0;

uniform vec3 pointLightViewPosition;
uniform vec3 pointLightIntensity;
uniform float pointLightRange;

uniform vec2      normalModulator;
uniform sampler2D normalMap;

#pragma include <brdfs/common>
#pragma include <lighting/punctual>
#pragma include <brdfs/ambient/basic>
#pragma include <brdfs/diffuse/lambert>
#pragma include <brdfs/specular/ggx>
#pragma include <color/spaces/srgb>
#pragma include <normals/normalPacking>

void main() {

  vec3 albedo = vec3(1.,1.,1.);
  vec3 specular = vec3(1.);
  float specularRoughness = 0.25;
  vec3 specularF0 = specularIntensityToF0( specular );

  vec3 normal = vec3( normalModulator, 1. ) * rgbToNormal( texture2D( normalMap, v_uv0 ).rgb );

  Surface surface;
  surface.position = v_viewSurfacePosition;
  surface.normal = normalize( v_viewSurfaceNormal );
  surface.viewDirection = normalize( -v_viewSurfacePosition );

  uvToTangentFrame( surface, v_uv0 );
  perturbSurfaceNormal_TangentSpace( surface, normal );

  PunctualLight punctualLight;
  punctualLight.position = pointLightViewPosition;
  punctualLight.intensity = pointLightIntensity;
  punctualLight.range = pointLightRange;

  DirectLight directLight;
  pointLightToDirectLight( surface, punctualLight, directLight );

  float dotNL = saturate( dot( directLight.direction, surface.normal ) );

  vec3 outgoingRadiance;
  outgoingRadiance += directLight.radiance * dotNL *
    BRDF_Specular_GGX( surface, directLight.direction, specularF0, specularRoughness ) ;
  outgoingRadiance += directLight.radiance * dotNL *
    BRDF_Diffuse_Lambert( albedo );

  gl_FragColor.rgb = linearTosRGB( outgoingRadiance );
  gl_FragColor.a = 1.;

}
