# CLAUDE.md — ubep.azure — wrapper R per Azure e Microsoft Graph

Repo Claude di progetto. Lingua di lavoro: italiano.

## Cos'è questo repo

Pacchetto R **pubblico** (`UBESP-DCTV/ubep.azure`) che fornisce wrapper per i task Azure e Microsoft Graph eseguiti alla Unit of Biostatistics, Epidemiology and Public Health (UBEP) dell'Università di Padova: gestione utenti, provisioning, cartelle `edcXX`.

A differenza di un progetto di consulenza, qui il repo **è** il deliverable: codice, test, documentazione roxygen, sito pkgdown. Non è uno scaffold di lavoro attorno a una fonte esterna.

La cartella condivisa (vedi `teams_path` sotto) non contiene il codice, ma il **contesto operativo** di cui il pacchetto è l'automazione: procedure REDCap, work instruction, configurazione dei server Azure, template dei file di import utenti. Si legge in `--add-dir`, si scrive solo con conferma esplicita.

## Ancoraggio

| Cosa | Path |
|---|---|
| Nota indice nel vault | [`c:/Users/corra/github/cl/obsidian-vault/progetti/ubep-azure/ubep-azure.md`](c:/Users/corra/github/cl/obsidian-vault/progetti/ubep-azure/ubep-azure.md) |
| Fonte ufficiale (cartella condivisa) | `C:/Users/corra/Unit of Biostatistics Epidemiology and Public Health/IT - RedCap UBEP` |
| Source label per `vault-add` | `ubep-sharepoint` |
| Repo remoto (pubblico) | <https://github.com/UBESP-DCTV/ubep.azure> |
| Sito pkgdown | <https://ubesp-dctv.github.io/ubep.azure/> |

## Modalità d'uso

Apri questa cartella in **Positron**. Apri una sessione Claude dal plugin integrato — niente da configurare, niente flag da passare.

Le directory aggiuntive (la cartella condivisa e la sotto-cartella di progetto del vault) sono pre-configurate in `.claude/settings.json` sotto `permissions.additionalDirectories` e vengono agganciate automaticamente ad ogni sessione lanciata in questo cwd.

Cwd = questo repo. Le directory accessibili sono:

- la cartella condivisa (R-mostly: l'hook globale `shared-path-guard` protegge dalle Write accidentali);
- la sotto-cartella di progetto del vault `<vault>/progetti/ubep-azure/` (lettura + scrittura).

**Il resto del vault NON è accessibile da questo repo, neanche in lettura.** È enforced a runtime dall'hook `PreToolUse` `vault_isolation.py` (referenziato in `.claude/settings.json`, scope in `.claude/vault-isolation.json`) e non è bypassabile da auto-mode. Le sole eccezioni sono `<vault>/progetti/ubep-azure/` (workspace nostro) e `<vault>/_inbox/` (write-only, per `/vault-add`).

## Regole rigide

1. **Scrivere QUI di default**: codice, test, documentazione, note di analisi. Tutto sotto git.
2. **Cartella condivisa = R-mostly**: leggi procedure, work instruction e template ufficiali, ma non scrivere senza conferma esplicita. L'hook globale `shared-path-guard` blocca i Write/Edit verso `IT - RedCap UBEP` finché non imposti `CLAUDE_SHARED_WRITE_OK=1` per l'operazione specifica.
3. **MAI** creare `.claude/`, `CLAUDE.md`, `.git/`, `.gitignore` dentro la cartella condivisa — l'hook globale lo blocca senza override.
4. **Vault = drop-in-only**: per appuntare qualcosa nel vault da questa sessione, usa `/vault-add` (skill globale). Quella scrive in `$OBSIDIAN_VAULT_PATH/_inbox/<slug>-ubep-sharepoint.md` con `source: ubep-sharepoint` automaticamente popolato.
5. **Credenziali e tenant ID non si committano.** Questo repo è pubblico. App registration, client secret, object ID, tenant ID, liste utenti reali: niente di tutto ciò entra in git, nemmeno negli esempi roxygen o nei test. Usa `.Renviron` (già in `.gitignore`) e, nei test, fixture anonime.
6. **Persone nuove = SEMPRE via `_inbox/`, mai diretta in `risorse/persone/`**: quando emerge un nominativo nuovo (collega, referente IT, contatto) nel contesto di questo progetto, NON creare una scheda direttamente — `risorse/persone/**` è fuori scope per design. Crea invece una nota in `_inbox/ubep-azure-persona-<nome-kebab>.md` con frontmatter `type: persona`, `source: ubep-sharepoint`, e tag che identifica il progetto. Sarà poi Corrado, dal vault in Modalità A, a lanciare `/note-promote` per smistare ogni scheda. Per LINKARE una persona nei testi di questo progetto, usa `[[<nome-kebab>]]`: se la scheda esiste già in `risorse/persone/`, Obsidian risolve il link senza che questo repo debba leggere il file.

## Struttura

Pacchetto R standard, già popolato — **non** uno scaffold vuoto:

```
ubep.azure/
├── .claude/            # config locale Claude (permessi, hook isolamento vault)
├── .github/            # CI: R-CMD-check, lint, codecov, pkgdown (tutti su main)
├── R/                  # sorgenti del pacchetto
├── man/                # documentazione generata da roxygen2 (NON editare a mano)
├── tests/testthat/     # test (testthat 3rd edition)
├── renv/ + renv.lock   # ambiente riproducibile
├── inst/, dev/         # risorse interne e script di sviluppo
├── DESCRIPTION         # metadati, dipendenze, versione
├── NAMESPACE           # generato da roxygen2 (NON editare a mano)
├── _pkgdown.yml        # config del sito di documentazione
├── README.Rmd → README.md   # editare il .Rmd, mai il .md
├── PROJECT-INDEX.md    # ancoraggio al vault
└── CLAUDE.md           # questo file
```

Due file **generati**, mai editati a mano: `NAMESPACE` e `man/*.Rd` (`devtools::document()`), e `README.md` (`devtools::build_readme()` da `README.Rmd`).

## Stack

Già deciso, non c'è nulla da scegliere:

- **R** + `renv` per l'ambiente riproducibile (`renv::restore()` al primo avvio).
- **roxygen2** per la documentazione (`devtools::document()` dopo ogni modifica alle docstring).
- **testthat** (3rd edition) per i test (`devtools::test()`).
- **lintr** per lo stile (config in `.lintr`), verificato in CI.
- **pkgdown** per il sito (`_pkgdown.yml`).

Comandi ricorrenti: `devtools::load_all()`, `devtools::document()`, `devtools::test()`, `devtools::check()`.

## Workflow git

- Un commit = una modifica logica. Messaggi in italiano, verbo all'imperativo.
- **Un branch per sotto-progetto, poi `main`.** Nessun ramo di integrazione intermedio: `develop` è stato ritirato nel 2026-07 perché non aveva mai contenuto un commit che `main` non avesse già, e un workflow che non gira mai è il posto dove le action invecchiano fino a rompersi.
- **Repo pubblico con CI.** Le GitHub Actions (`R-CMD-check`, `lint`, `codecov`, `pkgdown`) devono passare: `devtools::check()` in locale prima di pushare, non dopo.
- Il push su remote pubblico è il funzionamento normale di questo repo — ma **solo su tua richiesta esplicita**, mai di iniziativa.
- Bump di versione in `DESCRIPTION` + voce in `NEWS.md` quando la modifica è utente-visibile.

## Ponte verso il vault

Quando questo progetto produce knowledge riusabile (pattern di chiamata Graph API, workaround di autenticazione, schema di provisioning), candidalo per il vault tramite `/vault-add` (atterra in `_inbox/`, poi `/note-promote` lo smista in `risorse/`).

Quando le decisioni di progetto cambiano (deadline, stato, scope), aggiorna manualmente la nota indice nel vault, [`progetti/ubep-azure/ubep-azure.md`](c:/Users/corra/github/cl/obsidian-vault/progetti/ubep-azure/ubep-azure.md).

## Quando vale la pena lanciare slash command Claude

- **`/init`**: mai. Questo `CLAUDE.md` deriva dal template `meta/templates/project-scaffold/CLAUDE.md.tmpl` versionato nel vault (con adattamenti per il fatto che qui il repo è un pacchetto R pubblico preesistente). Se vuoi farlo evolvere, evolvi il template lì.
- **`/claude-automation-recommender`**: il repo ha già anni di storia e pattern consolidati (CI, renv, testthat) — qui ha senso subito, non fra 2-4 settimane.
- **`/code-review`** / **`/security-review`**: prima dei merge su `main`, e in particolare su ogni modifica che tocca autenticazione o gestione utenti (repo pubblico, superficie Graph API).
- **`/feature-dev:feature-dev`**: quando inizi una funzione nuova non banale.
