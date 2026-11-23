### 7.6.2 (23-11-2026)
**Features**:
- (Base) Levette di Zwift Play / Zwift Ride: inclinare verso l'interno e verso l'esterno sono ora due pulsanti separati, ognuno con la sua azione. La tua assegnazione attuale della levetta vale per entrambi.
- (Pro) L'app Wahoo ora è selezionabile come app di allenamento: BikeControl vi compare come rullo smart Bluetooth su un secondo dispositivo e gestisce il cambio virtuale.

**Fixes**:
- (Base) Windows: gli screenshot fatti con un pulsante del controller ora catturano tutto lo schermo anche con un ridimensionamento dello schermo oltre il 100 %. Prima venivano tagliati a destra e in basso.

### 7.6.1 (20-11-2026)
**Features**:
- (Base) MyWhoosh via Bluetooth: abbina BikeControl in MyWhoosh come dispositivo di sterzo, poi cambi marcia e scegli la strada agli incroci (pressione lunga). Se la connessione di rete non funziona, BikeControl propone il Bluetooth al suo posto.
- (Pro) Sensori: un elenco mostra da dove arrivano potenza, frequenza cardiaca, cadenza e velocità, rullo compreso, e ti permette di sostituirle con un tuo sensore. «Invia all'app di allenamento» appare solo senza rullo collegato, perché il rullo le trasmette già.
- (Pro) Protocollo di controllo: in Auto, la pagina del rullo mostra quale protocollo è stato scelto (ad es. «Auto: FTMS»).

**Fixes**:
- (Base) Shimano Di2: la configurazione dei canali D-Fly ora riconosce quale comando è il sinistro e quale il destro, e nessun pulsante che modifica cambia ancora marcia sulla bici.

### 7.6.0 (17-11-2026)
**Features**:
- (Base) Incyclist, Tour du Pain e Rampida sono ora supportati ufficialmente tramite OpenBikeControl.
- (Base) I comandi CYCPLUS T7 funzionano come controller: tutti e otto i pulsanti, con lo sterzo sulle frecce posteriori di default.
- (Pro) Le app OpenBikeControl ora vedono il tuo rapporto virtuale in tempo reale.
- (Base) Un editor dei pulsanti più chiaro: le azioni sono raggruppate in base a ciò che fanno (Rapporti, Rullo, Allenamento, Pedalata, …), e sul telefono si apre come pannello dal basso.
- (Base) Shimano Di2: una terza opzione di configurazione – imposta tu i canali D-Fly in E-TUBE, con una guida passo passo.
- (Base) Zwift Click V2: puoi usare, se vuoi, il controller destro senza sbloccarlo.
- Più margine per provare: 120 pressioni al giorno durante la prova (prima 80), poi 40 al giorno (prima 15) e, senza Pro, 30 minuti al giorno del cambio virtuale di BikeControl (prima 20).
- Una prova più chiara: BikeControl ti avvisa (anche con una notifica) quando ti restano 10 pressioni per oggi, e la scheda della prova mostra cosa avrai dopo. Se la tua app di allenamento cambia marcia da sola, «Pedala» non propone più il cambio virtuale di BikeControl, e il controllo da tastiera è indicato come facoltativo accanto a una connessione OpenBikeControl.
- (Base) KICKR Headwind: il ventilatore può seguire la tua frequenza cardiaca (da una fascia collegata a BikeControl) o la tua potenza, e scegli tu dove parte e dove arriva alla velocità massima. La pagina mostra il valore attuale e la velocità che ne deriva.
- (Base) Elite Rizer: l'inclinazione ora funziona con qualsiasi rullo smart.
- (Pro) I Controlli del rullo (Companion Mode) ora si aprono in modalità pedalata: un − e un + grandi con rapporto, potenza, cadenza e sviluppo al centro, e tutti gli altri pulsanti sotto. Con Modifica sposti e ridimensioni i riquadri e aggiungi pulsanti, valori e controllo della musica; c'è anche lo schermo intero. I suoi − e + ora usano la cambiata virtuale di BikeControl, con la vibrazione alla cambiata.

