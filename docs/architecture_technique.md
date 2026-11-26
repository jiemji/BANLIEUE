# *Banlieue* — Architecture Technique Modulaire

> **Version courante : 0.10.0** — Mise à jour : 2026-11-26

*Spécification technique de référence : Cœur générique 100 % découplé, Packs de Scénarios isolés (Option 1B), Moteur d'effets déclaratifs JSON + Hooks scriptés (Option 2A), Continuité Hybride par Import de Cassette (Option 3A) et Plateau Tactique `8×8` à Couverts & Interactifs.*

---

## 1. Principes Directeurs & Stack Validée

* **Moteur & Langage** : **Godot Engine 4** (`config_version=5`, renderer `GL Compatibility` 4.4–4.7) + **GDScript 2.0** typé strict.
* **Zéro identifiant métier en dur dans `game/scripts/`** : Le cœur du jeu ne connaît aucun nom de scénario, de commune, d'intérieur, de personnage, d'objet, d'action ni de spécialité spécifique. Le validateur (`process_banlieue_assets.py --mode validate`) vérifie automatiquement l'absence d'identifiants scénaristiques en dur dans tous les scripts `.gd` du moteur.
* **Option 1B — Packs de Scénarios 100 % isolés (`game/data/scenarios/<scenario_id>/`)** :
  * Chaque scénario possède son propre dossier autonome contenant son manifeste `scenario.json`, ses règles (`rules/`), ses personnages et profils (`characters/`), ses équipements (`equipment/`), ses dialogues (`dialogues/`), ses rencontres tactiques (`encounters/`), sa bande FM (`radio_fm.json`), son atlas cartographique N1–N3 (`world/`) et ses intérieurs N4 (`maps/interiors/`), ainsi qu'éventuellement ses propres assets ou scripts locaux.
  * `DataLoader.discover_scenarios()` détecte automatiquement tout dossier contenant un `scenario.json` (ordonné optionnellement via `data/scenarios_index.json`), en ignorant les dossiers gabarits préfixés par `_` ou `.` (tel `_template_scenario/`).
* **Option 2A — Combat Tactique `8×8`, Briques JSON + Hooks `custom_script`** :
  * `TensionTimeline` gère les déplacements (`PM 2–3`), portées (`1c / 2–4c / 2–6c`), Charges symétriques avec fenêtre temps réel `10 s`, **couverts/obstacles (`cover_tiles[]`)**, **éléments interactifs du décor (`combat_interactables[]`)** et exécute/prévisualise les briques d'effets déclaratives (`damage_resolve`, `push_ticks`, `cut_counter`, `set_counter_ready`, `modify_escalation_clock`, `advance_escape`, `add_shield`, `modify_moral`, `delay_crises`, `cancel_crisis`, `advance_turn_counter`, `modify_notoriete`, `set_flag`).
  * Tout bloc (rencontre, action, spécialité, crise, ennemi) peut déclarer `"custom_script": "scripts/mon_hook.gd"` (chemin relatif au pack ou `res://`) pour brancher un comportement boss/atypique sans modifier le cœur.
* **Option 3A — Continuité Hybride (Bande neuve OU Import de Cassette A/B/C)** :
  * L'écran `NewGamePanel` permet de choisir le **Scénario** à lancer ainsi que le **Mode de départ** : **Bande neuve** (archétype et casting définis par le pack) ou **Import d'une Cassette sauvegardée** (`SaveManager.read_slot_full`), qui transfère l'identité, l'XP, les compétences, les traits et l'équipement compatibles du Leader, les Francs/Faveurs/Notoriété acquis, le coffre compatible et les compagnons déjà recrutés présents dans le nouveau scénario.
