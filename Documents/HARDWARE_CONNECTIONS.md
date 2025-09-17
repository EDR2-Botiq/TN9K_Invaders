# Tang Nano 9K Hardware Connection Guide
## SNES Controller & Audio Circuit Diagrams

---

## 🎮 SNES Controller Connection

### SNES Controller Pinout (Looking at Controller Port)
```
    ╭─────────────╮
    │ 1 2 3 4 │ 5 6 7 │
    ╰───────────────╯
    Flat side on bottom

Pin 1: +5V (Power)
Pin 2: Clock
Pin 3: Latch
Pin 4: Data
Pin 5: Not Connected
Pin 6: Not Connected
Pin 7: Ground
```

### Connection Diagram to Tang Nano 9K

```
SNES Controller                     Tang Nano 9K
    Port                               FPGA

    Pin 1 (VCC) ─────────────────── 3.3V or 5V
                                     (Pin 1 or 2)

    Pin 2 (Clock) ──────┐
                        │
                    [1kΩ]           Pin 76
                        ├────────── (SNES_CLK)
                    [10kΩ]
                        │
                       GND

    Pin 3 (Latch) ──────┐
                        │
                    [1kΩ]           Pin 75
                        ├────────── (SNES_LATCH)
                    [10kΩ]
                        │
                       GND

    Pin 4 (Data) ───────┐
                        │
                    [1kΩ]           Pin 77
                        ├────────── (SNES_DATA)
                    [10kΩ]
                        │
                       3.3V

    Pin 7 (GND) ────────────────── GND
                                    (Pin 24/48/88)
```

### Level Shifting Circuit (If Using 5V Controller)
```
SNES 5V Signal              Tang Nano 9K 3.3V

Data Out ──┬──[1kΩ]──┬────── FPGA Pin 77
           │         │
         [2.2kΩ]   [10kΩ]
           │         │
          GND       3.3V

Clock ─────[1kΩ]──┬────────── FPGA Pin 76
                  │
                [10kΩ]
                  │
                 GND

Latch ─────[1kΩ]──┬────────── FPGA Pin 75
                  │
                [10kΩ]
                  │
                 GND
```

### Components Needed
- 3x 1kΩ resistors (series protection)
- 3x 10kΩ resistors (pull-down for clock/latch, pull-up for data)
- 1x 2.2kΩ resistor (voltage divider if 5V controller)
- SNES controller extension cable (to cut and wire)

---

## 🔊 Audio Output Circuit (2nd Order Sigma-Delta DAC)

### Important: Space Invaders Audio is MONO
**Space Invaders originally had mono sound only. Both pins 33 and 34 output the SAME audio signal.**
This provides compatibility with stereo equipment without needing a mono-to-stereo adapter.

### Option 1: Single Speaker/Mono Output (Recommended)
```
Tang Nano 9K              Audio Output (MONO)

Pin 33 or 34 ──[1kΩ]──┬──[4.7nF]──┬── Audio Out
(Use either one)       │           │
                     [10kΩ]       ===
                       │          GND
                      GND

                    Mono 3.5mm Jack
                  ╭─────────────╮
    Audio Out ────│ Tip         │
    GND ──────────│ Sleeve      │
                  ╰─────────────╯
```

### Option 2: Stereo Jack (Both Channels Get Same Signal)
```
Tang Nano 9K                    Stereo Jack (Dual Mono)
(Sigma-Delta)

Pin 33 ──[1kΩ]──┬──[4.7nF]──┬── Left Channel
                 │           │   (Same signal)
               [10kΩ]       ===
                 │          GND
                GND

Pin 34 ──[1kΩ]──┬──[4.7nF]──┬── Right Channel
                 │           │   (Same signal)
               [10kΩ]       ===
                 │          GND
                GND

                        3.5mm Stereo Jack
                     ╭─────────────╮
    Left ────────────│ Tip (L)     │ } Both get
    Right ───────────│ Ring (R)    │ } same audio
    GND ─────────────│ Sleeve      │
                     ╰─────────────╯

Note: Both pins output identical audio for stereo compatibility
```

### Why Two Pins?
- **Convenience**: No mono-to-stereo adapter needed
- **Compatibility**: Works with any stereo amplifier/headphones
- **Original Design**: Space Invaders was mono (1978 arcade)
- **FPGA Implementation**: Same signal routed to both pins

### Amplified Audio Circuit (Using LM386)

```
                    ┌──────────────┐
Tang Nano 9K        │    LM386     │        Speaker
                    │              │
Pin 33/34 ──[1kΩ]──┤2 (-IN)    5  ├──[10µF]──┬──[100Ω]──┐
(Audio PWM)         │              │          │          │
                    │3 (+IN)    1,8├─────────═╪═────────╪ 8Ω
           ┌────────┤              │          │       Speaker
          GND       │4 (GND)    7  ├─[0.05µF]─┘
                    │              │
           +5V─────┤6 (VCC)       │
                    └──────────────┘

Components:
- IC1: LM386 audio amplifier
- C1: 10µF electrolytic capacitor
- C2: 0.05µF ceramic capacitor
- C3: 100µF electrolytic (power supply bypass)
- R1: 1kΩ input resistor
- R2: 100Ω speaker impedance matching
- Speaker: 8Ω, 0.5W minimum
```

