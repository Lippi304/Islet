# Reference: Skiper 25 "Music toggle btn" — equalizer bars source (EQ-01)

**Source:** https://skiper-ui.com/v1/skiper25 (component page), source fetched via the shadcn registry JSON at https://skiper-ui.com/r/skiper25.json (the page's own "view source" is JS-interactive and not reachable via a plain HTTP fetch — this is the exact `skiper25.tsx` file content from the registry).

**License (per the registry file's own header comment):** "Free to use and modify in both personal and commercial projects. Attribution to Skiper UI is required when using the free version. No attribution required with Skiper UI Pro." — Author: @gurvinder-singh02, https://gxuri.me. No attribution mechanism currently exists in Islet's UI; planner should decide where a lightweight credit could live (e.g. About screen), or confirm Pro licensing removes the requirement.

**Full component source (`skiper25.tsx`):**

```tsx
"use client";

import { motion } from "framer-motion";
import React, { useEffect, useState } from "react";
import useSound from "use-sound";

const Skiper25 = () => {
  return (
    <div className="flex h-full w-full flex-col items-center justify-center">
      <div className="text-foreground absolute top-[20%] grid content-start justify-items-center gap-6 py-20 text-center">
        <span className="after:from-background after:to-foreground relative max-w-[12ch] text-xs uppercase leading-tight opacity-40 after:absolute after:left-1/2 after:top-full after:h-16 after:w-px after:bg-gradient-to-b after:content-['']">
          Click to play the music
        </span>
      </div>
      <MusicToggleButton />
    </div>
  );
};

export { Skiper25 };

export const MusicToggleButton = () => {
  const bars = 5;

  const getRandomHeights = () => {
    return Array.from({ length: bars }, () => Math.random() * 0.8 + 0.2);
  };

  const [heights, setHeights] = useState(getRandomHeights());

  const [isPlaying, setIsPlaying] = useState(false);

  const [play, { pause, sound }] = useSound("/audio/audio.m4a", {
    loop: true,
    onplay: () => setIsPlaying(true),
    onend: () => setIsPlaying(false),
    onpause: () => setIsPlaying(false),
    onstop: () => setIsPlaying(false),
    soundEnabled: true,
  });

  useEffect(() => {
    if (isPlaying) {
      const waveformIntervalId = setInterval(() => {
        setHeights(getRandomHeights());
      }, 100);

      return () => {
        clearInterval(waveformIntervalId);
      };
    }
    setHeights(Array(bars).fill(0.1));
  }, [isPlaying]);

  const handleClick = () => {
    if (isPlaying) {
      pause();
      setIsPlaying(false);
      return;
    }
    play();
    setIsPlaying(true);
  };

  return (
    <>
      <motion.div
        onClick={handleClick}
        key="audio"
        initial={{ padding: "14px 14px " }}
        whileHover={{ padding: "18px 22px " }}
        whileTap={{ padding: "18px 22px " }}
        transition={{ duration: 1, bounce: 0.6, type: "spring" }}
        className="bg-background cursor-pointer rounded-full p-2"
      >
        <motion.div
          initial={{ opacity: 0, filter: "blur(4px)" }}
          animate={{
            opacity: 1,
            filter: "blur(0px)",
          }}
          exit={{ opacity: 0, filter: "blur(4px)" }}
          transition={{ type: "spring", bounce: 0.35 }}
          className="flex h-[18px] w-full items-center gap-1 rounded-full"
        >
          {/* Waveform visualization */}
          {heights.map((height, index) => (
            <motion.div
              key={index}
              className="bg-foreground w-[1px] rounded-full"
              initial={{ height: 1 }}
              animate={{
                height: Math.max(4, height * 14),
              }}
              transition={{
                type: "spring",
                stiffness: 300,
                damping: 10,
              }}
            />
          ))}
        </motion.div>
      </motion.div>
    </>
  );
};
```

## What Phase 36 actually needs from this (per 36-CONTEXT.md D-EQ decisions)

Islet's EQ-01 scope is view-layer ONLY — the `onClick`/`useSound`/play-pause-toggle parts of this component are explicitly OUT of scope (see Deferred Ideas in 36-CONTEXT.md). Only the **bar rendering + animation** technique is the target:

- `bars = 5` (unchanged from today's `EqualizerBars.barCount`)
- Each bar: `w-[1px]` wide, `rounded-full` (SwiftUI: a thin `Capsule()`)
- Container: `h-[18px]`, `gap-1` (4px) between bars
- Height per bar: `Math.random() * 0.8 + 0.2` then rendered as `Math.max(4, height * 14)` → effective range **4–14px**
- Color: `bg-foreground` → solid white in Islet (locked: no gradient/accent tint, see D-EQ-03)
- **Animation technique (the key visual difference from today):** every **100ms**, reroll ALL bars to new random heights simultaneously, and let each bar's height *spring*-animate to its new target (`type: "spring", stiffness: 300, damping: 10`) rather than Islet's current continuous per-bar sine wave with independent period/phase. This produces a snappier, more "jumpy"/percussive feel vs. today's smooth wave.
- Paused state: all bars snap to a low flat height (`0.1` → clamped to 4px minimum) — same "flat when paused" contract Islet already has (D-04 in Phase 4/18's `EqualizerBars`).

**Constraint that does NOT come from this reference:** Islet's existing idle-CPU guarantee (bars must run zero clock while `!isPlaying`) is a locked precedent (D-04, `EqualizerBars` `TimelineView(.animation(paused: !isPlaying))`). The web reference's `setInterval` reroll technique must be reimplemented in a SwiftUI-idiomatic, idle-CPU-safe way (e.g. a periodic reroll of `@State` target heights driving `.animation(.spring(...), value:)`, still gated off entirely when paused) — planner's call on exact mechanism.
