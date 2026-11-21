# Synthèse du Projet — *Banlieue*

> **Version courante : 0.2.1** — Dernière mise à jour : 2026-11-21

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
* **Monde (`world/`)** : `WorldMapView` (N1–N3), `IsoDistrictView` (N4 + mode fond vivant d'accueil), `IsoPropNode`, `PawnActor`.
* **Interface (`ui/`)** : `TitleMenuPanel` (Accueil/Pause unifié), `NewGamePanel` (4 archétypes + 6 portraits découplés), `SaveLoadPanel` (3 cassettes manuelles), `OptionsPanel`, `HudOverlay`, `DialoguePanel`, `TimelinePanel`.
* **Orchestrateur** : `main.gd` (machine d'états `AppState`, raccourcis `Échap`/`Backspace`/`M`/`1-3`, Sas Boeing).

## 5. Dernières Améliorations *(v0.2.1 — 2026-11-21)*
* **Galerie complète des 6 profils joueur** : 5 nouveaux portraits BD (`player_02..06.png`) et 5 pions RGBA `526 px` assortis détourés proprement (nettoyage des poches magenta fermées ajouté à `process_banlieue_assets.py`) ; `"pending_asset"` retiré de `player_profiles.json`.
* **Décor `ruelle_relais.png`** : Coupe isométrique 2:1 `1200×896` assortie à `box_garage.png`, vérifiée à `162 px`, `ruelle_relais.json` basculé en `render_mode: "backdrop"` (`8×8`).
* **Préparation cartes IGN / RER (`world_map_view.gd`)** : Support affiné des fonds cartographiques illustrés (`has_backdrop`) et validation des champs `backdrop` N1–N3 dans `process_banlieue_assets.py`.
* **Socle Menus & Persistance *(v0.2.0)*** : Écran d'accueil vivant 28 s, Menu Pause unifié, `SaveManager` (3 cassettes manuelles), `SettingsManager` (`user://settings.cfg`), `NewGamePanel` (4 archétypes + `sang_froid`) et arbitrage `Échap`/`Backspace`.

## Statut du Code
* **Validation statique & assets** : `process_banlieue_assets.py --mode validate` → **0 erreur** (`0 pending assets`).
* **Tests headless Godot 4.7.2** : `smoke_test_menus.gd` et boot `--quit-after 30` → **0 erreur**.
* **Reste graphique planifié** : 4 images (`galaxian.png` + 3 cartes IGN/RER `map_idf.png`, `map_93.png`, `map_cradon.png`) planifiées pour le prochain reset quota (~06:36).
