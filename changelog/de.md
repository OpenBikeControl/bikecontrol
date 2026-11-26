### 7.7.0 (24-11-2026)
**Features**:
- (Pro) Die Wahoo App ist jetzt als Trainer-App wählbar: Läuft BikeControl auf einem Android-Gerät oder Windows-PC, erscheint es in der Wahoo App als Bluetooth-Smart-Trainer und übernimmt das virtuelle Schalten.
- (Pro) Android mit einer reinen Bluetooth-Trainer-App wie Grimpa: Der Fahren-Tab und die Einrichtung bieten jetzt das Gang-Overlay an. Die App läuft auf einem anderen Gerät, du kannst dein Handy also für alles andere nutzen und siehst deinen Gang trotzdem obendrauf.
- (Base) PedalCraft, suffer.online, Kardiacs, Sueur, TrainerKit, Pedal Mania, Warp, hupser und SaddleOut werden jetzt offiziell über OpenBikeControl unterstützt.

**Fixes**:
- (Base) Android: „Schließen“ in der Benachrichtigung von BikeControl entfernt jetzt auch das Gang-Overlay. Bisher blieb das Overlay auf dem Bildschirm, nachdem BikeControl beendet war.
- (Base) iPhone / iPad: BikeControl bleibt jetzt im Hintergrund wach, solange es auf deine Trainer-App wartet (bis zu 15 Minuten), und noch 5 Minuten, nachdem die App die Verbindung getrennt hat. Bisher konnte iOS BikeControl schlafen legen, bevor MyWhoosh und andere Apps es gefunden hatten – die App fand dann nichts oder konnte sich nicht verbinden.
- (Base) iPhone / iPad: Hat iOS BikeControl doch schlafen gelegt, ist es von selbst wieder im Netzwerk zu finden, sobald du zurückkehrst. Bisher musste die Netzwerkmethode neu gestartet werden.
- (Base) iPhone / iPad: BikeControl folgt einem Wechsel des WLANs oder Hotspots sofort, statt weiter die alte Adresse anzukündigen.
- (Base) iPhone, iPad und Mac: Die Startseite zeigt dir, wenn BikeControl im Netzwerk nicht zu finden ist – die Netzwerkprüfung ist nur einen Tipp entfernt.
- (Base) Mac: BikeControl wird nach dem Aufwachen des Mac wieder gefunden, ohne die Netzwerkmethode neu zu starten.
- (Base) Netzwerkprüfung: meldet keinen Fehler mehr, während BikeControl selbst das Netzwerk durchsucht oder wenn du nur die Trainer-Brücke nutzt und die Controller-Verbindung ausgeschaltet hast.
- (Base) Windows: Screenshots per Controller-Taste haben die richtigen Farben. Bisher waren Rot und Blau vertauscht.
- (Base) Windows: BikeControl friert nicht mehr ein, während sich ein Controller neu verbindet, z. B. der linke Zwift Click V2 in dem Modus, in dem er etwa einmal pro Minute neu startet. Bisher konnte das Fenster nach einer Weile nicht mehr reagieren und musste im Task-Manager beendet werden.
- (Base) Eigene Belegungen von Tasten, die so heißen wie eine Taste eines anderen Controllers (z. B. die Lenktasten des KICKR BIKE), bleiben nach einem Neustart erhalten. Bisher fielen sie jedes Mal auf die Standardbelegung zurück.
- (Pro) Virtueller Umwerfer: Das Öffnen der Einstellungen für virtuelles Schalten lässt dich jetzt auf dem großen Kettenblatt. Bisher bist du dabei aufs kleine Kettenblatt gefallen.

### 7.6.2 (23-11-2026)
**Features**:
- (Base) Paddel von Zwift Play / Zwift Ride: Nach innen und nach außen kippen sind jetzt zwei eigene Tasten, und du kannst jeder eine eigene Aktion zuweisen. Deine bisherige Paddel-Belegung gilt für beide.
- (Base) Elite Rizer und Sterzo: Die Totzone der Lenkung lässt sich jetzt auf der Geräteseite einstellen.
- (Base) Zubehör-Aktionen (z. B. Steigung hoch / runter am Rizer) legst du jetzt direkt auf der Zubehörseite auf eine Taste deines verbundenen Controllers: Tippe die Taste im Bild des Controllers an und wähle einfachen, doppelten oder langen Druck.
- (Base) Everycol wird jetzt offiziell über OpenBikeControl unterstützt.

**Fixes**:
- (Base) Windows: Screenshots per Controller-Taste nehmen jetzt den ganzen Bildschirm auf, auch wenn die Anzeigeskalierung über 100 % liegt. Bisher konnten rechts und unten Teile fehlen.
- (Base) Elite Rizer: Ist der Rizer gesperrt (rote LED) und lässt sich nicht neigen, zeigen seine Seite und der Fahren-Tab das jetzt an, statt zu behaupten, er folge der Steigung.
- (Base) Elite Rizer: Ein gesperrter Rizer wird jetzt schon beim Verbinden als gesperrt angezeigt, nicht erst, wenn eine Steigung ankommt.
- (Pro) MyWhoosh über Bluetooth, Grimpa und andere OpenBikeControl-Apps über Bluetooth: Die App findet jetzt sowohl den Controller von BikeControl als auch den weitergeleiteten Trainer. Bisher zeigte Android nur den Controller.
- (Base) Zwift Click V2 mit Rouvy: Das Entsperren durch Rouvy kommt jetzt über BikeControl beim Click V2 an.
- (Base) Zwift Click V2: Keine Meldung „Verbindung fehlgeschlagen“ mehr jede Minute, während sich der Controller selbst neu startet.
- (Base) Windows, Mac und Linux: Simulierte Tastendrücke werden 50 ms gehalten. Bisher verpassten Apps, die die Tastatur einmal pro Frame abfragen, viele einzelne Drücke.

