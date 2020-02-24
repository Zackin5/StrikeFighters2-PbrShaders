
// Sample size for irradiance map calculations
// The smaller the value the more accurate, but at cost of performance
#define IRRADIANCE_SAMPLEDELTA 0.05

// Sample count for IBL specular calculations
// #define IBL_SAMPLECOUNT 1024u
#define IBL_SAMPLECOUNT 256u

// Physical properties for each ThirdWire shader
#define TWNORMAL_METALLIC 0.0f
#define TWNORMAL_ROUGHNESS 0.9f

#define MESHREFLECTION_METALLIC 0.0f
#define MESHREFLECTION_ROUGHNESS 0.25f

#define MESHDECAL_METALLIC 0.0f
#define MESHDECAL_ROUGHNESS 0.5f

#define CANOPY_METALLIC 0.0f
#define CANOPY_ROUGHNESS 0.2f