### Advanced Filtered Audio Output (Optional for Sigma-Delta)

```
                   Optional 2nd Order Filter for Sigma-Delta
                       (Usually not needed with Σ-Δ DAC)
                            fc = 20kHz

Tang Nano 9K         R1=2.2kΩ    R2=2.2kΩ         Op-Amp Output
                    ┌──[====]──┬──[====]──┐      ┌─────────┐
Pin 33/34 ─[1kΩ]───┤          │          ├──┬───│+        │
(Σ-Δ Audio)         │       C1=3.3nF      │  │   │  TL072  ├── Audio Out
                    │          │          │  └───│-        │   (Line Level)
                    │         ===         │      └─────────┘
                    │          │       C2=1.5nF       │
                    │         GND         │          ─┴─
                    │                    ===         GND
                    │                     │
                    └────────────────────GND

Note: Sigma-Delta DAC typically needs only simple RC filtering
- 2nd order filter optional for audiophile quality
- Much better noise performance than PWM
```

---

## 📊 Connection Summary Table

| Function | Tang Nano 9K Pin | Direction | Voltage | External Connection |
|----------|-----------------|-----------|---------|-------------------|
| **SNES Controller** |
| SNES_LATCH | 75 | Output | 3.3V | SNES Pin 3 via 1kΩ |
| SNES_CLOCK | 76 | Output | 3.3V | SNES Pin 2 via 1kΩ |
| SNES_DATA | 77 | Input | 3.3V | SNES Pin 4 via 1kΩ |
| **Audio (Mono)** |
| L_AUDIO | 33 | Output | 3.3V Σ-Δ | Same mono signal |
| R_AUDIO | 34 | Output | 3.3V Σ-Δ | Same mono signal |
| **User Controls** |
| S1_RESET | 4 | Input | 1.8V | Internal Pull-up |
| S2_COIN | 3 | Input | 1.8V | Internal Pull-up |
| **Power** |
| VCC_3V3 | 1, 2 | Power | 3.3V | SNES VCC |
| GND | 24,48,88 | Ground | 0V | Common Ground |

---

## ⚠️ Important Notes

### SNES Controller
1. **Voltage Levels**: SNES controllers work with both 3.3V and 5V
2. **Pull-up on Data**: Data line requires pull-up (controller pulls low)
3. **Pull-down on Control**: Clock and Latch need pull-downs
4. **Timing**:
   - Latch pulse: 12µs high
   - Clock period: ~12µs (6µs high, 6µs low)
   - Read 16 bits (12 buttons + 4 always high)

### Audio Output (Sigma-Delta DAC)
1. **Oversampling**: 20MHz clock provides ~80x oversampling at 250kHz
2. **Filter Requirements**: Simple RC filter (R=1kΩ, C=4.7nF) is sufficient
3. **SNR Performance**: 2nd order Σ-Δ provides >90dB theoretical SNR
4. **Noise Shaping**: Pushes quantization noise above audio band
5. **Output Level**: 0-3.3V swing, DC coupled (needs AC coupling capacitor)
6. **Ground Loops**: Use single-point grounding to avoid noise
7. **Decoupling**: Add 100µF capacitor near amplifier power pins

### Protection
1. **Series Resistors**: Always use 1kΩ series resistors on I/O
2. **ESD Protection**: Add TVS diodes if frequently connecting/disconnecting
3. **Power Sequencing**: Power FPGA before connecting controllers

---

## 🔧 Testing Procedure

### SNES Controller Test
1. Connect controller with protection resistors
2. Load bitstream with SNES controller support
3. Monitor button presses via LED indicators
4. Verify all 12 buttons register correctly

### Audio Test
1. Build RC filter circuit (minimum)
2. Connect to amplified speaker or oscilloscope
3. Generate test tone (1kHz square wave)
4. Adjust filter values if needed
5. Test game audio effects

---

## 📝 PCB Design Recommendations

### Connector Board Layout
```
┌─────────────────────────────────┐
│  Tang Nano 9K Expansion Board    │
│                                  │
│  [SNES Port]     [3.5mm Audio]  │
│      :::             ○           │
│                                  │
│  Protection      Filter/Amp     │
│  Resistors       Components     │
│  ▪ ▪ ▪           ▪ ▪ ▪ ▪        │
│                                  │
│  [Pin Headers to Tang Nano 9K]  │
│  :::::::::::::::::::::::::::    │
└─────────────────────────────────┘
```

### Recommended PCB Features
- 2-layer PCB minimum
- Ground plane for noise reduction
- 0805 SMD components for compactness
- Pin headers for Tang Nano 9K connection
- Right-angle SNES connector
- 3.5mm stereo jack for audio
- Optional: LM386 amplifier section
- Optional: Volume potentiometer

---

## 📚 References

- SNES Controller Protocol: https://gamefaqs.gamespot.com/snes/916396-super-nintendo/faqs/5395
- LM386 Datasheet: https://www.ti.com/lit/ds/symlink/lm386.pdf
- RC Filter Calculator: https://www.omnicalculator.com/physics/low-pass-filter
- Tang Nano 9K Schematic: See Tang_Nano_9k_3672_Schematic.pdf

---

*Created for TN9K Space Invaders Project by EDR² (Eat, Drink, Repair and Repeat)*