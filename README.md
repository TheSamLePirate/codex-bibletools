# Interface TK dans un projet ocaml, pour présenter des textes bibliques.

C'est le portage du site web dont le moteur se trouve dans `bibleTools.js`

Pour ce projet, quand on parle de référence bibliques ou textuelles, on se réfère aux regexps décrites dans `bibleTools.js` qui permet de sélectionner un ou plusieurs versets à afficher.

Le dossier lib doit contenir des .ml qui permettent de gérer la lecture des JSONS. On doit avoir un .mli qui décrit l'interface des modules de lecture de jsons.

Le fichier bin/pascatho.ml doit contenir l'interface TK du projet.

L'interface doit permettre :
- de configurer quelle bible on veut lire (quelle traduction)
- de sélectionner un verset de par sa référence, on doit avoir des boutons : verset suivant/précédent, ajouter verset suivant/précédent, chapitre complet, capitre suivant/précédent. Ces boutons doivent être activés ou désactivés selon la pagination
- d'afficher un markdown (placé dans le dossier articles) qui contient des références textuelles vers les versets.
- un bouton `get lucky` qui permet de choisir au hasard un verset à afficher dans une sous sélection (exemple : on doit pouvoir choisir bible, un livre de la bible, et `get lucky` lancera un chapitre aléatoire et un verset aléatoire.

On doit avoir un moteur de recherche aussi, qui permet de sélectionner une sous partie des sources, et de rechercher. Ce moteur doit-être vraiment évolutif, dans un premier temps moteur de correspondance pure dans le texte, mais on utilisera des algorithmes plus évolués par la suite. Le moteur doit être lançable depuis l'interface mais un fichier bin/searchReIndex.ml peut être utilisé pour gérer l'indexation.
