#ifndef UNIVERSAL_SHADOWS_INCLUDED
#define UNIVERSAL_SHADOWS_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Shadow/ShadowSamplingTent.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/GlobalSamplers.hlsl"
#include "Core.hlsl"
#include "Shadows.deprecated.hlsl"

#define MAX_SHADOW_CASCADES 4

#if !defined(_RECEIVE_SHADOWS_OFF)
    #if defined(_MAIN_LIGHT_SHADOWS) || defined(_MAIN_LIGHT_SHADOWS_CASCADE) || defined(_MAIN_LIGHT_SHADOWS_SCREEN)
        #define MAIN_LIGHT_CALCULATE_SHADOWS

        #if defined(_MAIN_LIGHT_SHADOWS) || (defined(_MAIN_LIGHT_SHADOWS_SCREEN) && !defined(_SURFACE_TYPE_TRANSPARENT))
            #define REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
        #endif
    #endif

    #if defined(_ADDITIONAL_LIGHT_SHADOWS)
        #define ADDITIONAL_LIGHT_CALCULATE_SHADOWS
    #endif
#endif

#if defined(UNITY_DOTS_INSTANCING_ENABLED)
#define SHADOWMASK_NAME unity_ShadowMasks
#define SHADOWMASK_SAMPLER_NAME samplerunity_ShadowMasks
#define SHADOWMASK_SAMPLE_EXTRA_ARGS , unity_LightmapIndex.x
#else
#define SHADOWMASK_NAME unity_ShadowMask
#define SHADOWMASK_SAMPLER_NAME samplerunity_ShadowMask
#define SHADOWMASK_SAMPLE_EXTRA_ARGS
#endif

#if defined(SHADOWS_SHADOWMASK) && defined(LIGHTMAP_ON)
    #define SAMPLE_SHADOWMASK(uv) SAMPLE_TEXTURE2D_LIGHTMAP(SHADOWMASK_NAME, SHADOWMASK_SAMPLER_NAME, uv SHADOWMASK_SAMPLE_EXTRA_ARGS);
#elif !defined (LIGHTMAP_ON)
    #define SAMPLE_SHADOWMASK(uv) unity_ProbesOcclusion;
#else
    #define SAMPLE_SHADOWMASK(uv) half4(1, 1, 1, 1);
#endif

#define REQUIRES_WORLD_SPACE_POS_INTERPOLATOR

#if defined(LIGHTMAP_ON) || defined(LIGHTMAP_SHADOW_MIXING) || defined(SHADOWS_SHADOWMASK)
#define CALCULATE_BAKED_SHADOWS
#endif

SCREENSPACE_TEXTURE(_ScreenSpaceShadowmapTexture);

TEXTURE2D_SHADOW(_MainLightShadowmapTexture);
TEXTURE2D_SHADOW(_AdditionalLightsShadowmapTexture);
SAMPLER_CMP(sampler_LinearClampCompare);

TEXTURE2D_SHADOW(_CachedShadowmapAtlas);
float4x4    _CachedAdditionalLightsWorldToShadow[MAX_VISIBLE_LIGHTS];
float4      _CachedAdditionalShadowParams[MAX_VISIBLE_LIGHTS];         // Per-light data
TEXTURE2D_SHADOW(_CustomShadowmapAtlas);
float4x4    _CustomShadowMatrices[MAX_VISIBLE_LIGHTS];
float4      _CustomShadowParams[MAX_VISIBLE_LIGHTS];         // Per-custom shadow data
float4      _CustomShadowParams2[MAX_VISIBLE_LIGHTS];
float4      _CustomShadowPositions[MAX_VISIBLE_LIGHTS];
float4      _CustomShadowmapSize; // (xy: 1/width and 1/height, zw: width and height)
int         _CustomShadowCount;
float4      _CustomShadowOffset0; // xy: offset0, zw: offset1
float4      _CustomShadowOffset1; // xy: offset2, zw: offset3
#if  defined(UNITY_PLATFORM_WEBGL) && !defined(SHADER_API_GLES3)
#define _USE_WEBGL 1
#define _WEBGL1_MAX_SHADOWS 8
#else
#define _USE_WEBGL 0
#endif

