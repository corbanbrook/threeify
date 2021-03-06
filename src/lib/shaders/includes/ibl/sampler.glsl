mat3 normalToTangentFrame( const in vec3 normal ) {
  vec3 bitangent = vec3(0., 1., 0.);
	if (abs(normal.y) > abs(normal.x) && abs(normal.y) > abs(normal.z)) {
		// Sampling +Y or -Y, so we need a more robust bitangent.
		if (NdotY > 0.0) {
			bitangent = vec3(0.0, 0.0, 1.0);
		}
		else {
			bitangent = vec3(0.0, 0.0, -1.0);
		}
	}

  vec3 tangent = cross(bitangent, normal);
  bitangent = cross(normal, tangent);
  return  mat3( tangent, bitangent, normal );
}

#pragma include <math/math>
#pragma include <math/hammersley.glsl>
#pragma include <brdfs/specular/d_ggx> // NOTE: takes alpha, original versions here took roughness
#pragma include <brdfs/sheen/d_charlie>

#define NUM_SAMPLES 1024
#define LOD_BIAS 1

#define DISTRIBUTION_LAMBERTIAN 0
#define DISTRIBUTION_GGX 1
#define DISTRIBUTION_CHARLIE 2

vec3 getImportanceSample(uint distributionType, uint sampleIndex, vec3 N, float roughness) {

  float u = float(sampleIndex) / float(NUM_SAMPLES);
	float v = Hammersley(sampleIndex);

	float phi = PI2 * u;
  float cosTheta = 0.;
	float sinTheta = 0.;

	if( distributionType == DISTRIBUTION_LAMBERTIAN ) {
		cosTheta = 1. - v;
		sinTheta = sqrt( 1. - cosTheta*cosTheta );
	}

  else if( distributionType == DISTRIBUTION_GGX ) {
		float alphaRoughness = pow2( roughness );
		cosTheta = sqrt( ( 1. - v ) / ( 1. + ( pow2( alphaRoughness ) - 1. ) * v ) );
		sinTheta = sqrt( 1. - pow2( cosTheta ) );
	}

  else if( distributionType == DISTRIBUTION_CHARLIE ) {
		float alphaRoughness = pow2( roughness );
		sinTheta = pow( v, alphaRoughness / ( 2.*alphaRoughness + 1. ) );
		cosTheta = sqrt( 1. - pow2( sinTheta ) );
	}

	vec3 sampleDirection = normalize( vec3( sinTheta * cos( phi ), sinTheta * sin( phi ), cosTheta ) );
  mat3 tangentFrame = normalToTangentFrame( surfaceNormal );

	return normalMatrix * sampleDirection;
}

float PDF(uint distributionType, vec3 V, vec3 H, vec3 N, vec3 L, float roughness) {

  if( distributionType == DISTRIBUTION_LAMBERTIAN ) {
		float dotNL = dot( N, L );
		return max( dotNL * RECIPROCAL_PI, 0. );
	}

  else if( distributionType == DISTRIBUTION_GGX ) {
		float dotVH = saturate( dot( V, H ) );
		float dotNH = saturate( dot( N, H ) );
    float alpha = pow2( roughness );

		float D = D_GGX( alpha, dotNH );
		return max( D * dotVH / ( 4. * dotVH ), 0.);
	}

  else if( distributionType == DISTRIBUTION_CHARLIE ) {
		float dotVH = saturate( dot( V, H ) );
		float dotNH = saturate( dot( N, H ) );

		float D = D_Charlie( roughness, dotNH );
		return max( D * dotVH / ( 4. * dotVH ), 0. );
	}

	return 0.;
}

vec3 sampleIBL( vec3 direction, float lod );

