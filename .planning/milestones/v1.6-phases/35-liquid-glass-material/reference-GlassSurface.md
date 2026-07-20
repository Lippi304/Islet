# Reference: React Bits `<GlassSurface />` (JS + CSS)

User-supplied reference for the Phase 35 "Liquid Glass" material look. Original component is React/CSS — **not to be integrated as-is** (no React in this project). This file exists so downstream agents (researcher, planner) can read the exact visual technique to port into SwiftUI/AppKit, without depending on chat history.

**Ignored on purpose:** the component's own "Integration Instructions" (npm install, copy .jsx/.css into project, import/render). Not applicable — extract technique only.

## What it actually does

Two rendering paths, selected by feature-detecting SVG `backdrop-filter` support:

### Path 1 — `glass-surface--svg` (the "real" look)
An SVG `<filter>` with `feDisplacementMap` warps the backdrop per-pixel using a generated displacement map image (a rounded rect: bright near the edges, dark/blurred in the center, driven by `borderWidth`/`brightness`/`opacity`/`blur`). Three separate `feDisplacementMap` passes run against the same map with **independently offset scale factors per RGB channel** (`redOffset`, `greenOffset`, `blueOffset` added to a shared `distortionScale`), then recombined via `feBlend` (screen mode) and a final `feGaussianBlur`. The per-channel offset is what produces **chromatic-aberration edge fringing** — a subtle rainbow fringe at the warped edges, on top of the geometric warp itself.

CSS backdrop:
```css
.glass-surface--svg {
  background: hsl(0 0% 100% / var(--glass-frost, 0));  /* near-transparent frost */
  backdrop-filter: var(--filter-id) saturate(var(--glass-saturation, 1));
  box-shadow: /* multiple inset + outer shadows for rim highlight/depth */;
}
```

### Path 2 — `glass-surface--fallback` (Safari/Firefox, no SVG backdrop-filter support)
No distortion at all — just:
```css
backdrop-filter: blur(12px) saturate(1.8) brightness(1.1);
background: rgba(255,255,255,0.25);           /* rgba(255,255,255,0.1) in dark mode */
border: 1px solid rgba(255,255,255,0.3);
box-shadow: /* outer glow + inset highlight/shadow */
```

## SwiftUI porting notes (from discussion)

