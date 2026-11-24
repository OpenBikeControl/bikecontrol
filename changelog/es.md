### 7.7.0 (24-11-2026)
**Features**:
- (Pro) La app Wahoo ya se puede elegir como app de entrenamiento: con BikeControl en un dispositivo Android o un PC con Windows, aparece en la app Wahoo como rodillo inteligente Bluetooth y se encarga del cambio virtual.
- (Pro) Android con una app de entrenamiento solo Bluetooth como Grimpa: la pestaña Rodar y la configuración ahora ofrecen la superposición de marcha. La app se ejecuta en otro dispositivo, así que puedes usar el móvil para lo que quieras y seguir viendo tu marcha encima.

**Fixes**:
- (Base) Android: «Cerrar» en la notificación de BikeControl ahora también quita la superposición de marcha. Antes, la superposición seguía en pantalla después de cerrar BikeControl.
- (Base) Android con FulGaz o Biketerra: al conectar el rodillo, BikeControl pide ahora el permiso de Bluetooth que necesita para aparecer como rodillo. Antes, el puente se quedaba cargando y la app nunca lo mostraba. La página del rodillo muestra además el nombre con el que la app lo lista (Android lo acorta, p. ej. «KICKR CORE 1234 - Bik»).
- (Base) iPhone / iPad: BikeControl ahora sigue activo en segundo plano mientras espera a tu app de entrenamiento (hasta 15 minutos) y durante 5 minutos después de que la app se desconecte. Antes, iOS podía suspender BikeControl antes de que MyWhoosh y otras apps lo encontraran, y la app no encontraba nada o no podía conectarse.
- (Base) iPhone / iPad: si iOS llega a suspender BikeControl, vuelve a ser visible en la red por sí solo en cuanto regresas a él. Antes había que reiniciar el método de red.
- (Base) iPhone / iPad: BikeControl sigue de inmediato un cambio de Wi-Fi o de punto de acceso en lugar de anunciar la dirección anterior.
- (Base) iPhone / iPad: buscar entrenadores Wi-Fi ya no llena el registro de entradas «App crashed».
- (Base) iPhone, iPad y Mac: la pantalla de inicio te avisa cuando BikeControl no se encuentra en la red, con la comprobación de red a un toque.
- (Base) Mac: BikeControl vuelve a encontrarse después de que el Mac salga del reposo, sin reiniciar el método de red.
- (Base) MyWhoosh en otro dispositivo: si tras un minuto y medio no se ha conectado por la red, la pantalla de inicio ahora ofrece Bluetooth en su lugar. Antes esa opción solo aparecía en la página de comprobación de red.
- (Base) MyWhoosh en el mismo dispositivo Android: la pantalla de inicio ahora dice que el cambio virtual no llega a MyWhoosh ahí y qué configuraciones funcionan, en lugar de esperar a que MyWhoosh encuentre un rodillo que nunca mostrará.
- (Base) MyWhoosh en otro dispositivo Android: el paso del rodillo en la pantalla de inicio ahora te indica que cambies el rodillo a Bluetooth, porque MyWhoosh para Android solo encuentra rodillos por Bluetooth.
- (Base) Móvil Android sin Wi-Fi y la app de entrenamiento en el mismo móvil: el consejo ahora es conectarte a cualquier Wi-Fi o usar Local, en vez de «la misma Wi-Fi que la app».
- (Base) Estar sin conexión con la sesión iniciada ya no llena el registro de entradas «App crashed».
- (Base) Comprobación de red: ya no informa de un fallo mientras BikeControl está buscando en la red, ni cuando solo usas el puente del entrenador y tienes desactivada la conexión del mando.

### 7.6.2 (23-11-2026)
**Features**:
- (Base) Palancas de Zwift Play / Zwift Ride: inclinar hacia dentro e inclinar hacia fuera son ahora dos botones distintos, cada uno con su propia acción. Tu asignación actual de la palanca se aplica a ambos.
- (Base) Elite Rizer y Sterzo: la zona muerta de la dirección ahora se ajusta en la página del dispositivo.
- (Base) Las acciones de accesorios (p. ej. subir / bajar la inclinación del Rizer) se asignan ahora directamente a un botón de tu mando conectado desde la página del accesorio: toca el botón en la imagen del mando y elige pulsación simple, doble o larga.

