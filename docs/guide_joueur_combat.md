# Guide du Joueur — Comprendre & Maîtriser le Combat dans *Banlieue*

> **En bref** : Dans *Banlieue* (1980–1984), on ne distribue pas des coups d'épée pour vider des « PV ». On défend le **Moral** de sa bande et on fait plier la **Résolution** de ceux qui bloquent le passage — avant que les sirènes (CRS, fourgon de vigiles ou car de sécurité) ne bouclent tout le secteur.

---

## 1. L'esprit d'une confrontation dans *Banlieue*

Chaque combat oppose deux camps sur un souterrain de RER, un quai du canal ou un parking d'usine, avec **trois jauges qui comptent vraiment** :

1. **Ton Moral (côté bande)** : tes jeunes tiennent le pavé grâce à leur sang-froid et leur cohésion. Si le Moral d'un compagnon chute sous son **Seuil de Stress**, il entre en préavis de **Crise d'autonomie (`🔥`)** et risque de faire une bêtise incontrôlée (par exemple exploser de colère, déclencher du vacarme ou décrocher).
2. **La Résolution (côté adversaires)** : dès qu'un adversaire tombe à `0` de Résolution, il lâche l'affaire et recule. Quand tous les adversaires ont lâché l'affaire, tu remportes la manche.
3. **L'Horloge & l'Échappée** : chaque affrontement est une course contre la montre. L'horloge (ex. **CRS**, **Fourgon**, **Sécu**) descend cran par cran ; si elle atteint `0`, les renforts encerclent le lieu et vous forcent au repli d'urgence. Mais tu n'es pas obligé de « nettoyer » tout le plateau : si tu ouvres l'**Échappée** (`2/2` ou via un événement comme le *Train Fantôme*), toute la bande peut décrocher proprement !

---

## 2. Lire l'écran de combat en 10 secondes

```text
+-----------------------------------------------------------------------------+
| [HAUT] FRISE CHRONOLOGIQUE — Tour · Horloge · Échappée · Cartes verticales  |
+-----------------------------------------------------------------------------+
|   [Alerte rouge 10,0 s si un adversaire lance une Charge sur ta bande !]    |
|                                                                             |
|             [CENTRE] QUADRILLAGE ISOMÉTRIQUE 8×8                            |
|   • Tes PJ (bas-gauche) face aux adversaires (haut-droite)                  |
|   • Cases bleues     = déplacement possible (Points de Mouvement : 2 ou 3)  |
|   • Cases vertes 🛡  = couverts / obstacles protecteurs                     |
|   • Cases ambre  ⚙   = éléments interactifs du décor à déclencher           |
+------------------------+-------------------------+--------------------------+
| [BAS-GAUCHE]           | [BAS-CENTRE]            | [BAS-DROITE]             |
| FICHE PERSONNAGE ACTIF | MINUTES DU COMBAT       | FICHE SURVOLÉE           |
| Stats, PM, Actions,    | Dernière réplique,      | Fiche miroir du pion ou  |
| Objets ⚙, Fin (+1c),   | Journal déroulant,      | de la carte survolée +   |
| Réactions hors-frise ⚡| Bouton [Espace] Beat ▶  | distance & aperçu 🎲 %   |
+------------------------+-------------------------+--------------------------+
```

* **La Frise en haut** montre l'ordre de passage : plus une carte est à gauche (cran `0`), plus le personnage va agir vite.
* **La Fiche bas-gauche** s'adapte à **qui a le tour** : quand c'est à l'un de tes jeunes, elle affiche ses boutons d'action (`[1–9]`) ; quand c'est au tour d'un adversaire, elle affiche son intention et sa réplique.
* **La Fiche bas-droite** apparaît dès que tu **survoles un pion sur la grille ou une carte sur la Frise** : tu vois immédiatement sa distance en cases, s'il est à couvert (`🛡`), s'il a une garde active (`⚠`), et tes chances exactes de réussite (`🎲 %`) avant même de valider !