#if !_USE_WEBGL
#define CUSTOM_SHADOW_LOOP_BEGIN(shadowCount) \
    for (uint shadowIndex = 0u; shadowIndex < shadowCount; ++shadowIndex) {

#define CUSTOM_SHADOW_LOOP_END }
#else
// WebGL 1 doesn't support variable for loop conditions
#define CUSTOM_SHADOW_LOOP_BEGIN(shadowCount) \
    for (int shadowIndex = 0; shadowIndex < _WEBGL1_MAX_SHADOWS; ++shadowIndex) { \
        if (shadowIndex >= (int)shadowCount) break;

#define CUSTOM_SHADOW_LOOP_END }
#endif
// GLES3 causes a performance regression in some devices when using CBUFFER.
#ifndef SHADER_API_GLES3
CBUFFER_START(LightShadows)
#endif

// Last cascade is initialized with a no-op matrix. It always transforms
// shadow coord to half3(0, 0, NEAR_PLANE). We use this trick to avoid
// branching since ComputeCascadeIndex can return cascade index = MAX_SHADOW_CASCADES
float4x4    _MainLightWorldToShadow[MAX_SHADOW_CASCADES + 1];
float4      _CascadeShadowSplitSpheres0;
float4      _CascadeShadowSplitSpheres1;
float4      _CascadeShadowSplitSpheres2;
float4      _CascadeShadowSplitSpheres3;
float4      _CascadeShadowSplitSphereRadii;

float4      _MainLightShadowOffset0; // xy: offset0, zw: offset1
float4      _MainLightShadowOffset1; // xy: offset2, zw: offset3
float4      _MainLightShadowParams;   // (x: shadowStrength, y: >= 1.0 if soft shadows, 0.0 otherwise, z: main light fade scale, w: main light fade bias)
float4      _MainLightShadowmapSize;  // (xy: 1/width and 1/height, zw: width and height)

float4      _AdditionalShadowOffset0; // xy: offset0, zw: offset1
float4      _AdditionalShadowOffset1; // xy: offset2, zw: offset3
float4      _AdditionalShadowFadeParams; // x: additional light fade scale, y: additional light fade bias, z: 0.0, w: 0.0)
float4      _AdditionalShadowmapSize; // (xy: 1/width and 1/height, zw: width and height)

#if defined(ADDITIONAL_LIGHT_CALCULATE_SHADOWS)
#if !USE_STRUCTURED_BUFFER_FOR_LIGHT_DATA
// Point lights can use 6 shadow slices. Some mobile GPUs performance decrease drastically with uniform
// blocks bigger than 8kb while others have a 64kb max uniform block size. This number ensures size of buffer
// AdditionalLightShadows stays reasonable. It also avoids shader compilation errors on SHADER_API_GLES30
// devices where max number of uniforms per shader GL_MAX_FRAGMENT_UNIFORM_VECTORS is low (224)
float4      _AdditionalShadowParams[MAX_VISIBLE_LIGHTS];         // Per-light data
float4x4    _AdditionalLightsWorldToShadow[MAX_VISIBLE_LIGHTS];  // Per-shadow-slice-data
#endif
#endif

#ifndef SHADER_API_GLES3
CBUFFER_END
#endif

#if defined(ADDITIONAL_LIGHT_CALCULATE_SHADOWS)
    #if USE_STRUCTURED_BUFFER_FOR_LIGHT_DATA
        StructuredBuffer<float4>   _AdditionalShadowParams_SSBO;        // Per-light data - TODO: test if splitting _AdditionalShadowParams_SSBO[lightIndex].w into a separate StructuredBuffer<int> buffer is faster
        StructuredBuffer<float4x4> _AdditionalLightsWorldToShadow_SSBO; // Per-shadow-slice-data - A shadow casting light can have 6 shadow slices (if it's a point light)
    #endif
#endif

float4 _ShadowBias; // x: depth bias, y: normal bias

#define BEYOND_SHADOW_FAR(shadowCoord) shadowCoord.z <= 0.0 || shadowCoord.z >= 1.0

// Should match: UnityEngine.Rendering.Universal + 1
#define SOFT_SHADOW_QUALITY_OFF    half(0.0)
#define SOFT_SHADOW_QUALITY_LOW    half(1.0)
#define SOFT_SHADOW_QUALITY_MEDIUM half(2.0)
#define SOFT_SHADOW_QUALITY_HIGH   half(3.0)

struct ShadowSamplingData
{
    half4 shadowOffset0;
    half4 shadowOffset1;
    float4 shadowmapSize;
    half softShadowQuality;
};

ShadowSamplingData GetMainLightShadowSamplingData()
{
    ShadowSamplingData shadowSamplingData;

    // shadowOffsets are used in SampleShadowmapFiltered for low quality soft shadows.
    shadowSamplingData.shadowOffset0 = _MainLightShadowOffset0;
    shadowSamplingData.shadowOffset1 = _MainLightShadowOffset1;

    // shadowmapSize is used in SampleShadowmapFiltered otherwise
    shadowSamplingData.shadowmapSize = _MainLightShadowmapSize;
    shadowSamplingData.softShadowQuality = _MainLightShadowParams.y;

    return shadowSamplingData;
}
ShadowSamplingData GetCustomShadowSamplingData(int index)
{
    ShadowSamplingData shadowSamplingData = (ShadowSamplingData)0;

#if defined(CUSTOM_SHADOW_ON)|| defined(CUSTOM_SHADOW_ONLY_MAIN_LIGHT)
    // shadowOffsets are used in SampleShadowmapFiltered for low quality soft shadows.
    shadowSamplingData.shadowOffset0 = _CustomShadowOffset0;
    shadowSamplingData.shadowOffset1 = _CustomShadowOffset1;

    // shadowmapSize is used in SampleShadowmapFiltered otherwise.
    shadowSamplingData.shadowmapSize = _CustomShadowmapSize;
    shadowSamplingData.softShadowQuality = _CustomShadowParams[index].y;
#endif
    return shadowSamplingData;
}

ShadowSamplingData GetAdditionalLightShadowSamplingData(int index)
{
    ShadowSamplingData shadowSamplingData = (ShadowSamplingData)0;

    #if defined(ADDITIONAL_LIGHT_CALCULATE_SHADOWS)
        // shadowOffsets are used in SampleShadowmapFiltered for low quality soft shadows.
        shadowSamplingData.shadowOffset0 = _AdditionalShadowOffset0;
        shadowSamplingData.shadowOffset1 = _AdditionalShadowOffset1;

        // shadowmapSize is used in SampleShadowmapFiltered otherwise.
        shadowSamplingData.shadowmapSize = _AdditionalShadowmapSize;
        shadowSamplingData.softShadowQuality = _AdditionalShadowParams[index].y;
    #endif

    return shadowSamplingData;
}

// ShadowParams
// x: ShadowStrength
// y: 1.0 if shadow is soft, 0.0 otherwise
half4 GetMainLightShadowParams()
{
    return _MainLightShadowParams;
}


// ShadowParams
// x: ShadowStrength
// y: >= 1.0 if shadow is soft, 0.0 otherwise. Higher value for higher quality. (1.0 == low, 2.0 == medium, 3.0 == high)
// z: 1.0 if cast by a point light (6 shadow slices), 0.0 if cast by a spot light (1 shadow slice)
// w: first shadow slice index for this light, there can be 6 in case of point lights. (-1 for non-shadow-casting-lights)
half4 GetAdditionalLightShadowParams(int lightIndex)
{
    #if defined(ADDITIONAL_LIGHT_CALCULATE_SHADOWS)
        #if USE_STRUCTURED_BUFFER_FOR_LIGHT_DATA
            return _AdditionalShadowParams_SSBO[lightIndex];
        #else
            return _AdditionalShadowParams[lightIndex];
        #endif
    #else
        // Same defaults as set in AdditionalLightsShadowCasterPass.cs
        return half4(0, 0, 0, -1);
    #endif
}

half4 GetCustomShadowParams(int index)
{
#if defined(CUSTOM_SHADOW_ON) || defined(CUSTOM_SHADOW_ONLY_MAIN_LIGHT)

    return _CustomShadowParams[index];

#else
    // Same defaults as set in AdditionalLightsShadowCasterPass.cs
    return half4(0, 0, 0, -1);
#endif
}

half4 GetCustomShadowParams2(int index)
{
#if defined(CUSTOM_SHADOW_ON)|| defined(CUSTOM_SHADOW_ONLY_MAIN_LIGHT)

    return _CustomShadowParams2[index];

#else
    // Same defaults as set in AdditionalLightsShadowCasterPass.cs
    return half4(0, 0, 0, -1);
#endif
}

half4 GetCachedAdditionalLightShadowParams(int lightIndex)
{
#if defined(ADDITIONAL_LIGHT_CALCULATE_SHADOWS)

    return _CachedAdditionalShadowParams[lightIndex];

#else
    // Same defaults as set in AdditionalLightsShadowCasterPass.cs
    return half4(0, 0, 0, -1);
#endif
}
half SampleScreenSpaceShadowmap(float4 shadowCoord)
{
    shadowCoord.xy /= shadowCoord.w;

    // The stereo transform has to happen after the manual perspective divide
    shadowCoord.xy = UnityStereoTransformScreenSpaceTex(shadowCoord.xy);

#if defined(UNITY_STEREO_INSTANCING_ENABLED) || defined(UNITY_STEREO_MULTIVIEW_ENABLED)
    half attenuation = SAMPLE_TEXTURE2D_ARRAY(_ScreenSpaceShadowmapTexture, sampler_PointClamp, shadowCoord.xy, unity_StereoEyeIndex).x;
#else
    half attenuation = half(SAMPLE_TEXTURE2D(_ScreenSpaceShadowmapTexture, sampler_PointClamp, shadowCoord.xy).x);
#endif

    return attenuation;
}

real SampleShadowmapFiltered(TEXTURE2D_SHADOW_PARAM(ShadowMap, sampler_ShadowMap), float4 shadowCoord, ShadowSamplingData samplingData)
{
    real attenuation = real(1.0);

    if (samplingData.softShadowQuality == SOFT_SHADOW_QUALITY_LOW)
    {
        // 4-tap hardware comparison
        real4 attenuation4;
        attenuation4.x = real(SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, shadowCoord.xyz + float3(samplingData.shadowOffset0.xy, 0)));
        attenuation4.y = real(SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, shadowCoord.xyz + float3(samplingData.shadowOffset0.zw, 0)));
        attenuation4.z = real(SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, shadowCoord.xyz + float3(samplingData.shadowOffset1.xy, 0)));
        attenuation4.w = real(SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, shadowCoord.xyz + float3(samplingData.shadowOffset1.zw, 0)));
        attenuation = dot(attenuation4, real(0.25));
    }
    else if(samplingData.softShadowQuality == SOFT_SHADOW_QUALITY_MEDIUM)
    {
        real fetchesWeights[9];
        real2 fetchesUV[9];
        SampleShadow_ComputeSamples_Tent_5x5(samplingData.shadowmapSize, shadowCoord.xy, fetchesWeights, fetchesUV);

        attenuation = fetchesWeights[0] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[0].xy, shadowCoord.z))
                    + fetchesWeights[1] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[1].xy, shadowCoord.z))
                    + fetchesWeights[2] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[2].xy, shadowCoord.z))
                    + fetchesWeights[3] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[3].xy, shadowCoord.z))
                    + fetchesWeights[4] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[4].xy, shadowCoord.z))
                    + fetchesWeights[5] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[5].xy, shadowCoord.z))
                    + fetchesWeights[6] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[6].xy, shadowCoord.z))
                    + fetchesWeights[7] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[7].xy, shadowCoord.z))
                    + fetchesWeights[8] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[8].xy, shadowCoord.z));
    }
    else // SOFT_SHADOW_QUALITY_HIGH
    {
        real fetchesWeights[16];
        real2 fetchesUV[16];
        SampleShadow_ComputeSamples_Tent_7x7(samplingData.shadowmapSize, shadowCoord.xy, fetchesWeights, fetchesUV);

        attenuation = fetchesWeights[0] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[0].xy, shadowCoord.z))
                    + fetchesWeights[1] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[1].xy, shadowCoord.z))
                    + fetchesWeights[2] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[2].xy, shadowCoord.z))
                    + fetchesWeights[3] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[3].xy, shadowCoord.z))
                    + fetchesWeights[4] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[4].xy, shadowCoord.z))
                    + fetchesWeights[5] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[5].xy, shadowCoord.z))
                    + fetchesWeights[6] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[6].xy, shadowCoord.z))
                    + fetchesWeights[7] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[7].xy, shadowCoord.z))
                    + fetchesWeights[8] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[8].xy, shadowCoord.z))
                    + fetchesWeights[9] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[9].xy, shadowCoord.z))
                    + fetchesWeights[10] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[10].xy, shadowCoord.z))
                    + fetchesWeights[11] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[11].xy, shadowCoord.z))
                    + fetchesWeights[12] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[12].xy, shadowCoord.z))
                    + fetchesWeights[13] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[13].xy, shadowCoord.z))
                    + fetchesWeights[14] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[14].xy, shadowCoord.z))
                    + fetchesWeights[15] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[15].xy, shadowCoord.z));
    }

    return attenuation;
}