- **Distortion path 1 → `.distortionEffect(_:maxSampleOffset:)`** (SwiftUI Shader API, macOS 14+, no deployment-target bump needed from today's 15.0 floor). A Metal shader computes a per-pixel sample offset — the direct SwiftUI equivalent of `feDisplacementMap`. Decision: **build this** (full warp + chromatic fringe), not the simplified fallback.
- **Important constraint:** `.distortionEffect()` only warps content within the SwiftUI layer it's applied to — i.e. it distorts the app's own rendered material/gradient fill, **not** the live desktop content behind the transparent `NSPanel`. There is no "see the desktop bend through real glass" effect here; the warp is applied to Islet's own backdrop material layer.
- **Fallback path 2** maps directly to `.ultraThinMaterial` + saturation/brightness modifiers + a gradient-stroke rim highlight — this is the "cheap" option that was considered and explicitly **not** chosen (user wants the distortion visible).
- **Base gradient preserved:** the existing Phase 25 `gradientMaterial` (black near the top/screen edge → more transparent toward the bottom) stays as the visual direction/base fill; the new material composes the distortion shader + backdrop material **on top of** that gradient, not as a replacement for the vertical fade direction.

## Full original source (for exact parameter/formula reference)

<details>
<summary>GlassSurface.jsx</summary>

```jsx
/* eslint-disable react-hooks/exhaustive-deps */
import { useEffect, useState, useRef, useId } from 'react';
import './GlassSurface.css';

const GlassSurface = ({
  children,
  width = 200,
  height = 80,
  borderRadius = 20,
  borderWidth = 0.07,
  brightness = 50,
  opacity = 0.93,
  blur = 11,
  displace = 0,
  backgroundOpacity = 0,
  saturation = 1,
  distortionScale = -180,
  redOffset = 0,
  greenOffset = 10,
  blueOffset = 20,
  xChannel = 'R',
  yChannel = 'G',
  mixBlendMode = 'difference',
  className = '',
  style = {}
}) => {
  const uniqueId = useId().replace(/:/g, '-');
  const filterId = `glass-filter-${uniqueId}`;
  const redGradId = `red-grad-${uniqueId}`;
  const blueGradId = `blue-grad-${uniqueId}`;

  const [svgSupported, setSvgSupported] = useState(false);

  const containerRef = useRef(null);
  const feImageRef = useRef(null);
  const redChannelRef = useRef(null);
  const greenChannelRef = useRef(null);
  const blueChannelRef = useRef(null);
  const gaussianBlurRef = useRef(null);

  const generateDisplacementMap = () => {
    const rect = containerRef.current?.getBoundingClientRect();
    const actualWidth = rect?.width || 400;
    const actualHeight = rect?.height || 200;
    const edgeSize = Math.min(actualWidth, actualHeight) * (borderWidth * 0.5);

    const svgContent = `
      <svg viewBox="0 0 ${actualWidth} ${actualHeight}" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <linearGradient id="${redGradId}" x1="100%" y1="0%" x2="0%" y2="0%">
            <stop offset="0%" stop-color="#0000"/>
            <stop offset="100%" stop-color="red"/>
          </linearGradient>
          <linearGradient id="${blueGradId}" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" stop-color="#0000"/>
            <stop offset="100%" stop-color="blue"/>
          </linearGradient>
        </defs>
        <rect x="0" y="0" width="${actualWidth}" height="${actualHeight}" fill="black"></rect>
        <rect x="0" y="0" width="${actualWidth}" height="${actualHeight}" rx="${borderRadius}" fill="url(#${redGradId})" />
        <rect x="0" y="0" width="${actualWidth}" height="${actualHeight}" rx="${borderRadius}" fill="url(#${blueGradId})" style="mix-blend-mode: ${mixBlendMode}" />
        <rect x="${edgeSize}" y="${edgeSize}" width="${actualWidth - edgeSize * 2}" height="${actualHeight - edgeSize * 2}" rx="${borderRadius}" fill="hsl(0 0% ${brightness}% / ${opacity})" style="filter:blur(${blur}px)" />
      </svg>
    `;

    return `data:image/svg+xml,${encodeURIComponent(svgContent)}`;
  };

  const updateDisplacementMap = () => {
    feImageRef.current?.setAttribute('href', generateDisplacementMap());
  };

  useEffect(() => {
    updateDisplacementMap();
    [
      { ref: redChannelRef, offset: redOffset },
      { ref: greenChannelRef, offset: greenOffset },
      { ref: blueChannelRef, offset: blueOffset }
    ].forEach(({ ref, offset }) => {
      if (ref.current) {
        ref.current.setAttribute('scale', (distortionScale + offset).toString());
        ref.current.setAttribute('xChannelSelector', xChannel);
        ref.current.setAttribute('yChannelSelector', yChannel);
      }
    });

    gaussianBlurRef.current?.setAttribute('stdDeviation', displace.toString());
  }, [
    width, height, borderRadius, borderWidth, brightness, opacity, blur, displace,
    distortionScale, redOffset, greenOffset, blueOffset, xChannel, yChannel, mixBlendMode
  ]);

  useEffect(() => {
    if (!containerRef.current) return;
    const resizeObserver = new ResizeObserver(() => { setTimeout(updateDisplacementMap, 0); });
    resizeObserver.observe(containerRef.current);
    return () => { resizeObserver.disconnect(); };
  }, []);

  useEffect(() => { setTimeout(updateDisplacementMap, 0); }, [width, height]);
  useEffect(() => { setSvgSupported(supportsSVGFilters()); }, []);

  const supportsSVGFilters = () => {
    if (typeof window === 'undefined' || typeof document === 'undefined') return false;
    const isWebkit = /Safari/.test(navigator.userAgent) && !/Chrome/.test(navigator.userAgent);
    const isFirefox = /Firefox/.test(navigator.userAgent);
    if (isWebkit || isFirefox) return false;
    const div = document.createElement('div');
    div.style.backdropFilter = `url(#${filterId})`;
    return div.style.backdropFilter !== '';
  };

  const containerStyle = {
    ...style,
    width: typeof width === 'number' ? `${width}px` : width,
    height: typeof height === 'number' ? `${height}px` : height,
    borderRadius: `${borderRadius}px`,
    '--glass-frost': backgroundOpacity,
    '--glass-saturation': saturation,
    '--filter-id': `url(#${filterId})`
  };

  return (
    <div ref={containerRef} className={`glass-surface ${svgSupported ? 'glass-surface--svg' : 'glass-surface--fallback'} ${className}`} style={containerStyle}>
      <svg className="glass-surface__filter" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <filter id={filterId} colorInterpolationFilters="sRGB" x="0%" y="0%" width="100%" height="100%">
            <feImage ref={feImageRef} x="0" y="0" width="100%" height="100%" preserveAspectRatio="none" result="map" />
            <feDisplacementMap ref={redChannelRef} in="SourceGraphic" in2="map" id="redchannel" result="dispRed" />
            <feColorMatrix in="dispRed" type="matrix" values="1 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 1 0" result="red" />
            <feDisplacementMap ref={greenChannelRef} in="SourceGraphic" in2="map" id="greenchannel" result="dispGreen" />
            <feColorMatrix in="dispGreen" type="matrix" values="0 0 0 0 0  0 1 0 0 0  0 0 0 0 0  0 0 0 1 0" result="green" />
            <feDisplacementMap ref={blueChannelRef} in="SourceGraphic" in2="map" id="bluechannel" result="dispBlue" />
            <feColorMatrix in="dispBlue" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 1 0 0  0 0 0 1 0" result="blue" />
            <feBlend in="red" in2="green" mode="screen" result="rg" />
            <feBlend in="rg" in2="blue" mode="screen" result="output" />
            <feGaussianBlur ref={gaussianBlurRef} in="output" stdDeviation="0.7" />
          </filter>
        </defs>
      </svg>
      <div className="glass-surface__content">{children}</div>
    </div>
  );
};

