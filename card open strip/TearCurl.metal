#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]]
half4 tearCurl(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float progress,
    float curlRadius
) {
    if (progress < 0.001) {
        return layer.sample(position);
    }

    float2 uv = position / size;
    float R = curlRadius * 0.35;

    // Tear direction: fold peels leftward, fold line moves left to right
    float2 dir = float2(-1.0, 0.0);

    // Origin at left edge — fold line sweeps from x=0 to x=1
    float2 origin = float2(0.0, 0.5);

    float2 foldCenter = origin - dir * progress;

    // Signed distance from fold line along dir
    float d = dot(uv - foldCenter, dir);

    // === ZONE: Paper peeled away (d > R) ===
    if (d > R) {
        return half4(0, 0, 0, 0);
    }

    // === ZONE: On the cylinder (0 <= d <= R) ===
    if (d >= 0.0) {
        float theta = asin(clamp(d / R, 0.0, 1.0));

        // Back surface
        float backArc = (M_PI_F - theta) * R;
        float2 backUV = uv + dir * (backArc - d);
        bool backValid = (backUV.x >= 0.0 && backUV.x <= 1.0 &&
                          backUV.y >= 0.0 && backUV.y <= 1.0);

        if (backValid) {
            half4 color = layer.sample(clamp(backUV, float2(0.0), float2(1.0)) * size);
            float cylT = theta / (M_PI_F / 2.0);
            float shade = mix(0.85, 0.75, cylT);
            color.rgb *= half3(shade);
            return color;
        }

        // Front surface
        float frontArc = theta * R;
        float2 frontUV = uv + dir * (frontArc - d);
        if (frontUV.x < 0.0 || frontUV.x > 1.0 || frontUV.y < 0.0 || frontUV.y > 1.0) {
            return half4(0, 0, 0, 0);
        }
        half4 color = layer.sample(frontUV * size);
        float cylFrontT = theta / (M_PI_F / 2.0);
        float shade = mix(0.85, 0.6, cylFrontT);
        color.rgb *= half3(shade);
        return color;
    }

    // === ZONE: Flat side (d < 0) ===
    float R2 = R * mix(5.0, 1.5, progress);
    float behindDist = -d;

    if (behindDist < R2) {
        float theta2 = asin(clamp(behindDist / R2, 0.0, 1.0));
        float arcLen2 = theta2 * R2;
        float origDist = M_PI_F * R + arcLen2;

        float2 foldPoint = uv + dir * behindDist;
        float2 backUV = foldPoint + dir * origDist;

        bool backCovers = (backUV.x >= 0.0 && backUV.x <= 1.0 &&
                           backUV.y >= 0.0 && backUV.y <= 1.0);

        if (backCovers) {
            half4 color = layer.sample(backUV * size);
            float curlT = theta2 / (M_PI_F / 2.0);
            float shadow = mix(0.85, 0.75, curlT);
            color.rgb *= half3(shadow);
            return color;
        }
    }

    // Original flat content with shadow near fold line
    half4 flat = layer.sample(position);
    if (d > -0.08) {
        float shadowT = exp(d * 20.0);
        float shade = mix(1.0, 0.85, shadowT);
        flat.rgb *= half3(shade);
    }
    return flat;
}
