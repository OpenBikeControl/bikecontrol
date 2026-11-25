### 7.7.0 (24-11-2026)
**Features**:
- (Pro) Aplikację Wahoo można teraz wybrać jako aplikację treningową: gdy BikeControl działa na urządzeniu z Androidem lub komputerze z Windows, pojawia się w aplikacji Wahoo jako trenażer smart Bluetooth i sam zajmuje się wirtualną zmianą biegów.
- (Pro) Android z aplikacją treningową tylko przez Bluetooth, np. Grimpa: zakładka Jazda i konfiguracja proponują teraz nakładkę z biegiem. Aplikacja działa na innym urządzeniu, więc możesz używać telefonu do czegokolwiek i nadal widzieć swój bieg na wierzchu.
- (Base) PedalCraft, suffer.online, Kardiacs, Sueur, TrainerKit, Pedal Mania, Warp, hupser i SaddleOut są teraz oficjalnie obsługiwane przez OpenBikeControl.

**Fixes**:
- (Base) Android: „Zamknij” w powiadomieniu BikeControl usuwa teraz także nakładkę z biegiem. Wcześniej nakładka zostawała na ekranie po zamknięciu BikeControl.
- (Base) iPhone / iPad: BikeControl pozostaje teraz aktywny w tle, gdy czeka na twoją aplikację treningową (do 15 minut), oraz przez 5 minut po rozłączeniu aplikacji. Wcześniej iOS mógł uśpić BikeControl, zanim MyWhoosh i inne aplikacje go znalazły, więc aplikacja nic nie znajdowała albo nie mogła się połączyć.
- (Base) iPhone / iPad: jeśli iOS mimo to uśpi BikeControl, po powrocie do niego sam znów staje się widoczny w sieci. Wcześniej trzeba było zrestartować metodę sieciową.
- (Base) iPhone / iPad: BikeControl od razu podąża za zmianą Wi-Fi lub hotspotu, zamiast ogłaszać stary adres.
- (Base) iPhone, iPad i Mac: ekran główny informuje, gdy BikeControl nie można znaleźć w sieci, a sprawdzanie sieci jest o jedno stuknięcie dalej.
- (Base) Mac: BikeControl jest ponownie znajdowany po wybudzeniu Maca, bez restartowania metody sieciowej.
- (Base) Sprawdzanie sieci: nie zgłasza już błędu, gdy BikeControl sam przeszukuje sieć, ani gdy używasz tylko mostka trenażera i masz wyłączone połączenie kontrolera.
- (Base) Windows: zrzuty ekranu robione przyciskiem kontrolera mają właściwe kolory. Wcześniej czerwony i niebieski były zamienione.
- (Base) Własne przypisania przycisków, które nazywają się tak samo jak przycisk innego kontrolera (np. przyciski skrętu KICKR BIKE), zostają po ponownym uruchomieniu. Wcześniej za każdym razem wracały do domyślnych.
- (Pro) Wirtualna przerzutka przednia: otwarcie ustawień wirtualnej zmiany biegów zostawia cię na dużej tarczy. Wcześniej przełączało cię na małą tarczę.

### 7.6.2 (23-11-2026)
**Features**:
- (Base) Łopatki Zwift Play / Zwift Ride: przechylenie do środka i na zewnątrz to teraz dwa osobne przyciski, każdy z własną akcją. Twoje dotychczasowe przypisanie łopatki działa dla obu.
- (Base) Elite Rizer i Sterzo: martwą strefę skrętu można teraz ustawić na stronie urządzenia.
- (Base) Akcje akcesoriów (np. zwiększanie / zmniejszanie nachylenia Rizera) przypiszesz teraz bezpośrednio do przycisku połączonego kontrolera na stronie akcesorium: dotknij przycisku na obrazku kontrolera i wybierz pojedyncze, podwójne lub długie naciśnięcie.
- (Base) Everycol jest teraz oficjalnie obsługiwany przez OpenBikeControl.

**Fixes**:
- (Base) Windows: zrzuty ekranu robione przyciskiem kontrolera obejmują teraz cały ekran, także przy skalowaniu ekranu powyżej 100 %. Wcześniej prawa i dolna część mogły być ucinane.
- (Base) Elite Rizer: gdy Rizer jest zablokowany (czerwona dioda) i nie chce się pochylać, jego strona i karta Jazda pokazują to teraz, zamiast twierdzić, że podąża za nachyleniem.
- (Base) Elite Rizer: zablokowany Rizer jest teraz pokazywany jako zablokowany zaraz po połączeniu, a nie dopiero gdy przyjdzie nachylenie.
- (Pro) MyWhoosh przez Bluetooth, Grimpa i inne aplikacje OpenBikeControl przez Bluetooth: aplikacja znajduje teraz zarówno kontroler BikeControl, jak i przekazywany trenażer. Wcześniej Android pokazywał tylko kontroler.
- (Base) Zwift Click V2 z Rouvy: odblokowanie przez Rouvy dociera teraz do Click V2 przez BikeControl.
- (Base) Zwift Click V2: koniec z komunikatem „Nie udało się połączyć” co minutę, gdy kontroler sam się restartuje.
- (Base) Windows, Mac i Linux: symulowane naciśnięcia klawiszy są przytrzymywane przez 50 ms. Wcześniej aplikacje, które sprawdzają klawiaturę raz na klatkę, gubiły wiele pojedynczych naciśnięć.

