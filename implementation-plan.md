# Piano di implementazione — controller Intellivision per FreeIntv

## 1. Obiettivo

Realizzare un’app Flutter per smartphone che riproduca il controller Mattel Intellivision (disco direzionale, tastierino numerico e tre pulsanti d’azione) e invii i comandi a un PC che esegue giochi tramite RetroArch e il core FreeIntv. L’esperienza iniziale deve richiedere solo l’installazione dell’app e del core modificato: connessione diretta su Wi‑Fi locale senza ADB o ricevitore separato. Il supporto USB nativo e Bluetooth sono estensioni successive. Gli overlay specifici dei giochi sono un’estensione ulteriore: **non fanno parte della prima versione**.

Il riferimento visivo è l’immagine fornita dall’utente. L’interfaccia dovrà mantenere la disposizione riconoscibile del controller, adattandosi alle dimensioni dello schermo e all’uso in orizzontale.

## 2. Cosa emerge dai sorgenti

Il repository `FreeIntv-master` contiene un core **libretro**, non un’applicazione host autonoma. In `src/libretro.c`, `update_input()` legge lo standard RetroPad e gli assi analogici. `src/controller.c` converte questi ingressi nello stato elettrico del controller Intellivision. La mappatura documentata nel README è:

| Controller Intellivision | Ingresso RetroPad del core |
|---|---|
| Disco, 8 direzioni | D-pad; stick sinistro supporta 16 direzioni |
| Tre pulsanti azione | A, B, Y |
| Tastierino 1–9 | Stick destro in 8 direzioni / Mini-keypad |
| Tastierino 0 e 5 | L3 e R3 |
| Clear e Enter | L2 e R2 |
| Ultimo tasto tastierino selezionato | X |
| Pausa e scambio controller | Start e Select |
| Mini-keypad | L o R tenuto premuto |

Il core non espone oggi un protocollo remoto. L’architettura richiesta aggiunge al modulo FreeIntv un ricevitore nativo integrato: il core accetta connessioni dallo smartphone e aggiorna direttamente gli stati di input che `retro_run()` applica a FreeIntv. Per Wi‑Fi, il telefono e il PC devono essere sulla stessa LAN e l’utente inserisce nell’app l’indirizzo IP del PC. Non viene installato né avviato alcun programma ricevitore separato, driver, ADB o gamepad virtuale.

FreeIntv supporta già overlay PNG e JPG nella cartella `system/freeintv_overlays`, associati al nome base della ROM; l’immagine è usata dal display multi-schermo del core. La futura funzione dell’app dovrà rendere disponibile quell’immagine sul telefono e identificare la ROM attiva.

## 3. Architettura proposta

### App Flutter (smartphone)

- Schermata di connessione con stato, trasporto attivo, qualità/ritardo stimato e azione di disconnessione.
- Schermata controller con disco touch analogico, keypad fisso 3×4 a bersagli grandi e quasi quadrati, e tre pulsanti azione; il keypad riporta `1…9`, `Clear`, `0`, `Enter` come hardware originale (con nota opzionale che Clear/Enter corrispondono a `*`/`#`).
- Impostazioni per orientamento, feedback aptico, sensibilità/zone morte del disco, layout simmetrico e mappature alternative.
- Livello input indipendente dalla UI: ogni controllo produce eventi `pressed`, `released` o asse normalizzato; più dita e pulsanti simultanei devono essere gestiti correttamente.
- Livello trasporto intercambiabile: Wi-Fi LAN è il primo trasporto; USB Accessory e Bluetooth potranno riusare lo stesso protocollo.

### Ricevitore remoto integrato nel core FreeIntv

Componente C nativo compilato insieme al core libretro (prima piattaforma consigliata: Windows; Linux in una fase seguente) che:

1. avvia il listener quando il core viene inizializzato o quando l’utente abilita il controller remoto;
2. accetta una connessione autorizzata dell’app usando il trasporto configurato;
3. valida e conserva lo stato remoto corrente in una struttura thread-safe;
4. integra tale stato in `update_input()` prima delle funzioni esistenti del controller;
5. rilascia tutti i controlli a timeout, disconnessione, unload o deinit del core.

L’app Flutter invia controlli semantici (direzioni, azioni e singoli tasti keypad). Il core li converte in ingressi equivalenti e li combina con il controller locale/RetroPad. Questo evita driver virtuali OS e riusa `controller.c`; occorre definire precedenze e combinazione quando app remota e gamepad locale inviano ingressi insieme.

### Collegamenti

