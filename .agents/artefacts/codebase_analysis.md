# Analyse Technique de la Codebase — *Banlieue*

> **Version courante : 0.5.0** — Mise à jour : 2026-11-22

---

## 1. Fiche d'Identité
* **Racine Godot** : `e:\JDR\BANLIEUE\game\project.godot` (`config_version=5`, renderer `GL Compatibility`, viewport `1280×720` `canvas_items/expand`)
* **Langage** : GDScript 2.0 (typé explicitement) + GLSL ES (`film_1982_post.gdshader`, `pawn_outline.gdshader`) + JSON Data-Driven
* **Outillage qualité** : `.agents/skills/banlieue-asset-pipeline/scripts/process_banlieue_assets.py`

---

## 2. Diagramme des Flux & Machine d'États

```text
                       [ JSON Data ]
         (world/*, maps/*, characters, dialogues,
          timeline_encounters, radio_fm, player_profiles)
                             │
                             ▼
                       (DataLoader)
                             │
    (SettingsManager) ──────►┼──────► (SaveManager) ◄──► user://saves/slot_1..3.json
           │                 ▼
           │            (GameState)
           │                 │ signaux (state_changed, phase_changed, zoom_changed, ...)
           ▼                 ▼
     (AudioRadio)      [ main.gd : AppState ]
                   TITLE_MENU ⇄ NEW_GAME_SETUP ⇄ IN_GAME ⇄ PAUSE_MENU
                             │
          ┌──────────────────┼──────────────────┐
          ▼                  ▼                  ▼
   [WorldMapView N1-3] [IsoDistrictView N4] [UI Layers 10 & 20]
                                           (HUD, Dialogue, Frise,
                                            Title/Pause, NewGame,
                                            SaveLoad, Options)
```

---

## 3. Inventaire des 21 Scripts GDScript (`game/scripts/`)

| Couche | Script | Rôle principal |
|---|---|---|
| **Orchestrateur** | `main.gd` | Machine d'états `AppState`, cycle titre 28 s, Sas Boeing, arbitrage `Échap`/`F`/`Backspace`/`M`/`1-6`, HUD/shake combat |
| **Autoload** | `autoload/data_loader.gd` | Chargement hiérarchique JSON, `player_profiles.json`, `equipment.json` (`skills_catalog`, `equipment_catalog`) & `apply_leader_profile()` |
| **Autoload** | `autoload/settings_manager.gd` | Chargement/sauvegarde `user://settings.cfg`, affichage, audio, grain, secousse, police |
| **Autoload** | `autoload/game_state.gd` | État vivant, `member_progression` (`xp`, `skills`, `equipment`, `traits`), `box_stash`, `aura_bonus`/`get_total_aura()`, `to_save_dict()` |
| **Autoload** | `autoload/audio_radio.gd` | Synthèse temps réel (`AudioStreamGenerator`) SFX + Cold Wave + lit FM titre |
| **Autoload** | `autoload/save_manager.gd` | Gestion des 3 cassettes manuelles (`slot_1..3.json`) et lecture rapide des métadonnées |
| **Système** | `systems/squad_manager.gd` | Formation (`3+` / `2+1` / `1+1+1`), bascule à la volée, déplacements & distances de renfort |
| **Système** | `systems/tension_timeline.gd` | Frise pas-à-pas `3B`, ciblage libre `2A` + `preview_*`, stats/bonus équipement, gains d'XP/traits en fin de scène |
| **Système** | `systems/dialogue_runner.gd` | Évaluation de prérequis (dont `min_skill`, `require_item`) et exécution des effets (`add_xp`, `grant_item`, `add_trait`) |
| **Monde** | `world/world_map_view.gd` | Cartes papier 2D N1–N3 (`Camera2D`, zoom, survol, marqueurs de groupes) |
| **Monde** | `world/iso_district_view.gd` | Vue isométrique 2:1 N4 hybride (`backdrop`/`modular`), mode accueil & mode scène de combat cinémascope |
| **Monde** | `world/iso_prop_node.gd` | Props isométriques triés par Y-sort en mode modulaire |
| **Monde** | `world/pawn_actor.gd` | Pion RGBA 526 px, shader contour dynamique 2 px et ombre portée 4h |
| **UI Jeu** | `ui/hud_overlay.gd` | Bandeau 1982 (`Fiches [F]`), fil d'Ariane N1–N4, bouton `Menu`, gestion bande, tuner FM, pistes (masqué en combat) |
| **UI Jeu** | `ui/dialogue_panel.gd` | Boîte de dialogue BD avec portrait, choix annotés et police dynamique |
| **UI Jeu** | `ui/timeline_panel.gd` | HUD unifié Option A : barre fine haut, Frise-Cartes Unifiée (portraits, stats, hors-frise) & barre actions timing |
| **UI Jeu** | `ui/character_sheet_panel.gd` | Carnet de Bande `[F]` double-page : `Esprit/Corps/Énergie`, compétences `-3..+5`, XP, coffre équipement & relations |
| **UI Menu** | `ui/title_menu_panel.gd` | Menu unifié Accueil (`TITLE_MENU`) / Pause (`PAUSE_MENU`) avec confirmations |
| **UI Menu** | `ui/new_game_panel.gd` | Écran « Nouvelle partie » 2 colonnes (prénom + 6 portraits/pions + 4 archétypes) |
| **UI Menu** | `ui/save_load_panel.gd` | Modale 3 cassettes manuelles (sauver, écraser, charger, effacer + confirmations) |
| **UI Menu** | `ui/options_panel.gd` | Modale Options temps réel reliée à `SettingsManager` |

---

## 4. Conventions & Contrats Vérifiés Automatiquement
* **Strict GDScript 2.0** : `process_banlieue_assets.py` interdit `class_name` dans `autoload/` et interdit toute inférence `:=` sur `.get(`, `.call(`, `JSON.parse_string` ou `[` (zéro violation sur les 20 scripts).
* **Chargement d'images robuste** : Les vues UI et monde utilisent `_load_texture_safe()` (fallback `Image.load_from_file`) pour tolérer les PNG hors cache `.import`, et `DataLoader.apply_leader_profile()` / `NewGamePanel` basculent proprement sur `leader.png` / `leader_pawn.png` pour les profils `pending_asset`.
* **Persistance séparée** : Préférences globales dans `user://settings.cfg` (`ConfigFile`) ; sauvegardes de session manuelles exclusivement dans `user://saves/slot_1..3.json`.

---

## 5. Couverture de Test & Validation
* **Validation statique & intégrité (`--mode validate`)** : Contrôle JSON atlas N1–N3 (`map_idf.png`, `map_93.png`, `map_cradon.png` + 5 secteurs & 9 lieux inclus), **9/9 intérieurs N4** en mode `backdrop` (`garage_bananes`, `squat_kepons`, `lisiere_poudrerie` inclus), **9 personnages** (`manu` & `zoe` inclus), **23 dialogues**, rencontres, `player_profiles.json`, `res://` et RGBA `526 px` de tous les pions → **0 erreur** (**0 pending graphic assets**).
* **Smoke test automatisé Godot 4.7.2 headless (`smoke_test_menus.gd`)** : Vérifie les 5 autoloads, les 4 archétypes sociaux, les 6 portraits/pions joueur réels sur disque, **Manu & Zoé + bande à 6 membres**, les 5 secteurs / 9 lieux de Cradon, les `occluders` calibrés des 9 intérieurs `backdrop`, la spécialité `sang_froid`, la persistance `SettingsManager`, le cycle complet `SaveManager` et la machine d'états UI de `main.tscn` → **0 erreur**.
