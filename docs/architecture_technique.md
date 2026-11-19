# *Banlieue* — Architecture Technique

*Spécification technique de référence et socle du Jalon 0 — Phase Technique (🛠️ Léo).*

---

## 1. Stack Technique Validée

* **Perspective & Caméra** : **2D Isométrique / Vue 3/4 de dessus** (projection losange `2:1`, tri en profondeur `y_sort_enabled`, déplacements fluides sur grille logique et zones cliquables par secteur).
* **Moteur & Langage** : **Godot Engine 4** (`config_version=5`, renderer `GL Compatibility` pour compatibilité universelle 4.4–4.7 et démarrage immédiat sans dépendance lourde) + **GDScript 2.0**.
* **Architecture Data-Driven (Option C)** : Séparation stricte entre le code moteur (`scripts/`), les scènes (`scenes/`), les shaders (`shaders/`) et l'ensemble des données narratives et systémiques au format **JSON** (`data/`). Permet de brancher le futur **Chantier D (Scénario)** et de nouveaux quartiers/dialogues/rencontres sans modifier la logique du moteur.
* **Rendu DA & Son du Jalon 0** :
  * *Visuel* : Greybox isométrique vectoriel/procédural au trait BD encré + shader post-process `film_1982_post.gdshader` (grain 16mm, bascule Jour gouache délavée ↔ Nuit N&B argentique préservant sélectivement les **4 couleurs-signaux** : orange sodium, rouge fanzine, bleu électrique, halo pâle de la Poudrerie).
  * *Audio* : Synthèse procédurale légère en temps réel via `AudioStreamGenerator` (clic mécanique de touche cassette sur la Frise, coup sec d'Interruption hors-tour, grondement grave Boeing au Sas crépusculaire, souffle/zapping FM et impulsion basse Cold Wave nocturne), zéro fichier audio externe requis pour le Jalon 0.

---

## 2. Arborescence du Projet

Le projet Godot est isolé dans le sous-dossier `game/` afin que l'éditeur n'indexe ni les PDF volumineux de `Références/`, ni la documentation créative de `docs/`.

```text
BANLIEUE/
├── docs/                                # Bible, chantiers créatifs et doc technique
├── Références/                          # Sources JDR Zone (hors indexation Godot)
└── game/                                # Racine du projet Godot 4 (ouvrir game/project.godot)
    ├── project.godot                    # Configuration Godot 4.4+ (GL Compatibility) & Autoloads
    ├── icon.svg                         # Icône du projet
    ├── data/                            # Cœur Data-Driven 100 % JSON
    │   ├── characters.json              # Leader, Karim, Nadia, Ludo, Franck (FAVE/FASA, Moral, Stress, Spécialités)
    │   ├── locations.json               # 6 lieux isométriques, décors, hotspots et graphe de voisinage
    │   ├── dialogues.json               # Nœuds narratifs, conditions et effets (Francs/Faveurs/Flags/Recrutement)
    │   ├── timeline_encounters.json     # Rencontre Gare RER « du Y », ennemis, CRS, Train Fantôme & interruptions
    │   └── radio_fm.json                # 5 fréquences FM (92.4, 95.8, 98.6, 101.2, 104.7 nuit)
    ├── shaders/
    │   └── film_1982_post.gdshader      # Grain argentique 16mm, bascule Jour/Nuit 4 couleurs-signaux, tremblement Sas
    ├── scenes/
    │   └── main.tscn                    # Scène racine minimaliste assemblée par main.gd
    └── scripts/
        ├── main.gd                      # Orchestrateur principal, transitions Jour/Sas/Nuit & écran bilan
        ├── autoload/                    # Singletons globaux (sans class_name)
        │   ├── data_loader.gd           # Chargement et indexation des 5 JSON
        │   ├── game_state.gd            # État vivant (phase, horloge, économie, bande, Moral, flags)
        │   └── audio_radio.gd           # Synthèse procédurale (Frise, FM, Sas Boeing, Cold Wave, Mute)
        ├── systems/                     # Logique métier pure découplée des vues
        │   ├── squad_manager.gd         # Bande modulable (3 / 2+1 / 1+1+1), bascule à la volée, distance « Renfort »
        │   ├── tension_timeline.gd      # Frise chronologique, Interruptions hors-tour & préavis Crise d'autonomie
        │   └── dialogue_runner.gd       # Évaluation de conditions et exécution des effets sur GameState
        ├── world/
        │   └── iso_district_view.gd     # Rendu vectoriel isométrique 2:1, pions, Train Fantôme & « petits détails qui clochent »
        └── ui/
            ├── hud_overlay.gd           # Bandeau 1982, switcher 1/2/3, carte des 6 lieux & Tuner Radio FM
            ├── dialogue_panel.gd        # Boîte de dialogue BD/fanzine et choix annotés
            └── timeline_panel.gd        # Vue « planche-contact / bande magnétique » de la Frise de Tension
```

---

## 3. Systèmes Cœurs & Flux de Données

### Autoloads *(Singletons sans `class_name`)*
1. **`DataLoader`** : Charge au démarrage les 5 fichiers JSON de `res://data/` et expose des accesseurs typés (`get_character`, `get_location`, `get_dialogue`, `get_encounter`).
2. **`GameState`** : Source unique de vérité pour l'état de la partie (`phase` `"day" | "twilight" | "night"`, `clock_minutes`, `francs`, `faveurs`, `notoriete`, `fasa_bonus`, `flags`, `clues`, `squad_members`, `member_states`, `active_group_id`, `current_station_idx`) ; émet des signaux découplés (`state_changed`, `phase_changed`, `active_group_changed`, `log_added`).
3. **`AudioRadio`** : Synthétiseur procédural alimenté par `GameState` (tonalité adaptée au changement de phase Jour/Sas/Nuit et au zapping des 5 fréquences FM, avec bascule Mute).

### Systèmes Métiers (`scripts/systems/`)
* **`SquadManager`** : Pilote la bande modulable (`3+`, `2+1`, `1+1+1`), la **bascule libre à la volée** entre sous-groupes (`switch_to_group`), les consignes d'attente (`Guetter`, `Bricoler`, `Attendre`), les déplacements inter-lieux et le calcul de proximité (`compute_reinforcement_ticks`) permettant d'insérer les potes proches comme **« Renfort dans X crans »** sur une Frise nocturne.
* **`TensionTimeline`** : Orchestre la **Frise chronologique de Tension** en crans triés : annonces des intentions adverses à l'avance, **1 Réaction d'Interruption hors-tour** par personnage et par cycle (rechargée au tour normal), contre-interruptions des adversaires vétérans, **préavis diégétique de Crise d'autonomie** à `+2 crans` dès que le **Moral** atteint le seuil de Stress (offrant l'option `Retenir` avant explosion), compte à rebours des CRS et arrivée du **Train Fantôme RER B**.
* **`DialogueRunner`** : Interprète les nœuds de `dialogues.json`, vérifie les prérequis (`min_francs`, `require_member`, `require_flag`, `min_fasa`) et applique leurs effets sur `GameState` puis notifie les vues via signaux.