vec3 filterColor(uint distributionType, vec3 N, float roughness, float filterWidth ) {

	vec4 color = vec4(0.f);
	const float solidAngleTexel = 4.0 * PI / (6.0 * pow2( filterWidth );

	for( uint i = 0; i < NUM_SAMPLES; i++ ) {

		vec3 H = getImportanceSample(distributionType, i, N, roughness);
		// Note: reflect takes incident vector.
		// Note: N = V
		vec3 V = N;
		vec3 L = normalize(reflect(-V, H));

		float dotNL = dot(N, L);

		if ( dotNL > 0.0 ) {
			float lod = 0.0;

			if ( roughness > 0.0 || distributionType == DISTRIBUTION_LAMBERTIAN ) {
				// Mipmap Filtered Samples
				// see https://github.com/derkreature/IBLBaker
				// see https://developer.nvidia.com/gpugems/GPUGems3/gpugems3_ch20.html
				float pdf = PDF( distributionType, V, H, N, L, roughness );

				float solidAngleSample = 1.0 / ( float( NUM_SAMPLES ) * pdf );

				lod = 0.5 * log2( solidAngleSample / solidAngleTexel );
				lod += LOD_BIAS;
			}

			if(distributionType == DISTRIBUTION_LAMBERTIAN) {
				color += vec4( sampleIBL( H, lod ), 1.0 );
			}
			else {
				color += vec4( sampleIBL( L, lod ) * dotNL, dotNL );
			}
		}
	}

	if(color.w == 0.f)
	{
		return color.rgb;
	}

	return color.rgb / color.w;
}

#pragma include <brdfs/specular/v_ggx_smithcorrelated>  // NOTE: takes alpha, original versions here took roughness
#pragma include <brdfs/sheen/v_charlie>

// Compute LUT for GGX distribution.
// See https://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf
vec3 LUT(uint distributionType, float NdotV, float roughness)
{
	// Compute spherical view vector: (sin(phi), 0, cos(phi))
	vec3 V = vec3(sqrt(1.0 - NdotV * NdotV), 0.0, NdotV);

	// The macro surface normal just points up.
	vec3 N = vec3(0.0, 0.0, 1.0);

	// To make the LUT independant from the material's F0, which is part of the Fresnel term
	// when substituted by Schlick's approximation, we factor it out of the integral,
	// yielding to the form: F0 * I1 + I2
	// I1 and I2 are slighlty different in the Fresnel term, but both only depend on
	// NoL and roughness, so they are both numerically integrated and written into two channels.
	float A = 0;
	float B = 0;
	float C = 0;

	for(uint i = 0; i < NUM_SAMPLES; ++i)
	{
		// Importance sampling, depending on the distribution.
		vec3 H = getImportanceSample(distributionType, i, N, roughness);
		vec3 L = normalize(reflect(-V, H));

		float dotNL = saturate(L.z);
		float dotNH = saturate(H.z);
		float dotVH = saturate(dot(V, H));
    float alphaRoughness = roughness * roughness;

		if (NdotL > 0.0)
		{

			if (distributionType == DISTRIBUTION_GGX)
			{
				// LUT for GGX distribution.

				// Taken from: https://bruop.github.io/ibl
				// Shadertoy: https://www.shadertoy.com/view/3lXXDB
				// Terms besides V are from the GGX PDF we're dividing by.
				float V_pdf = V_SmithGGXCorrelated(alphaRoughness, dotNV, dotNL) * dotVH * dotNL / dotNH;
				float Fc = pow(1.0 - dotVH, 5.0);
				A += (1.0 - Fc) * V_pdf;
				B += Fc * V_pdf;
				C += 0;
			}

			if (distributionType == DISTRIBUTION_CHARLIE)
			{
				// LUT for Charlie distribution.
				float sheenDistribution = D_Charlie(roughness, dotNH);
				float sheenVisibility = V_Charlie(roughness, dotNL, dotNV);

				A += 0;
				B += 0;
				C += sheenVisibility * sheenDistribution * dotNL * dotVH;
			}
		}
	}

	// The PDF is simply pdf(v, h) -> NDF * <nh>.
	// To parametrize the PDF over l, use the Jacobian transform, yielding to: pdf(v, l) -> NDF * <nh> / 4<vh>
	// Since the BRDF divide through the PDF to be normalized, the 4 can be pulled out of the integral.
	return vec3(4.0 * A, 4.0 * B, 4.0 * 2.0 * PI * C) / float( NUM_SAMPLES );
}

/*

// entry point
void filterCubeMap(uint distributionType, uint currentMipLevel, float roughness, float filterWidth)
{
	vec2 newUV = inUV * float(1 << currentMipLevel);

	newUV = newUV*2.0-1.0;

	for(int face = 0; face < 6; ++face)
	{
		vec3 scan = uvToXYZ(face, newUV);

		vec3 direction = normalize(scan);
		direction.y = -direction.y;

		writeFace(face, filterColor(distributionType, direction, roughness, filterWidth));

		//Debug output:
		//writeFace(face,  texture(uCubeMap, direction).rgb);
		//writeFace(face,   direction);
	}

	// Write LUT:
	// x-coordinate: NdotV
	// y-coordinate: roughness
	if (currentMipLevel == 0)
	{

		outLUT = LUT(distributionType, inUV.x, inUV.y, roughness);

	}
}

*/