export default GlassSurface;
```
</details>

<details>
<summary>GlassSurface.css</summary>

```css
.glass-surface {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  transition: opacity 0.26s ease-out;
}

.glass-surface__filter {
  width: 100%;
  height: 100%;
  pointer-events: none;
  position: absolute;
  inset: 0;
  opacity: 0;
  z-index: -1;
}

.glass-surface__content {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0.5rem;
  border-radius: inherit;
  position: relative;
  z-index: 1;
}

.glass-surface--svg {
  background: light-dark(hsl(0 0% 100% / var(--glass-frost, 0)), hsl(0 0% 0% / var(--glass-frost, 0)));
  backdrop-filter: var(--filter-id, url(#glass-filter)) saturate(var(--glass-saturation, 1));
  box-shadow:
    0 0 2px 1px light-dark(color-mix(in oklch, black, transparent 85%), color-mix(in oklch, white, transparent 65%)) inset,
    0 0 10px 4px light-dark(color-mix(in oklch, black, transparent 90%), color-mix(in oklch, white, transparent 85%)) inset,
    0px 4px 16px rgba(17, 17, 26, 0.05),
    0px 8px 24px rgba(17, 17, 26, 0.05),
    0px 16px 56px rgba(17, 17, 26, 0.05),
    0px 4px 16px rgba(17, 17, 26, 0.05) inset,
    0px 8px 24px rgba(17, 17, 26, 0.05) inset,
    0px 16px 56px rgba(17, 17, 26, 0.05) inset;
}

.glass-surface--fallback {
  background: rgba(255, 255, 255, 0.25);
  backdrop-filter: blur(12px) saturate(1.8) brightness(1.1);
  -webkit-backdrop-filter: blur(12px) saturate(1.8) brightness(1.1);
  border: 1px solid rgba(255, 255, 255, 0.3);
  box-shadow:
    0 8px 32px 0 rgba(31, 38, 135, 0.2),
    0 2px 16px 0 rgba(31, 38, 135, 0.1),
    inset 0 1px 0 0 rgba(255, 255, 255, 0.4),
    inset 0 -1px 0 0 rgba(255, 255, 255, 0.2);
}

@media (prefers-color-scheme: dark) {
  .glass-surface--fallback {
    background: rgba(255, 255, 255, 0.1);
    backdrop-filter: blur(12px) saturate(1.8) brightness(1.2);
    -webkit-backdrop-filter: blur(12px) saturate(1.8) brightness(1.2);
    border: 1px solid rgba(255, 255, 255, 0.2);
    box-shadow:
      inset 0 1px 0 0 rgba(255, 255, 255, 0.2),
      inset 0 -1px 0 0 rgba(255, 255, 255, 0.1);
  }
}
```
</details>

## Props reference (for tuning equivalents)

| Prop | Default | SwiftUI-shader equivalent |
|------|---------|---------------------------|
| `borderRadius` | 20 | Match `NotchShape`'s existing corner radii, not a free parameter |
| `borderWidth` | 0.07 | Edge-band width where distortion is strongest (fraction of min(width,height)) |
| `brightness` | 50 | Displacement map center brightness — tune strength of inner (near-zero) distortion |
| `blur` | 11 | Input blur before displacement — softens the map |
| `distortionScale` | -180 | Overall displacement strength (negative = inward warp direction) |
| `redOffset`/`greenOffset`/`blueOffset` | 0/10/20 | Per-channel scale delta from `distortionScale` — drives the chromatic fringe width |
| `saturation` | 1 | Backdrop saturation multiplier |
| `backgroundOpacity` | 0 | Frost layer opacity on top of the distorted backdrop |

**Decision:** port the numeric relationships (per-channel offset delta, blur-before-displace, edge-band width), not the literal pixel values — those need on-device tuning against Islet's actual pill/wing dimensions (much smaller than this component's 200-400pt web defaults).
