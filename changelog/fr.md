### 7.5.0 (09-11-2026)
**Features**:
- BikeControl est désormais disponible sous Linux (.deb et AppImage).
- Beaucoup d'autres applis d'entraînement sont maintenant officiellement prises en charge via OpenBikeControl : Grimpa, icTrainer, Auuki, VoxVelo, VeloWorkout, Pedalparty, VeloPopuli, Vieta, DirtWatts, WattLog.pro, REZVIVO, OpenRadlr et zwoTrainer.
- Davantage d'actions sont prises en charge avec Zwift.
- Power Lock : une pression maintient la puissance que tu développes à cet instant, quel que soit le profil de la route. Arrête de pédaler et il relâche, pour ne pas redémarrer face à un mur de résistance.
- Shimano Di2 : choisis entre les canaux E-TUBE (recommandé : la Di2 ne change jamais de vitesse via les leviers, même si BikeControl se déconnecte) et le mode boutons. Les leviers filaires fonctionnent aussi désormais.
- Les home trainers antérieurs au FTMS, comme le Saris Hammer avec un ancien firmware et les anciens Wahoo KICKR, peuvent maintenant être pilotés.

**Fixes**:
- Windows : le pont Bluetooth vers le téléphone envoie de nouveau des données et ne plante plus. Si une appli d'entraînement reste bloquée sur une ancienne connexion Bluetooth, BikeControl te demande de réappairer.
- Android : les manettes qui décrochent après une longue session sont retrouvées.
- Les manettes que tu oublies restent oubliées après un redémarrage.
- TrainingPeaks Virtual : la manette ne tourne plus en boucle après la connexion, et deux iPhone n'entrent plus en conflit.
- Target Power ne paraît plus soudain très dur quand tu ralentis sur des home trainers à la mesure de cadence lente (p. ex. Decathlon D500).
- La vitesse virtuelle tient compte de ton plateau avant.
- La superposition Windows s'ouvre avec l'opacité et la position enregistrées.
- Les capteurs de puissance pédalier Shimano sont reconnus comme capteurs de puissance.

### 7.4.0 (29-10-2026)
**Features**:
- Chaîne sur le home trainer : indique le plateau et le pignon sur lesquels se trouve ta vraie chaîne, et chaque vitesse virtuelle se ressent comme son équivalent réel.
- ERG à ta façon : démarre à ta dernière cible ou à ta puissance actuelle, par pas de 1, 5, 10 ou 25 W.
- Ride Cave et Velotoss sont désormais officiellement pris en charge via OpenBikeControl.
- Les manettes vibrent quand tu changes de vitesse.
- Boutons du MUOV smart bike (bêta) et meilleur changement de vitesse virtuel sur les home trainers récents.

**Fixes**:
- Shimano Di2 : les boutons des cocottes et les satellites fonctionnent en mode boutons.
- Une manette que tu déconnectes « pour cette session » reste déconnectée.
- Les capteurs de puissance Magene PES-P sont reconnus.

### 7.3.0 (19-10-2026)
**Features**:
- Shimano Di2 : intégration bien meilleure. Les leviers fonctionnent tout de suite comme boutons BikeControl, sans attribuer d'abord des canaux D-Fly dans l'appli E-Tube. La Di2 passe de nouveau les vitesses normalement dès que BikeControl se déconnecte, et aucun réglage de la Di2 n'est modifié.
- Biketerra est désormais officiellement pris en charge : il se connecte à BikeControl en Bluetooth via OpenBikeControl, avec boutons et direction.
- Stages SB20 : les boutons de vitesse du vélo fonctionnent comme manette (bêta).

**Fixes**:
- Les manettes continuent de fonctionner quand l'appli d'entraînement est au premier plan (Android, macOS, Windows).
- Meilleur changement de vitesse virtuel sur les home trainers qui appliquent les vitesses sans les confirmer (famille KICKR, Tacx Neo).
- Les home trainers Van Rysel sont désormais détectés.
