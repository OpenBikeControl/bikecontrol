### 7.7.0 (24-11-2026)
**Features**:
- (Pro) L'app Wahoo peut maintenant être choisie comme app d'entraînement : avec BikeControl sur un appareil Android ou un PC Windows, il apparaît dans l'app Wahoo comme home trainer Bluetooth et assure les vitesses virtuelles.
- (Pro) Android avec une app d'entraînement uniquement Bluetooth comme Grimpa : l'onglet Rouler et la configuration proposent désormais la superposition du braquet. L'app tourne sur un autre appareil, tu peux donc utiliser ton téléphone pour autre chose tout en voyant ton braquet par-dessus.
- (Base) PedalCraft, suffer.online, Kardiacs, Sueur, TrainerKit, Pedal Mania, Warp, hupser et SaddleOut sont maintenant officiellement pris en charge via OpenBikeControl.

**Fixes**:
- (Base) Grimpa, Biketerra et Ride Cave : la configuration active maintenant la méthode de connexion Bluetooth et, sur Android, demande dès l'étape de la manette l'autorisation Bluetooth nécessaire. Avant, elle activait une méthode réseau que ces apps ne peuvent pas utiliser.
- (Base) Android : « Fermer » dans la notification de BikeControl retire maintenant aussi la superposition du braquet. Avant, elle restait à l'écran après la fermeture de BikeControl.
- (Base) Android avec FulGaz ou Biketerra : en connectant le home trainer, BikeControl demande maintenant l'autorisation Bluetooth dont il a besoin pour apparaître comme home trainer. Avant, le pont tournait sans fin et l'app ne l'affichait jamais. La page du home trainer affiche aussi le nom sous lequel l'app le liste (Android le raccourcit, p. ex. « KICKR CORE 1234 - Bik »).
- (Base) iPhone / iPad : BikeControl reste désormais actif en arrière-plan tant qu'il attend ton app d'entraînement (jusqu'à 15 minutes), et pendant 5 minutes après la déconnexion de l'app. Auparavant, iOS pouvait suspendre BikeControl avant que MyWhoosh et d'autres apps ne l'aient trouvé : l'app ne trouvait rien ou ne pouvait pas se connecter.
- (Base) iPhone / iPad : si iOS suspend malgré tout BikeControl, il redevient visible sur le réseau de lui-même dès que tu y reviens. Auparavant, il fallait redémarrer la méthode réseau.
- (Base) iPhone / iPad : BikeControl suit immédiatement un changement de Wi-Fi ou de partage de connexion au lieu d'annoncer l'ancienne adresse.
- (Base) iPhone / iPad : la recherche de home trainers Wi-Fi ne remplit plus le journal d'entrées « App crashed ».
- (Base) iPhone, iPad et Mac : l'écran d'accueil t'indique quand BikeControl est introuvable sur le réseau, avec la vérification du réseau à portée de main.
- (Base) Mac : BikeControl est de nouveau trouvé après la sortie de veille du Mac, sans redémarrer la méthode réseau.
- (Base) MyWhoosh sur un autre appareil : s'il ne s'est pas connecté par le réseau au bout d'une minute et demie, l'écran d'accueil propose désormais le Bluetooth à la place. Auparavant, cette proposition n'apparaissait que sur la page de vérification du réseau.
- (Base) MyWhoosh sur le même appareil Android : l'écran d'accueil indique désormais que le changement de vitesse virtuel n'y atteint pas MyWhoosh et quelles configurations fonctionnent, au lieu d'attendre que MyWhoosh trouve un home trainer qu'il n'affichera jamais.
- (Base) MyWhoosh sur un autre appareil Android : l'étape du home trainer sur l'écran d'accueil te dit désormais de passer le home trainer en Bluetooth, car MyWhoosh pour Android ne trouve les home trainers qu'en Bluetooth.
- (Base) Téléphone Android sans Wi-Fi et app d'entraînement sur le même téléphone : le conseil est désormais de rejoindre n'importe quel Wi-Fi ou d'utiliser Local, au lieu de « le même Wi-Fi que l'app ».
- (Base) Être hors ligne en étant connecté à ton compte ne remplit plus le journal d'entrées « App crashed ».
- (Base) Vérification du réseau : ne signale plus d'échec pendant que BikeControl parcourt lui-même le réseau, ni quand tu utilises seulement le pont du home trainer avec la connexion de la manette désactivée.
- (Base) Windows : sur un PC sans adaptateur Bluetooth, l'autorisation Bluetooth l'indique maintenant et ouvre les paramètres Bluetooth au lieu de ne rien faire, et les home trainers Wi-Fi et les manettes sont trouvés sans lui. Si Windows refuse d'activer le Bluetooth, BikeControl te le dit et ouvre les paramètres.
- (Base) Windows : les captures d'écran prises avec un bouton de la manette ont les bonnes couleurs. Avant, le rouge et le bleu étaient inversés.
- (Base) Les assignations personnalisées des boutons qui portent le même nom qu'un bouton d'une autre manette (p. ex. les boutons de direction du KICKR BIKE) sont conservées après un redémarrage. Avant, elles revenaient chaque fois à l'assignation par défaut.

### 7.6.2 (23-11-2026)
**Features**:
- (Base) Palettes Zwift Play / Zwift Ride : incliner vers l'intérieur et vers l'extérieur sont maintenant deux boutons distincts, chacun avec sa propre action. Ton assignation actuelle de la palette s'applique aux deux.
- (Base) Elite Rizer et Sterzo : la zone morte de la direction se règle maintenant sur la page de l'appareil.
- (Base) Les actions d'accessoire (p. ex. monter / descendre l'inclinaison du Rizer) s'assignent maintenant directement à un bouton de ta manette connectée depuis la page de l'accessoire : touche le bouton sur l'image de la manette, puis choisis appui simple, double ou long.
- (Base) Everycol est maintenant officiellement pris en charge via OpenBikeControl.

