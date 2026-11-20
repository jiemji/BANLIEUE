# Changelog — *Banlieue* (Cradon-lès-Gonesse, 1980–1984)

Toutes les évolutions notables du projet Godot 4 et de ses documents de conception sont consignées ici.

## [0.2.0] - 2026-11-20
### Feature
- **Écran d'accueil & Menu Principal unifié** : Lancement direct sur le décor vivant du **Box-Garage** animé par une respiration cyclique lente Jour → Crépuscule → Nuit (28 s) sous shader pellicule 16mm et lit radio FM feutré. Un même panneau gère l'accueil (`TITLE_MENU`) et la pause en cours de partie (`PAUSE_MENU`).
  - Fichiers impactés : `game/scripts/main.gd`, `game/scripts/ui/title_menu_panel.gd`, `game/scripts/world/iso_district_view.gd`, `game/scripts/autoload/audio_radio.gd`.
- **Sauvegardes manuelles sur 3 Cassettes (`SaveManager`)** : Implémentation de 3 emplacements manuels (`Cassette A`, `Cassette B`, `Cassette C` dans `user://saves/slot_1..3.json`, sans sauvegarde automatique), avec métadonnées détaillées (portrait, prénom, archétype, lieu, phase/heure, bande, Francs, horodatage) et confirmations d'écrasement, chargement ou suppression.
  - Fichiers impactés : `game/scripts/autoload/save_manager.gd`, `game/scripts/autoload/game_state.gd`, `game/scripts/ui/save_load_panel.gd`.
- **Écran « Nouvelle partie » — 4 Archétypes & Portraits libres** : Création du protagoniste découplant totalement l'apparence (prénom libre + 6 profils visuels `player_01..06` avec pions en pied assortis) de l'histoire personnelle parmi **4 archétypes sociaux** (*L'Enfant de la Dalle*, *La Grande Gueule du Bourg*, *Les Mains-Noires*, *L'Échappé·e des Pavillons*), avec repli gracieux sur les visuels `leader` tant que les 5 paires supplémentaires sont marquées `"pending_asset": true`.
  - Fichiers impactés : `game/data/player_profiles.json`, `game/scripts/ui/new_game_panel.gd`, `game/scripts/autoload/data_loader.gd`, `game/scripts/autoload/game_state.gd`.
- **Nouvelle spécialité Frise `sang_froid`** : Interruption hors-tour de *L'Échappé·e des Pavillons* permettant d'apaiser une Crise d'autonomie en préavis (+10 Moral) ou de percer un bluff adverse.
  - Fichier impacté : `game/scripts/systems/tension_timeline.gd`.

### UI-UX
- **Options persistantes (`SettingsManager`)** : Modale de réglages enregistrés dans `user://settings.cfg` — mode d'affichage (Fenêtré / Plein écran), volume général, coupure du son synchronisée avec le HUD, ambiance Radio FM / Cold Wave, intensité du grain 16mm (`Désactivé` / `Léger` / `1982`), secousses d'écran et taille de police des dialogues (`Normale` / `Grande`).
  - Fichiers impactés : `game/scripts/autoload/settings_manager.gd`, `game/scripts/ui/options_panel.gd`, `game/scripts/ui/dialogue_panel.gd`, `game/scripts/ui/hud_overlay.gd`.
- **Arbitrage des raccourcis clavier** : `Échap` est dédié à l'ouverture/fermeture du Menu Pause et des modales ; le dézoom cartographique (`N4 → N1`) passe sur `Retour arrière (Backspace)` (ou bouton `▲` / molette). Le bouton `Rejouer` de la barre haute est remplacé par `Menu`.
  - Fichiers impactés : `game/scripts/main.gd`, `game/scripts/ui/hud_overlay.gd`.

### Config & Outillage
- **Autoloads & Validation** : Enregistrement de `SettingsManager` et `SaveManager` dans `game/project.godot` et extension du validateur `process_banlieue_assets.py` pour contrôler `data/player_profiles.json` et gérer proprement le drapeau `pending_asset`.
  - Fichiers impactés : `game/project.godot`, `.agents/skills/banlieue-asset-pipeline/scripts/process_banlieue_assets.py`.

### Documentation
- Consolidation des spécifications UX/persistance et synchronisation de la Bible et des fiches personnages/architecture.
  - Fichiers impactés : `docs/structure_menus_et_ecrans.md`, `docs/architecture_technique.md`, `docs/personnages_et_relations.md`, `docs/pitch_bible.md`.

---

## [0.1.0] - 2026-11-20
### Feature
- **Socle Jalon 0 — « Couvre-Feu au Galaxian »** : Initialisation du prototype Godot 4 Data-Driven (`GL Compatibility`), atlas multi-zoom à 4 niveaux (`IDF → 93 → Cradon-lès-Gonesse → Intérieurs isométriques 2:1`), bande modulable (`3+` / `2+1` / `1+1+1`), Frise chronologique de Tension avec Interruptions hors-tour et Crises d'autonomie, Sas crépusculaire Boeing, shader pellicule 1982 et pipeline assets 2D (`banlieue-asset-artist`).
  - Commits de référence : `ac8c48d`, `6248441`, `917196e`, `dc4ab13`.