### Flux de Données
```text
[data/*.json] ──► (DataLoader) ──► [SquadManager / TensionTimeline / DialogueRunner] ◄──► (GameState)
                                                    │                                          │
                                        Signaux découplés                               Signaux d'état
                                                    ▼                                          ▼
                            [IsoDistrictView / DialoguePanel / TimelinePanel / HudOverlay] + (AudioRadio & Shader)
```

---

## 4. Plan du Premier Prototype Jouable (Jalon 0 — *« Couvre-Feu au Galaxian »*)

### Séquences livrées et testables dès le Jalon 0
1. **Box-Garage de la Cité *(Jour)*** : Accueil du trio de départ (**Leader, Karim, Nadia**), briefing, choix d'équipement (blouson *FASA +1* ou bricole *103 SP*) et test du tuner **5 stations FM**.
2. **Le Galaxian *(Jour)*** : Découverte de l'avis de fermeture du S.O., discussion avec **Ludo** et déblocage des 3 pistes de ville.
3. **Enquête scindée en bascule libre (`1/2/3`)** : Répartition entre **Tour B** (ruse électrique de Nadia face à la loge de la Concierge), **Chez Bébert** (négociation de Faveur avec **Franck** et coup de chaud sur le Moral de Karim) et **Ruelle du Relais Municipal** (dilemme familial de **Ludo** avec son cousin S.O.).
4. **Sas Sensoriel Crépusculaire** : Transition physique Jour → Nuit déclenchée par le crépuscule (grondement Boeing, secousse de cadre, passage au rendu N&B + 4 couleurs-signaux et basse Cold Wave).
5. **Frise Chronologique Nocturne — Gare RER « du Y »** : Confrontation sur le quai contre Skin nerveux, cousin S.O. et S.O. vétéran, gestion des **Interruptions hors-tour**, préavis et arbitrage de la **Crise d'autonomie de Karim**, arrivée des CRS et apparition du **Train Fantôme du RER B**.
6. **Retour au Box-Garage & Bilan** : Résolution humaine de la crise, choix d'ouvrir ou non la porte à **Ludo** (recrutement), bref signal sur la **104.7 FM** et récapitulatif du Jalon 0.

### Jalons ultérieurs
* **Jalon 1 *(Production Visuelle & Audio)*** : Remplacement progressif du greybox isométrique par tuiles peintes/encrées, portraits BD expressifs et vrais stems musicaux Cold Wave / FM.
* **Jalon 2 *(Chantier D — Campagne Complète)*** : Ouverture du **Chantier D** dans `docs/` pour injecter le scénario principal, les 4 autres compagnons recrutables et les 4 fins directement via de nouveaux fichiers JSON sans refondre le moteur.