* **Rendu DA & Son 1980–1984** :
  * **Atlas Spatial Multi-Zoom N1–N4** : Plans papier IGN/RATP 1982 aux niveaux N1–N3 (`WorldMapView`) + scènes intérieures isométriques `2:1` hybrides `backdrop` / `modular` au niveau N4 (`IsoDistrictView` + `IsoPropNode` piloté par `rules/props_catalog.json`, `occluders[]`, `ambient_fx[]` et `diegetic_signs[]`).
  * **Pions modulaires 3 parties (`256×526` RGBA)** : Assemblage temps réel en 4 passes (`heads` + `tops` + `bottoms`) mis en cache par `DataLoader.assemble_modular_pawn()` pour tous les PJ et PNJ, couplé au shader de contour `2 px` et à l'ombre portée `4h` (`PawnActor`), tandis que les portraits BD `1024×1024` restent utilisés dans le HUD, la Frise, les dialogues et les fiches.
  * **Audio procédural** : `AudioRadio` (`AudioStreamGenerator`) pilote les SFX cassette/interruption/alerte Charge 10 s, le grondement du Sas, la basse Cold Wave nocturne et le souffle FM déclaratif (`white_noise_ambience` dans `radio_fm.json`).

---

## 2. Arborescence Modulaire du Projet

```text
BANLIEUE/
├── .agents/                             # Agents dédiés & pipeline assets/validation Python
│   ├── agents/                          # banlieue-asset-artist.md & banlieue-combat-ux.md
│   └── skills/banlieue-asset-pipeline/  # SKILL.md + scripts/process_banlieue_assets.py (détourage, découpe 3 parties & validate multi-packs)
├── docs/                                # Bible créative, UX combat, fiches PJ et architecture technique
├── Références/                          # Sources documentaires (hors indexation Godot)
└── game/                                # Racine du projet Godot 4
    ├── project.godot                    # Configuration GL Compatibility & Autoloads
    ├── assets/                          # Bibliothèque graphique partagée (portraits, modular/{heads,tops,bottoms}, locations, maps)
    ├── data/
    │   ├── scenarios_index.json         # Ordre d'affichage optionnel & scénario par défaut
    │   └── scenarios/                   # Packs de scénarios 100 % isolés (Option 1B)
    │       ├── couvre_feu_galaxian/     # Scénario principal : « Couvre-Feu au Galaxian » (11 intérieurs Cradon+Aulnay, 11 persos, 52 équipements)
    │       │   ├── scenario.json        # Manifeste : départ, phases/sas, modificateurs de trajet, fins multiples
    │       │   ├── rules/               # skills.json, combat_actions.json, specialties.json, props_catalog.json
    │       │   ├── characters/          # characters.json (avec blocs crisis) & player_profiles.json (8 profils)
    │       │   ├── equipment/           # equipment.json (4 slots + actions ★ dont inline combat_action)
    │       │   ├── dialogues/           # dialogues.json (arbre narratif, conditions & Jets de rue 2d6)
    │       │   ├── encounters/          # timeline_encounters.json (cover_tiles, combat_interactables, horloge, échappée, outcomes)
    │       │   ├── radio_fm.json        # Stations FM du scénario (dont white_noise_ambience)
    │       │   ├── world/               # idf.json, departments/*.json, cities/*.json
    │       │   └── maps/interiors/      # 1 fichier JSON par décor intérieur N4
    │       ├── ronde_du_canal/          # 2e pack autonome : « Ronde de Nuit sur l'Ourcq » (4 intérieurs, map_ourcq.png, scripts/ponton_hook.gd)
    │       ├── greve_citroen_aulnay/    # 3e pack autonome : « Ondes Libres à Citroën Aulnay » (4 intérieurs, map_aulnay.png, scripts/aulnay_hook.gd)
    │       └── _template_scenario/      # Gabarit prêt à dupliquer (ignoré dans le sélecteur en jeu sur préfixe _)
    ├── shaders/                         # film_1982_post.gdshader & pawn_outline.gdshader
    ├── scenes/main.tscn                 # Scène racine minimaliste
    └── scripts/                         # Cœur moteur 100 % générique (zéro ID métier en dur)
        ├── main.gd                      # Orchestrateur piloté par scenario.json et outcomes de rencontres
        ├── autoload/                    # data_loader.gd, settings_manager.gd, game_state.gd, audio_radio.gd, save_manager.gd
        ├── systems/                     # squad_manager.gd, tension_timeline.gd, dialogue_runner.gd
        ├── world/                       # world_map_view.gd, iso_district_view.gd, iso_prop_node.gd, pawn_actor.gd
        └── ui/                          # hud_overlay, dialogue_panel, timeline_panel, character_sheet_panel, title_menu_panel, new_game_panel, save_load_panel, options_panel
```