- **Wi-Fi LAN (primo rilascio):** connessione TCP diretta all’IP locale del PC sulla porta 55355. Telefono e PC devono condividere una rete fidata; niente ADB, driver, servizio PC o port forwarding. Discovery automatica può seguire l’inserimento IP.
- **Sicurezza LAN:** il prototipo usa codice condiviso in chiaro e deve restare limitato allo sviluppo su rete fidata. Prima della distribuzione pubblica servono pairing con credenziale casuale e trasporto autenticato/cifrato. L’opzione del core resta disabilitata di default.
- **USB nativo:** Android Open Accessory è un percorso futuro e richiede il PC nel ruolo host USB e un protocollo lato app/core; il normale cavo telefono-PC da solo non crea una rete o una porta accessibile senza ADB.
- **Bluetooth:** milestone futura dopo la scelta e validazione su dispositivi reali tra BLE e Bluetooth Classic.
- Il protocollo non dipende dal trasporto. Ogni pacchetto include versione, sequenza, stato completo dei controlli (non solo delta) e keep-alive. Pacchetti fuori sequenza vengono ignorati; perdita della connessione azzera lo stato.
- Pairing/associazione esplicita tramite chiave/codice configurabile nel core e nell’app, rifiuto di client sconosciuti e nessun servizio esposto oltre il necessario. La configurazione e le istruzioni sul listener devono restare accessibili tramite opzioni libretro/log del frontend, senza UI desktop aggiuntiva.

### Integrazione con il ciclo libretro

FreeIntv continuerà a leggere gli ingressi RetroPad esistenti. Un modulo remoto interno fornirà uno stato sincronizzato al percorso `update_input()` e le funzioni esistenti di `controller.c` manterranno la conversione in segnali Intellivision. Il listener userà I/O non bloccante o un thread dedicato; `retro_run()` non deve mai attendere I/O, pairing o timeout. Il thread non deve chiamare callback libretro né accedere direttamente alla memoria emulata: pubblica solo uno snapshot sincronizzato che il thread del core acquisisce a ogni frame. Il listener deve poter essere disattivato e chiuso correttamente in `retro_unload_game()`/`retro_deinit()`.

## 4. Ambito per rilasci

### Fase 0 — decisioni e prove tecniche

- Fissare target minimo: raccomandazione Android + Windows per MVP; decidere se iOS e Linux siano requisiti successivi.
- Prototipare il listener integrato nel core Windows: collegare lo smartphone, ricevere lo stato e applicarlo direttamente in FreeIntv, senza gamepad virtuale. Verificare anche che il core continui a funzionare con gamepad locale e senza client remoto.
- Provare Wi‑Fi LAN da almeno un telefono reale, misurando latenza, firewall Windows e stabilità in foreground/background. Mantenere il listener su loopback durante lo sviluppo; abilitare ascolto LAN solo nel profilo di rilascio con pairing autenticato e protezione del traffico.
- Definire protocollo, pairing, opzioni libretro, sincronizzazione tra thread e criteri di latenza/affidabilità da confermare con test manuali.
- Controllare licenza GPLv2+ del core e tenere separata l’applicazione. Chiarire eventuale riuso di immagini e marchi del controller.

**Gate:** non iniziare l’implementazione completa finché il listener integrato, l’assenza di blocchi in `retro_run()` e almeno un trasporto non sono dimostrati sul setup target.

### Fase 1 — MVP funzionante

- Flutter: connessione, controller portrait/landscape, gestione multi-touch, stato premuto/rilasciato, preferenze persistenti e indicatore connessione.
- Core Windows: listener remoto, discovery/associazione compatibile con la UX scelta, ricezione dello stato controlli, integrazione con input libretro, log diagnostico e chiusura sicura.
- Protocollo v1 documentato e indipendente dal trasporto.
- Profilo predefinito compatibile con RetroPad FreeIntv; istruzioni di setup per la mappatura in RetroArch.
- Wi‑Fi LAN come trasporto iniziale; nessun setup ADB. Scansione/discovery automatica può seguire l’MVP. USB nativo tramite Android Open Accessory e Bluetooth sono milestone successive, subordinate a prototipi multipiattaforma.
- Prima prova end-to-end: avvio gioco, movimento, tre azioni, tutti i 12 tasti, input simultanei e rilascio sicuro dopo disconnessione.

### Fase 2 — robustezza e usabilità

- Riconnessione controllata, indicazione batteria/trasporto ove disponibile, gestione permessi, diagnostica esportabile e aggiornamento del core e dell’app.
- Opzioni libretro per abilitare/disabilitare il listener, scegliere trasporto e parametri di associazione; profili keypad configurabili dove utili.
- Vibrazione tattile configurabile e calibrazione soglia/centro del disco.
- Modalità due giocatori: ogni telefono/istanza è assegnato a una porta, con chiara gestione dello scambio Left/Right del core.
- Validazione su differenti dimensioni schermo, versioni OS e configurazioni RetroArch.

### Fase 3 — Overlay ROM-specifici (extra, non disponibili al lancio)

