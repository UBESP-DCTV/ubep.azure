# dev/

Script di sviluppo del pacchetto: `00-setup.R`, `02-dev_cycle.R`,
`03-check_cycle.R`. La cartella è esclusa dalla costruzione del pacchetto
(`.Rbuildignore`).

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
