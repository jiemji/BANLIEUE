# Analyse Technique de la Codebase — *Banlieue*

> **Version courante : 0.7.0** — Mise à jour : 2026-11-22

---

## 1. Fiche d'Identité
* **Racine Godot** : `e:\JDR\BANLIEUE\game\project.godot` (`config_version=5`, renderer `GL Compatibility`, viewport `1280×720` `canvas_items/expand`)
* **Langage** : GDScript 2.0 (typé explicitement) + GLSL ES (`film_1982_post.gdshader`, `pawn_outline.gdshader`) + JSON Data-Driven
* **Outillage qualité** : `.agents/skills/banlieue-asset-pipeline/scripts/process_banlieue_assets.py`

---

## 2. Diagramme des Flux & Machine d'États

```text
                       [ JSON Data ]
         (world/*, maps/*, characters, equipment, dialogues,
           timeline_encounters, radio_fm, player_profiles)
                              │
                              ▼
                        (DataLoader) ◄── game/assets/modular/{heads,tops,bottoms}/
                              │           (assemblage ImageTexture 256x526 en cache)
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
| **Autoload** | `autoload/data_loader.gd` | Chargement JSON, `player_profiles.json`, `equipment.json`, `apply_leader_profile()` & assembleur 4 passes **`assemble_modular_pawn()`** (`256×526` caché) |
| **Autoload** | `autoload/settings_manager.gd` | Chargement/sauvegarde `user://settings.cfg`, affichage, audio, grain, secousse, police |
| **Autoload** | `autoload/game_state.gd` | État vivant, `member_progression` (4 slots **`look_top` / `look_bottom` / `tool` / `fetish`**), `box_stash`, **`get_character_pawn_texture()`**, Jets de rue `2d6`, `to_save_dict()` |
| **Autoload** | `autoload/audio_radio.gd` | Synthèse temps réel (`AudioStreamGenerator`) SFX + Cold Wave + lit FM titre |
| **Autoload** | `autoload/save_manager.gd` | Gestion des 3 cassettes manuelles (`slot_1..3.json`) et lecture rapide des métadonnées |
| **Système** | `systems/squad_manager.gd` | Formation (`3+` / `2+1` / `1+1+1`), bascule à la volée, déplacements & distances de renfort |
| **Système** | `systems/tension_timeline.gd` | Frise pas-à-pas `3B`, Jets de rue `2d6`, 8 actions équipement `★`, Interruptions modulées, ciblage pion (`*_on`) & `get_entity_sheet_data` (4 slots) |
| **Système** | `systems/dialogue_runner.gd` | Évaluation prérequis (`min_skill`, `require_item`, `require_action`), résolution `skill_check` (`next`/`fail_next`), effets (`add_xp`, `grant_item`, `add_trait`) |
| **Monde** | `world/world_map_view.gd` | Cartes papier 2D N1–N3 (`Camera2D`, zoom, survol, marqueurs de groupes) |
| **Monde** | `world/iso_district_view.gd` | Vue isométrique 2:1 N4 (`backdrop`/`modular`), mode accueil & plateau combat (pions modulaires PJ, PNJ dont `concierge`, et 3 ennemis de combat) |
| **Monde** | `world/iso_prop_node.gd` | Props isométriques triés par Y-sort en mode modulaire |
| **Monde** | `world/pawn_actor.gd` | Pion RGBA `256×526` (contour 2 px sans couture, ombre 4h), garde-fou recalcul géométrique & surbrillance combat (halo + chevron `▼`) |
| **UI Jeu** | `ui/hud_overlay.gd` | Bandeau 1982 (`Fiches [F]`), fil d'Ariane N1–N4, bouton `Menu`, gestion bande, tuner FM, pistes (masqué en combat) |
| **UI Jeu** | `ui/dialogue_panel.gd` | Boîte de dialogue BD avec portrait `1024 px`, choix en `ScrollContainer`, badges `🎲 %` / `⚠ FAILLE`, bandeau `_roll_banner` |
| **UI Jeu** | `ui/timeline_panel.gd` | IHM Combat `v0.6.0` : Frise haute verticale (`82×104`), Fiche Actif bas-gauche, Minutes bas-centre, Fiche Survolé bas-droite & ciblage clic pion |
| **UI Jeu** | `ui/character_sheet_panel.gd` | Carnet de Bande `[F]` double-page : portrait BD intact + pion modulaire temps réel, `Esprit/Corps/Énergie`, `-3..+5`, XP, **4 emplacements `Haut/Bas/Outil/Fétiche`** |
| **UI Menu** | `ui/title_menu_panel.gd` | Menu unifié Accueil (`TITLE_MENU`) / Pause (`PAUSE_MENU`) avec confirmations |
| **UI Menu** | `ui/new_game_panel.gd` | Écran « Nouvelle partie » (prénom + 6 portraits BD conservés + aperçu modulaire tête/archétype + 4 archétypes) |
| **UI Menu** | `ui/save_load_panel.gd` | Modale 3 cassettes manuelles (sauver, écraser, charger, effacer + confirmations) |
| **UI Menu** | `ui/options_panel.gd` | Modale Options temps réel reliée à `SettingsManager` |

---

## 4. Conventions & Contrats Vérifiés Automatiquement
* **Strict GDScript 2.0** : `process_banlieue_assets.py` interdit `class_name` dans `autoload/` et interdit toute inférence `:=` sur `.get(`, `.call(`, `JSON.parse_string` ou `[` (zéro violation sur les 21 scripts).
* **Assemblage Modulaire Sans Couture (`256×526` RGBA)** : Les 3 calques (`bottom`, puis cou du `head`, puis `top`, puis visage et longueurs latérales du `head`) sont fusionnés côté CPU dans `DataLoader.assemble_modular_pawn()` via `_load_part_image()` (support ressource importée et repli `Image.load_from_file`), de sorte que `pawn_outline.gdshader` trace un unique contour extérieur continu et une seule ombre portée `4h`. Les portraits BD `1024×1024` restent séparés sur `"portrait"`.
* **Persistance séparée** : Préférences globales dans `user://settings.cfg` (`ConfigFile`) ; sauvegardes de session manuelles exclusivement dans `user://saves/slot_1..3.json`.

---

## 5. Couverture de Test & Validation
* **Validation statique & intégrité (`--mode validate`)** : Contrôle JSON atlas N1–N3 (`map_idf.png`, `map_93.png`, `map_cradon.png` + 5 secteurs & 9 lieux), **9/9 intérieurs N4** en `backdrop` (dont `concierge` déployée dans `tour_b.json`), **9 personnages** avec `"appearance"` `256×526` RGBA, **40 dialogues**, **`39` équipements sur 4 emplacements** (`14 look_top`, `13 look_bottom`, `tool`, `fetish`), **3 ennemis combat modulaires**, `player_profiles.json` et zéro path `res://` cassé → **0 erreur**.
* **Smoke test automatisé Godot 4.7.2 headless (`smoke_test_menus.gd`)** : Vérifie `206` assertions `OK`, incluant l'assemblage `256×526` des PJ/PNJ, l'échange dynamique de texture `look_top` / `look_bottom` (`perfecto_cloute`, `treillis_rangers`) et retour au repli de base, la présence du PNJ `concierge` dans `tour_b`, la conservation des portraits BD et le rendu modulaire réel (`_is_standee == false`) des 3 ennemis sur le plateau de combat → **0 erreur**.
