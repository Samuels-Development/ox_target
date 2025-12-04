# ox_target (Cursor-Based Fork)

> **This is a modified fork of [ox_target](https://github.com/overextended/ox_target) with cursor-based targeting instead of the traditional "eye" icon system.**

If you have any issues or suggestions, feel free to PR, create an issue or join my discord: https://discord.gg/FzPehMQaBQ

## Video Preview
https://github.com/user-attachments/assets/7f586163-bd78-4d11-b899-b8e32484c75d



## 🎯 What's Different

- **Cursor-based interaction** - Uses a mouse cursor instead of a centered eye icon
- **Click-to-lock system** - Options follow your cursor until you click to lock them in place
- **White entity outlines** - Only entities with valid targets get outlined (in white)
- **Smart auto-unlock** - Moving cursor to a different target automatically switches focus
- **Cinematic vignette** - Screen edges darken when targeting mode is active
- **Camera lock** - Camera stays fixed while targeting for precise cursor control

### How It Works
1. Hold targeting key (default: Left Alt) - cursor appears, vignette effect activates
2. Hover over targets - options appear (faded) and follow your cursor
3. Click to lock - options become solid and clickable (you can press right-click to unlock an option and then target something else)
4. Select an option or right-click to cancel

### Configuration
Add to your `server.cfg` to customize:

```cfg
# Disable entity outline (default: 1 = enabled)
setr ox_target:drawOutline 0

# Use target's interaction distance for outline (default: 1 = enabled)
# When enabled, outline only appears when close enough to interact
setr ox_target:outlineUseTargetDistance 0

# Distance at which entity outline appears (default: 5)
# Only used when outlineUseTargetDistance is disabled
setr ox_target:outlineDistance 10

# Outline color as R,G,B,A (default: 255,255,255,255 = white)
setr ox_target:outlineColor "0,150,255,255"

# Disable vignette/darkened corners effect (default: 1 = enabled)
setr ox_target:vignette 0

# Center cursor on screen when targeting starts (default: 1 = enabled)
setr ox_target:centerCursor 0
```

---

## Original ox_target

![](https://img.shields.io/github/downloads/overextended/ox_target/total?logo=github)
![](https://img.shields.io/github/downloads/overextended/ox_target/latest/total?logo=github)
![](https://img.shields.io/github/contributors/overextended/ox_target?logo=github)
![](https://img.shields.io/github/v/release/overextended/ox_target?logo=github)

A performant and flexible standalone "third-eye" targeting resource, with additional functionality for supported frameworks.

ox_target is the successor to qtarget, which was a mostly-compatible fork of bt-target.
To improve many design flaws, ox_target has been written from scratch and drops support for bt-target/qtarget standards, though partial compatibility is being implemented where possible.


## 📚 Documentation

https://overextended.dev/ox_target

## 💾 Download

https://github.com/overextended/ox_target/releases/latest/download/ox_target.zip

## ✨ Features

- Improved entity and world collision than its predecessor.
- Improved error handling when running external code.
- Menus for nested target options.
- Partial compatibility for qtarget (the thing qb-target is based on, I made the original idiots).
- Registering options no longer overrides existing options.
- Groups and items checking for supported frameworks.
