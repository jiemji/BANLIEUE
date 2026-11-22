# *Banlieue* — Structure des Écrans, Menus & Création de Partie

*Spécification UX, persistance et création du protagoniste — validée avant implémentation Godot 4.*

---

## 1. Architecture des États & Contrôles

### Machine d'états globale

```text
  [ Lancement ]
        │
        ▼
  ( TITLE_MENU ) ◄────────── Retour à l'accueil (confirmation) ─────────┐
     │       │                                                          │
     │       ├──► [ Modal: SAVE_LOAD (Charger) ] ───► ( IN_GAME )       │
     │       ├──► [ Modal: OPTIONS ]                     ▲  │           │
     │       └──► ( NEW_GAME_SETUP ) ──► Lancer ─────────┘  │           │
     │                                                      │ Échap     │
     │                                                      ▼           │
     └──────────────────────────────────────────────► ( PAUSE_MENU ) ───┘
                                                        │   │   │
                                        Sauver/Charger ─┘   │   └─► Options
                                                            └─► Nouvelle partie (conf.)
```

* **`TITLE_MENU`** : Écran d'accueil unifié au lancement du jeu, hors partie active.
* **`NEW_GAME_SETUP`** : Écran « Nouvelle partie » (composition libre du Leader : prénom/surnom, portrait + pion assorti, choix parmi 4 archétypes).
* **`IN_GAME`** : Session active (exploration multi-zoom `N1–N4`, dialogues, Frise de Tension).
* **`PAUSE_MENU`** : Même panneau que le Menu Principal, surimposé sur la partie en cours (met la simulation et les entrées du monde en pause, sans perdre l'état de `GameState` ni des vues).
* **Modales (`SAVE_LOAD` et `OPTIONS`)** : Ouvrables aussi bien depuis `TITLE_MENU` que depuis `PAUSE_MENU`, et refermables vers l'état appelant.

### Arbitrage clavier & navigation

| Touche / Action | En jeu (`IN_GAME`) | Dans un menu / une modale (`TITLE_MENU`, `PAUSE_MENU`, `SAVE_LOAD`, `OPTIONS`, `NEW_GAME_SETUP`) |
|---|---|---|
| **`Échap`** | Ferme le **Carnet de Bande** s'il est ouvert, sinon ouvre le **Menu Pause** (`PAUSE_MENU`). *(Si un sous-panneau ou une popup d'alerte est ouverte, l'arbitrage ferme d'abord la surcouche active.)* | Ferme la modale active (`SAVE_LOAD` / `OPTIONS` / confirmation) ou referme `PAUSE_MENU` pour reprendre la partie. Sur `NEW_GAME_SETUP`, revient au menu appelant. |
| **`F`** | Ouvre / referme le **Carnet de Bande (Fiches PJ)** ([fiches_personnages_pj.md](file:///e:/JDR/BANLIEUE/docs/fiches_personnages_pj.md)). | Verrouillé. |
| **`1` – `6`** | Bascule librement entre les sous-groupes de la bande (jusqu'à 6 membres). *(En confrontation sur la Frise, `1–4`, `Tab` et `Espace` pilotent le combat — voir [ux_combat_frise.md](file:///e:/JDR/BANLIEUE/docs/ux_combat_frise.md).)* | Verrouillé. |
| **`Retour arrière` (`Backspace`)** | Dézoome d'un niveau cartographique (`N4 → N3 → N2 → N1`) — remplace l'ancien usage d'`Échap`. | Navigation standard / édition du champ texte. |
| **Bouton `▲` / Molette** | Dézoom cartographique `N4 → N3 → N2 → N1` et navigation atlas. | Inactif sur les vues monde (verrouillées pendant le menu). |
| **`M`** | Bascule rapide entre l'intérieur actif (`N4`) et le plan de Cradon (`N3`). | Verrouillé. |

---

## 2. Écran d'Accueil & Menu Principal Unifié

### Fond vivant temps réel & ambiance 1982

* **Décors en arrière-plan** : Dès l'ouverture du jeu (`TITLE_MENU`), la vue isométrique du **Box-Garage** est chargée et visible en arrière-plan en temps réel (sans passer par un écran titre intermédiaire).
* **Respiration cyclique & shader** : Le post-process [film_1982_post.gdshader](file:///e:/JDR/BANLIEUE/game/shaders/film_1982_post.gdshader) reste actif avec une oscillation lente et continue entre la **gouache délavée du Jour**, la lueur **orange sodium du Crépuscule** et le **N&B argentique nocturne à 4 couleurs-signaux**, accompagnée d'une très légère dérive de caméra.
* **Ambiance sonore** : Un souffle FM discret et les tonalités d'[audio_radio.gd](file:///e:/JDR/BANLIEUE/game/scripts/autoload/audio_radio.gd) accompagnent l'écran selon les réglages enregistrés dans `user://settings.cfg`.

### Colonne de menu fanzine 1982

* **Implantation** : Panneau latéral gauche (~`380 px` de large), fond sombre encre/charbon, typographie crème et cartouche à **bordure rouge fanzine *Zone***.
* **En-tête** : Titre **`BANLIEUE`**, sous-titre **`Cradon-lès-Gonesse · 1980–1984`**, et indicateur diégétique discret en pied de colonne (ex. `[FM 92.4 · Radio Béton Libre]` ou fréquence active).

### États comparés du Menu Unifié

| Bouton | État à l'Accueil (`TITLE_MENU`) | État En Jeu (`PAUSE_MENU`) |
|---|---|---|
| **Reprendre** | *(Masqué)* | **Actif** — Referme le menu et rend la main à `IN_GAME`. |
| **Nouvelle partie** | **Actif** — Ouvre `NEW_GAME_SETUP`. | **Actif (avec confirmation)** — Avertit que la progression non sauvegardée sera perdue avant d'ouvrir `NEW_GAME_SETUP`. |
| **Charger une partie** | **Actif** si au moins 1 cassette est occupée ; **grisé/désactivé** si les 3 emplacements sont vierges. | **Actif** si au moins 1 cassette est occupée (confirmation si partie en cours non sauvegardée). |
| **Sauvegarder la partie** | **Visible mais grisé/désactivé**, avec infobulle *« Disponible en cours de partie »*. | **Actif** — Ouvre `SAVE_LOAD` en mode écriture sur les 3 cassettes. |
| **Options** | **Actif** — Ouvre la modale `OPTIONS`. | **Actif** — Ouvre la modale `OPTIONS`. |
| **Retour à l'accueil** | *(Masqué)* | **Actif (avec confirmation)** — Quitte la session en cours et revient à `TITLE_MENU`. |
| **Quitter** | **Actif** — Ferme l'application. | **Actif (avec confirmation)** — Ferme l'application après avertissement. |

---

## 3. Sauvegarde & Chargement *(3 Emplacements Manuels — Cassettes TDK 1982)*

### Règles de persistance

* **3 emplacements manuels stricts** : `Cassette A`, `Cassette B`, `Cassette C` enregistrés respectivement dans `user://saves/slot_1.json`, `user://saves/slot_2.json` et `user://saves/slot_3.json`.
* **Zéro auto-save** : Le joueur garde un contrôle total et explicite sur ses sauvegardes (aucune écriture automatique en arrière-plan).
* **Sécurités d'interaction** :
  * *Écrasement* : Sauvegarder sur une cassette déjà occupée demande une confirmation explicite (*« Enregistrer par-dessus Cassette A ? »*).
  * *Chargement* : En cours de partie (`PAUSE_MENU`), charger une cassette demande confirmation si la session active risque d'être remplacée.
  * *Effacement* : Un bouton `Effacer` discret sur chaque slot occupé permet de libérer la cassette après confirmation.

### Carte d'affichage d'un emplacement

Chaque cassette présente :
1. **Intitulé du slot** (`CASSETTE A / B / C`).
2. **Si occupé** :
   * **Portrait miniature + Prénom & Archétype** du Leader (ex. *« Sam · Les Mains-Noires »*) ;
   * **Lieu actuel** (ex. *« Chez Bébert — Vieux Bourg »*) ;
   * **Phase & Heure** (ex. *« JOUR · 17 h 45 »* ou *« NUIT · 22 h 10 »*) ;
   * **Bande & Francs** (ex. *« 3 membres · 35 F »*) ;
   * **Horodatage réel** de l'enregistrement (ex. *« 20/11/2026 · 23:18 »*).
3. **Si vierge** : Mention sobre `— Emplacement vierge —`.

### Schéma JSON cible (`user://saves/slot_N.json`)

```json
{
  "schema_version": 1,
  "saved_at": "2026-11-20T23:18:00",
  "meta": {
    "slot_label": "Cassette A",
    "leader_name": "Sam",
    "archetype_id": "mains_noires",
    "archetype_title": "Les Mains-Noires",
    "portrait_id": "player_03",
    "location_id": "chez_bebert",
    "location_name": "Chez Bébert",
    "phase": "day",
    "clock_text": "18 h 05",
    "squad_count": 3,
    "francs": 25
  },
  "leader_profile": {
    "name": "Sam",
    "archetype_id": "mains_noires",
    "portrait_id": "player_03",
    "portrait_path": "res://assets/portraits/player_03.png",
    "pawn_path": "res://assets/pawns/player_03_pawn.png"
  },
  "game_state": {
    "phase": "day",
    "clock_minutes": 1085,
    "francs": 25,
    "faveurs": 1,
    "notoriete": 1,
    "aura_bonus": 1,
    "flags": {},
    "clues": [],
    "activity_log": [],
    "squad_members": ["leader", "karim", "nadia"],
    "member_states": {},
    "member_progression": {},
    "active_group_id": 0,
    "current_station_idx": 0,
    "last_encounter_outcome": "",
    "current_zoom_level": 4,
    "current_region_id": "idf",
    "current_department_id": "dept_93",
    "current_city_id": "cradon_les_gonesse"
  }
}
```

---

## 4. Options (`user://settings.cfg`)

Tous les réglages sont persistés automatiquement dans `user://settings.cfg` via `ConfigFile` et appliqués en direct sans redémarrage :

| Catégorie | Paramètre | Valeurs / Plage | Cible technique |
|---|---|---|---|
| **Affichage** | Mode d'affichage | `Fenêtré` / `Plein écran` | `DisplayServer.window_set_mode(...)` |
| **Audio** | Volume général | `0 %` → `100 %` *(défaut `80 %`)* | `AudioRadio` / bus audio principal |
| **Audio** | Couper le son | `ON` / `OFF` *(synchro avec bouton `Son` du HUD)* | `AudioRadio` |
| **Audio** | Ambiance Radio FM | `ON` / `OFF` | Nappe FM / souffle 104.7 dans `AudioRadio` |
| **Rendu 1982** | Grain pellicule 16mm | `Désactivé` (`0.0`) / `Léger` (`0.02`) / `1982` (`0.042`) | Paramètre `grain_strength` de [film_1982_post.gdshader](file:///e:/JDR/BANLIEUE/game/shaders/film_1982_post.gdshader) |
| **Confort** | Secousse d'écran *(Boeing / Crise)* | `ON` / `OFF` | Multiplicateur sur `shake_amount` du shader |
| **Lisibilité** | Taille des textes de dialogue | `Normale` / `Grande` | `DialoguePanel` |

---

## 5. Écran « Nouvelle partie » — 4 Archétypes & Portraits Libres

### Maquette de l'écran en 2 colonnes

```text
┌──────────────────────────────────────────────────────────────────────────┐
│  NOUVELLE PARTIE — QUI MÈNE LA BANDE ?                                   │
├──────────────────────────────┬───────────────────────────────────────────┤
│  PRÉNOM / SURNOM             │  CHOISIS TON ARCHÉTYPE & TON HISTOIRE     │
│  [ ______________________ ]  │  [1. La Dalle]   [2. Le Bourg]            │
│                              │  [3. L'Atelier]  [4. Les Pavillons]       │
│  PORTRAIT & PION (libres)    │ ───────────────────────────────────────── │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐ │  TITRE DE L'ARCHÉTYPE                     │
│  │ P1 │ │ P2 │ │ P3 │ │ P4 │ │  Sous-titre social                        │
│  └────┘ └────┘ └────┘ └────┘ │                                           │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐ │  Esprit · Corps · Énergie                 │
│  │ P5 │ │ P6 │ │ P7 │ │ P8 │ │  Compétences & Failles (-3..+5)           │
│  └────┘ └────┘ └────┘ └────┘ │                                           │
│                              │  Attitude · Aura · Moral · Seuil Stress   │
│  [Aperçu grand portrait      │  Spécialité Frise : ...                   │
│   + aperçu pion en pied]     │  Atout de départ : ...                    │
├──────────────────────────────┴───────────────────────────────────────────┤
│  [ ◄ Retour Menu ]   Résumé : « Sam · Les Mains-Noires »  [ Lancer ► ]   │
└──────────────────────────────────────────────────────────────────────────┘
```

### Principe strict de découplage *(Apparence ↔ Histoire)*

* **Galerie de 6 à 8 portraits diversifiés** : Représentant différentes ethnies, cultures, genres et looks 1980–1984 (définis dans `game/data/player_profiles.json`), chacun accompagné de son **pion en pied assorti** (`526 px` RGBA détouré sans socle ni contour épais, compatible avec `pawn_outline.gdshader` et ombre portée 4h, produit via `banlieue-asset-artist`).
* **Neutralité absolue** :
  * Le choix du portrait est **100 % cosmétique et libre** : aucune statistique, aucun bonus caché et aucune étiquette ethnique ou culturelle n'est attachée aux portraits.
  * Chaque histoire personnelle des 4 archétypes repose **uniquement** sur le vécu social, familial et territorial à Cradon-lès-Gonesse, **sans jamais caractériser le protagoniste par son ethnie ou sa culture**.
* **Saisie d'identité** : Champ **Prénom / Surnom** libre (avec valeur par défaut suggérée ou éditable en un clic, ex. *« Alex »*, *« Sam »*, *« Camille »*).

### Les 4 Archétypes & Histoires Personnelles Validés

| ID & Titre | Histoire personnelle *(ancrage social pur)* | Profil & Gameplay |
|---|---|---|
| **`enfant_dalle`**<br>**L'Enfant de la Dalle**<br>*(Débrouillard·e du Parking)* | Tu as grandi entre les cages d'escalier de la Tour B et les boxes en sous-sol, clés autour du cou dès l'école primaire pendant que chez toi on enchaînait les horaires décalés. Tu connais chaque chaufferie, chaque interphone cassé et chaque combine de palier pour tenir jusqu'à la fin du mois sans rien devoir à la Concierge. | `Esprit 3 · Corps 3 · Énergie 4`<br>`Attitude 62 · Aura 3 · Moral 72` *(Seuil Stress `28`)*<br>**Compétences** : `caves_esquive +3`, `systeme_d +2`, `baston_pression -1`<br>**Spécialité Frise** : *Réflexe de rue* (`reflexe_rue` — retarde les patrouilles de +2 crans)<br>**Atout de départ** : `+10 F` (`35 F` au total), `flag: bg_dalle`. |
| **`grande_gueule`**<br>**La Grande Gueule du Bourg**<br>*(Habitué·e du Comptoir)* | Viré·e ou décrocheur·se du lycée/LEP, tu tiens tes quartiers entre le baby-foot de *Chez Bébert* et les flippers du *Galaxian*. Tout le Vieux Bourg connaît ta tchatche — et deux ou trois tauliers te doivent déjà une tournée ou un service pour un coup de main passé. | `Esprit 4 · Corps 2 · Énergie 3`<br>`Attitude 70 · Aura 3 · Moral 68` *(Seuil Stress `30`)*<br>**Compétences** : `tchatche +4`, `jeux_culture +2`, `mecanique_mob -2`<br>**Spécialité Frise** : *Baratin / Déconcentration* (`moquerie` — casse une intimidation, `-2 crans`)<br>**Atout de départ** : `+1 Faveur`, `flag: bg_bourg`. |
| **`mains_noires`**<br>**Les Mains-Noires**<br>*(Enfant de l'Atelier & de la Chaîne)* | Un proche gréviste à Citroën Aulnay ou cheminot sur le RER B, des dimanches entiers les mains dans le cambouis d'une 103 SP et d'un vieux poste à souder. Tu parles peu, tu ne recules pas quand ça pousse, et tu refuses que le fatalisme des licenciements décide de ton avenir. | `Esprit 2 · Corps 4 · Énergie 4`<br>`Attitude 60 · Aura 4 · Moral 74` *(Seuil Stress `26`)*<br>**Compétences** : `mecanique_mob +3`, `baston_pression +3`, `ondes_radio -2`<br>**Spécialité Frise** : *Menace / Interposition* (`interposition` — amortit le prochain coup moral)<br>**Atout de départ** : `+1 Aura` (`aura_bonus: 1`), `flag: bg_atelier`. |
| **`echappe_pavillons`**<br>**L'Échappé·e des Pavillons**<br>*(La Fissure du Lotissement)* | Tu viens du lotissement calme aux volets tirés dès 21 h — un foyer rangé qui vote bien, craint les tours et ne comprend rien à tes nuits au Box-Garage ni à tes cassettes pirates. Coincé·e entre couvre-feu domestique et envie d'air, tu connais de l'intérieur les petits arrangements des notables du *Relais Municipal*. | `Esprit 4 · Corps 2 · Énergie 3`<br>`Attitude 66 · Aura 2 · Moral 64` *(Seuil Stress `32`)*<br>**Compétences** : `sang_froid_nerfs +3`, `lecture_rue +3`, `baston_pression -2`<br>**Spécialité Frise** : *Sang-froid / Coup d'avance* (`sang_froid` — calme une Crise ou perce un bluff)<br>**Atout de départ** : `+15 F` (`40 F` au total), `flag: bg_pavillons`. |

### Lancement de la partie

Au clic sur **`Lancer la partie ►`** :
1. `GameState` réinitialise une nouvelle session (`reset_new_slice()`) et injecte le profil complet du Leader (prénom, portrait, pion en pied assorti, stats de l'archétype, spécialité Frise, bonus de départ et `flag` narratif).
2. Le joueur rejoint le **Box-Garage** en compagnie de **Karim & Nadia** pour ouvrir le niveau-pilote *« Couvre-Feu au Galaxian »* (les 4 autres compagnons du vivier restant recrutables au fil du jeu).