real SampleShadowmap(TEXTURE2D_SHADOW_PARAM(ShadowMap, sampler_ShadowMap), float4 shadowCoord, ShadowSamplingData samplingData, half4 shadowParams, bool isPerspectiveProjection = true)
{
    // Compiler will optimize this branch away as long as isPerspectiveProjection is known at compile time
    if (isPerspectiveProjection)
        shadowCoord.xyz /= shadowCoord.w;

    real attenuation;
    real shadowStrength = shadowParams.x;

#if (_SHADOWS_SOFT)
    if(shadowParams.y > SOFT_SHADOW_QUALITY_OFF)
    {
        attenuation = SampleShadowmapFiltered(TEXTURE2D_SHADOW_ARGS(ShadowMap, sampler_ShadowMap), shadowCoord, samplingData);
    }
    else
#endif
    {
        // 1-tap hardware comparison
        attenuation = real(SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, shadowCoord.xyz));
    }

    attenuation = LerpWhiteTo(attenuation, shadowStrength);

    // Shadow coords that fall out of the light frustum volume must always return attenuation 1.0
    // TODO: We could use branch here to save some perf on some platforms.
    return BEYOND_SHADOW_FAR(shadowCoord) ? 1.0 : attenuation;
}

half ComputeCascadeIndex(float3 positionWS)
{
    float3 fromCenter0 = positionWS - _CascadeShadowSplitSpheres0.xyz;
    float3 fromCenter1 = positionWS - _CascadeShadowSplitSpheres1.xyz;
    float3 fromCenter2 = positionWS - _CascadeShadowSplitSpheres2.xyz;
    float3 fromCenter3 = positionWS - _CascadeShadowSplitSpheres3.xyz;
    float4 distances2 = float4(dot(fromCenter0, fromCenter0), dot(fromCenter1, fromCenter1), dot(fromCenter2, fromCenter2), dot(fromCenter3, fromCenter3));

    half4 weights = half4(distances2 < _CascadeShadowSplitSphereRadii);
    weights.yzw = saturate(weights.yzw - weights.xyz);

    return half(4.0) - dot(weights, half4(4, 3, 2, 1));
}

