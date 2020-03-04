// Physical properties for each ThirdWire shader
#define TWNORMAL_SPECULAR 0.4f
#define TWNORMAL_ROUGHNESS 0.7f

#define NOTTEXTURE_SPECULAR 0.0f
#define NOTTEXTURE_ROUGHNESS 0.9f

#define MESHREFLECTION_SPECULAR 0.0f
#define MESHREFLECTION_ROUGHNESS 0.15f

#define MESHDECAL_SPECULAR 0.5f
#define MESHDECAL_ROUGHNESS 0.8f

#define TERRAIN_SPECULAR 0.0f
#define TERRAIN_ROUGHNESS 1.0f

#define CANOPY_SPECULAR 1.0f
#define CANOPY_ROUGHNESS 0.5f

// Sample size for irradiance map calculations
// The smaller the value the more accurate, but at cost of performance
#define IRRADIANCE_SAMPLEDELTA 0.15

// Sample count for IBL specular calculations
// #define IBL_SAMPLECOUNT 1024u
#define IBL_SAMPLECOUNT 256u