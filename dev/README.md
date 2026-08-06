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