**Fixes**:
- (Base) Windows : les captures d'écran prises avec un bouton de la manette couvrent maintenant tout l'écran, même avec une mise à l'échelle supérieure à 100 %. Avant, la droite et le bas pouvaient être coupés.
- (Base) Elite Rizer : quand le Rizer est verrouillé (LED rouge) et refuse de s'incliner, sa page et l'onglet Rouler l'indiquent maintenant, au lieu d'affirmer qu'il suit la pente.
- (Base) Elite Rizer : un Rizer verrouillé s'affiche maintenant comme verrouillé dès sa connexion, pas seulement quand une pente arrive.
- (Pro) MyWhoosh en Bluetooth, Grimpa et les autres apps OpenBikeControl en Bluetooth : l'app trouve maintenant à la fois la manette BikeControl et le home trainer relayé. Avant, Android ne montrait que la manette.
- (Base) Zwift Click V2 avec Rouvy : le déverrouillage de Rouvy atteint maintenant le Click V2 via BikeControl.
- (Base) Zwift Click V2 : plus de message « Connexion impossible » chaque minute pendant que la manette redémarre d'elle-même.
- (Base) Windows, Mac et Linux : les appuis de touches simulés sont maintenus 50 ms. Avant, les apps qui lisent le clavier une fois par image manquaient beaucoup d'appuis isolés.

### 7.6.1 (20-11-2026)
**Features**:
- (Base) MyWhoosh en Bluetooth : associe BikeControl dans MyWhoosh comme appareil de direction, puis change de vitesse et choisis ta route aux intersections (appui long). Si la connexion réseau ne marche pas, BikeControl te propose le Bluetooth à la place.
- (Pro) Capteurs : une liste montre d'où viennent la puissance, la fréquence cardiaque, la cadence et la vitesse, home trainer compris, et te permet de remplacer chacune par ton propre capteur. « Envoyer à l'app d'entraînement » n'apparaît plus que sans home trainer connecté, puisque celui-ci les transmet déjà.
- (Pro) Protocole de contrôle : en Auto, la page du home trainer indique le protocole choisi (p. ex. « Auto : FTMS »).

**Fixes**:
- (Base) Shimano Di2 : la configuration des canaux D-Fly reconnaît maintenant quelle manette est à gauche et laquelle à droite, et aucun bouton qu'elle modifie ne passe encore les vitesses du vélo.
- (Pro) Overlay des vitesses : continue d'afficher les vitesses de ton home trainer après sa reconnexion.
- (Base) Elite Square : les assignations personnalisées des boutons Y, A, B et Z sont conservées après un redémarrage.
- (Base) Un deuxième home trainer mémorisé ne se connecte plus tout seul à côté de celui que tu utilises. Avant, il pouvait se connecter sans que tu le voies et mélanger valeurs et commandes.
- (Base) Pont du home trainer : avec deux home trainers connectés, la puissance de celui que tu utilises ne retombe plus par moments à 0.

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