float4 TransformWorldToShadowCoord(float3 positionWS)
{
#ifdef _MAIN_LIGHT_SHADOWS_CASCADE
    half cascadeIndex = ComputeCascadeIndex(positionWS);
#else
    half cascadeIndex = half(0.0);
#endif

    float4 shadowCoord = mul(_MainLightWorldToShadow[cascadeIndex], float4(positionWS, 1.0));

    return float4(shadowCoord.xyz, 0);
}

half MainLightRealtimeShadow(float4 shadowCoord, float3 positionWS = 0)
{

#if defined(_PER_MATERIAL_SHADOW_BIAS)
    shadowCoord = TransformWorldToShadowCoord(positionWS + shadowCoord.yzw * shadowCoord.x);
#endif

    #if !defined(MAIN_LIGHT_CALCULATE_SHADOWS)
        return half(1.0);
    #elif defined(_MAIN_LIGHT_SHADOWS_SCREEN) && !defined(_SURFACE_TYPE_TRANSPARENT)
        return SampleScreenSpaceShadowmap(shadowCoord);
    #else
        ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
        half4 shadowParams = GetMainLightShadowParams();
        return SampleShadowmap(TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_LinearClampCompare), shadowCoord, shadowSamplingData, shadowParams, false);
    #endif
}

// returns 0.0 if position is in light's shadow
// returns 1.0 if position is in light
half AdditionalLightRealtimeShadow(int lightIndex, float3 positionWS, half3 lightDirection, float shadowBias = 0)
{
    #if defined(ADDITIONAL_LIGHT_CALCULATE_SHADOWS)
        ShadowSamplingData shadowSamplingData = GetAdditionalLightShadowSamplingData(lightIndex);

        half4 shadowParams = GetAdditionalLightShadowParams(lightIndex);

        int shadowSliceIndex = shadowParams.w;
        if (shadowSliceIndex < 0)
            return 1.0;

        half isPointLight = shadowParams.z;

        UNITY_BRANCH
        if (isPointLight)
        {
            // This is a point light, we have to find out which shadow slice to sample from
            float cubemapFaceId = CubeMapFaceID(-lightDirection);
            shadowSliceIndex += cubemapFaceId;
        }


#if defined(_PER_MATERIAL_SHADOW_BIAS)
        positionWS += lightDirection * shadowBias;
#endif

        #if USE_STRUCTURED_BUFFER_FOR_LIGHT_DATA
            float4 shadowCoord = mul(_AdditionalLightsWorldToShadow_SSBO[shadowSliceIndex], float4(positionWS, 1.0));
        #else
            float4 shadowCoord = mul(_AdditionalLightsWorldToShadow[shadowSliceIndex], float4(positionWS, 1.0));
        #endif

        return SampleShadowmap(TEXTURE2D_ARGS(_AdditionalLightsShadowmapTexture, sampler_LinearClampCompare), shadowCoord, shadowSamplingData, shadowParams, true);
    #else
        return half(1.0);
    #endif
}