### 7.6.1 (20-11-2026)
**Features**:
- (Base) MyWhoosh über Bluetooth: Kopple BikeControl in MyWhoosh als Lenkgerät, dann schaltest du Gänge und wählst an Kreuzungen deinen Weg (langer Druck). Klappt die Verbindung übers Netzwerk nicht, bietet BikeControl stattdessen Bluetooth an.
- (Pro) Sensoren: Eine Liste zeigt, woher Leistung, Herzfrequenz, Trittfrequenz und Geschwindigkeit kommen – dein Trainer eingeschlossen – und du kannst jeden Wert durch einen eigenen Sensor ersetzen. „An Trainer-App senden“ erscheint nur noch ohne verbundenen Trainer, denn mit Trainer laufen die Werte ohnehin über ihn.
- (Pro) Steuerungsprotokoll: Bei Automatisch zeigt die Trainerseite jetzt, welches Protokoll gewählt wurde (z. B. „Automatisch: FTMS“).

**Fixes**:
- (Base) Shimano Di2: Die Einrichtung der D-Fly-Kanäle erkennt jetzt, welcher Schalthebel links und welcher rechts ist, und keine Taste, die sie ändert, schaltet noch am Rad.
- (Pro) Gang-Overlay: Zeigt nach einem erneuten Verbinden des Trainers weiter die Gänge deines Trainers.
- (Base) Elite Square: Eigene Belegungen der Tasten Y, A, B und Z bleiben nach einem Neustart erhalten.
- (Base) Ein zweiter gespeicherter Trainer verbindet sich nicht mehr von selbst neben dem, den du fährst. Bisher konnte er sich unbemerkt verbinden und Werte und Befehle durcheinanderbringen.
- (Base) Trainer-Bridge: Mit zwei verbundenen Trainern springt die Leistung des gefahrenen nicht mehr kurz auf 0.

### 7.6.0 (17-11-2026)
**Features**:
- (Base) Incyclist, Tour du Pain und Rampida werden jetzt offiziell über OpenBikeControl unterstützt.
- (Base) CYCPLUS-T7-Schalthebel funktionieren als Controller: alle acht Tasten, standardmäßig Lenken mit den hinteren Pfeiltasten.
- (Pro) OpenBikeControl-Apps sehen jetzt live deinen virtuellen Gang.
- (Base) Ein übersichtlicherer Tasten-Editor: Aktionen sind danach gruppiert, was sie tun (Gänge, Trainer, Workout, Fahren, …), und auf dem Handy öffnet er sich als Bottom Sheet.
- (Base) Shimano Di2: eine dritte Einrichtungsoption – stell die D-Fly-Kanäle selbst in E-TUBE ein, mit einer Schritt-für-Schritt-Anleitung.
- (Base) Zwift Click V2: Du kannst den rechten Controller optional ohne Entsperren nutzen.
- Mehr Raum zum Ausprobieren: 120 Tastendrücke am Tag in der Testphase (vorher 80), danach 40 am Tag (vorher 15), und ohne Pro 30 Minuten am Tag virtuelles Schalten von BikeControl (vorher 20).
- Klarere Testphase: BikeControl warnt dich (auch als Mitteilung), wenn für heute noch 10 Tastendrücke übrig sind, und die Testphasen-Karte zeigt, was nach der Testphase gilt. Schaltet deine Trainer-App selbst, schlägt „Fahren“ kein virtuelles Schalten von BikeControl mehr vor, und die Tastatursteuerung ist neben einer OpenBikeControl-Verbindung als optional markiert.
- (Base) KICKR Headwind: Der Ventilator kann deiner Herzfrequenz (von einem mit BikeControl verbundenen Brustgurt) oder deiner Leistung folgen, und du legst fest, ab wann er anläuft und wann er volle Stufe erreicht. Die Seite zeigt den aktuellen Wert und die Stufe, die daraus wird.
- (Base) Elite Rizer: Die Steigung funktioniert jetzt mit jedem Smart Trainer.
- (Pro) Trainer-Steuerung (Companion Mode) startet jetzt im Fahrmodus: ein großes − und + mit Gang, Leistung, Trittfrequenz und Übersetzung dazwischen, alle anderen Tasten darunter. Über Bearbeiten verschiebst du Kacheln, änderst ihre Größe und fügst Tasten, Werte und Musiksteuerung hinzu; dazu gibt es Vollbild. − und + schalten dort jetzt BikeControls eigenes virtuelles Schalten, mit Vibration beim Schalten.

**Fixes**:
- Zwift: Die Ride-On-Bombe zündet jetzt auch bei kurzem Druck (Zwift braucht die Taste einen Moment lang gedrückt).
- Elite-Trainer tauchen nicht mehr doppelt auf (WLAN und Bluetooth).
- Windows: BikeControl stürzt nicht mehr beim Schließen ab, und auch nicht bei Netzwerk-, Benachrichtigungs- oder Bluetooth-Fehlern.
- Android: kein Absturz mehr, wenn Android den Hintergrunddienst neu startet, und „Schließen & beenden“ beendet die App immer.
- Shimano Di2: Die Kanaleinrichtung bricht sauber ab, wenn ein Schalthebel die Einstellung nicht übernimmt.
- Windows & macOS: Bei „Screenshot aufnehmen“ wählst du jetzt selbst den Ordner (Start in „Bilder“), statt dass neben der App gespeichert wird, und es wird gemeldet, wenn ein Screenshot nicht gespeichert werden kann.

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