**Fixes**:
- (Base) Windows: las capturas de pantalla con un botón del mando ahora recogen toda la pantalla con los colores correctos, también con un escalado de pantalla superior al 100 %. Antes podían cortarse por la derecha y por abajo, y el rojo y el azul estaban intercambiados.
- (Base) Elite Rizer: cuando el Rizer está bloqueado (LED rojo) y no se inclina, su página y la pestaña Rodar ahora lo indican, en lugar de decir que sigue la pendiente.
- (Base) Elite Rizer: un Rizer bloqueado ahora se muestra como bloqueado en cuanto se conecta, no solo cuando llega una pendiente.
- (Base) Windows: en un PC sin adaptador Bluetooth, el permiso de Bluetooth ahora lo indica y abre los ajustes de Bluetooth en lugar de no hacer nada, y los rodillos Wi-Fi y los mandos se encuentran sin él. Si Windows no deja activar el Bluetooth, BikeControl te lo dice y abre los ajustes.

### 7.6.1 (20-11-2026)
**Features**:
- (Base) MyWhoosh por Bluetooth: empareja BikeControl en MyWhoosh como dispositivo de dirección; luego cambia de marcha y elige tu camino en los cruces (pulsación larga). Si la conexión por red no funciona, BikeControl te ofrece Bluetooth en su lugar.
- (Pro) Sensores: una lista muestra de dónde vienen la potencia, el pulso, la cadencia y la velocidad, rodillo incluido, y te deja sustituir cualquiera por tu propio sensor. «Enviar a la app de entrenamiento» solo aparece sin rodillo conectado, ya que el rodillo ya los transmite.
- (Pro) Protocolo de control: en Auto, la página del rodillo muestra qué protocolo eligió Auto (p. ej. «Auto: FTMS»).

**Fixes**:
- (Base) Shimano Di2: la configuración de los canales D-Fly ahora reconoce qué maneta es la izquierda y cuál la derecha, y ningún botón que cambia sigue cambiando de marcha en la bici.

### 7.6.0 (17-11-2026)
**Features**:
- (Base) Incyclist, Tour du Pain y Rampida tienen ahora soporte oficial a través de OpenBikeControl.
- (Base) Las manetas CYCPLUS T7 funcionan como mandos: los ocho botones, con la dirección en las flechas traseras por defecto.
- (Pro) Las apps de OpenBikeControl ven ahora tu marcha virtual en directo.
- (Base) Un editor de botones más claro: las acciones se agrupan según lo que hacen (Marchas, Rodillo, Entrenamiento, Rodar, …), y en el móvil se abre como hoja inferior.
- (Base) Shimano Di2: una tercera opción de configuración – configura tú mismo los canales D-Fly en E-TUBE, con una guía paso a paso.
- (Base) Zwift Click V2: puedes usar opcionalmente el mando derecho sin desbloquearlo.
- Más margen para probar: 120 pulsaciones al día durante la prueba (antes 80), 40 al día después (antes 15) y, sin Pro, 30 minutos al día del cambio virtual de BikeControl (antes 20).
- Una prueba más clara: BikeControl te avisa (también con una notificación) cuando te quedan 10 pulsaciones para hoy, y la tarjeta de prueba muestra lo que tendrás después. Si tu app de entrenamiento cambia de marcha por sí misma, «Rodar» ya no sugiere el cambio virtual de BikeControl, y el control por teclado aparece como opcional junto a una conexión OpenBikeControl.
- (Base) KICKR Headwind: el ventilador puede seguir tu frecuencia cardíaca (de una banda conectada a BikeControl) o tu potencia, y tú decides dónde arranca y dónde llega a velocidad máxima. La página muestra la lectura actual y la velocidad resultante.
- (Base) Elite Rizer: la inclinación ahora funciona con cualquier rodillo inteligente.
- (Pro) Los Controles del rodillo (modo Companion) abren ahora en modo pedaleo: un − y un + grandes con tu marcha, potencia, cadencia y desarrollo en medio, y los demás botones debajo. Con Editar mueves y cambias el tamaño de los mosaicos y añades botones, datos y control de música; también hay pantalla completa. Su − y + cambian ahora con el cambio virtual de BikeControl, con la vibración al cambiar.

