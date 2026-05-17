# Pascatho

Application OCaml locale pour explorer plusieurs corpus religieux et doctrinaux depuis une interface GTK native.

Il s'agit d'une interface gtk pour avoir en local le site : http://www.pascatho.ovh
Le tout est généré par codex(openAI) en ocaml.


Le projet reprend la logique de sélection et de références décrite dans [`sources.js`](./sources.js) et historiquement dans [`bibleTools.js`](./bibleTools.js), puis l’expose via :
- une interface graphique GTK native en OCaml/C
- un backend CLI `pascatho`
- des tests unitaires et d’intégration sous Dune

Le runtime n’utilise plus `bibleTools.js` pour charger les abréviations bibliques : ces données ont été recodées dans [`lib/bibleTools.ml`](./lib/bibleTools.ml).

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
- bouton `🍀` pour sélectionner aléatoirement une référence compatible avec la source courante
- bouton `📋` pour copier la référence affichée dans le presse-papiers
- affichage d’articles Markdown avec liens internes vers les références du corpus
- bouton `Back` avec pile d’historique entre articles et références
- mise en évidence de mots-clés via le fichier [`highlights`](./highlights)
- recherche textuelle dans le texte affiché via `Ctrl+f` ou `🔍`, avec surlignage, compteur et navigation suivant/précédent
- rendu enrichi des références dans les textes Vatican, y compris notes effectivement utilisées
- fond GTK animé avec image de fond, croix fil de fer et logo

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

L’interface permet notamment :
- saisie d’une référence libre puis `Entrée` ou `Afficher`
- sélection hiérarchique d’une source puis `>`
- navigation `Chapitre`, `Précédent`, `Suivant`, `+`
- ouverture directe d’un article depuis la liste du bas
- recherche dans le contenu courant avec `Ctrl+f`

Quelques commandes CLI utiles :

```bash
dune exec pascatho -- translations
dune exec pascatho -- project-root
dune exec pascatho -- show-ref --translation bible_aelf --reference "Jn 1,1"
dune exec pascatho -- source-list --translation bible_aelf
dune exec pascatho -- search --query "foi"
```

## Développement

Validation locale :

```bash
dune build
dune runtest
```

Pour l’installation détaillée sous Debian/Ubuntu via WSL, voir [`INSTALL.md`](./INSTALL.md).