float4 GetCustomShadowPosition(int index)
{
    return _CustomShadowPositions[index];
}

half remap(half x, half in_min, half in_max, half out_min, half out_max) {
    return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min;
}

int GetCustomShadowCount() {
    return _CustomShadowCount;
}

half GetCustomShadowFalloff(half2 shadowCoord,
    half2 areaX, half2 areaY,
    half threshold) {
    return min(
        min(saturate(remap(shadowCoord.x, areaX.x, areaX.x + threshold, 0, 1)),
        saturate(remap(shadowCoord.x, areaX.y-threshold, areaX.y, 1, 0)))
        ,
        min(saturate(remap(shadowCoord.y, areaY.x, areaY.x + threshold, 0, 1)),
            saturate(remap(shadowCoord.y, areaY.y-threshold, areaY.y, 1, 0)))
    );
}
half GetCustomShadowFalloff(half3 shadowCoord,
    half2 areaX, half2 areaY,
    half threshold) {
    return min(
        min(
        min(saturate(remap(shadowCoord.x, areaX.x, areaX.x + threshold, 0, 1)),
            saturate(remap(shadowCoord.x, areaX.y - threshold, areaX.y, 1, 0)))
        ,
        min(saturate(remap(shadowCoord.y, areaY.x, areaY.x + threshold, 0, 1)),
            saturate(remap(shadowCoord.y, areaY.y - threshold, areaY.y, 1, 0)))
    )
        ,
        min(saturate(remap(shadowCoord.z, 0, threshold, 0, 1)),
            saturate(remap(shadowCoord.z, 1, 1-threshold, 0, 1)))
        );
}