### 7.6.1 (20-11-2026)
**Features**:
- (Base) MyWhoosh przez Bluetooth: sparuj BikeControl w MyWhoosh jako urządzenie do skrętu, a potem zmieniaj biegi i wybieraj drogę na skrzyżowaniach (długie naciśnięcie). Jeśli połączenie przez sieć nie działa, BikeControl proponuje zamiast tego Bluetooth.
- (Pro) Czujniki: jedna lista pokazuje, skąd pochodzą moc, tętno, kadencja i prędkość – łącznie z trenażerem – i pozwala zastąpić każdą z nich własnym czujnikiem. „Wysyłaj do aplikacji treningowej” pojawia się tylko bez połączonego trenażera, bo trenażer już je przekazuje.
- (Pro) Protokół sterowania: w trybie Auto strona trenażera pokazuje, który protokół został wybrany (np. „Auto: FTMS”).

**Fixes**:
- (Base) Shimano Di2: konfiguracja kanałów D-Fly rozpoznaje teraz, która manetka jest lewa, a która prawa, i żaden zmieniony przez nią przycisk nie zmienia już biegów w rowerze.
- (Pro) Nakładka z biegami: po ponownym połączeniu trenażera dalej pokazuje biegi twojego trenażera.
- (Base) Elite Square: własne przypisania przycisków Y, A, B i Z zostają po ponownym uruchomieniu.
- (Base) Drugi zapamiętany trenażer nie łączy się już sam obok tego, na którym jeździsz. Wcześniej mógł połączyć się niezauważony i mieszać odczyty i polecenia.
- (Base) Most trenażera: przy dwóch połączonych trenażerach moc tego, na którym jeździsz, nie spada już chwilami do 0.

### 7.6.0 (17-11-2026)
**Features**:
- (Base) Incyclist, Tour du Pain i Rampida są teraz oficjalnie obsługiwane przez OpenBikeControl.
- (Base) Manetki CYCPLUS T7 działają jako kontrolery: wszystkie osiem przycisków, domyślnie sterowanie tylnymi strzałkami.
- (Pro) Aplikacje OpenBikeControl widzą teraz twój wirtualny bieg na żywo.
- (Base) Czytelniejszy edytor przycisków: akcje są pogrupowane według tego, co robią (Biegi, Trenażer, Trening, Jazda, …), a na telefonie otwiera się jako panel od dołu.
- (Base) Shimano Di2: trzecia opcja konfiguracji – ustaw kanały D-Fly samodzielnie w E-TUBE, z instrukcją krok po kroku.
- (Base) Zwift Click V2: opcjonalnie możesz używać prawego kontrolera bez odblokowywania.
- Więcej czasu na test: 120 naciśnięć dziennie w okresie próbnym (wcześniej 80), potem 40 dziennie (wcześniej 15), a bez Pro 30 minut dziennie wirtualnej zmiany biegów BikeControl (wcześniej 20).
- Czytelniejszy okres próbny: BikeControl ostrzega cię (także powiadomieniem), gdy zostało 10 naciśnięć na dziś, a karta okresu próbnego pokazuje, co zostaje po nim. Jeśli twoja aplikacja treningowa sama zmienia biegi, „Jazda” nie proponuje już wirtualnej zmiany biegów BikeControl, a sterowanie klawiaturą jest oznaczone jako opcjonalne obok połączenia OpenBikeControl.
- (Base) KICKR Headwind: wentylator może podążać za tętnem (z pasa połączonego z BikeControl) lub mocą, a ty ustawiasz, kiedy rusza i kiedy osiąga pełną prędkość. Strona pokazuje bieżący odczyt i wynikającą z niego prędkość.
- (Base) Elite Rizer: nachylenie działa teraz z każdym trenażerem smart.
- (Pro) Sterowanie trenażerem (Companion Mode) otwiera się teraz w trybie jazdy: duże − i + z biegiem, mocą, kadencją i przełożeniem pośrodku, a pozostałe przyciski poniżej. Przez Edytuj przesuwasz kafelki, zmieniasz ich rozmiar i dodajesz przyciski, wartości i sterowanie muzyką; jest też pełny ekran. Jego − i + zmieniają teraz biegi przez wirtualną zmianę biegów BikeControl, z wibracją przy zmianie.

