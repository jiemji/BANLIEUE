# *Banlieue* — Architecture Technique

*Spécification technique de référence et socle du Jalon 0 — Phase Technique (🛠️ Léo).*

---

## 1. Stack Technique Validée

* **Architecture Spatiale Multi-Zoom (4 Niveaux)** :
  * **Niveaux 1, 2 & 3 *(Plans papier IGN / RATP 1982 en 2D)*** : pilotés par `WorldMapView` (`scripts/world/world_map_view.gd`) + `Camera2D` (zoom molette, panoramique clic droit, fil d'Ariane supérieur, `Retour arrière (Backspace)` / `M`, tandis qu'`Échap` ouvre le Menu Principal / Pause).
    * **N1 (`idf.json`)** : Île-de-France (8 départements ; seul le **93** est `playable`, les 7 autres sont `undescribed` avec `travel_hooks`).
    * **N2 (`departments/93.json`)** : Seine-Saint-Denis (axes RER B Nord en Y, RN2, Canal de l'Ourcq ; seule **Cradon-lès-Gonesse** est `playable` au départ, avec liaisons déjà modélisées vers Aulnay, La Courneuve, Drancy, Bobigny, etc.).
    * **N3 (`cities/cradon_les_gonesse.json`)** : Plan de Cradon-lès-Gonesse (4 secteurs colorés, 6 bâtiments cliquables, affichage temps réel des sous-groupes `G1/G2/G3` et des lignes de **Renfort**).
  * **Niveau 4 *(Intérieurs & Scènes de détail en 2D Isométrique `2:1`)*** : rendu hybride `backdrop` / `modular` (`render_mode`), **grilles rectangulaires `grid_w × grid_h` variables** (sans contrainte `8×8`, ex. *Le Galaxian* `12×8`, *Ruelle du Relais* `14×7`), `zones[]`, `blocked_cells[]`, `exits[]`, tri en profondeur `y_sort_enabled` + **masquage du décor au premier plan** (`IsoPropNode` en modulaire, `occluders[]` `Polygon2D`/RGBA sur `backdrop`, marqueurs `hotspots`/`exits` sur calque supérieur dédié), `Camera2D` avec suivi optionnel de bande (`follow_squad`), panoramique ZQSD/flèches/clic droit et zoom molette.
* **Moteur & Langage** : **Godot Engine 4** (`config_version=5`, renderer `GL Compatibility` pour compatibilité universelle 4.4–4.7 et démarrage immédiat sans dépendance lourde) + **GDScript 2.0**.
* **Architecture Data-Driven (Option C)** : Séparation stricte entre le code moteur (`scripts/`), les scènes (`scenes/`), les shaders (`shaders/`) et l'ensemble des données narratives et cartographiques modulaires au format **JSON** (`data/world/` + `data/maps/interiors/`). Permet d'étendre le 93, d'ajouter de nouvelles communes et d'injecter le futur **Chantier D (Scénario)** sans modifier le moteur.
* **Rendu DA & Son du Jalon 0 / Jalon 1** :
  * *Visuel* : Décors isométriques BD illustrés (`game/assets/locations/`) ou greybox vectoriel de secours + **sprites personnages en pied RGBA détourés sans socle (`526 px` paddés)** animés par `PawnActor` (`scripts/world/pawn_actor.gd`) avec **shader contour dynamique `2 px`** (`shaders/pawn_outline.gdshader` : crème repos, orange déplacement, jaune dialogue, bleu guet, rouge Stress) et **ombre silhouette projetée vers 4h (`+30°`)** prête pour des `lights` dynamiques + shader post-process `film_1982_post.gdshader` (grain 16mm, bascule Jour gouache délavée ↔ Nuit N&B argentique préservant sélectivement les **4 couleurs-signaux** : orange sodium, rouge fanzine, bleu électrique, halo pâle de la Poudrerie).
  * *Pipeline Assets capitalisé* : Agent dédié persistant [banlieue-asset-artist.md](file:///e:/JDR/BANLIEUE/.agents/agents/banlieue-asset-artist.md) + skill [SKILL.md](file:///e:/JDR/BANLIEUE/.agents/skills/banlieue-asset-pipeline/SKILL.md) + script `process_banlieue_assets.py`.
  * *Audio* : Synthèse procédurale légère en temps réel via `AudioStreamGenerator` (clic mécanique de touche cassette sur la Frise, coup sec d'Interruption hors-tour, grondement grave Boeing au Sas crépusculaire, souffle/zapping FM et impulsion basse Cold Wave nocturne), zéro fichier audio externe requis pour le Jalon 0.

---

## 2. Arborescence du Projet

Le projet Godot est isolé dans le sous-dossier `game/` afin que l'éditeur n'indexe ni les PDF volumineux de `Références/`, ni la documentation créative de `docs/`.

```text
BANLIEUE/
├── .agents/                             # Capitalisation locale : agent dédié & pipeline assets 2D
│   ├── agents/banlieue-asset-artist.md  # Agent DA/Assets 2D persistant (portraits, pions, décors)
│   └── skills/banlieue-asset-pipeline/  # Skill + script Python de détourage RGBA & validation Godot
├── docs/                                # Bible, chantiers créatifs et doc technique
├── Références/                          # Sources JDR Zone (hors indexation Godot)
└── game/                                # Racine du projet Godot 4 (ouvrir game/project.godot)
    ├── project.godot                    # Configuration Godot 4.4+ (GL Compatibility) & Autoloads
    ├── icon.svg                         # Icône du projet
    ├── assets/                          # Portraits BD (1024px), sprites en pied RGBA (526px), décors iso
    │   ├── portraits/                   # leader, karim, nadia, ludo, franck, concierge, so_agent...
    │   ├── pawns/                       # *_pawn.png (RGBA propre sans socle pour contour 2px + ombre 4h)
    │   └── locations/                   # Décors iso 1200x896 (box_garage, tour_b, chez_bebert, gare_rer_y...)
    ├── data/                            # Cœur Data-Driven 100 % JSON (atlas hiérarchique + systèmes)
    │   ├── characters.json              # Compagnons & PNJ (FAVE/FASA, Moral, Stress, Spécialités)
    │   ├── world/                       # Cartes N1–N3 style IGN / RATP 1982
    │   │   ├── idf.json                 # N1 : Île-de-France (seul le 93 playable)
    │   │   ├── departments/93.json      # N2 : Seine-Saint-Denis (seule Cradon playable)
    │   │   └── cities/cradon_les_gonesse.json # N3 : Secteurs, voiries & 6 lieux cliquables
    │   ├── maps/interiors/              # N4 : 1 JSON par intérieur à taille X×Y libre (backdrop/modular)
    │   │   ├── box_garage.json          # 8×8 (backdrop)
    │   │   ├── galaxian.json            # 12×8 (modular, 2 zones)
    │   │   ├── tour_b.json              # 8×8 (backdrop)
    │   │   ├── chez_bebert.json         # 8×8 (backdrop)
    │   │   ├── ruelle_relais.json       # 14×7 (modular, 2 zones)
    │   │   └── gare_rer_y.json          # 8×8 (backdrop)
    │   ├── dialogues.json               # Nœuds narratifs, conditions et effets (Francs/Faveurs/Flags/Recrutement)
    │   ├── timeline_encounters.json     # Rencontre Gare RER « du Y », ennemis, CRS, Train Fantôme & interruptions
    │   └── radio_fm.json                # 5 fréquences FM (92.4, 95.8, 98.6, 101.2, 104.7 nuit)
    ├── shaders/
    │   ├── film_1982_post.gdshader      # Grain argentique 16mm, bascule Jour/Nuit 4 couleurs-signaux, tremblement Sas
    │   └── pawn_outline.gdshader        # Contour dynamique 2 px par action du personnage
    ├── scenes/
    │   └── main.tscn                    # Scène racine minimaliste assemblée par main.gd
    └── scripts/
        ├── main.gd                      # Orchestrateur principal, transitions N1–N4 (Backspace/M), Menu (Échap) & Sas Jour→Nuit
        ├── autoload/                    # Singletons globaux (sans class_name)
        │   ├── data_loader.gd           # Chargement hiérarchique idf → 93 → ville → intérieurs & indexation
        │   ├── game_state.gd            # État vivant (zoom N1-N4, phase, horloge, économie, bande, Moral, flags)
        │   └── audio_radio.gd           # Synthèse procédurale (Frise, FM, Sas Boeing, Cold Wave, Mute)
        ├── systems/                     # Logique métier pure découplée des vues
        │   ├── squad_manager.gd         # Bande modulable (3 / 2+1 / 1+1+1), bascule à la volée, distance « Renfort »
        │   ├── tension_timeline.gd      # Frise chronologique, Interruptions hors-tour & préavis Crise d'autonomie
        │   └── dialogue_runner.gd       # Évaluation de conditions et exécution des effets sur GameState
        ├── world/
        │   ├── world_map_view.gd        # Vue cartes papier 2D N1–N3, Camera2D, pions bande & liens Renfort
        │   ├── iso_district_view.gd     # Vue isométrique N4 hybride (backdrop/modular), tailles X×Y, occluders, Camera2D
        │   ├── iso_prop_node.gd         # Props 3D triés en Y-sort dans _pawn_container en mode modulaire
        │   └── pawn_actor.gd            # Nœud pion : shader contour 2px, ombre silhouette 4h (+ lights), cartel
        └── ui/
            ├── hud_overlay.gd           # Bandeau 1982, fil d'Ariane N1-N4, switcher 1/2/3 & Tuner Radio FM
            ├── dialogue_panel.gd        # Boîte de dialogue BD/fanzine avec portraits et choix annotés
            └── timeline_panel.gd        # Vue « planche-contact / bande magnétique » de la Frise de Tension
```

---

## 3. Systèmes Cœurs & Flux de Données

### Autoloads *(Singletons sans `class_name`)*
1. **`DataLoader`** : Charge la hiérarchie modulaire (`data/world/idf.json` → `departments/*.json` → `cities/*.json` → `maps/interiors/*.json`) ainsi que les personnages, dialogues, rencontres et stations FM, et expose les accesseurs typés (`get_region`, `get_department`, `get_city`, `get_interior`, `get_location`, `get_character`, `get_dialogue`, `get_encounter`).
2. **`GameState`** : Source unique de vérité pour l'état de la partie (`current_zoom_level` `1..4`, `current_region_id`, `current_department_id`, `current_city_id`, `phase` `"day" | "twilight" | "night"`, `clock_minutes`, `francs`, `faveurs`, `notoriete`, `fasa_bonus`, `flags`, `clues`, `squad_members`, `member_states`, `active_group_id`, `current_station_idx`) ; émet des signaux découplés (`state_changed`, `phase_changed`, `active_group_changed`, `zoom_changed`, `log_added`).
3. **`AudioRadio`** : Synthétiseur procédural alimenté par `GameState` (tonalité adaptée au changement de phase Jour/Sas/Nuit et au zapping des 5 fréquences FM, avec bascule Mute).

### Systèmes Métiers (`scripts/systems/`)
* **`SquadManager`** : Pilote la bande modulable (`3+`, `2+1`, `1+1+1`), la **bascule libre à la volée** entre sous-groupes (`switch_to_group`), les consignes d'attente (`Guetter`, `Bricoler`, `Attendre`), les déplacements inter-lieux et le calcul de proximité (`compute_reinforcement_ticks`) permettant d'insérer les potes proches comme **« Renfort dans X crans »** sur une Frise nocturne.
* **`TensionTimeline`** : Orchestre la **Frise chronologique de Tension** en crans triés : annonces des intentions adverses à l'avance, **1 Réaction d'Interruption hors-tour** par personnage et par cycle (rechargée au tour normal), contre-interruptions des adversaires vétérans, **préavis diégétique de Crise d'autonomie** à `+2 crans` dès que le **Moral** atteint le seuil de Stress (offrant l'option `Retenir` avant explosion), compte à rebours des CRS et arrivée du **Train Fantôme RER B**.
* **`DialogueRunner`** : Interprète les nœuds de `dialogues.json`, vérifie les prérequis (`min_francs`, `require_member`, `require_flag`, `min_fasa`) et applique leurs effets sur `GameState` puis notifie les vues via signaux.

### Flux de Données & Navigation
```text
[data/world/* + data/maps/interiors/* + data/*.json] ──► (DataLoader) ──► [Systèmes Métiers] ◄──► (GameState)
                                                                                 │                       │
                                                                         Signaux découplés        Signaux zoom/état
                                                                                 ▼                       ▼
                                                  [WorldMapView (N1-N3) / IsoDistrictView (N4) / UI] + (AudioRadio & Shader)
```

**Contrôles de navigation multi-zoom** :
* **Fil d'Ariane (`IDF › 93 › Cradon › Intérieur`) & bouton `▲`** en haut de l'écran, ou bouton **`Plan de Cradon (N3) [M]`**.
* **Clavier** : `Échap` ouvre ou ferme le Menu Principal / Pause (et ferme d'abord la modale active), `Retour arrière (Backspace)` remonte d'un niveau cartographique (`N4 → N3 → N2 → N1`), `M` bascule entre l'intérieur actif (`N4`) et le plan de ville (`N3`), `ZQSD` / flèches pour déplacer la caméra en Niveau 4.
* **Souris** : clic gauche sur un nœud `playable` / bâtiment pour zoomer/entrer (ou sur une dalle `exits[]` pour sortir au N3), **molette** pour zoomer/dézoomer (en N2/N3, un dézoom répété au plancher remonte d'un niveau), **clic droit maintenu** pour faire glisser la carte.

---

## 4. Plan du Premier Prototype Jouable (Jalon 0 — *« Couvre-Feu au Galaxian »*)

### Séquences livrées et testables dès le Jalon 0
1. **Box-Garage de la Cité *(Jour)*** : Accueil du trio de départ (**Leader, Karim, Nadia**), briefing, choix d'équipement (blouson *FASA +1* ou bricole *103 SP*) et test du tuner **5 stations FM**.
2. **Le Galaxian *(Jour)*** : Découverte de l'avis de fermeture du S.O., discussion avec **Ludo** et déblocage des 3 pistes de ville.
3. **Enquête scindée en bascule libre (`1/2/3`)** : Répartition entre **Tour B** (ruse électrique de Nadia face à la loge de la Concierge), **Chez Bébert** (négociation de Faveur avec **Franck** et coup de chaud sur le Moral de Karim) et **Ruelle du Relais Municipal** (dilemme familial de **Ludo** avec son cousin S.O.).
4. **Sas Sensoriel Crépusculaire** : Transition physique Jour → Nuit déclenchée par le crépuscule (grondement Boeing, secousse de cadre, passage au rendu N&B + 4 couleurs-signaux et basse Cold Wave).
5. **Frise Chronologique Nocturne — Gare RER « du Y »** : Confrontation sur le quai contre Skin nerveux, cousin S.O. et S.O. vétéran, gestion des **Interruptions hors-tour**, préavis et arbitrage de la **Crise d'autonomie de Karim**, arrivée des CRS et apparition du **Train Fantôme du RER B**.
6. **Retour au Box-Garage & Bilan** : Résolution humaine de la crise, choix d'ouvrir ou non la porte à **Ludo** (recrutement), bref signal sur la **104.7 FM** et récapitulatif du Jalon 0.

### Structure des Menus, Persistance & Création de Partie *(prévu pour l'implémentation suivante)*
Conformément à la spécification validée dans [structure_menus_et_ecrans.md](file:///e:/JDR/BANLIEUE/docs/structure_menus_et_ecrans.md), la couche accueil, sauvegarde, options et sélection du protagoniste s'appuiera sur les modules suivants :
* **Données & Assets** : `data/player_profiles.json` (4 archétypes sociaux + galerie libre de **6 à 8 portraits** multi-ethnies/cultures avec **pions en pied assortis** en `526 px` RGBA produits via `banlieue-asset-artist`).
* **Persistance *(Autoloads)*** : `scripts/autoload/save_manager.gd` (3 emplacements manuels `user://saves/slot_1.json`..`slot_3.json`, zéro auto-save) et `scripts/autoload/settings_manager.gd` (`user://settings.cfg` pour affichage, audio/FM, grain 16mm, secousse écran et taille de texte).
* **Écrans UI** : `scripts/ui/title_menu_panel.gd` (menu unifié Accueil/Pause sur fond vivant du Box-Garage), `scripts/ui/save_load_panel.gd`, `scripts/ui/options_panel.gd` et `scripts/ui/new_game_panel.gd`.

### Jalons ultérieurs
* **Jalon 1 *(Production Visuelle & Audio)*** : Remplacement progressif du greybox isométrique par tuiles peintes/encrées, portraits BD expressifs et vrais stems musicaux Cold Wave / FM.
* **Jalon 2 *(Chantier D — Campagne Complète)*** : Ouverture du **Chantier D** dans `docs/` pour injecter le scénario principal, les 4 autres compagnons recrutables et les 4 fins directement via de nouveaux fichiers JSON sans refondre le moteur.