half CustomShadow(int index, float3 positionWS, float depthBias = 0) {
    ShadowSamplingData shadowSamplingData = GetCustomShadowSamplingData(index);

    half4 shadowParams = GetCustomShadowParams(index);
    half4 shadowParams2 = GetCustomShadowParams2(index);

    float4 lightPos = GetCustomShadowPosition(index);
    float3 lightVector = lightPos.xyz - positionWS * lightPos.w;

    float distanceSqr = max(dot(lightVector, lightVector), HALF_MIN);
    half3 lightDirection = half3(lightVector * rsqrt(distanceSqr));

    float4 shadowCoord = mul(_CustomShadowMatrices[index], float4(positionWS + lightDirection * shadowParams.z + lightDirection * depthBias, 1.0));

    //shadowCoord.x += shadowParams2.x/ shadowCoord.w;
    //shadowCoord.y += shadowParams2.y/ shadowCoord.w;

    half shadowTileScale = 1.0 / (half)GetCustomShadowCount();

    float falloff = GetCustomShadowFalloff(half2(shadowCoord.x / shadowCoord.w,shadowCoord.y / shadowCoord.w), half2(shadowParams2.x, shadowParams2.y/*shadowParams2.y*/),
        half2(shadowParams2.z, shadowParams2.w/*shadowParams2.w*/),
        shadowParams.w * shadowTileScale * 0.25);

    //return falloff;
    
    return lerp(1,
        SampleShadowmap(TEXTURE2D_ARGS(_CustomShadowmapAtlas, sampler_LinearClampCompare), shadowCoord, shadowSamplingData, shadowParams, true)
        , falloff);
}

half CustomShadows(float depthBias, float3 positionWS)
{
    int shadowsCount = GetCustomShadowCount();
    half attenuation = 1;
    CUSTOM_SHADOW_LOOP_BEGIN(shadowsCount)
        attenuation *= CustomShadow((int)shadowIndex, positionWS, depthBias);
        CUSTOM_SHADOW_LOOP_END
   /* for (int shadowIndex = 0; shadowIndex < shadowsCount; ++shadowIndex) {
        attenuation *= CustomShadow(shadowIndex, positionWS);
    }*/
        return attenuation;
}


half CustomShadows(float3 positionWS)
{
    int shadowsCount = GetCustomShadowCount();
    half attenuation = 1;
    CUSTOM_SHADOW_LOOP_BEGIN(shadowsCount)
        attenuation *= CustomShadow((int)shadowIndex, positionWS);
    CUSTOM_SHADOW_LOOP_END
        /* for (int shadowIndex = 0; shadowIndex < shadowsCount; ++shadowIndex) {
             attenuation *= CustomShadow(shadowIndex, positionWS);
         }*/
        return attenuation;
}

