# Synthèse du Projet — *Banlieue*

> **Version courante : 0.7.0** — Dernière mise à jour : 2026-11-22

## 1. Identité & Stack
* **Titre** : *Banlieue* — *Cradon-lès-Gonesse (1980–1984)*
* **Genre** : Exploration urbaine, enquête sociale, bande modulable et Frise chronologique de Tension (hybride JDR *Zone* × *Disco Elysium* / *Margerin* / *La Haine*).
* **Moteur** : **Godot Engine 4.7.2** (`GL Compatibility`), **GDScript 2.0** à typage explicite strict, projet isolé dans `game/`.
* **Architecture** : **100 % Data-Driven (JSON)** séparant les données (`game/data/`), la logique métier (`scripts/systems/`), les états/persistances (`scripts/autoload/`) et les vues (`scripts/world/`, `scripts/ui/`).

## 2. Piliers Techniques
* **Atlas Multi-Zoom 4 Niveaux** : `N1` Île-de-France → `N2` Seine-Saint-Denis (93) → `N3` Plan de Cradon-lès-Gonesse → `N4` Intérieurs isométriques 2:1 hybrides (`backdrop` / `modular`).
* **Bascule Jour / Crépuscule / Nuit** : Post-process `film_1982_post.gdshader` (grain 16mm réglable, bascule N&B argentique préservant 4 couleurs-signaux) + audio procédural `AudioStreamGenerator` (FM + Cold Wave).
* **Pipeline Assets 2D** : Conservation des **portraits BD `1024×1024`** pour les dialogues, la Frise et les fiches ; assemblage runtime de **pions en pied modulaires 3 couches (`256×526` RGBA : tête / haut+bras / bas+pieds)** pour PJ et PNJ avec contour shader `2 px` continu et ombre portée `4h`, contrôlés par `process_banlieue_assets.py`.

## 3. Contraintes Strictes du Dépôt
* Aucun `class_name` dans `game/scripts/autoload/*.gd`.
* Jamais d'inférence `:=` avec `.get(`, `JSON.parse_string`, `.call(` ou `[` dans aucun `.gd`.
* Tous les chemins `res://` cités dans `.gd`, `.tscn`, `.godot`, `.gdshader` et JSON doivent exister sur disque.

## 4. Modules Clés (`game/scripts/`)
* **Autoloads (5)** : `DataLoader` (incluant `assemble_modular_pawn()` / `get_appearance_pawn_texture()`), `SettingsManager`, `GameState` (4 emplacements `look_top` / `look_bottom` / `tool` / `fetish` & `get_character_pawn_texture()`), `AudioRadio`, `SaveManager`.
* **Systèmes (`systems/`)** : `SquadManager` (`3+` / `2+1` / `1+1+1` + renforts), `TensionTimeline` (Frise à Interruptions dont `sang_froid` + préavis de Crises + fiches entités 4 emplacements), `DialogueRunner`.
* **Monde (`world/`)** : `WorldMapView` (N1–N3), `IsoDistrictView` (N4 + mode fond vivant + `set_combat_stage_mode` rendant PJ, PNJ et ennemis via calques modulaires 3 parties), `IsoPropNode`, `PawnActor`.
* **Interface (`ui/`)** : `TitleMenuPanel`, `NewGamePanel` (aperçu modulaire tête + archétype), `SaveLoadPanel`, `OptionsPanel`, `HudOverlay` (`Fiches [F]`), `DialoguePanel`, `TimelinePanel` (Frise haute verticale + triptyque bas Actif/Minutes/Survolé + ciblage clic pion), `CharacterSheetPanel` (Carnet `[F]` 4 emplacements `Haut / Bas / Outil / Fétiche` + pion assemblé en direct).
* **Orchestrateur** : `main.gd` (machine d'états `AppState`, raccourcis `Échap`/`F`/`Backspace`/`M`/`1-6`, masquage `_hud` en combat & micro-secousse caméra, Sas Boeing).

## 5. Dernières Améliorations *(v0.7.0 — 2026-11-22)*
* **Personnages Modulaires en 3 Parties & Équipement `Haut / Bas` (`v0.7.0`)** :
  * **Assets & Pipeline (`process_banlieue_assets.py`, `game/assets/modular/`)** : Découpe normalisée des 12 pions historiques + génération de 6 nouveaux sprites PNJ/coffre → **16 têtes**, **17 hauts+bras**, **15 bas+pieds** `256×526` RGBA ; **portraits BD `1024×1024`** conservés pour dialogues, Frise et en-têtes.
  * **4 Emplacements & PNJ (`equipment.json`, `characters.json`, `player_profiles.json`, `timeline_encounters.json`, `tour_b.json`)** : Scission de `look` en **`look_top` (`14` hauts)** et **`look_bottom` (`13` bas)** dans un catalogue de `39` objets ; `"appearance"` 3 parties sur les 9 personnages, les 6 profils joueur et les 3 ennemis de combat ; ajout de Mme Deschamps (`concierge`) dans `tour_b.json`.
  * **Assemblage Temps Réel sans Couture (`data_loader.gd`, `game_state.gd`, `pawn_actor.gd`, `iso_district_view.gd`, `character_sheet_panel.gd`, `new_game_panel.gd`)** : Composition 4 passes en une seule `ImageTexture` cachée (contour `2 px` continu, ombre `4h` unique), prévisualisation en direct `[F]` et *Nouvelle partie*, et remplacement des standees ennemis en combat par de vrais pions assemblés.
* **Refonte IHM Combat Tactique Isométrique (`v0.6.0` — [ux_combat_frise.md](file:///e:/JDR/BANLIEUE/docs/ux_combat_frise.md))** : Frise chronologique en bandeau haut (`y=8..126`) avec cartes verticales, scène centrale isométrique `2:1` 2 axes (héros bas→gauche, PNJ haut→droite) avec ciblage clic pion, triptyque bas **Fiche Actif (gauche) · Minutes du combat (centre) · Fiche Survolé (droite)**.
* **Jets de rue (`2d6 + Carac + Comp`), Failles & Carnet `[F]` (`v0.5.0 / v0.5.1` — [fiches_personnages_pj.md](file:///e:/JDR/BANLIEUE/docs/fiches_personnages_pj.md))** : 3 Caractéristiques, 10 compétences `-3..+5`, XP, Jets de rue `3..97%` et actions `★` d'équipement sur Frise et dans 10 scènes de [dialogues.json](file:///e:/JDR/BANLIEUE/game/data/dialogues.json).

## Statut du Code
* **Validation statique & assets** : `process_banlieue_assets.py --mode validate` → **0 erreur** (`48` calques `256×526` RGBA vérifiés).
* **Tests headless Godot 4.7.2** : `smoke_test_menus.gd` (`206` assertions `OK`) et boot `--quit-after 30` → **0 erreur**.
