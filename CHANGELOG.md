#### 2.0.3 (2025-04-08)
- adjust TrainingPeaks Virtual key mapping (#12)
- attempt to reconnect device if connection is lost 

#### 2.0.2 (2025-04-07)
- fix bluetooth scan issues on older Android devices by asking for location permission

#### 2.0.1 (2025-04-06)
- long pressing a button will trigger the action again every 250ms

#### 2.0.0 (2025-04-06)
- You can now customize the actions (touches, mouse clicks or keyboard keys) for all buttons on all supported Zwift devices
- now shows the battery level of the connected devices
- add more troubleshooting information

### 1.1.10 (2025-04-03)
- Add more troubleshooting during connection

### 1.1.8 (2025-04-02)
- Android: make sure the touch reassignment page is fullscreen

### 1.1.7 (2025-04-01)
- Zwift Ride: fix connection issues by connecting only to the left controller
- Windows: connect sequentially to fix (finally?) fix connection issues
- Windows: change the way keyboard is simulated, should fix glitches

### 1.1.6 (2025-03-31)
- Zwift Ride: add buttonPowerDown to shift gears
- Zwift Play: Fix buttonShift assignment
- Android: fix action to go to next song
- App now checks if you run the latest available version

### 1.1.5 (2025-03-30)
- fix bluetooth connection #6, also add missing entitlement on macOS

### 1.1.3 (2025-03-30)
- Windows: fix custom keyboard profile recreation after restart, also warn when choosing MyWhoosh profile (may fix #7)
- Zwift Ride: button map adjustments to prevent double shifting
- potential fix for #6 

### 1.1.1 (2025-03-30)
- potential fix for Bluetooth device detection

### 1.1.0 (2025-03-30)
- Windows & macOS: allow setting custom keymap and store the setting
- Android: allow customizing the touch area, so it can work with any device without guesswork where the buttons are (#4)
- Zwift Ride: update Zwift Ride decoding based on Feedback from @JayyajGH (#3)

### 1.0.6 (2025-03-29)
- Another potential keyboard fix for Windows
- Zwift Play: actually also use the dedicated shift buttons 

### 1.0.5 (2025-03-29)
- Zwift Ride: remap the shifter buttons to the correct values

### 1.0.0+4 (2025-03-29)
- Zwift Ride: attempt to fix button parsing
- Android: fix missing permissions
- Windows: potential fix for key press issues

### 1.0.0+3 (2025-03-29)

- Windows: fix connection by using a different Bluetooth stack (issue #1)
- Android: fix non-working touch propagation (issue #2)
