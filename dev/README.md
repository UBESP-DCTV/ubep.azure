# dev/

Script di sviluppo del pacchetto: `00-setup.R`, `02-dev_cycle.R`,
`03-check_cycle.R`. La cartella è esclusa dalla costruzione del pacchetto
(`.Rbuildignore`).

## `riqualifica-superficie.R`

Esegue il protocollo di riqualificazione: quando un aggiornamento di REDCap
cambia l'impronta di superficie di un'istanza, la scrittura si degrada da sola
a `dry_run` finché la superficie nuova non è misurata e la conformità
riguadagnata. Lo script fa i quattro passi in ordine — legge l'impronta,
aggiunge la riga nel registro, esegue la conformità, che scrive lei la data.

```sh
Rscript dev/riqualifica-superficie.R --diagnosi   # dice dove siamo
Rscript dev/riqualifica-superficie.R              # esegue
```

Chiede rete, segreto e istanza, quindi non gira in CI: server, segreto,
progetto e utente arrivano da `.Renviron`.

Esiste come script e non come procedura da rifare a mano perché il momento in
cui serve è **subito dopo una finestra di manutenzione**, che è il momento
peggiore per improvvisare quattro passi in ordine. I modi di sbagliarlo sono
cancelli e non promemoria: si ferma se il registro non risolve nell'albero
sorgente (contro una copia installata la data non arriverebbe mai in git, senza
alcun errore), se l'istanza è fuori dalla finestra di major, e se l'impronta
**non** è cambiata — che è il caso di un lancio anticipato, e senza quel
cancello aggiungerebbe una riga doppia e rifarebbe una conformità inutile.

## `misura-canale.R`

Legge le istanze che hanno il modulo e stampa le righe che il foglio dei
parametri tiene sotto «La flotta osservata»: versione di REDCap, cancello di
major, impronta di superficie, impronta delle liste di indirizzi, coppie,
coppie con una scadenza, versione del modulo e del contratto.

```sh
Rscript dev/misura-canale.R            # la misura intera
Rscript dev/misura-canale.R --breve    # una riga per istanza
```

**Gira sulla macchina di provisioning, non dalla postazione.** Le liste di
indirizzi delle istanze ammettono un indirizzo solo, quello statico della VM;
da altrove ogni istanza risulterebbe non raggiunta e il guasto somiglierebbe a
una flotta rotta. Lo script lo dice prima di provarci, riconoscendo la
macchina dall'endpoint dell'identità gestita.

Sola lettura, e la guardia in `tests/testthat/test-runner-guardie.R` lo tiene
tale: una misura che potesse cambiare ciò che misura renderebbe illeggibile il
proprio esito.

Nasce il 2026-08-15 dalla fusione di due script che stavano fuori da git —
`verifica-canale.R` sulla macchina e `misura-canale.R` in `/tmp`. Il secondo
era un soprainsieme del primo, e il foglio dei parametri aveva dovuto scrivere
che quello corto «da solo non basta, e va detto perché il nome invita a
crederlo». Due nomi di cui uno contiene l'altro sono la trappola: chi ha fretta
lancia quello corto. Il modo `--breve` conserva l'unica proprietà che il corto
aveva davvero — non passa da `observe_instance()`, quindi risponde anche
quando un'istanza restituisce un payload che l'osservatore non sa leggere.

## Dove sono finiti gli spec e i piani

I documenti di design e i piani di implementazione **non stanno più qui**.
Contengono la mappa istanza→versione della flotta REDCap, e questo repository è
pubblico; la decisione è del 2026-08-05 ed è la numero 8 del design della fase 3
del canale di autorizzazione.

Vivono nella cartella di progetto del vault, insieme al censimento dei server e
alle note di decisione. Chi lavora al pacchetto senza accesso al vault trova in
`NEWS.md` che cosa è cambiato a ogni release e perché, e nella documentazione
roxygen il comportamento di ogni funzione, con le ragioni delle scelte non
ovvie: gli spec servono a ricostruire *perché* una decisione è stata presa, non
a usare il pacchetto.

La storia di git è stata riscritta nello stesso passaggio, quindi quei documenti
non compaiono nemmeno nei commit precedenti. Va detto per intero ciò che questo
non fa: `origin/main` li ha portati fino al 2026-08-05, quindi fork, cache e
cloni già esistenti li conservano.