**Fixes**:
- Zwift: Bomba Ride On odpala się też po krótkim naciśnięciu (Zwift wymaga chwilowego przytrzymania przycisku).
- Trenażery Elite nie pojawiają się już podwójnie (WiFi i Bluetooth).
- Windows: BikeControl nie zawiesza się już przy zamykaniu ani przy błędach sieci, powiadomień czy Bluetooth.
- Android: koniec z awarią, gdy Android restartuje usługę w tle, a „Zamknij i wyjdź” zawsze zamyka aplikację.
- Shimano Di2: konfiguracja kanałów kończy się czysto, gdy manetka nie przyjmie ustawienia.
- Windows i macOS: „Zrób zrzut ekranu” pozwala teraz wybrać folder (zaczynając od Obrazów) zamiast zapisywać obok aplikacji, i informuje, gdy zrzutu nie da się zapisać.

### 7.5.0 (09-11-2026)
**Features**:
- BikeControl jest już dostępny na Linuksie (.deb i AppImage).
- Dużo więcej aplikacji treningowych jest teraz oficjalnie obsługiwanych przez OpenBikeControl: Grimpa, icTrainer, Auuki, VoxVelo, VeloWorkout, Pedalparty, VeloPopuli, Vieta, DirtWatts, WattLog.pro, REZVIVO, OpenRadlr i zwoTrainer.
- Więcej akcji działa z Zwift.
- Power Lock: jedno naciśnięcie utrzymuje moc, którą właśnie generujesz, niezależnie od tego, co robi trasa. Przestań pedałować, a puści, więc nie ruszasz pod ścianę oporu.
- Shimano Di2: wybierz między kanałami E-TUBE (zalecane: Di2 nigdy nie zmienia biegów z manetek, nawet gdy BikeControl się rozłączy) a trybem przycisków. Manetki przewodowe też już działają.
- Można teraz sterować starszymi trenażerami sprzed FTMS, takimi jak Saris Hammer ze starszym firmware i starsze modele Wahoo KICKR.

**Fixes**:
- Windows: most Bluetooth do telefonu znów przesyła dane i już się nie zawiesza. Gdy aplikacja treningowa utknie na starym połączeniu Bluetooth, BikeControl poprosi o ponowne sparowanie.
- Android: kontrolery, które odpadają po długiej sesji, są znów wykrywane.
- Zapomniane gamepady pozostają zapomniane po restarcie.
- TrainingPeaks Virtual: kontroler nie kręci się już bez końca po połączeniu, a dwa iPhone'y już ze sobą nie kolidują.
- Target Power nie jest już nagle bardzo ciężki, gdy zwalniasz na trenażerach z wolnym odczytem kadencji (np. Decathlon D500).
- Wirtualna prędkość uwzględnia przednią tarczę.
- Nakładka w Windows otwiera się z zapisaną przezroczystością i pozycją.
- Korbowe pomiary mocy Shimano są rozpoznawane jako pomiary mocy.

### 7.4.0 (29-10-2026)
**Features**:
- Łańcuch na trenażerze: ustaw tarczę i zębatkę, na których leży twój prawdziwy łańcuch, a każdy wirtualny bieg będzie odczuwalny jak jego prawdziwy odpowiednik.
- ERG po twojemu: zacznij od ostatniego celu lub aktualnej mocy, z krokiem 1, 5, 10 lub 25 W.
- Ride Cave i Velotoss są teraz oficjalnie obsługiwane przez OpenBikeControl.
- Gamepady wibrują przy zmianie biegu.
- Przyciski roweru MUOV smart bike (beta) i lepsza wirtualna zmiana biegów na nowoczesnych trenażerach.

**Fixes**:
- Shimano Di2: przyciski na klamkomanetkach i satelity działają w trybie przycisków.
- Kontroler rozłączony „na tę sesję” pozostaje rozłączony.
- Pomiary mocy Magene PES-P są rozpoznawane.

### 7.3.0 (19-10-2026)
**Features**:
- Shimano Di2: znacznie lepsza integracja. Manetki działają od razu jako przyciski BikeControl, bez wcześniejszego przypisywania kanałów D-Fly w aplikacji E-Tube. Di2 znów zmienia biegi normalnie, gdy tylko BikeControl się rozłączy, i żadne ustawienie Di2 nie jest zmieniane.
- Biketerra jest teraz oficjalnie obsługiwana: łączy się z BikeControl przez Bluetooth za pomocą OpenBikeControl, z przyciskami i sterowaniem.
- Stages SB20: przyciski zmiany biegów roweru działają jako kontroler (beta).

**Fixes**:
- Gamepady działają dalej, gdy aplikacja treningowa jest na pierwszym planie (Android, macOS, Windows).
- Lepsza wirtualna zmiana biegów na trenażerach, które stosują biegi bez ich potwierdzania (rodzina KICKR, Tacx Neo).
- Trenażery Van Rysel są teraz wykrywane.
