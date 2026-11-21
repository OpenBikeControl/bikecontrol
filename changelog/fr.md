### 7.6.1 (20-11-2026)
**Features**:
- (Base) MyWhoosh en Bluetooth : associe BikeControl dans MyWhoosh comme appareil de direction, puis change de vitesse et choisis ta route aux intersections (appui long). Si la connexion réseau ne marche pas, BikeControl te propose le Bluetooth à la place.
- (Pro) Capteurs : une liste montre d'où viennent la puissance, la fréquence cardiaque, la cadence et la vitesse, home trainer compris, et te permet de remplacer chacune par ton propre capteur. « Envoyer à l'app d'entraînement » n'apparaît plus que sans home trainer connecté, puisque celui-ci les transmet déjà.
- (Pro) Protocole de contrôle : en Auto, la page du home trainer indique le protocole choisi (p. ex. « Auto : FTMS »).
- (Base) Configuration : l'app d'entraînement choisie passe au centre, en grand, avec la question « tourne sur » juste en dessous. « Changer d'app » réaffiche la liste complète.

### 7.6.0 (17-11-2026)
**Features**:
- (Base) Incyclist, Tour du Pain et Rampida sont désormais officiellement pris en charge via OpenBikeControl.
- (Base) Les manettes CYCPLUS T7 fonctionnent comme manettes BikeControl : les huit boutons, avec la direction sur les flèches arrière par défaut.
- (Pro) Les applis OpenBikeControl voient maintenant ta vitesse virtuelle en direct.
- (Base) Un éditeur de boutons plus clair : les actions sont regroupées selon ce qu'elles font (Vitesses, Home trainer, Séance, Rouler, …), et sur téléphone il s'ouvre en volet du bas.
- (Base) Shimano Di2 : une troisième option de configuration – règle toi-même les canaux D-Fly dans E-TUBE, avec un guide pas à pas.
- (Base) Zwift Click V2 : tu peux utiliser la manette droite sans la déverrouiller, si tu le souhaites.
- Plus de marge pour essayer : 120 appuis par jour pendant l'essai (avant 80), 40 par jour ensuite (avant 15) et, sans Pro, 30 minutes par jour de changement de vitesse virtuel BikeControl (avant 20).
- Un essai plus clair : BikeControl te prévient (aussi par notification) quand il te reste 10 appuis pour aujourd'hui, et la carte d'essai indique ce que tu auras après l'essai. Si ton app d'entraînement gère elle-même les vitesses, « Rouler » ne propose plus le changement de vitesse virtuel de BikeControl, et le contrôle au clavier est indiqué comme optionnel à côté d'une connexion OpenBikeControl.
- (Base) KICKR Headwind : le ventilateur peut suivre votre fréquence cardiaque (d'une ceinture connectée à BikeControl) ou votre puissance, et vous réglez où il démarre et où il atteint la pleine vitesse. La page affiche la valeur actuelle et la vitesse qui en découle.
- (Base) Elite Rizer : l'inclinaison fonctionne maintenant avec n'importe quel home trainer connecté.
- (Pro) Les Commandes du home trainer (mode Companion) s'ouvrent maintenant en mode pédalage : un grand − et un grand + avec ta vitesse, ta puissance, ta cadence et ton développement au milieu, et tous les autres boutons en dessous. Avec Modifier, tu déplaces et redimensionnes les tuiles et ajoutes des boutons, des valeurs et le contrôle de la musique ; le plein écran est aussi là. Ses − et + passent maintenant par le changement de vitesse virtuel de BikeControl, avec la vibration au changement.

**Fixes**:
- Zwift : la Bombe Ride On part aussi sur un appui court (Zwift a besoin que le bouton reste appuyé un instant).
- Les home trainers Elite n'apparaissent plus en double (WiFi et Bluetooth).
- Windows : BikeControl ne plante plus à la fermeture, ni sur des erreurs réseau, de notification ou Bluetooth.
- Android : plus de plantage quand Android redémarre le service en arrière-plan, et « Fermer et quitter » quitte toujours.
- Shimano Di2 : la configuration des canaux s'arrête proprement quand une manette n'accepte pas le réglage.
- Windows et macOS : « Faire une capture d'écran » te laisse maintenant choisir le dossier (en partant d'Images) au lieu d'enregistrer à côté de l'app, et signale quand une capture ne peut pas être enregistrée.

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