---

## 3. Les Jets de rue (`2d6`) & les Failles (`⚠`)

Chaque tentative (tchatche, coup de pression, tir, manipulation d'un objet) jette **2 dés à 6 faces (`2d6`) + Caractéristique (`Esprit` ou `Corps`) + Compétence (`-3` à `+5`)** contre une difficulté (**DD**).

* **Double 6 (`6+6`)** = réussite critique automatique (**plancher `3 %`** même si le coup est désespéré) + **Coup d'éclat** (effet renforcé !).
* **Double 1 (`1+1`)** = échec critique automatique (**plafond `97 %`** même si tu es favori).
* **Surveiller les Failles (`⚠`)** : si ton personnage a une compétence **négative** (par exemple `-2` en *Caisse & Pression* pour Nadia), le bouton s'affiche avec un avertissement `⚠`. En cas d'échec, le raté se transforme en **couac de faille** : `0` dégât infligé et une perte de **Moral** pour le lanceur !

---

## 4. Un combat complet, tour par tour — Exemple : *Gare RER « du Y » (22 h 15)*

Pour voir toutes les options en action, suivons **Toi (Leader)**, **Karim** (équipé d'un *Lance-pierre artisanal*) et **Nadia** face à **3 adversaires** :
* Le **Skin du Bourg** (`3` Résol., mobile, aime charger)
* Le **Cousin S.O.** (`4` Résol.)
* Le **Chef S.O. Vétéran** (`5` Résol., **garde/contre-interruption prête `⚠`**)

### Scène 1 — Bouger sur les cases bleues (`PM`) et prendre un Couvert (`🛡`)

C'est **ton tour** (`cran 0`, fiche bas-gauche active). Sur le plateau `8×8`, tu démarres en `(5,6)` avec `2` ou `3` **Points de Mouvement (`PM`)** — les cases où tu peux marcher s'allument en **bleu**.

1. En face de toi à gauche se trouve un **Pilier béton `(2,4)`** (case vert foncé `🛡` infranchissable) et devant toi la **Banquette quai `(5,4)`** (case vert clair `🛡` accessible).
2. **Tu cliques sur la case bleue `(5,4)`** : ton pion avance sur la banquette sans dépenser ton action du tour !
   * **Ce que ça t'apporte** : tu es désormais **à couvert (`🛡 Banquette quai`)**. Si un ennemi te vise avec une attaque à distance, ta difficulté augmente (`+1` DD, ou `+2` DD contre un gros obstacle comme le *Pilier béton*), et surtout chaque choc moral subi à l'abri est amorti de **`2` points** ! *(Astuce : un obstacle bloquant comme le Pilier protège aussi toute case immédiatement adjacente à lui.)*
3. Maintenant, il te reste des actions : tu dois choisir la bonne selon **la distance en cases**.

---

### Scène 2 — Choisir selon la Distance (`1c` · `2–4c` · `2–6c`) et cibler un pion

Tu vérifies les distances en survolant tes ennemis : le **Cousin S.O.** en `(4,2)` est à **`2` cases** de toi.

| Action | Portée | Ce que ça change sur ton tour |
|---|---|---|
| **Corps à corps** | `1` case | **Verrouillé (`🔒 H.P.`)** à 2 cases — il faut être collé à l'ennemi (ou utiliser ton dernier `PM` pour te coller). Inflige `-2/-3` Résol. et **repousse sa carte sur la Frise (`+1/+2 crans`)**. |
| **Lancer** | `2–4` cases | **Disponible !** Canette/pavé (`-2/-3` Résol., `+1 cran` en Coup d'éclat). |
| **Tir** | `2–6` cases | **Verrouillé (`🔒 Outil tir`)** si tu n'as ni *Lance-pierre* ni *Pétards Mammouth* équipés sur ce personnage. Karim, lui, peut tirer de loin avec son *Lance-pierre* ! |
| **Charge** | `2–5` cases | Saute au contact sur la case libre la plus proche d'un ennemi pour frapper fort (`-3/-4` Résol. + recul). **Attention aux gardes `⚠` !** *(Voir Scène 5.)* |
| **Tchatche** | `1–5` cases | Pression verbale / preuves sur un adversaire (`-2/-3` Résol.). |
| **Échappée** | Partout | Fait reculer l'horloge (**CRS `+2/+3 crans`**) et avance la jauge d'**Échappée (`+1`)**. |

Tu cliques sur **[5] Tchatche 🎯** : la fiche passe en mode **ciblage pion**, et les pions valides s'allument en rouge sur la grille. Tu survoles **Cousin S.O.** → la fiche bas-droite te confirme `Dist. 2 case(s) · 🎲 72% · Cousin S.O. -2 Résol.`. **Tu cliques sur le pion du Cousin S.O.** : le jet réussit, sa Résolution descend à `2/4`, et ton tour se termine (`+2 crans` sur la Frise).

---

### Scène 3 — Le pas-à-pas `[Espace]` et l'Alerte Charge `10 secondes` (`⚡`)

Dans les **Minutes du combat** (bas-centre), le gros bouton affiche **`[Espace] Action : Skin du Bourg ▶`**.

> **Pourquoi `[Espace]` ?** Le jeu ne résout jamais 4 événements d'un coup en te perdant : **un appui sur `Espace` exécute un seul « beat »** (une action ennemie, une crise ou 1 cran d'horloge), pour que tu voies toujours ce qui arrive.

Tu appuies sur `Espace`. Le **Skin du Bourg** initie une **Charge** contre toi !
* Aussitôt, l'action s'arrête net : une **flèche rouge** apparaît entre le Skin et ta case d'atterrissage, la grille pulse en rouge et un **bandeau d'alerte chronométré à `10,0 s`** s'ouvre en haut de la scène !
* Tu as **10 secondes** pour réagir avant qu'il ne te percute (`-8 Moral`) :
  * Sur le bandeau (ou en cliquant directement sur le pion rouge du Skin), tu vois tes alliés qui ont leur **Réaction prête** (*Karim `72%`*, *Nadia `58%`*).
  * **Tu cliques sur Karim** (ou sur le pion du Skin) : Karim lâche une vanne ou un pas de traverse !
  * **Résultat symétrique d'une Charge interceptée** : l'interception réussit (`🎲`) → le Skin du Bourg s'arrête net sur place, inflige **`0` dégât**, reçoit le statut **💫 ASSOMMÉ** et **perd `2 rangs`** (il recule loin à droite sur la Frise) !

*(À l'inverse, si aucun PJ n'intercepte à temps ou si le chrono arrive à `0,0 s`, la charge aboutit et le Skin bondit au contact pour frapper.)*

---

### Scène 4 — Utiliser le Décor (`⚙`) en plein combat

C'est maintenant le tour de **Karim** (`(3,6)`). Juste à côté de lui en `(1,5)` brille une case ambre **`⚙ Extincteur du quai`** (`distance 2 ≤ portée max 2`).

Deux façons équivalentes de l'activer :
* **Cliquer directement sur la case ambre `(1,5)`** sur la grille isométrique, **ou**
* Cliquer sur le bouton vert **`⚙ Extincteur du quai · 72%`** dans sa fiche bas-gauche.

Karim déclenche la goupille (Jet *Système D* vs DD 9) : un nuage de poudre blanche envahit le souterrain ! **Tous les adversaires perdent `-1` de Résolution** et les **CRS perdent `+1` cran**. L'objet du décor (`one_shot`) disparaît ensuite de la grille.

*(Selon le scénario, les décors offrent d'autres leviers : **Vanne d'écluse** sur le canal de l'Ourcq pour gagner du temps et avancer l'Échappée, ou **Projecteur halogène** à Citroën Aulnay pour éblouir les vigiles, couper leur garde et remonter le Moral.)*

---

### Scène 5 — Garde adverse (`⚠`), Action d'Équipement `★` & Charge PJ

Au tour suivant, il faut neutraliser le **Chef S.O. Vétéran** (`5` Résol.). En le survolant, sa fiche bas-droite t'avertit en rouge : **`⚠ Interception & Contre prêts !`**.

* **Piège à éviter** : si tu lances une **Charge** sur un ennemi qui a sa garde prête (`counter_ready`), il a une chance d'intercepter ta charge au vol — et si son jet passe, **c'est TON personnage qui sera Assommé (`💫`), repoussé de 2 rangs (`+4 crans`) et stoppé avec 0 dégât !**
* **La bonne réponse : ton Action d'Équipement `★` (`1× par combat`)** :
  * Si tu portes un objet actif comme le *Perfecto clouté* (**`★ Intimidation Look`**), la *Parka de ronde* (**`★ Bluff de Ronde`**) ou l'*Émetteur 98.4 FM* (**`★ Appel 98.4 FM`**), tu as un bouton doré **`★`** sur ta fiche.
  * Tu sélectionnes **`★ Bluff de Ronde`**, tu cliques sur le Chef S.O. Vétéran : l'action passe, **coupe sa garde active (`counter_ready = false`)**, entame sa Résolution et fait reculer l'horloge !
* Maintenant que sa garde est brisée, **Nadia** ou **Toi** pouvez déclencher une **Charge (`2–5c`)** sans risque d'interception : en survolant le Chef Vétéran, la grille dessine une **flèche jaune** et met en surbrillance la **case d'atterrissage exacte** à côté de lui. Clic gauche → ton pion bondit au contact et le fait plier !

---

### Scène 6 — Spécialités hors-frise (`⚡`), `⏳ Fin (+1c)` & Crises d'autonomie (`🔥`)

Que se passe-t-il si un adversaire finit par encaisser un coup sur le Moral d'un pote ?
* Si **Karim** passe sous son Seuil de Stress (`≤ 40` Moral), sa carte sur la Frise tremble et affiche **`🔥 Crise dans 2 crans`** !
* Tant que la Crise n'a pas éclaté (avant qu'elle atteigne `0`), tu peux intervenir **hors-tour** avec les boutons en bas de la fiche active :
  * **`🛡 Retenir`** : un camarade avec sa Réaction disponible plaque le pote en crise pour le calmer (`+8 Moral`, crise annulée).
  * **Les Spécialités hors-frise (`⚡`)** (chacun a 1 Réaction par cycle, renouvelée quand il agit — ou conservée tout de suite avec **`⏳ Fin (+1c)`** si tu finis ton tour sans attaquer) :
    * **⚡ Moquerie** *(Karim / Ludo / Zoé)* : vise un ennemi sur la grille (`-1/-2` Résol. et le recule de **`+2 crans`** sur la Frise).
    * **⚡ Interposition** *(Leader Mains-Noires / Franck / Manu)* : donne un bouclier absorbant le prochain coup moral (`-6` ou `-8`) + `+4 Moral`.
    * **⚡ Réflexe de rue** *(Leader Enfant de la Dalle / Nadia)* : retarde l'horloge (`+2/+3 crans`) et fait progresser l'**Échappée (`+1`)**.
    * **⚡ Sang-froid** *(Leader Échappé des Pavillons)* : annule instantanément une Crise en préavis (`+10/+12 Moral`), perce un bluff ennemi ou recentre le lanceur (`+6 Moral`).

---

### Scène 7 — Trois façons de conclure l'affrontement

1. **Victoire de terrain** : tous les adversaires tombent à `0` de Résolution → gain d'XP maximal + trait éventuel.
2. **Échappée réussie** : dès que la jauge d'Échappée atteint son seuil (ex. `2/2`) ou qu'un événement se déclenche (ex. le **Train Fantôme** au tour 6 ou l'**Appel 98.4 FM** au tour 4), le bouton doré **`Filer par le Quai !`** s'allume dans ta fiche active → repli propre de toute la bande sans casse.
3. **Fin du compte à rebours** : l'horloge arrive à `0` → repli précipité devant les renforts (perte de Moral et/ou Notoriété), mais l'histoire continue.

---

## 5. Récapitulatif rapide des options

| Option | Portée | Où cliquer | Effet clé |
|---|---|---|---|
| **Déplacement (`PM`)** | `2–3` cases (BFS) | Case **bleue** sur la grille | Se placer à portée ou prendre un couvert `🛡` sans perdre son action |
| **Corps à corps** | `1` case | Bouton `[1]` → **pion ennemi** | `-2/-3` Résol. + recul `+1/+2 crans` |
| **Lancer** | `2–4` cases | Bouton `[2]` → **pion ennemi** | `-2/-3` Résol. (`+1 cran` si Coup d'éclat) |
| **Tir** *(Outil 1982 requis)* | `2–6` cases | Bouton `[3]` → **pion ennemi** | `-2/-3` Résol., coupe garde en Coup d'éclat |
| **Charge** | `2–5` cases | Bouton `[4]` → **pion ennemi** | Bondit au contact + gros choc (attention aux gardes `⚠` !) |
| **Tchatche** | `1–5` cases | Bouton `[5]` → **pion ennemi** | `-2/-3` Résol. via `Esprit + Tchatche` |
| **Échappée** | Partout | Bouton `[6]` | `+2/+3` crans horloge, `+1` Échappée |
| **Équipement `★`** | Variable (`1×/combat`) | Bouton doré `★` (→ pion si ciblé) | Capacité spéciale liée à ta tenue/outil/fétiche |
| **Décor `⚙`** | `≤ max_range` (`1–2c`) | Case **ambre `⚙`** ou bouton vert `⚙` | Jet `2d6` avec effet tactique de zone ou d'horloge |
| **Fin tour `⏳ (+1c)`** | — | Pied de la fiche bas-gauche | Passe vite (`+1 cran`) et garde ta Réaction prête |
| **Hors-frise `⚡ / 🛡`** | Variable | Pied de la fiche bas-gauche | Interruption de spécialité ou retenue d'une Crise |

---

## 6. Mémo des Commandes & 5 Réflexes pour Gagner

| Commande | Action |
|---|---|
| `Clic gauche` case bleue | Déplacer le PJ actif (`PM`) |
| `Clic gauche` case ambre `⚙` | Déclencher l'élément interactif du décor à portée |
| `Clic gauche` sur un pion | Sélectionner/exécuter l'action ciblée ou **Intercepter** une Charge en cours |
| `Survol` pion ou carte Frise | Afficher la fiche miroir bas-droite + distance + aperçu `🎲 %` |
| `1` – `9` | Activer l'option correspondante dans la fiche bas-gauche |
| `Clic droit` ou `Échap` | Annuler le ciblage en cours |
| `Espace` ou `Entrée` | Avancer au beat suivant (quand les Minutes attendent `▶`) |

### 5 réflexes qui sauvent une bande :
1. **Regarde toujours la Fiche Survolée à droite avant de valider** : repère la distance exacte, les failles `⚠` et si l'ennemi a sa garde prête.
2. **Ne charge jamais une garde `⚠` tête baissée** : coupe d'abord sa garde avec un **Tir** en Coup d'éclat, un objet du décor (`⚙`) ou une action d'équipement **`★`**.
3. **Utilise tes `PM` pour finir sur un couvert `🛡`** : `-2` dégâts moraux par coup reçu fait souvent la différence entre tenir et partir en Crise.
4. **Garde toujours au moins un pote avec sa Réaction prête (`⚡`)** pour pouvoir cliquer le bandeau rouge dans les **10 secondes** quand un gros bras charge.
5. **N'oublie pas l'Échappée** : faire plier les ennemis rapporte un peu plus d'XP, mais décrocher proprement au bon moment garde toute la bande intacte pour la suite de la nuit.
