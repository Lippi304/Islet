# Reference: componentry.fun "Signature" component — onboarding animation (ONBOARD-04)

**Source:** `npx shadcn@latest add @componentry/signature` (componentry.fun's shadcn registry). User supplied the full component source directly in discussion.

**Font dependency:** `LastoriaBoldRegular.otf`, fetched during discussion from `https://www.componentry.fun/LastoriaBoldRegular.otf` (confirmed live, 177816 bytes, valid OTF/TrueType). **FLAGGED LICENSE RISK — read before using this font file:** the font's own embedded metadata reads `Typeface © Abo Daniel 2019. All Rights Reserved.` componentry.fun requiring users to download it into their own project does not itself grant a commercial redistribution/embedding license — it's the demo site's convenience hosting, not a license. Islet is a paid product (€7.99 one-time). The user's own response when asked directly was uncertain ("Das hier ist alles opensource aber irgendwie" — not a confirmed license). **Researcher/planner must verify actual usage terms for "La storia Bold" before shipping** (check the font's original source/foundry for its real license), and have a libre substitute (e.g. an OFL-licensed script/handwriting font) ready if commercial use can't be confirmed. Do not ship the .otf file as-is without resolving this.

**Full component source:**

```tsx
"use client";

import { useEffect, useId, useState } from "react";
import { motion } from "framer-motion";
import opentype from "opentype.js";
import { cn } from "@/lib/utils";

interface SignatureProps {
  /** Text to generate signature for */
  text?: string;
  /** Color of the signature path */
  color?: string;
  /** Font size of the signature */
  fontSize?: number;
  /** Animation duration in seconds */
  duration?: number;
  /** Delay before animation starts in seconds */
  delay?: number;
  /** Additional CSS classes */
  className?: string;
  /** Only animate when in view */
  inView?: boolean;
  /** Only animate once */
  once?: boolean;
  /** Custom font URL to load */
  fontUrl?: string;
}

export function Signature({
  text = "Signature",
  color = "currentColor",
  fontSize = 32,
  duration = 1.5,
  delay = 0,
  className,
  inView = false,
  once = true,
  fontUrl,
}: SignatureProps) {
  const [paths, setPaths] = useState<string[]>([]);
  const [width, setWidth] = useState<number>(300);
  const height = fontSize * 3; // Give plenty of vertical space
  const horizontalPadding = fontSize * 0.1;
  const topMargin = fontSize * 1.5; // Shift down
  const baseline = topMargin;
  const maskId = `signature-reveal-${useId().replace(/:/g, "")}`;

  useEffect(() => {
    async function load() {
      try {
        let font;
        const fontPaths = fontUrl
          ? [fontUrl]
          : [
              "/LastoriaBoldRegular.otf",
              "./LastoriaBoldRegular.otf",
              "https://www.componentry.fun/LastoriaBoldRegular.otf",
            ];
        for (const path of fontPaths) {
          try {
            font = await opentype.load(path as string);
            break;
          } catch {
            // Try next path
          }
        }
        if (!font) {
          throw new Error("Font could not be loaded from any path");
        }
        let x = horizontalPadding;
        const newPaths: string[] = [];
        for (const char of text) {
          const glyph = font.charToGlyph(char);
          const path = glyph.getPath(x, baseline, fontSize);
          newPaths.push(path.toPathData(3));
          const advanceWidth = glyph.advanceWidth ?? font.unitsPerEm;
          x += advanceWidth * (fontSize / font.unitsPerEm);
        }
        setPaths(newPaths);
        setWidth(x + horizontalPadding);
      } catch (error) {
        console.error("Signature component font load error:", error);
        setPaths([]);
        setWidth(text.length * fontSize * 0.6);
      }
    }
    load();
  }, [text, fontSize, baseline, horizontalPadding, fontUrl]);

  const variants = {
    hidden: { pathLength: 0, opacity: 0 },
    visible: { pathLength: 1, opacity: 1 },
  };

  return (
    <motion.svg
      key={paths.length}
      width={width}
      height={height}
      viewBox={`0 0 ${width} ${height}`}
      fill="none"
      className={cn("text-foreground overflow-visible", className)}
      initial="hidden"
      whileInView={inView ? "visible" : undefined}
      animate={inView ? undefined : "visible"}
      viewport={{ once }}
    >
      <defs>
        <mask id={maskId} maskUnits="userSpaceOnUse">
          {paths.map((d, i) => (
            <motion.path
              key={i}
              d={d}
              stroke="white"
              strokeWidth={fontSize * 0.22}
              fill="none"
              variants={variants}
              transition={{
                pathLength: {
                  delay: delay + i * 0.2,
                  duration,
                  ease: "easeInOut",
                },
                opacity: {
                  delay: delay + i * 0.2 + 0.01,
                  duration: 0.01,
                },
              }}
              vectorEffect="non-scaling-stroke"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          ))}
        </mask>
      </defs>
      {paths.map((d, i) => (
        <motion.path
          key={i}
          d={d}
          stroke={color}
          strokeWidth={2}
          fill="none"
          variants={variants}
          transition={{
            pathLength: {
              delay: delay + i * 0.2,
              duration,
              ease: "easeInOut",
            },
            opacity: {
              delay: delay + i * 0.2 + 0.01,
              duration: 0.01,
            },
          }}
          vectorEffect="non-scaling-stroke"
          strokeLinecap="butt"
          strokeLinejoin="round"
        />
      ))}
      <g mask={`url(#${maskId})`}>
        {paths.map((d, i) => (
          <path key={i} d={d} fill={color} />
        ))}
      </g>
    </motion.svg>
  );
}
```

## How this maps onto ONBOARD-04 (per 36-CONTEXT.md decisions)

- **Text:** `"Meet Islet"` (locked — user's choice over just "Islet").
- **Color:** the app's existing orange accent (locked — not the rainbow-gradient alternative the user first floated).
- **Mechanism:** per character, get a vector glyph outline from the font, animate `pathLength` 0→1 (a stroke literally "drawing" the letter), staggered by `i * 0.2s`, ~1.5s duration, ease-in-out — then the completed strokes reveal a filled glyph via a mask. This is a genuine hand-drawing reveal, not a simple fade/slide.
- **SwiftUI porting note (planner's call, not decided here):** there's no `opentype.js` equivalent built into SwiftUI, but Core Text (`CTFontCreatePathForGlyph`) can extract the same per-glyph vector outline at runtime, which can then drive a SwiftUI `Shape`/`Path` with `.trim(from:to:)` animated 0→1 per glyph (SwiftUI's native analog to `pathLength`) — same staggered-delay, ease-in-out contract. This is a technique decision for the research/planning phase, not locked here.
- **Scope boundary:** only the "Meet Islet" heading on onboarding page 1 is replaced. The body subtext below it (`"Your notch, upgraded. Now Playing, charging, and a drag-and-drop shelf — always one glance away."`) stays completely unchanged — same font, same text, same timing.
