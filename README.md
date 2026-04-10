# Pascatho

Application OCaml locale pour explorer plusieurs corpus religieux et doctrinaux depuis une interface GTK native.

Le projet reprend la logique de sélection et de références décrite dans [`bibleTools.js`](./bibleTools.js) et [`sources.js`](./sources.js), puis l’expose via :
- une interface graphique GTK native en OCaml/C
- un backend CLI `pascatho`
- des tests unitaires et d’intégration sous Dune

## Fonctionnalités

- lecture de plusieurs traductions bibliques JSON
- navigation par référence libre ou par sélecteurs hiérarchiques
- affichage de sources multiples :
  - `Bible`
  - `Coran`
  - `Vatican`
  - `Can`, `Can1917`, `Can1990`
  - `Catechisme`, `CatechismeE`, `CatechismeX`, `CatechismeTrente`
  - `Compendium`, `CompendiumSocial`
  - `Rael`
  - `Hadiths`, `Hadiths2`
- navigation `précédent`, `suivant`, `chapitre`, et ajout de verset avant/après
- affichage d’articles Markdown avec liens internes vers les références du corpus
- mise en évidence de mots-clés via le fichier [`highlights`](./highlights)
- recherche textuelle dans le corpus Vatican

## Structure

- [`lib/`](./lib) : logique métier
- [`bin/`](./bin) : exécutable principal et bindings GTK
- [`test/`](./test) : tests
- [`articles/`](./articles) : articles Markdown
- [`datas/`](./datas) : corpus JSON

## Lancement rapide

Depuis le dépôt :

```bash
dune exec pascatho
```

Quelques commandes CLI utiles :

```bash
dune exec pascatho -- translations
dune exec pascatho -- show-ref --translation bible_aelf --reference "Jn 1,1"
dune exec pascatho -- search --query "foi"
```

## Développement

Validation locale :

```bash
dune build
dune runtest
```

Pour l’installation détaillée sous Debian/Ubuntu via WSL, voir [`INSTALL.md`](./INSTALL.md).
