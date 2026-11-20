### 7.6.1 (20-11-2026)
**Features**:
- MyWhoosh przez Bluetooth: sparuj BikeControl w MyWhoosh jako urządzenie do skrętu, a potem zmieniaj biegi i wybieraj drogę na skrzyżowaniach (długie naciśnięcie). Jeśli połączenie przez sieć nie działa, BikeControl proponuje zamiast tego Bluetooth.
- Czujniki: jedna lista pokazuje, skąd pochodzą moc, tętno, kadencja i prędkość – łącznie z trenażerem – i pozwala zastąpić każdą z nich własnym czujnikiem. „Wysyłaj do aplikacji treningowej” pojawia się tylko bez połączonego trenażera, bo trenażer już je przekazuje.
- Protokół sterowania: w trybie Auto strona trenażera pokazuje, który protokół został wybrany (np. „Auto: FTMS”).

### 7.6.0 (17-11-2026)
**Features**:
- Incyclist, Tour du Pain i Rampida są teraz oficjalnie obsługiwane przez OpenBikeControl.
- Manetki CYCPLUS T7 działają jako kontrolery: wszystkie osiem przycisków, domyślnie sterowanie tylnymi strzałkami.
- Aplikacje OpenBikeControl widzą teraz twój wirtualny bieg na żywo.
- Czytelniejszy edytor przycisków: akcje są pogrupowane według tego, co robią (Biegi, Trenażer, Trening, Jazda, …), a na telefonie otwiera się jako panel od dołu.
- Shimano Di2: trzecia opcja konfiguracji – ustaw kanały D-Fly samodzielnie w E-TUBE, z instrukcją krok po kroku.
- Zwift Click V2: opcjonalnie możesz używać prawego kontrolera bez odblokowywania.
- Więcej czasu na test: 120 naciśnięć dziennie w okresie próbnym (wcześniej 80), potem 40 dziennie (wcześniej 15), a bez Pro 30 minut dziennie wirtualnej zmiany biegów BikeControl (wcześniej 20).
- Czytelniejszy okres próbny: BikeControl ostrzega cię (także powiadomieniem), gdy zostało 10 naciśnięć na dziś, a karta okresu próbnego pokazuje, co zostaje po nim. Jeśli twoja aplikacja treningowa sama zmienia biegi, „Jazda” nie proponuje już wirtualnej zmiany biegów BikeControl, a sterowanie klawiaturą jest oznaczone jako opcjonalne obok połączenia OpenBikeControl.
- KICKR Headwind: wentylator może podążać za tętnem (z pasa połączonego z BikeControl) lub mocą, a ty ustawiasz, kiedy rusza i kiedy osiąga pełną prędkość. Strona pokazuje bieżący odczyt i wynikającą z niego prędkość.
- Elite Rizer: nachylenie działa teraz z każdym trenażerem smart.
- Sterowanie trenażerem (Companion Mode) otwiera się teraz w trybie jazdy: duże − i + z biegiem, mocą, kadencją i przełożeniem pośrodku, a pozostałe przyciski poniżej. Przez Edytuj przesuwasz kafelki, zmieniasz ich rozmiar i dodajesz przyciski, wartości i sterowanie muzyką; jest też pełny ekran. Jego − i + zmieniają teraz biegi przez wirtualną zmianę biegów BikeControl, z wibracją przy zmianie.

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