half CachedAdditionalLightShadow(int lightIndex, float3 positionWS, half3 lightDirection) {
//#if defined(ADDITIONAL_LIGHT_CALCULATE_SHADOWS)
    ShadowSamplingData shadowSamplingData = GetAdditionalLightShadowSamplingData(lightIndex);

    half4 shadowParams = //half4(1, 1, 0, _CachedShadowOffset.z);//
        GetCachedAdditionalLightShadowParams(lightIndex);

    int shadowSliceIndex = shadowParams.w;
    if (shadowSliceIndex < 0)
        return 1.0;

    half isPointLight = shadowParams.z;

    UNITY_BRANCH
        if (isPointLight)
        {
            // This is a point light, we have to find out which shadow slice to sample from
            float cubemapFaceId = CubeMapFaceID(-lightDirection);
            shadowSliceIndex += cubemapFaceId;
        }

//#if USE_STRUCTURED_BUFFER_FOR_LIGHT_DATA
  //  float4 shadowCoord = mul(_AdditionalLightsWorldToShadow_SSBO[shadowSliceIndex], float4(positionWS, 1.0));
//#else
    float4 shadowCoord = mul(_CachedAdditionalLightsWorldToShadow[shadowSliceIndex], float4(positionWS, 1.0));
//#endif
    //float4 shadowCoord = mul(_CachedShadow, float4(positionWS+(lightDirection * _CachedShadowOffset.x), 1.0));
//
//    real attenuation = 1;
//
//    // Compiler will optimize this branch away as long as isPerspectiveProjection is known at compile time
//
//#if (_SHADOWS_SOFT)
//    if (shadowParams.y > SOFT_SHADOW_QUALITY_OFF)
//    {
//        attenuation = SampleShadowmapFiltered(TEXTURE2D_SHADOW_ARGS(_CachedShadowmap, sampler_LinearClampCompare), shadowCoord, shadowSamplingData);
//    }
//    else
//#endif
//    {
//        // 1-tap hardware comparison
//        attenuation = real(SAMPLE_TEXTURE2D_SHADOW(_CachedShadowmap, sampler_LinearClampCompare, shadowCoord.xyz));
//    }


    return //attenuation;//
    SampleShadowmap(TEXTURE2D_ARGS(_CachedShadowmapAtlas, sampler_LinearClampCompare), shadowCoord, shadowSamplingData, shadowParams, true);
//#else
//    return half(1.0);
//#endif
}

half GetMainLightShadowFade(float3 positionWS)
{
    float3 camToPixel = positionWS - _WorldSpaceCameraPos;
    float distanceCamToPixel2 = dot(camToPixel, camToPixel);

    float fade = saturate(distanceCamToPixel2 * float(_MainLightShadowParams.z) + float(_MainLightShadowParams.w));
    return half(fade);
}

half GetAdditionalLightShadowFade(float3 positionWS)
{
    #if defined(ADDITIONAL_LIGHT_CALCULATE_SHADOWS)
        float3 camToPixel = positionWS - _WorldSpaceCameraPos;
        float distanceCamToPixel2 = dot(camToPixel, camToPixel);

        float fade = saturate(distanceCamToPixel2 * float(_AdditionalShadowFadeParams.x) + float(_AdditionalShadowFadeParams.y));
        return half(fade);
    #else
        return half(1.0);
    #endif
}

half MixRealtimeAndBakedShadows(half realtimeShadow, half bakedShadow, half shadowFade)
{
#if defined(LIGHTMAP_SHADOW_MIXING)
    return min(lerp(realtimeShadow, 1, shadowFade), bakedShadow);
#else
    return lerp(realtimeShadow, bakedShadow, shadowFade);
#endif
}

half BakedShadow(half4 shadowMask, half4 occlusionProbeChannels)
{
    // Here occlusionProbeChannels used as mask selector to select shadows in shadowMask
    // If occlusionProbeChannels all components are zero we use default baked shadow value 1.0
    // This code is optimized for mobile platforms:
    // half bakedShadow = any(occlusionProbeChannels) ? dot(shadowMask, occlusionProbeChannels) : 1.0h;
    half bakedShadow = half(1.0) + dot(shadowMask - half(1.0), occlusionProbeChannels);
    return bakedShadow;
}

half MainLightShadow(float4 shadowCoord, float3 positionWS, half4 shadowMask, half4 occlusionProbeChannels)
{
    half realtimeShadow = MainLightRealtimeShadow(shadowCoord, positionWS);

#ifdef CALCULATE_BAKED_SHADOWS
    half bakedShadow = BakedShadow(shadowMask, occlusionProbeChannels);
#else
    half bakedShadow = half(1.0);
#endif

#ifdef MAIN_LIGHT_CALCULATE_SHADOWS
    half shadowFade = GetMainLightShadowFade(positionWS);
#else
    half shadowFade = half(1.0);
#endif

    return MixRealtimeAndBakedShadows(realtimeShadow, bakedShadow, shadowFade);
}