- Definire prima la destinazione dell’overlay: telefono oppure display libretro. Raccomandazione iniziale: rendering sul telefono; il core integrato potrà in seguito comunicare alla app i metadati della ROM attiva, se il protocollo lo prevede.
- Catalogo locale associato a ROM, con nome visualizzato, percorso/hash ROM, immagine, provenienza e licenza/diritti.
- Importazione manuale e associazione ROM, anteprima e gestione di immagini mancanti o non valide; non distribuire immagini commerciali senza autorizzazione.
- Il core conosce il percorso ROM passato a `retro_load_game()` e può inviare all’app il basename tramite protocollo. Per Frog Bog l’app dovrà associare l’overlay con il nome base della ROM, senza estensione, e conservarlo come asset utente.
- Il layout mobile usa una griglia stabile 3×4; dimensioni e spaziatura sono scalate insieme mantenendo i centri dei tasti in coordinate normalizzate. Il core cerca overlay in `system/freeintv_overlays/<basename-ROM>.png` o `.jpg`, eliminando l’estensione della ROM. Per mostrarlo nell’app occorre identificare la ROM attiva e rendere disponibile l’immagine sul telefono (importazione locale con stesso basename oppure trasferimento dal core). Il formato core 370×600 è un riferimento per calibrare l’allineamento, non un vincolo per la grafica mobile.
- Testare overlay associati correttamente, nessun overlay, immagine errata e tasti sovrapposti all’input principale.

## 5. Mappatura funzionale dell’interfaccia

| Elemento touch | Evento suggerito | RetroPad visto dal core |
|---|---|---|
| Disco touch | asse X/Y normalizzato, dead zone configurabile | stick sinistro (16-way); D-pad come fallback/configurazione |
| Pulsante alto/sinistro/destro | pressione mantenuta | Y / A / B |
| Ciascun tasto 1–9, Clear, 0, Enter | pressione mantenuta | tasti mappati tramite profilo keypad dedicato |
| Pausa | impulso o pressione | Start |
| Scambia controller | impulso | Select |
| Ultimo tasto selezionato | pressione | X |
| Mini-keypad | eventuale modalità secondaria | L/R, solo se usata nel mapping |

La corrispondenza keypad-to-RetroPad non è diretta uno-a-uno nella mappatura standard: il core usa lo stick destro per 1–9 e L3/R3/L2/R2 per 0/5/Clear/Enter. La UI può offrire i 12 pulsanti fisici; il layer di mapping nel core deve convertire quegli ingressi equivalenti, con gestione di selezione/pressione simultanea coerente con le capacità del core. La prova tecnica deve verificare eventuali conflitti tra tasti premuti simultaneamente e le semantiche del controller.

## 6. UX e schermate

1. **Benvenuto/setup:** guida installazione del core modificato e associazione al PC, guida connessione e verifica input.
2. **Connessione:** elenco PC trovati o inserimento/scan, trasporto scelto, pairing autorizzato dal PC e feedback errori.
3. **Controller:** replica grafica ispirata all’hardware; modalità landscape raccomandata, ridimensionamento accessibile, tasti con feedback immediato e disco senza drift.
4. **Impostazioni:** layout/orientamento, sensibilità, vibrazione, mapping, connessione preferita, privacy e reset.
5. **Overlay (fase futura):** libreria/importazione, dettaglio gioco e preview; nascosta o dichiarata “in arrivo” nel rilascio MVP.

## 7. Modello dati e protocollo

Stato controller interno, indipendente da Flutter widgets:

- assi del disco X/Y in intervallo normalizzato;
- insieme dei pulsanti premuti identificati da enum stabile;
- numero sequenziale monotono e timestamp monotono;
- versione protocollo e identificatore sessione.

Inviare snapshot a frequenza limitata mentre cambia lo stato e heartbeat periodico. Un messaggio `disconnect` è utile ma non sufficiente: il ricevitore applica un timeout breve, svuota gli input e termina la sessione se non arrivano heartbeat. Versionare il protocollo fin dall’inizio; evitare di inviare ROM, BIOS o credenziali.

## 8. Struttura tecnica suggerita

```text
mobile/
  lib/domain/          controller state, button IDs, mapping profiles
  lib/presentation/    screens, controller widgets, accessibility
  lib/transport/       client Bluetooth/USB, discovery, codec
  test/                unit e widget tests
FreeIntv-master/src/
  remote_input.c/.h    protocollo, lifecycle, stato sincronizzato, pairing
  remote_transport_*.c backend Wi‑Fi/Bluetooth/USB Accessory per piattaforma
  libretro.c           integrazione snapshot in update_input e opzioni core
  controller.c         conversione ai codici controller esistenti
protocol/
  v1.md                pacchetti, stati, timeout, compatibilità
```

L’app mobile può vivere in una cartella o repository separato. Il ricevitore è parte del core FreeIntv e segue la sua toolchain/build matrix; non esiste un target o pacchetto companion.

