# Analyse Technique de la Codebase — *Banlieue*

> **Version courante : 0.10.0** — Mise à jour : 2026-11-26

---

## 1. Fiche d'Identité
* **Racine Godot** : `e:\JDR\BANLIEUE\game\project.godot` (`config_version=5`, renderer `GL Compatibility`, viewport `1280×720` `canvas_items/expand`)
* **Langage** : GDScript 2.0 (typé explicitement) + GLSL ES (`film_1982_post.gdshader`, `pawn_outline.gdshader`) + JSON Data-Driven
* **Outillage qualité** : [process\_banlieue\_assets.py](file:///e:/JDR/BANLIEUE/.agents/skills/banlieue-asset-pipeline/scripts/process_banlieue_assets.py) (détourage, découpe 3 parties & validation multi-packs)

---

## 2. Diagramme des Flux & Machine d'États

```text
          [ game/data/scenarios_index.json + data/scenarios/<id>/ ]
          (scenario.json, rules/*, world/*, maps/*, characters/*,
           equipment/*, dialogues/*, encounters/*, radio_fm.json, scripts/*.gd)
                               │
                               ▼
                         (DataLoader) ◄── game/assets/modular/{heads,tops,bottoms}/
                               │           (assemblage ImageTexture 256x526 en cache)
      (SettingsManager) ──────►┼──────► (SaveManager) ◄──► user://saves/slot_1..3.json
             │                 ▼                           (Cassettes + Import Option 3A)
             │            (GameState)
             │                 │ signaux (state_changed, phase_changed, zoom_changed, ...)
             ▼                 ▼
       (AudioRadio)      [ main.gd : AppState ]
                     TITLE_MENU ⇄ NEW_GAME_SETUP ⇄ IN_GAME ⇄ PAUSE_MENU
                               │
            ┌──────────────────┼──────────────────┐
            ▼                  ▼                  ▼
     [WorldMapView N1-3] [IsoDistrictView N4] [UI Layers 10 & 20]
                                              (HUD, Dialogue, Frise 8x8,
                                               Title/Pause, NewGame,
                                               SaveLoad, Options)
```

---

## 3. Inventaire des 24 Scripts GDScript (`game/scripts/` + Hooks de Packs)

| Couche | Script | Rôle principal |
|---|---|---|
| **Orchestrateur** | `main.gd` | Machine d'états `AppState`, titre dynamique `scenario.json`, Sas & fins pilotés par JSON, raccourcis `Échap`/`F`/`Backspace`/`M`/`1-9`, pause auto chrono 10 s |
| **Autoload** | `autoload/data_loader.gd` | Découverte multi-packs (`discover_scenarios()` filtrant `_`/` .`), chargement isolé par scénario, actions `★` inline sur équipement, `assemble_modular_pawn()` (`256×526`) |
| **Autoload** | `autoload/settings_manager.gd` | Chargement/sauvegarde `user://settings.cfg`, affichage, audio, grain, secousse, police |
| **Autoload** | `autoload/game_state.gd` | État vivant, `start_scenario_session()` + Import Cassette `import_from_cassette_dict()`, `member_progression` (4 slots), `box_stash`, Jets `2d6` |
| **Autoload** | `autoload/audio_radio.gd` | Synthèse temps réel (`AudioStreamGenerator`) SFX Charge/clics + Cold Wave + stations `radio_fm.json` (`white_noise_ambience`) |
| **Autoload** | `autoload/save_manager.gd` | 3 cassettes manuelles (`slot_1..3.json`) avec `scenario_id` + bascule automatique de pack au rechargement |
| **Système** | `systems/squad_manager.gd` | Formation (`3+` / `2+1` / `1+1+1`), bascule à la volée, distances & renforts via `DataLoader.get_location()` |
| **Système** | `systems/tension_timeline.gd` | Grille `8×8`, déplacement BFS (`PM 2–3`), portées (`1c / 2–4c / 2–6c`), Charge `10 s`, **couverts (`cover_tiles`)**, **interactifs (`combat_interactables`)**, 13 briques JSON + `custom_script` |
| **Système** | `systems/dialogue_runner.gd` | Évaluation prérequis (`min_skill`, `require_item`, `require_action`), résolution `skill_check`, effets (`add_xp`, `grant_item`, `unlock_location`, `trigger_ending`) |
| **Monde** | `world/world_map_view.gd` | Cartes papier 2D N1–N3 (`Camera2D`, zoom, survol, marqueurs depuis `scenario.json`) |
| **Monde** | `world/iso_district_view.gd` | Vue isométrique 2:1 N4 (`backdrop`/`modular`), plateau combat `8×8` (cases bleues PM, couronnes portée, couverts `🛡`, interactifs `⚙`, flèche Charge) |
| **Monde** | `world/iso_prop_node.gd` | Props isométriques triés par Y-sort pilotés par `rules/props_catalog.json` |
| **Monde** | `world/pawn_actor.gd` | Pion RGBA `256×526` (contour 2 px sans couture, ombre 4h) & surbrillance combat |
| **UI Jeu** | `ui/hud_overlay.gd` | Bandeau 1982 (`Fiches [F]`), fil d'Ariane N1–N4, bouton `Menu`, gestion bande, tuner FM, pistes |
| **UI Jeu** | `ui/dialogue_panel.gd` | Boîte de dialogue BD avec portrait `1024 px`, choix, badges `🎲 %` / `⚠ FAILLE`, bandeau `_roll_banner` |
| **UI Jeu** | `ui/timeline_panel.gd` | IHM Combat `v0.10.0` : Frise haute verticale (`82×104`), alerte Charge `10 s`, Fiche Actif (badges `🛡`, actions `★`, boutons `⚙`), Minutes, Fiche Survolé & ciblage pion |
| **UI Jeu** | `ui/character_sheet_panel.gd` | Carnet de Bande `[F]` double-page : portrait BD + pion modulaire, `Esprit/Corps/Énergie`, `-3..+5`, XP, 4 emplacements |
| **UI Menu** | `ui/title_menu_panel.gd` | Menu unifié Accueil (`TITLE_MENU`) / Pause (`PAUSE_MENU`) avec confirmations |
| **UI Menu** | `ui/new_game_panel.gd` | Sélection du Scénario, mode **Bande Neuve** vs **Import de Cassette**, prénom, 8 profils BD, 4 archétypes |
| **UI Menu** | `ui/save_load_panel.gd` | Modale 3 cassettes manuelles (avec affichage du scénario et confirmations) |
| **UI Menu** | `ui/options_panel.gd` | Modale Options temps réel reliée à `SettingsManager` |
| **Hooks Packs** | `scenarios/*/scripts/*.gd` | 3 hooks `RefCounted` isolés : `ponton_hook.gd`, `aulnay_hook.gd`, `demo_hook.gd` (`_template_scenario`) |

---

## 4. Conventions & Contrats Vérifiés Automatiquement
* **Zéro ID métier dans le cœur** : `process_banlieue_assets.py` interdit tout identifiant de scénario, lieu, personnage ou quête dans `game/scripts/`.
* **Strict GDScript 2.0** : aucun `class_name` dans `autoload/` et aucune inférence `:=` sur `.get(`, `.call(`, `JSON.parse_string` ou `[` sur l'ensemble des 24 fichiers `.gd`.
* **Convention gabarit `_`** : tout dossier `game/data/scenarios/_*` reste ignoré du sélecteur `NewGamePanel` mais validé intégralement par `--mode validate`.
* **Assemblage Modulaire (`256×526` RGBA)** : fusion CPU 4 passes dans `DataLoader.assemble_modular_pawn()` (coins `(0,0)` et `(255,525)` transparents vérifiés).

---

## 5. Couverture de Test & Validation
* **Validation statique multi-packs (`--mode validate`)** : Contrôle **4 packs** (`couvre_feu_galaxian` : 11 lieux / 11 persos / 52 équipements ; `ronde_du_canal` : 4 lieux / `map_ourcq.png` ; `greve_citroen_aulnay` : 4 lieux / `map_aulnay.png` ; `_template_scenario` : 1 lieu / 3 persos), skills de `combat_interactables`, `24` `.gd` et `0` path cassé → **0 erreur**.
* **Smoke test automatisé Godot 4.7.2 headless (`smoke_test_menus.gd`)** : Teste les 4 archétypes, 8 profils, Jets de rue `2d6`, déplacement/portées/Charges `10 s`, **couverts (`Banquette quai`, `Pilier béton`) & interactifs (`prop_extincteur_quai`)**, bascule multi-packs (`couvre_feu_galaxian` ↔ `ronde_du_canal` ↔ `greve_citroen_aulnay`), masquage `_template_scenario`, Import de Cassette A/B/C et rendu modulaire IHM → **0 erreur**.
