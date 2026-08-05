---
name: punto
description: "Facciamo il punto su ubep-azure: rigenera il portale nel vault. Usa quando Corrado dice «facciamo il punto», «dove siamo», «aggiorna il portale», «riprendiamo», «a che punto siamo», oppure a fine di una sessione in cui lo stato del progetto è cambiato."
---

# punto

**Non farlo tu. Lancia il subagente `punto`.**

La rigenerazione legge le note del vault e la storia del repo, e ne riscrive una
pagina: farlo in questa sessione la riempie di materiale che non le serve, e
parte da un contesto di conversazione che il compito non usa. Il subagente lavora
in isolamento, con la procedura nel proprio system prompt
(`.claude/agents/punto.md`) — che quindi non entra qui dentro.

## Dove sta il portale

Nel **vault**, non in questo repo:
`c:/Users/corra/github/cl/obsidian-vault/progetti/ubep-azure/portale/`.

Questo repo è pubblico e il portale contiene conteggi e identificativi che il
confine informativo del progetto tiene fuori da git pubblico. Effetto collaterale
gradito: niente da aggiungere a `.Rbuildignore`.

Conseguenza sul commit: si committa **nel repo del vault**, non in questo.

## Come lanciarlo

Prompt: `Rigenera il portale del punto seguendo la tua procedura.`

Aggiungi una riga di contesto **solo** se in questa sessione è successo qualcosa
che né le note né i commit hanno ancora registrato, e in tal caso di' anche dove
annotarlo.

| Situazione | Modo |
|---|---|
| `/punto` chiesto mentre stai lavorando | `run_in_background: true` — non bloccante, la notifica arriva a fine |
| Fine sessione, stato cambiato | **sincrono** — un task in background non sopravvive alla chiusura della sessione |

## Quando è dovuto

A fine di ogni sessione in cui lo stato è cambiato: un passo eseguito, una
decisione presa o rovesciata, un problema aperto o chiuso.

## Cosa fai tu, al ritorno

Riporta a Corrado **due righe**, non il contenuto della pagina: quando è stato
generato il punto, e se sono emerse contraddizioni fra le fonti.

Poi proponi il commit — non eseguirlo d'iniziativa:

```bash
git -C c:/Users/corra/github/cl/obsidian-vault add progetti/ubep-azure/portale/index.html
git -C c:/Users/corra/github/cl/obsidian-vault commit -m "Aggiorna il portale di ubep-azure al <data>"
```

Con due o tre righe sul cambiamento rispetto al punto precedente. Un commit per
punto: `git log` su quel file è la storia dei punti.

## Se serve cambiare la forma della pagina

`template.html` non lo tocca il subagente. Modificarlo è un atto deliberato, con
un commit suo, e **richiede la verifica visiva in Chrome** a 1100 e 700 px —
l'unico caso in cui serve ancora aprire un browser.

Quando cambia l'insieme delle sezioni, `SEZIONI_ATTESE` in `verifica.py` va
allineato: stessa lista, stesso ordine degli `id` del template.
