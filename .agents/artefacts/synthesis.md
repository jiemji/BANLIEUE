# Synthèse du Projet — *Banlieue*

> **Version courante : 0.4.2** — Dernière mise à jour : 2026-11-22

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
* **Interface (`ui/`)** : `TitleMenuPanel` (Accueil/Pause unifié), `NewGamePanel` (4 archétypes + 6 portraits découplés), `SaveLoadPanel` (3 cassettes manuelles), `OptionsPanel`, `HudOverlay`, `DialoguePanel`, `TimelinePanel` (**Option A Unifiée** : barre d'état fine haut, Frise-Cartes unifiée avec portraits/stats/actions hors-frise et barre actions timing `1–4` / `Tab` / `Espace`).
* **Orchestrateur** : `main.gd` (machine d'états `AppState`, raccourcis `Échap`/`Backspace`/`M`/`1-6`, masquage `_hud` en combat & micro-secousse caméra, Sas Boeing).

## 5. Dernières Améliorations *(v0.4.2 — 2026-11-22)*
* **Refonte UX Combat — « Option A : Frise-Cartes Unifiée » ([ux_combat_frise.md](file:///e:/JDR/BANLIEUE/docs/ux_combat_frise.md))** :
  * Suppression des doublons entre frise haute, portraits bas et colonne ennemie droite : toute la bande isométrique supérieure reste dégagée (`zoom 0.85`), surmontée d'une barre d'état fine + tiroir `Journal` repliable.
  * Chaque protagoniste figure une seule fois sur la **Frise-Cartes Unifiée** (`get_ordered_rail_entries`) avec portrait BD, stats (`Moral/Attitude/Aura` ou `Résolution/Intention/Contre`) et boutons hors-frise (`⚡ Interruption` + `🛡 Retenir`), au-dessus d'une rangée dédiée aux actions du timing `[1–4]` et à l'aperçu au survol.
* **Acquis précédents *(v0.4.0 / v0.4.1)*** : Renommage complet `FAVE → Attitude` & `FASA → Aura`, ciblage libre, prévisualisation non destructive et pas-à-pas strict `awaiting_step` / `step_next_beat()`.

## Statut du Code
* **Validation statique & assets** : `process_banlieue_assets.py --mode validate` → **0 erreur** (**0 pending graphic assets**).
* **Tests headless Godot 4.7.2** : `smoke_test_menus.gd` et boot `--quit-after 30` → **0 erreur**.
