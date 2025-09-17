# Space Invaders (SI) Video RAM — Layout, Decoding, and Portrait Output

## TL;DR
- Resolution: **256 × 224** pixels, **1 bit per pixel** (monochrome).  
- VRAM window: **0x2400–0x3FFF** (7,168 bytes = 256×224 / 8).  
- **32 bytes per scanline** (because 256 / 8 = 32).  
- Each byte encodes **8 horizontal pixels**; bit value `1` = lit pixel.

---

## 1) Memory Map & Geometry

- **CPU address space** reserves:
  - `0000–1FFF` ROM (8 KB)
  - `2000–23FF` RAM (1 KB “work RAM”)
  - `2400–3FFF` **Video RAM** (7 KB)  
  This is the framebuffer read by the video hardware.

- **Framebuffer size**: 256×224 = 57,344 pixels → /8 = **7,168 bytes**.

---

## 2) Raw (Unrotated) Addressing

Think of VRAM as a **row-major, 1bpp bitmap**:

- **Rows**: 224  
- **Bytes per row**: 32  
- **Cols (pixels)**: 256

For a pixel at **(x, y)** where `x ∈ [0,255]`, `y ∈ [0,223]`:

```text
byte_addr = 0x2400 + y * 32 + (x >> 3)
bit_index = x & 7            ; 0 = leftmost bit in the byte
pixel = (VRAM[byte_addr] >> bit_index) & 1
```

So, **bit 0** of each byte corresponds to the **leftmost** of the 8 horizontal pixels that the byte covers; **bit 7** is the rightmost. That mapping, plus **32 bytes per scanline**, yields the full 256-wide row.

---

## 3) Portrait Output (Cabinet Rotation)

To recreate the cabinet view (portrait, rotated **counter-clockwise**):

- Portrait coordinates: **(Xp, Yp)** where `Xp ∈ [0,223]`, `Yp ∈ [0,255]`.

- Rotation mapping:
```text
Xp = 223 - y
Yp = x
```

Sampling from raw VRAM:
```text
x = Yp
y = 223 - Xp
byte_addr = 0x2400 + y * 32 + (x >> 3)
bit_index = x & 7
pixel = (VRAM[byte_addr] >> bit_index) & 1
```

This gives a **224×256** portrait image.

---

## 4) Scaling to 480×640 Portrait Mode

### Option A: Edge-to-edge fill
- 224→480 = 15/7 (≈2.14×) horizontally  
- 256→640 = 5/2 (2.5×) vertically  
- Requires fractional nearest-neighbor or accumulator scaler.

### Option B: 2× integer + padding (recommended)
- 224×256 → **448×512** (2× scaling)  
- Centered in 480×640 with padding:  
  - X pad: 16 px each side  
  - Y pad: 64 px top and bottom  
- Razor-sharp pixels, no shimmer.

Mapping (top-origin raster):
```text
Xin = (Xo - 16) >> 1
Yin = (Yo - 64) >> 1
pixel = Portrait[Yin, Xin]
```

Where `Xo ∈ [0..479]`, `Yo ∈ [0..639]`.

---

## 5) Output Timing (480×640 @ 25.2 MHz)

### Pixel clock
- **25.200 MHz** (close to VGA 25.175 MHz)

### Horizontal
- Active: 480  
- Front porch: 12  
- Sync: 72  
- Back porch: 36  
- Total: 600  

### Vertical
- Active: 640  
- Front porch: 13  
- Sync: 3  
- Back porch: 29  
- Total: 685  

### Refresh rate
```
f = 25.2e6 / (600 × 685) ≈ 61.4 Hz
```

### Polarity
- HSYNC: negative  
- VSYNC: negative  
- DE: high in active region

---

## 6) Color, Overlays, and “Tint”

Original cabinets were **B/W CRTs** with **color gels** for screen regions (e.g., green at bottom, red at top). To emulate this, apply color by Y-ranges or stencil masks after decoding. VRAM itself remains 1bpp.

---

## 7) Common Pitfalls

- **Bit order confusion** → image mirrored in 8-pixel chunks.  
- **Rotation mistakes** → sideways image.  
- **Stride mismatch** → each row is **32 bytes**.  
- **Expecting RGB** → VRAM is strictly **1bpp**.

---

## 8) Sanity Checks

- Pixel (0,0) → addr 0x2400, bit 0.  
- Pixel (255,0) → addr 0x2400+31, bit 7.  
- Pixel (255,223) → addr 0x3FFF, bit 7.  

---

## 9) Timing and Delay in Hardware

Pipeline latency estimate (BRAM + regs): **5–6 cycles** at pixclk.  
Always delay **DE/HS/VS** by the same number of cycles to align syncs with pixel data.

Example shift-register delay (Verilog-style):
```verilog
reg [5:0] de_d, hs_d, vs_d;
always @(posedge pixclk) begin
  de_d <= {de_d[4:0], de_in};
  hs_d <= {hs_d[4:0], hs_in};
  vs_d <= {vs_d[4:0], vs_in};
end
assign de_out = de_d[5];
assign hs_out = hs_d[5];
assign vs_out = vs_d[5];
```

This keeps syncs aligned to valid pixels.

---

## 10) Debug Checklist

- ✅ Row stride = 32 bytes  
- ✅ Rows = 224  
- ✅ Bit order correct  
- ✅ Rotation applied correctly  
- ✅ DE delayed to match pixel pipeline latency  

---
