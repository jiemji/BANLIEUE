# Synthèse du Projet — *Banlieue*

> **Version courante : 0.5.1** — Dernière mise à jour : 2026-11-22

## 1. Identité & Stack
* **Titre** : *Banlieue* — *Cradon-lès-Gonesse (1980–1984)*
* **Genre** : Exploration urbaine, enquête sociale, bande modulable et Frise chronologique de Tension (hybride JDR *Zone* × *Disco Elysium* / *Margerin* / *La Haine*).
* **Moteur** : **Godot Engine 4.7.2** (`GL Compatibility`), **GDScript 2.0** à typage explicite strict, projet isolé dans `game/`.
* **Architecture** : **100 % Data-Driven (JSON)** séparant les données (`game/data/`), la logique métier (`scripts/systems/`), les états/persistances (`scripts/autoload/`) et les vues (`scripts/world/`, `scripts/ui/`).

## 2. Piliers Techniques
* **Atlas Multi-Zoom 4 Niveaux** : `N1` Île-de-France → `N2` Seine-Saint-Denis (93) → `N3` Plan de Cradon-lès-Gonesse → `N4` Intérieurs isométriques 2:1 hybrides (`backdrop` / `modular`).
* **Bascule Jour / Crépuscule / Nuit** : Post-process `film_1982_post.gdshader` (grain 16mm réglable, bascule N&B argentique préservant 4 couleurs-signaux) + audio procédural `AudioStreamGenerator` (FM + Cold Wave).
* **Pipeline Assets 2D** : Portraits BD 1024 px et sprites en pied RGBA détourés sans socle (`526 px` paddés) pour shader contour 2 px et ombre portée 4h, contrôlés par `process_banlieue_assets.py`.

## 3. Contraintes Strictes du Dépôt
* Aucun `class_name` dans `game/scripts/autoload/*.gd`.
* Jamais d'inférence `:=` avec `.get(`, `JSON.parse_string`, `.call(` ou `[` dans aucun `.gd`.
* Tous les chemins `res://` cités dans `.gd`, `.tscn`, `.godot`, `.gdshader` et JSON doivent exister (sauf profils `pending_asset: true` dans `player_profiles.json` en attente de génération).

## 4. Modules Clés (`game/scripts/`)
* **Autoloads (5)** : `DataLoader`, `SettingsManager`, `GameState`, `AudioRadio`, `SaveManager`.
* **Systèmes (`systems/`)** : `SquadManager` (`3+` / `2+1` / `1+1+1` + renforts), `TensionTimeline` (Frise à Interruptions dont `sang_froid` + préavis de Crises), `DialogueRunner`.
* **Monde (`world/`)** : `WorldMapView` (N1–N3), `IsoDistrictView` (N4 + mode fond vivant d'accueil + `set_combat_stage_mode` cinémascope), `IsoPropNode`, `PawnActor`.
* **Interface (`ui/`)** : `TitleMenuPanel`, `NewGamePanel`, `SaveLoadPanel`, `OptionsPanel`, `HudOverlay` (avec bouton `Fiches [F]`), `DialoguePanel`, `TimelinePanel` (**Option A Unifiée**), `CharacterSheetPanel` (**Carnet de Bande `[F]`**).
* **Orchestrateur** : `main.gd` (machine d'états `AppState`, raccourcis `Échap`/`F`/`Backspace`/`M`/`1-6`, masquage `_hud` en combat & micro-secousse caméra, Sas Boeing).

## 5. Dernières Améliorations *(v0.5.1 — 2026-11-22)*
* **Jets de rue (`2d6 + Carac + Comp`), Failles & Équipement Actif (`v0.5.1`)** : Moteur unifié `preview_street_roll()` / `perform_street_roll()` dans `GameState` (36 combinaisons exactes `3..97%`, Coup d'éclat `+10 XP` / impact accru, Couac de faille sur `< 0`), câblé sur 10 scènes de [dialogues.json](file:///e:/JDR/BANLIEUE/game/data/dialogues.json) (`DialoguePanel` avec badges `%` et bandeau résultat) et sur `TensionTimeline` / `TimelinePanel` (actions `[1–6]` incluant `★` équipement `1×/confrontation`, Interruptions modulées par compétences).
* **Fiches de Personnages PJ & Carnet de Bande `[F]` (`v0.5.0` — [fiches_personnages_pj.md](file:///e:/JDR/BANLIEUE/docs/fiches_personnages_pj.md))** :
  * **3 Caractéristiques & 10 Compétences bipolaires (`-3..+5`)** dans [equipment.json](file:///e:/JDR/BANLIEUE/game/data/equipment.json), `characters.json` et `player_profiles.json`, évolutives par **XP** et **24 équipements actifs** (`Look`, `Outil`, `Fétiche` + `box_stash`), sauvegardées dans `member_progression` / `box_stash`.
  * **UI Double-Page `[F]` (`character_sheet_panel.gd`)** : portraits/pion, barres `Esprit/Corps/Énergie`, compétences `-3..+5` avec dépense XP, échange coffre en 1 clic, actions débloquées, traits et thermomètre relationnel.
* **Acquis précédents *(v0.4.0 → v0.4.2)*** : Frise-Cartes Unifiée Option A (`ux_combat_frise.md`), renommage complet `FAVE → Attitude` & `FASA → Aura`, pas-à-pas strict `step_next_beat()`.

## Statut du Code
* **Validation statique & assets** : `process_banlieue_assets.py --mode validate` → **0 erreur** (**0 pending graphic assets**).
* **Tests headless Godot 4.7.2** : `smoke_test_menus.gd` et boot `--quit-after 30` → **0 erreur**.