half AdditionalLightShadow(int lightIndex, float3 positionWS, half3 lightDirection, half4 shadowMask, half4 occlusionProbeChannels, float shadowBias = 0)
{
#if defined(CACHED_SHADOW_ON)
    half realtimeShadow = min( AdditionalLightRealtimeShadow(lightIndex, positionWS, lightDirection, shadowBias), CachedAdditionalLightShadow(lightIndex, positionWS, lightDirection));
#else
    half realtimeShadow = AdditionalLightRealtimeShadow(lightIndex, positionWS, lightDirection, shadowBias);
#endif
#ifdef CALCULATE_BAKED_SHADOWS
    half bakedShadow = BakedShadow(shadowMask, occlusionProbeChannels);
#else
    half bakedShadow = half(1.0);
#endif

#ifdef ADDITIONAL_LIGHT_CALCULATE_SHADOWS
    half shadowFade = GetAdditionalLightShadowFade(positionWS);
#else
    half shadowFade = half(1.0);
#endif

    return MixRealtimeAndBakedShadows(realtimeShadow, bakedShadow, shadowFade);
}

float4 GetShadowCoord(VertexPositionInputs vertexInput)
{
#if defined(_MAIN_LIGHT_SHADOWS_SCREEN) && !defined(_SURFACE_TYPE_TRANSPARENT)
    return ComputeScreenPos(vertexInput.positionCS);
#else
    return TransformWorldToShadowCoord(vertexInput.positionWS);
#endif
}

float3 ApplyShadowBias(float3 positionWS, float3 normalWS, float3 lightDirection)
{
    float invNdotL = 1.0 - saturate(dot(lightDirection, normalWS));
    float scale = invNdotL * _ShadowBias.y;

    // normal bias is negative since we want to apply an inset normal offset
    positionWS = lightDirection * _ShadowBias.xxx + positionWS;
    positionWS = normalWS * scale.xxx + positionWS;
    return positionWS;
}

///////////////////////////////////////////////////////////////////////////////
// Deprecated                                                                 /
///////////////////////////////////////////////////////////////////////////////

// Renamed -> _MainLightShadowParams
#define _MainLightShadowData _MainLightShadowParams

// Deprecated: Use GetMainLightShadowFade or GetAdditionalLightShadowFade instead.
float GetShadowFade(float3 positionWS)
{
    float3 camToPixel = positionWS - _WorldSpaceCameraPos;
    float distanceCamToPixel2 = dot(camToPixel, camToPixel);

    float fade = saturate(distanceCamToPixel2 * float(_MainLightShadowParams.z) + float(_MainLightShadowParams.w));
    return fade * fade;
}

// Deprecated: Use GetShadowFade instead.
float ApplyShadowFade(float shadowAttenuation, float3 positionWS)
{
    float fade = GetShadowFade(positionWS);
    return shadowAttenuation + (1 - shadowAttenuation) * fade * fade;
}

// Deprecated: Use GetMainLightShadowParams instead.
half GetMainLightShadowStrength()
{
    return _MainLightShadowData.x;
}

// Deprecated: Use GetAdditionalLightShadowParams instead.
half GetAdditionalLightShadowStrenth(int lightIndex)
{
    #if defined(ADDITIONAL_LIGHT_CALCULATE_SHADOWS)
        #if USE_STRUCTURED_BUFFER_FOR_LIGHT_DATA
            return _AdditionalShadowParams_SSBO[lightIndex].x;
        #else
            return _AdditionalShadowParams[lightIndex].x;
        #endif
    #else
        return half(1.0);
    #endif
}

// Deprecated: Use SampleShadowmap that takes shadowParams instead of strength.
real SampleShadowmap(float4 shadowCoord, TEXTURE2D_SHADOW_PARAM(ShadowMap, sampler_ShadowMap), ShadowSamplingData samplingData, half shadowStrength, bool isPerspectiveProjection = true)
{
    half4 shadowParams = half4(shadowStrength, 1.0, 0.0, 0.0);
    return SampleShadowmap(TEXTURE2D_SHADOW_ARGS(ShadowMap, sampler_ShadowMap), shadowCoord, samplingData, shadowParams, isPerspectiveProjection);
}

// Deprecated: Use AdditionalLightRealtimeShadow(int lightIndex, float3 positionWS, half3 lightDirection) in Shadows.hlsl instead, as it supports Point Light shadows
half AdditionalLightRealtimeShadow(int lightIndex, float3 positionWS)
{
    return AdditionalLightRealtimeShadow(lightIndex, positionWS, half3(1, 0, 0));
}

#endif
