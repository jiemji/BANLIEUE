# Synthèse du Projet — *Banlieue*

> **Version courante : 0.10.0** — Dernière mise à jour : 2026-11-26

## 1. Identité & Stack
* **Titre** : *Banlieue* — *Seine-Saint-Denis (1980–1984)*
* **Genre** : Exploration urbaine, enquête sociale, bande modulable et Frise chronologique de Tension (hybride JDR *Zone* × *Disco Elysium* / *Margerin* / *La Haine*).
* **Moteur** : **Godot Engine 4.7.2** (`GL Compatibility`), **GDScript 2.0** à typage explicite strict, projet isolé dans `game/`.
* **Architecture** : **100 % Modulaire & Data-Driven (JSON)** — cœur moteur générique sans aucun identifiant métier en dur, **Packs de Scénarios isolés** (`game/data/scenarios/<id>/`), briques d'effets combat déclaratives + hooks `custom_script` et **Import de Cassette A/B/C**.

## 2. Piliers Techniques
* **Atlas Multi-Zoom 4 Niveaux** : `N1` Île-de-France → `N2` Seine-Saint-Denis (93) → `N3` Communes (`Cradon-lès-Gonesse`, `Aulnay-sous-Bois`, `Berges de l'Ourcq`) → `N4` Intérieurs isométriques 2:1 hybrides (`backdrop` / `modular`).
* **Bascule Jour / Crépuscule / Nuit** : Post-process `film_1982_post.gdshader` (grain 16mm réglable, bascule N&B argentique préservant 4 couleurs-signaux) + audio procédural `AudioStreamGenerator` (FM déclarative via `radio_fm.json` + Cold Wave).
* **Pipeline Assets 2D** : Conservation des **portraits BD `1024×1024`** pour les dialogues, la Frise et les fiches ; assemblage runtime de **pions en pied modulaires 3 couches (`256×526` RGBA : tête / haut+bras / bas+pieds)** pour PJ et PNJ avec contour shader `2 px` continu et ombre portée `4h`, contrôlés par [process\_banlieue\_assets.py](file:///e:/JDR/BANLIEUE/.agents/skills/banlieue-asset-pipeline/scripts/process_banlieue_assets.py).

## 3. Contraintes Strictes du Dépôt
* Aucun `class_name` dans `game/scripts/autoload/*.gd`.
* Jamais d'inférence `:=` avec `.get(`, `JSON.parse_string`, `.call(` ou `[` dans aucun `.gd`.
* Zéro identifiant métier scénaristique codé en dur dans `game/scripts/` (`FORBIDDEN_HARDCODED_IDS` dans `process_banlieue_assets.py`).
* Dossiers gabarits préfixés par `_` ou `.` dans `game/data/scenarios/` ignorés en jeu par `DataLoader.discover_scenarios()`, tout en restant validés par `--mode validate`.
* Tous les chemins `res://` et relatifs de pack cités dans `.gd`, `.tscn`, `.godot`, `.gdshader` et JSON doivent exister sur disque.

## 4. Modules Clés (`game/scripts/`)
* **Autoloads (5)** : `DataLoader` (découverte multi-packs, cache textures & `assemble_modular_pawn()` `256×526`), `SettingsManager`, `GameState` (4 emplacements `look_top` / `look_bottom` / `tool` / `fetish`, Jets `2d6`, états de pack), `AudioRadio` (`radio_fm.json`, SFX Charge `10 s`), `SaveManager` (cassettes taggées `scenario_id` + import inter-scénarios).
* **Systèmes (`systems/`)** : `SquadManager` (`3+` / `2+1` / `1+1+1` + renforts dynamiques), `TensionTimeline` (grille `8×8`, `PM 2–3`, portées, Charge `10 s`, couverts `cover_tiles[]`, interactifs `combat_interactables[]`, 13 briques JSON + `custom_script`), `DialogueRunner`.
* **Monde (`world/`)** : `WorldMapView` (N1–N3 pilotés par JSON), `IsoDistrictView` (N4 + plateau combat `8×8` avec couverts `🛡`, interactifs `⚙` et flèche de Charge), `IsoPropNode` (`rules/props_catalog.json`), `PawnActor`.
* **Interface (`ui/`)** : `TitleMenuPanel` (fond dynamique depuis `scenario.json`), `NewGamePanel` (sélecteur de scénario + Bande Neuve / Import Cassette + 8 profils), `SaveLoadPanel`, `OptionsPanel`, `HudOverlay`, `DialoguePanel`, `TimelinePanel` (Frise haute verticale + triptyque bas Actif/Minutes/Survolé + alerte Charge `10 s` + badges couvert/boutons `⚙`), `CharacterSheetPanel`.
* **Orchestrateur** : `main.gd` (machine d'états `AppState`, raccourcis `Échap`/`F`/`Backspace`/`M`/`1-9`, Sas & fins 100 % pilotés par `scenario.json` et `outcomes`).

## 5. Dernières Améliorations *(v0.8.0 → v0.10.0 — 2026-11-26)*
* **Profondeur Tactique Combat (`v0.10.0` — [ux\_combat\_frise.md](file:///e:/JDR/BANLIEUE/docs/ux_combat_frise.md))** : Couverts/obstacles (`cover_tiles[]`, `+defense_bonus` DD à distance, `-moral_absorb` aux chocs moraux PJ) et éléments interactifs du décor (`combat_interactables[]` déclenchables au clic ou bouton `⚙` via Jet `2d6`) sur les 3 scénarios jouables.
* **Scénario n°3 Inédit & Gabarit Modding (`v0.10.0` — [guide\_modding.md](file:///e:/JDR/BANLIEUE/docs/guide_modding.md))** : Création du 3e pack autonome [greve\_citroen\_aulnay](file:///e:/JDR/BANLIEUE/game/data/scenarios/greve_citroen_aulnay/scenario.json) (*« Ondes Libres à Citroën Aulnay »*, 4 intérieurs N4, `emetteur_pirate_fm` `★` inline, `scripts/aulnay_hook.gd`), du gabarit [\_template\_scenario](file:///e:/JDR/BANLIEUE/game/data/scenarios/_template_scenario/scenario.json) et de la bibliothèque étendue (3 portraits BD, 11 tenues `256×526`, `casemate_poudrerie.png`, `map_ourcq.png`, `map_aulnay.png`, `ecluse_ponton`, commune d'Aulnay dans `couvre_feu_galaxian`).
* **Architecture 100 % Modulaire (`v0.9.0` — [architecture\_technique.md](file:///e:/JDR/BANLIEUE/docs/architecture_technique.md))** : Packs isolés (`1B`), moteur de briques JSON + `custom_script` (`2A`) et Import de Cassette (`3A`), zéro identifiant métier dans `game/scripts/`.
* **Combat Tactique `8×8`, Portées & Charge 10 s (`v0.8.0`)** : Déplacement `PM`, portées (`1c / 2–4c / 2–6c`), Charge symétrique Assommé (`-2 rangs`) et alerte d'interception temps réel `10,0 s`.

## Statut du Code
* **Validation statique & assets** : `process_banlieue_assets.py --mode validate` → **0 erreur** sur **4 packs** (`couvre_feu_galaxian`, `ronde_du_canal`, `greve_citroen_aulnay`, `_template_scenario`), `24` scripts GDScript, `0` identifiant métier en dur.
* **Tests headless Godot 4.7.2** : `smoke_test_menus.gd` + boot `--quit-after 30` → **0 erreur**.