**Fixes**:
- Zwift: la Bomba Ride On se lanza también con una pulsación corta (Zwift necesita el botón pulsado un momento).
- Los rodillos Elite ya no aparecen dos veces (WiFi y Bluetooth).
- Windows: BikeControl ya no se cierra inesperadamente al salir ni por errores de red, notificaciones o Bluetooth.
- Android: ya no se cierra cuando Android reinicia el servicio en segundo plano, y «Cerrar y salir» siempre sale.
- Shimano Di2: la configuración de canales se detiene limpiamente cuando una maneta no acepta el ajuste.
- Windows y macOS: «Hacer captura de pantalla» ahora te deja elegir la carpeta (empezando en Imágenes) en lugar de guardar junto a la app, y avisa cuando una captura no se puede guardar.

### 7.5.0 (09-11-2026)
**Features**:
- BikeControl ya está disponible en Linux (.deb y AppImage).
- Muchas más apps de entrenamiento tienen ahora soporte oficial a través de OpenBikeControl: Grimpa, icTrainer, Auuki, VoxVelo, VeloWorkout, Pedalparty, VeloPopuli, Vieta, DirtWatts, WattLog.pro, REZVIVO, OpenRadlr y zwoTrainer.
- Más acciones compatibles con Zwift.
- Power Lock: una pulsación mantiene la potencia que estás generando ahora mismo, haga lo que haga la carretera. Si dejas de pedalear, se suelta, para que no tengas que arrancar contra un muro de resistencia.
- Shimano Di2: elige entre canales E-TUBE (recomendado: la Di2 nunca cambia desde las manetas, aunque BikeControl se desconecte) y el modo botón. Las manetas con cable ahora también funcionan.
- Ahora se pueden controlar rodillos anteriores a FTMS, como el Saris Hammer con firmware antiguo y los modelos antiguos de Wahoo KICKR.

**Fixes**:
- Windows: el puente Bluetooth al móvil vuelve a enviar datos y ya no se cierra. Si una app de entrenamiento se queda atascada en una conexión Bluetooth antigua, BikeControl te avisa para que vuelvas a emparejar.
- Android: los mandos que se desconectan tras una sesión larga se vuelven a encontrar.
- Los mandos que olvidas siguen olvidados tras reiniciar.
- TrainingPeaks Virtual: el mando ya no se queda cargando tras conectarse, y dos iPhones ya no entran en conflicto.
- Target Power ya no se siente de repente muy duro al bajar el ritmo en rodillos con una lectura de cadencia lenta (p. ej., Decathlon D500).
- La velocidad virtual tiene en cuenta tu plato delantero.
- La superposición de Windows se abre con la opacidad y la posición que guardaste.
- Los potenciómetros de biela Shimano se reconocen como potenciómetros.

### 7.4.0 (29-10-2026)
**Features**:
- Cadena en el rodillo: indica el plato y el piñón en los que está tu cadena real, y cada marcha virtual se siente como su equivalente real.
- ERG a tu manera: empieza con tu último objetivo o tu potencia actual, en pasos de 1, 5, 10 o 25 W.
- Ride Cave y Velotoss tienen ahora soporte oficial a través de OpenBikeControl.
- Los mandos vibran al cambiar de marcha.
- Botones de la MUOV smart bike (beta) y mejor cambio virtual en rodillos modernos.

**Fixes**:
- Shimano Di2: los botones de las manetas y los satélites funcionan en modo botón.
- Un mando que desconectas «para esta sesión» sigue desconectado.
- Se reconocen los potenciómetros Magene PES-P.

### 7.3.0 (19-10-2026)
**Features**:
- Shimano Di2: integración mucho mejor. Las manetas funcionan al instante como botones de BikeControl, sin asignar antes canales D-Fly en la app E-Tube. La Di2 vuelve a cambiar con normalidad en cuanto BikeControl se desconecta, y no se modifica ningún ajuste de la Di2.
- Biketerra tiene ahora soporte oficial: se conecta a BikeControl por Bluetooth mediante OpenBikeControl, con botones y dirección.
- Stages SB20: los botones de cambio de la bici funcionan como mando (beta).

**Fixes**:
- Los mandos siguen funcionando mientras la app de entrenamiento está en primer plano (Android, macOS, Windows).
- Mejor cambio virtual en rodillos que aplican las marchas sin confirmarlas (familia KICKR, Tacx Neo).
- Ahora se detectan los rodillos Van Rysel.