## 9. Piano di verifica

### Verifiche automatiche

- Conversione assi→direzioni e dead zone, bordi e diagonali.
- Codifica/decodifica protocollo, versioni sconosciute, sequenze duplicate e pacchetti troncati.
- Pressione/rilascio, multi-touch, interruzione app, perdita rete/USB/Bluetooth e reset degli input.
- Compatibilità della mappatura con tutti gli ingressi dichiarati da FreeIntv.

### Verifiche manuali end-to-end

- RetroArch avvia il core modificato; il core riceve input remoto senza gamepad virtuale, mentre gli input locali continuano a funzionare.
- Testare disco in 8 direzioni e diagonali/16 direzioni dove supportato, tre azioni e tutti i tasti del keypad.
- Tenere un’azione mentre si muove il disco o si preme un tasto numerico.
- Perdita/riattivazione USB o Bluetooth e app sospesa: nessun ingresso resta bloccato.
- Latenza percepita, batteria, riscaldamento e uso prolungato su dispositivi di fascia minima concordati.
- Ciclo completo: installare solo il core e l’app, connessione sulla stessa Wi‑Fi senza ADB o driver, pairing, avvio gioco, riconnessione e disassociazione.

## 10. Rischi e mitigazioni

| Rischio | Mitigazione / decisione necessaria |
|---|---|
| Integrazione socket/Bluetooth/USB varia tra sistemi host | Isolare backend nativi dietro un’interfaccia C e validare per piattaforma |
| Wi‑Fi LAN può essere isolata dal firewall o dalla configurazione guest/router | Mostrare IP e diagnostica nell’app; documentare rete fidata e regola firewall; non richiedere port forwarding |
| USB mobile diretto richiede un protocollo accessorio host/accessory | Pianificarlo come trasporto separato; non confonderlo con il cavo USB con debug ADB |
| BLE potrebbe non comportarsi bene come flusso di eventi a bassa latenza | Confrontare BLE e Bluetooth Classic con prototipo prima della scelta |
| Mapping 12 tasti su ingressi libretro più limitati | Prototipo con FreeIntv; controllare concorrenza e rilascio; aggiornare core solo se indispensabile |
| Listener LAN nel core espone input alla rete locale | Opt-in core option, pairing crittografico e cifratura autenticata, timeout e singolo client; nessun port forwarding |
| Overlay commerciali soggetti a copyright | Consentire contenuti forniti/importati dall’utente e memorizzare attribuzione/licenza |
| iOS non può offrire lo stesso accesso hardware di Android | Trattarlo come target separato, con prova di fattibilità e matrice feature |

## 11. Criteri di completamento MVP

- Uno smartphone supportato si associa direttamente al listener integrato nel core FreeIntv; non sono richiesti ADB, driver o software ricevitore separato.
- Il core FreeIntv riceve input remoti e locali corretti per disco, azioni e tastierino, senza gamepad virtuale.
- Wi‑Fi LAN funziona sui dispositivi e sistemi operativi dichiarati nella release. USB nativo e Bluetooth possono essere rilasciati in milestone successive e solo dopo la validazione.
- Pressioni e rilasci sono deterministici; disconnessioni e sospensioni non lasciano input attivi.
- Setup, autorizzazione, stato connessione e recupero errore sono documentati nell’app e nelle opzioni/log del frontend, senza companion.
- Gli overlay ROM-specifici non sono necessari per completare il flusso di gioco e sono esclusi dalla release iniziale.

## 12. Decisioni da chiudere all’avvio

1. Piattaforme MVP: proposta Android + Windows; confermare se Android+iOS o Linux siano invece obbligatori.
2. Confermare i frontend e sistemi host target: il ricevitore sarà compilato dentro il core, quindi il supporto dipenderà dagli stack e dalle policy disponibili per ciascun target.
3. Scegliere dopo la spike la discovery LAN e i backend Bluetooth/USB Accessory realizzabili sia nell’app mobile sia nel core compilato per i sistemi host target.
4. Decidere se il controller virtuale debba agire sempre sulla porta 1 o offrire selezione P1/P2.
5. Per gli overlay futuri, scegliere telefono vs PC come display e definire la fonte lecita delle immagini.

## Riferimenti nel repository

- `FreeIntv-master/README.md` — requisiti BIOS, overlay core e mappatura RetroPad.
- `FreeIntv-master/src/controller.c` — conversione RetroPad→stato controller e keypad.
- `FreeIntv-master/src/controller.h` — codici dei 12 tasti.
- `FreeIntv-master/src/libretro.c` — acquisizione input e opzione `freeintv_multiscreen_overlay`.
- `FreeIntv-master/src/libretro_core_options.h` — descrizione e default dell’opzione overlay.
