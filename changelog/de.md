### 7.6.0 (17-11-2026)
**Features**:
- Incyclist, Tour du Pain und Rampida werden jetzt offiziell über OpenBikeControl unterstützt.
- CYCPLUS-T7-Schalthebel funktionieren als Controller: alle acht Tasten, standardmäßig Lenken mit den hinteren Pfeiltasten.
- OpenBikeControl-Apps sehen jetzt live deinen virtuellen Gang.
- Ein übersichtlicherer Tasten-Editor: Aktionen sind danach gruppiert, was sie tun (Gänge, Trainer, Workout, Fahren, …), und auf dem Handy öffnet er sich als Bottom Sheet.
- Shimano Di2: eine dritte Einrichtungsoption – stell die D-Fly-Kanäle selbst in E-TUBE ein, mit einer Schritt-für-Schritt-Anleitung.
- Zwift Click V2: Du kannst den rechten Controller optional ohne Entsperren nutzen.
- Mehr Raum zum Ausprobieren: 120 Tastendrücke am Tag in der Testphase (vorher 80), danach 40 am Tag (vorher 15), und ohne Pro 30 Minuten am Tag virtuelles Schalten von BikeControl (vorher 20).

**Fixes**:
- Elite-Trainer tauchen nicht mehr doppelt auf (WLAN und Bluetooth).
- Windows: BikeControl stürzt nicht mehr beim Schließen ab, und auch nicht bei Netzwerk-, Benachrichtigungs- oder Bluetooth-Fehlern.
- Android: kein Absturz mehr, wenn Android den Hintergrunddienst neu startet, und „Schließen & beenden“ beendet die App immer.
- Shimano Di2: Die Kanaleinrichtung bricht sauber ab, wenn ein Schalthebel die Einstellung nicht übernimmt.

### 7.5.0 (09-11-2026)
**Features**:
- BikeControl gibt es jetzt auch für Linux (.deb und AppImage).
- Viele weitere Trainings-Apps werden jetzt offiziell über OpenBikeControl unterstützt: Grimpa, icTrainer, Auuki, VoxVelo, VeloWorkout, Pedalparty, VeloPopuli, Vieta, DirtWatts, WattLog.pro, REZVIVO, OpenRadlr und zwoTrainer.
- Mit Zwift werden mehr Aktionen unterstützt.
- Power Lock: Ein Druck hält genau die Leistung, die du gerade trittst, egal was die Strecke macht. Hörst du auf zu treten, gibt er nach, damit du nicht gegen eine Wand aus Widerstand neu anfahren musst.
- Shimano Di2: Wähle zwischen E-TUBE-Kanälen (empfohlen: Die Di2 schaltet nie über die Hebel, auch wenn BikeControl die Verbindung verliert) und dem Tastenmodus. Kabelgebundene Hebel funktionieren jetzt auch.
- Ältere Trainer aus der Zeit vor FTMS, etwa der Saris Hammer mit älterer Firmware und ältere Wahoo-KICKR-Modelle, lassen sich jetzt steuern.

**Fixes**:
- Windows: Die Bluetooth-Brücke zum Handy sendet wieder Daten und stürzt nicht mehr ab. Hängt eine Trainings-App an einer alten Bluetooth-Verbindung, sagt dir BikeControl, dass du neu koppeln sollst.
- Android: Controller, die nach einer langen Session wegfallen, werden wieder gefunden.
- Gamepads, die du vergisst, bleiben nach einem Neustart vergessen.
- TrainingPeaks Virtual: Der Controller dreht sich nach dem Verbinden nicht mehr endlos, und zwei iPhones kommen sich nicht mehr in die Quere.
- Target Power fühlt sich nicht mehr plötzlich sehr schwer an, wenn du auf Trainern mit träger Trittfrequenzmessung (z. B. Decathlon D500) langsamer wirst.
- Die virtuelle Geschwindigkeit berücksichtigt dein vorderes Kettenblatt.
- Das Windows-Overlay öffnet sich mit der gespeicherten Deckkraft und Position.
- Shimano-Kurbel-Powermeter werden als Powermeter erkannt.

### 7.4.0 (29-10-2026)
**Features**:
- Kette am Trainer: Stell Kettenblatt und Ritzel ein, auf denen deine echte Kette liegt, und jeder virtuelle Gang fühlt sich an wie sein echtes Gegenstück.
- ERG nach deinem Geschmack: Starte bei deinem letzten Ziel oder deiner aktuellen Leistung, in Schritten von 1, 5, 10 oder 25 W.
- Ride Cave und Velotoss werden jetzt offiziell über OpenBikeControl unterstützt.
- Gamepads vibrieren beim Schalten.
- Tasten am MUOV Smart Bike (Beta) und besseres virtuelles Schalten auf modernen Trainern.

**Fixes**:
- Shimano Di2: Griff- und Satellitentasten funktionieren im Tastenmodus.
- Ein Controller, den du „für diese Session“ trennst, bleibt getrennt.
- Magene-PES-P-Powermeter werden erkannt.

### 7.3.0 (19-10-2026)
**Features**:
- Shimano Di2: viel bessere Integration. Die Schalthebel funktionieren sofort als BikeControl-Tasten, ohne vorher D-Fly-Kanäle in der E-Tube-App zuzuweisen. Die Di2 schaltet wieder normal, sobald BikeControl die Verbindung trennt, und keine Di2-Einstellung wird verändert.
- Biketerra wird jetzt offiziell unterstützt: Es verbindet sich per Bluetooth über OpenBikeControl mit BikeControl, mit Tasten und Lenkung.
- Stages SB20: Die Schalttasten des Bikes funktionieren als Controller (Beta).

**Fixes**:
- Gamepads funktionieren weiter, während die Trainings-App im Vordergrund ist (Android, macOS, Windows).
- Besseres virtuelles Schalten auf Trainern, die Gänge übernehmen, ohne sie zu bestätigen (KICKR-Familie, Tacx Neo).
- Van-Rysel-Trainer werden jetzt erkannt.