---

## 3. Guide d'Extension Sans Modifier le Cœur (`.gd`)

> **Manuel détaillé & modèle prêt à copier** : voir [guide\_modding.md](file:///e:/JDR/BANLIEUE/docs/guide_modding.md) et le gabarit autonome [\_template\_scenario](file:///e:/JDR/BANLIEUE/game/data/scenarios/_template_scenario/scenario.json) (ignoré automatiquement dans le sélecteur en jeu tant que son dossier commence par `_`, tout en étant vérifié par `--mode validate`).

1. **Ajouter un nouveau Scénario complet** :
   * Dupliquer un dossier sous `game/data/scenarios/<mon_scenario>/` et ajuster `scenario.json` (`id`, `title`, `subtitle`, `start_hierarchy`, `start_state`, `intro_dialogue_id`, `phase_transitions`, `endings`). Aucun enregistrement dans le code n'est nécessaire : `DataLoader.discover_scenarios()` l'affiche automatiquement dans `NewGamePanel` (et gère l'import optionnel d'une Cassette A/B/C).
2. **Ajouter un Personnage (Compagnon ou PNJ)** :
   * Ajouter sa fiche dans `characters/characters.json` (ou un fichier dédié `characters/<nom>.json` — tous les `.json` du sous-dossier sont fusionnés automatiquement) avec son `portrait`, son `appearance` (`head`, `default_top`, `default_bottom` en `256×526` RGBA), son `specialty_id` et son bloc déclaratif `crisis`. Pour le placer dans un décor N4, l'ajouter au tableau `npcs[]` du lieu avec `phase`, `require_flag` / `hide_if_flag` / `hide_if_in_squad` et `dialogue_id`.
3. **Ajouter un Décor N4 ou une Commune N2/N3** :
   * Créer `maps/interiors/<lieu>.json` (`render_mode: "backdrop"` avec `occluders[]`, ou `"modular"` utilisant les types de `rules/props_catalog.json`), puis référencer ce fichier dans `children[]` de la ville N3 (avec `completed_if_flag` optionnel). Un nœud `"status": "locked"` peut être ouvert en jeu via l'effet dialogue `"unlock_location": "<id>"`.
4. **Ajouter un Équipement, une Action de Combat ou une Spécialité** :
   * Déclarer l'objet dans `equipment/*.json` (`look_top`, `look_bottom`, `tool` ou `fetish`). S'il débloque une action active `★`, définir ses briques d'effets dans `rules/combat_actions.json` ou directement en ligne via `"combat_action": { ... }` dans `unlocks_actions[]`.
   * Déclarer toute nouvelle spécialité hors-tour dans `rules/specialties.json` (`intercept_skills` + `modes[]`).

---

## 4. Validation Automatisée & Tests Headless

```powershell
python "e:\JDR\BANLIEUE\.agents\skills\banlieue-asset-pipeline\scripts\process_banlieue_assets.py" --mode validate --game-root "e:\JDR\BANLIEUE\game"
g:\Programmes\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path "e:\JDR\BANLIEUE\game" --script "C:\Users\jmjou\.gemini\antigravity\brain\23b0f781-d36a-455c-bc8a-bdd20bfd22a8\scratch\smoke_test_menus.gd"
```