**Fixes**:
- Zwift: la Bomba Ride On parte anche con una pressione breve (Zwift vuole il pulsante tenuto premuto per un attimo).
- I rulli Elite non compaiono più due volte (WiFi e Bluetooth).
- Windows: BikeControl non va più in crash alla chiusura né per errori di rete, notifiche o Bluetooth.
- Android: nessun crash quando Android riavvia il servizio in background, e «Chiudi ed esci» esce sempre.
- Shimano Di2: la configurazione dei canali si interrompe correttamente quando un comando non accetta l'impostazione.
- Windows e macOS: «Acquisisci screenshot» ora ti permette di scegliere la cartella (partendo da Immagini) invece di salvare accanto all'app, e segnala quando uno screenshot non può essere salvato.

### 7.5.0 (09-11-2026)
**Features**:
- BikeControl è ora disponibile su Linux (.deb e AppImage).
- Molte altre app di allenamento sono ora supportate ufficialmente tramite OpenBikeControl: Grimpa, icTrainer, Auuki, VoxVelo, VeloWorkout, Pedalparty, VeloPopuli, Vieta, DirtWatts, WattLog.pro, REZVIVO, OpenRadlr e zwoTrainer.
- Più azioni supportate con Zwift.
- Power Lock: una pressione mantiene la potenza che stai spingendo in quel momento, qualunque cosa faccia la strada. Smetti di pedalare e si sblocca, così non riparti contro un muro di resistenza.
- Shimano Di2: scegli tra i canali E-TUBE (consigliato: la Di2 non cambia mai dalle leve, anche se BikeControl si disconnette) e la modalità pulsanti. Ora funzionano anche le leve cablate.
- Ora si possono controllare i rulli precedenti a FTMS, come il Saris Hammer con firmware datato e i vecchi modelli Wahoo KICKR.

**Fixes**:
- Windows: il ponte Bluetooth verso il telefono invia di nuovo i dati e non va più in crash. Se un'app di allenamento resta bloccata su una vecchia connessione Bluetooth, BikeControl ti dice di riassociare.
- Android: i controller che si scollegano dopo una lunga sessione vengono ritrovati.
- I gamepad che rimuovi restano rimossi dopo un riavvio.
- TrainingPeaks Virtual: il controller non resta più in caricamento dopo la connessione, e due iPhone non vanno più in conflitto.
- Target Power non risulta più improvvisamente pesantissimo quando rallenti su rulli con una lettura della cadenza lenta (es. Decathlon D500).
- La velocità virtuale tiene conto della tua corona anteriore.
- L'overlay di Windows si apre con l'opacità e la posizione salvate.
- I misuratori di potenza su pedivella Shimano vengono riconosciuti come misuratori di potenza.

### 7.4.0 (29-10-2026)
**Features**:
- Catena sul rullo: imposta la corona e il pignone su cui si trova la tua catena reale, e ogni rapporto virtuale si sente come il suo equivalente reale.
- ERG a modo tuo: parti dal tuo ultimo obiettivo o dalla potenza attuale, con passi di 1, 5, 10 o 25 W.
- Ride Cave e Velotoss sono ora supportati ufficialmente tramite OpenBikeControl.
- I gamepad vibrano quando cambi.
- Pulsanti della MUOV smart bike (beta) e cambio virtuale migliore sui rulli moderni.

**Fixes**:
- Shimano Di2: i pulsanti sulle leve e i satelliti funzionano in modalità pulsanti.
- Un controller che scolleghi «per questa sessione» resta scollegato.
- I misuratori di potenza Magene PES-P vengono riconosciuti.

### 7.3.0 (19-10-2026)
**Features**:
- Shimano Di2: integrazione molto migliore. Le leve funzionano subito come pulsanti BikeControl, senza assegnare prima i canali D-Fly nell'app E-Tube. La Di2 torna a cambiare normalmente appena BikeControl si disconnette, e nessuna impostazione della Di2 viene modificata.
- Biketerra è ora supportato ufficialmente: si collega a BikeControl via Bluetooth tramite OpenBikeControl, con pulsanti e sterzo.
- Stages SB20: i pulsanti del cambio della bici funzionano come controller (beta).

**Fixes**:
- I gamepad continuano a funzionare mentre l'app di allenamento è in primo piano (Android, macOS, Windows).
- Cambio virtuale migliore sui rulli che applicano i rapporti senza confermarli (famiglia KICKR, Tacx Neo).
- I rulli Van Rysel vengono ora rilevati.
