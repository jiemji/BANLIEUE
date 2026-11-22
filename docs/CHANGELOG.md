# Changelog — *Banlieue* (Cradon-lès-Gonesse, 1980–1984)

Toutes les évolutions notables du projet Godot 4 et de ses documents de conception sont consignées ici.

## [0.7.0] - 2026-11-22
### Personnages Modulaires en 3 Parties (`tête / haut+bras / bas+pieds`) & Équipement `Haut / Bas`
- **Pipeline Assets 2D Modulaire (`process_banlieue_assets.py`, `SKILL.md`, `banlieue-asset-artist.md`)** : Découpe canonique `256×526` RGBA en 3 calques empilables (`heads/`, `tops/`, `bottoms/`) à partir des 12 pions existants plus 6 nouveaux sprites générés sur gabarit `leader_pawn.png` pour les PNJ et objets du coffre (`concierge`, `so_agent`, `cousin_so`, `skin_nerveux`, `perfecto_cloute`, `parka_anonyme`, `treillis_rangers`).
- **4 Emplacements d'Équipement (`equipment.json`, `characters.json`, `player_profiles.json`, `timeline_encounters.json`, `tour_b.json`)** : Scission de l'ancien slot `look` en **`look_top` (Haut — 14 blousons/vestes/parkas)** et **`look_bottom` (Bas — 13 pantalons/jeans/chaussures à bonus cohérents)** aux côtés de `tool` et `fetish` ; câblage `"appearance"` sur les 9 personnages (incluant Mme Deschamps déployée dans `tour_b.json`), les 6 profils joueur et les 3 ennemis de combat.
- **Assemblage Runtime Unifié (`data_loader.gd`, `game_state.gd`, `pawn_actor.gd`, `iso_district_view.gd`, `character_sheet_panel.gd`, `new_game_panel.gd`, `tension_timeline.gd`)** : Composition en 4 passes sur une seule `ImageTexture` `256×526` mise en cache (préservant un contour shader `2 px` continu sans couture interne ni ombre coupée), rafraîchissement temps réel du Carnet `[F]`, de Nouvelle Partie et des grilles N4/combat (remplaçant les standees ennemis par de vrais pions assemblés), tout en conservant intactes les illustrations **portraits BD `1024×1024`** dans les dialogues, la Frise et les en-têtes.

## [0.6.0] - 2026-11-22
### Refonte IHM Combat Tactique Isométrique
- **Frise Chronologique Haute à Cartes Verticales (`timeline_panel.gd`)** : Déplacement de la frise en bandeau haut (`y = 8..126`) avec cartes rectangulaires verticales (`82×104 px`) centrées sur l'essentiel (portrait, nom, jauge Moral/Résolution).
- **Quadrillage Isométrique Central & Surbrillance (`iso_district_view.gd`, `pawn_actor.gd`)** : Déploiement de tous les protagonistes présents sur une grille `2:1` centrée au milieu de l'écran (`héros` alignés sur l'axe bas→gauche, `PNJ` standees BD alignés sur l'axe haut→droite), avec mise en surbrillance de l'acteur actif (anneau sol + chevron `▼` + shader contour épaissi) et détection directe survol/clic sur pion.
- **Triptyque Bas Actif / Minutes / Survolé & Ciblage Pion (`timeline_panel.gd`, `tension_timeline.gd`, `main.gd`)** : Fiche détaillée du personnage actif (PJ ou PNJ) en bas à gauche avec options `[1–6]` et réactions hors-frise ; **Minutes du combat** déroulantes entre les deux fiches ; fiche miroir en bas à droite au survol d'un PJ/PNJ (incluant prévisualisation `🎲 %` lorsque le joueur doit cliquer un pion pour exécuter une option ciblée).
- **Documentation & Tests (`ux_combat_frise.md`, `architecture_technique.md`, `.agents/artefacts/*`, `smoke_test_menus.gd`)** : Mise à jour des spécifications UI combat et ajout de vérifications automatisées sur le triptyque bas, les cartes verticales hautes, le déploiement 2 axes et le ciblage par clic pion.

## [0.5.1] - 2026-11-22
### Jets de rue (`2d6 + Carac + Comp`), Failles & Actions d'Équipement Actives
- **Moteur de Jets de rue (`game_state.gd`)** : Implémentation centralisée de `preview_street_roll()`, `perform_street_roll()`, `compute_street_roll_chance()` (36 combinaisons exactes avec double 1 = échec critique / plafond `97 %` et double 6 = réussite critique / plancher `3 %`), sélection automatique du meilleur membre (`get_best_active_group_roller()`), file de tests déterministe (`enqueue_forced_roll` / `clear_forced_rolls`) et détection d'actions équipées (`has_equipped_action`, `has_action_in_active_group`).
- **Dialogues à Jets & Équipement (`dialogue_runner.gd`, `dialogue_panel.gd`, `dialogues.json`)** : Support des nœuds `skill_check`, `fail_next`, `fail_effects`, `flaw_extra_effects`, `require_action` et `bonus_if_*` sur 10 scènes clés du Jalon 0 + Canal/Poudrerie (`box_garage_mobs`, `box_garage_radio`, `galaxian_flipper`, `tour_b_concierge`, `chez_bebert_franck`, `ruelle_ludo`, `garage_bananes_manu`, `squat_kepons_zoe`, `squat_kepons_fanzine`, `poudrerie_bunker`) ; affichage des badges `[🎲 XX% · Prénom +Y]`, alerte `⚠ FAILLE`, info-bulles de formule et bandeau résultat Coup d'éclat (`+10 XP`) / Échec / Faille dans `DialoguePanel`.
- **Frise Chronologique de Tension (`tension_timeline.gd`, `timeline_panel.gd`, `timeline_encounters.json`)** : Câblage des difficultés `dc_social` / `dc_pression` et des jets `2d6 + Carac + Comp` sur `act_tchatche`, `act_pression`, `act_repli` et **8 actions d'équipement jouables `★`** (`1×/confrontation`, touches `[1–6]`) avec Coups d'éclat, Couacs de faille (`Moral`) et bonus de compétences sur les Interruptions hors-tour.
- **Validation & Tests (`process_banlieue_assets.py`, `smoke_test_menus.gd`)** : Contrôle statique étendu à `equipment.json`, `skill_check`, `fail_next` et `require_action` ; extension du test smoke automatisé et synchronisation documentaire (`fiches_personnages_pj.md`, `ux_combat_frise.md`, `architecture_technique.md`, `.agents/artefacts/*`).

## [0.5.0] - 2026-11-22
### Fiches de Personnages PJ, Progression XP, Équipement Actif & Carnet de Bande `[F]`
- **Données & Catalogue d'Équipement ([equipment.json](file:///e:/JDR/BANLIEUE/game/data/equipment.json), `characters.json`, `player_profiles.json`, `dialogues.json`)** : Définition des **10 compétences bipolaires (`-3` à `+5`)**, de **24 équipements actifs** répartis sur 3 emplacements (`Look`, `Outil`, `Fétiche`) et enrichissement complet des 4 archétypes du Leader + 6 compagnons PJ (`Esprit / Corps / Énergie`, `skills`, `default_equipment`, `bio`, `arc_summary`, `relations`), plus conditions/effets de dialogues (`min_skill`, `require_item`, `add_xp`, `grant_item`, `add_trait`).
- **Moteur de Fiches & Persistance (`data_loader.gd`, `game_state.gd`, `dialogue_runner.gd`, `tension_timeline.gd`)** : Calcul des valeurs effectives (`get_effective_characteristic`, `get_effective_skill`, `get_best_active_group_skill`, `get_effective_aura_for`, `get_effective_moral_max`, `get_effective_stress_threshold`), dépense d'XP (`upgrade_member_skill`), gestion du coffre partagé (`box_stash`, `equip_item`, `unequip_slot`), gains d'XP/traits en fin de Frise et persistance rétrocompatible dans `SaveManager`.
- **Interface « Carnet de Bande `[F]` » (`character_sheet_panel.gd`, `hud_overlay.gd`, `new_game_panel.gd`, `main.gd`)** : Modale double-page fanzine `1060×616` avec onglets portraits (`1..6`, flèches `Gauche/Droite`), barres de caractéristiques & compétences bipolaires, boutons d'XP, échange d'équipement du coffre en 1 clic, traits et thermomètre relationnel ; intégration HUD (`Fiches [F]`), raccourci `F` / `Échap` et aperçu `Esprit/Corps/Énergie` sur *Nouvelle partie*.

## [Docs] - 2026-11-22
### Consolidation Design Fiches PJ (`v0.5.0`) & Synchronisation de `docs/`
- **Spécification complète [fiches_personnages_pj.md](file:///e:/JDR/BANLIEUE/docs/fiches_personnages_pj.md)** : Modèle hybride **Option B + C** centré sur **3 Caractéristiques** (`Esprit`, `Corps`, `Énergie`), **10 compétences bipolaires (`-3` à `+5`)** avec profils de départ et failles pour les 4 archétypes du Leader + les 6 compagnons PJ, progression **XP + Équipement à effets actifs** (*Look / Outil / Fétiche* apportant bonus chiffrés ou nouvelles compétences/actions), thermomètre relationnel et maquette UI du **Carnet de Bande `[F]`**.
- **Synchronisation documentaire transversale** : Alignement de [pitch_bible.md](file:///e:/JDR/BANLIEUE/docs/pitch_bible.md), [personnages_et_relations.md](file:///e:/JDR/BANLIEUE/docs/personnages_et_relations.md), [structure_menus_et_ecrans.md](file:///e:/JDR/BANLIEUE/docs/structure_menus_et_ecrans.md), [monde_et_economie.md](file:///e:/JDR/BANLIEUE/docs/monde_et_economie.md), [direction_artistique_sonore.md](file:///e:/JDR/BANLIEUE/docs/direction_artistique_sonore.md) et [architecture_technique.md](file:///e:/JDR/BANLIEUE/docs/architecture_technique.md) sur les évolutions récentes (`5 secteurs / 9 lieux`, `Attitude/Aura`, formation `1–6`, combat unifié Option A et préparation `v0.5.0`).

## [0.4.2] - 2026-11-22
### UX Combat — « Option A : Frise-Cartes Unifiée » (`1280×720`)
- **Suppression des doublons & libération de la scène** (`timeline_panel.gd`, `iso_district_view.gd`) : Retrait de la colonne ennemie droite et de la double rangée de portraits pour concentrer l'interface en deux espaces dédiés au bas de l'écran : la **Frise-Cartes Unifiée** (`y = 444..614`, avec barre d'état fine tout en haut `y = 8..44`) puis les **Actions dans le timing de la Frise** + prévisualisation (`y = 620..712`). Recentrage de `IsoDistrictView` en mode combat (`zoom = 0.85`, décalage `Vector2(0.0, 120.0 / cz)`).
- **Fiches protagonistes complètes sur le rail** (`tension_timeline.gd`, `timeline_panel.gd`) : Enrichissement de `get_ordered_rail_entries()` avec fusion des crises sur les fiches alliées (`in_crisis`, `attitude`, `aura`, `moral`, `stress_threshold`, `reaction_ready`), stats de résolution segmentées/intentions sur les fiches ennemies cliquables, et boutons hors-frise (`⚡ Interruption` + `🛡 Retenir`) directement intégrés à chaque fiche alliée.
- **Documentation & Tests** : Mise à jour de [ux_combat_frise.md](file:///e:/JDR/BANLIEUE/docs/ux_combat_frise.md), `architecture_technique.md`, `.agents/artefacts/*` et vérifications dédiées dans `smoke_test_menus.gd`.

## [0.4.1] - 2026-11-22
### Lexique & Refactorisation complète (`FAVE → Attitude`, `FASA → Aura`)
- **Renommage complet dans les données JSON (`characters.json`, `player_profiles.json`, `dialogues.json`, `timeline_encounters.json`)** : Migration de toutes les propriétés (`"fave"` → `"attitude"`, `"fasa"` → `"aura"`, `"fasa_bonus"` → `"aura_bonus"`, `"min_fasa"` → `"min_aura"`) et de tous les libellés joueurs vers **Attitude** et **Aura**, tout en conservant intactes les clés et mentions des **Faveurs** (`faveurs`, `min_faveurs`, `faveurs_bonus`).
- **Renommage complet dans le moteur GDScript (`data_loader.gd`, `game_state.gd`, `dialogue_runner.gd`, `tension_timeline.gd`, `hud_overlay.gd`, `new_game_panel.gd`, `main.gd`)** : Conversion vers `aura_bonus`, `get_total_aura()`, `min_aura` et affichages UI `Attitude` / `Aura` (avec repli rétrocompatible dans `GameState.load_from_save_dict()` sur d'éventuelles cassettes locales `fasa_bonus`).
- **Documentation & Tests** : Mise à jour de l'ensemble de la documentation de conception (`pitch_bible.md`, `personnages_et_relations.md`, `niveau_pilote.md`, `monde_et_economie.md`, `direction_artistique_sonore.md`, `structure_menus_et_ecrans.md`, `architecture_technique.md`) et extension de `smoke_test_menus.gd` (`aura_bonus`, `attitude`, `aura`, `get_total_aura()`).

## [0.4.0] - 2026-11-22
### Refonte UX Combat & Frise Chronologique de Tension (`1A / 2A / 3B / 4A`)
- **Spécification UX & Agent dédié** : Création de l'agent [banlieue-combat-ux.md](file:///e:/JDR/BANLIEUE/.agents/agents/banlieue-combat-ux.md) et rédaction de [ux_combat_frise.md](file:///e:/JDR/BANLIEUE/docs/ux_combat_frise.md).
- **Scène ouverte / HUD cinémascope `1280×720` (`1A`)** (`timeline_panel.gd`, `iso_district_view.gd`, `main.gd`) : Masquage du HUD d'exploration en combat et recentrage caméra (`set_combat_stage_mode`, zoom `0.88`) ; rail bande magnétique horizontal scrollable en bandeau haut (`y = 8..116`), cartes ennemies flottantes à droite (`x = 958..1268`), tiroir `Journal` repliable, bark BD 1 ligne + barre pas-à-pas bas-centre et dock tactique bas (`y = 492..712`).
- **Ciblage libre + prévisualisation au survol (`2A`)** (`tension_timeline.gd`, `timeline_panel.gd`, `timeline_encounters.json`) : Sélection explicite d'ennemi par clic ou `Tab` (`select_target`, `cycle_target`, `get_selected_target`), jauges de Résolution segmentées, `intent_label`, badge rouge `counter_label` et prévisualisation en lecture seule (`preview_player_action`, `preview_interruption`, `preview_restrain`) affichant `Cran X → Y`, impact Résolution et alerte `⚠ CONTRE-INTERRUPTION` sur le rail et les cartes.
- **Résolution pas-à-pas strict (`3B`)** (`tension_timeline.gd`, `main.gd`) : Chaîne `awaiting_step` / `step_next_beat()` exécutant un seul beat non-allié à la fois (crise, action ennemie, avancée d'un cran, renforts ou Train Fantôme) sur appui `Espace` / `Entrée` ou bouton `▶`, avec micro-secousse caméra (`combat_feedback_emitted`, `SettingsManager.screen_shake`) et garde d'entrées `input_blocked` lorsque Pause/Options est ouvert.
- **Interruptions & Crises intégrées aux portraits (`4A`)** (`tension_timeline.gd`, `timeline_panel.gd`) : Dock bas de 1 à 6 portraits alliés (jauge Moral, seuil Stress, bouton d'Interruption cliquable sous le portrait, vibration fanzine + bouton direct `🛡 Retenir` en préavis de Crise d'autonomie, et crises dédiées pour `manu`, `zoe` et `ludo`).

## [0.3.0] - 2026-11-22
### Expansion Canal de l'Ourcq & Lisière de la Poudrerie (Option C) + Polish Jalon 0 (Option D)
- **3 nouveaux lieux isométriques 2:1 (`1200×896`, `8×8` `backdrop`)** :
  - `game/assets/locations/garage_bananes.png` + `game/data/maps/interiors/garage_bananes.json` (*Le Garage des Bananes* — **Manu** recrutable, établi/mobylettes, `occluders[]` murets, volets et 103 SP rouge).
  - `game/assets/locations/squat_kepons.png` + `game/data/maps/interiors/squat_kepons.json` (*Entrepôt-Squat des Kepons* — **Zoé** recrutable, sérigraphie & fanzines, `occluders[]` murets & double porte).
  - `game/assets/locations/lisiere_poudrerie.png` + `game/data/maps/interiors/lisiere_poudrerie.json` (*Grilles & Bunkers de la Poudrerie* — brèche, fûts rouillés, bunker cadenassé et flaque nocturne ambiguë, `occluders[]` fûts & buisson avant).
- **Atlas Cradon-lès-Gonesse étendu à 5 secteurs & 9 lieux (`cradon_les_gonesse.json`)** : Ajout du 5e secteur `Canal de l'Ourcq & Zone Ind.`, du tracé `water` Canal de l'Ourcq dans `world_map_view.gd`, des 3 cartes cliquables et de la matrice complète des distances `neighbors` sur les 9 JSON intérieurs.
- **Écriture des dialogues & recrutements (`dialogues.json`)** : Rencontres/recrutements de **Manu** (affinité `[Les Mains-Noires]` `bg_atelier`, `mobs_tuned`, FASA/Francs) et **Zoé** (affinité `[L'Échappé·e des Pavillons]` `bg_pavillons`, `inspected_notice`, Faveur) avec frictions croisées `Manu ↔ Zoé`, plus scènes à double lecture Jour/Nuit à la Poudrerie (réaction `Nadia` + `104.7 FM`).
- **Socle Option D consolidé (`0.2.3`)** : Calibrage `occluders[]` sur `galaxian.json` & `ruelle_relais.json`, bande fluide 1–6 (`touches 1–6`, formation 6 places, libellés HUD dynamiques), contraste nocturne des cartes IGN et réactivité `[Enfant de la Dalle]` & `[Grande Gueule du Bourg]`.

## [0.2.3] - 2026-11-21
### Polish Jalon 0 (Option D) & Recrutables Canal (Vague 1 Option C)
- **Profondeur premier plan (`occluders[]`) & Hotspots** : Calibration au pixel des `occluders` sur `game/data/maps/interiors/galaxian.json` (murets avant, comptoir-caisse, baby-foot) et `ruelle_relais.json` (poubelles/caisses et fourgon Type H municipal) ; recalage entier des hotspots de `galaxian.json` (`hs_notice`, `hs_flipper`).
- **Support fluide jusqu'à 6 membres de bande** : Extension de la formation isométrique (`iso_district_view.gd`), des raccourcis clavier `1–6` (`main.gd`), des libellés dynamiques du panneau latéral (`hud_overlay.gd`) et du bilan final du Jalon 0.
- **Lisibilité cartographique (`world_map_view.gd`)** : Contraste nocturne renforcé des cartes IGN/RER, rendu dédié du tracé `water` pour le **Canal de l'Ourcq** en N3 et coches d'accomplissement étendues.
- **Réactivité des Archétypes (`dialogues.json`)** : Ajout de choix dédiés `[Enfant de la Dalle]` (`tour_b_concierge`, flag `bg_dalle`) et `[Grande Gueule du Bourg]` (`chez_bebert_franck`, flag `bg_bourg`).
- **Personnages Manu & Zoé prêts (`characters.json`)** : Génération, détourage RGBA (`526 px` sans socle) et intégration de `manu.png` / `manu_pawn.png` et `zoe.png` / `zoe_pawn.png` (catalogue porté à **9 personnages** ; les 3 décors Canal/Poudrerie de la Vague 2 restent planifiés après reset quota).

## [0.2.2] - 2026-11-21
### Assets & Cartographie
- **Décor isométrique 2:1 `Le Galaxian` (`galaxian.png`, `1200×896`)** : Finalisation des 6/6 intérieurs du Jalon 0 en mode `backdrop` ; contrôle d'échelle à `162 px`, bascule de `game/data/maps/interiors/galaxian.json` en `render_mode: "backdrop"` (`8×8`) et recalage des collisions, lumières, sortie, hotspots (`hs_notice`, `hs_flipper`) et `npc_ludo_galaxian`.
- **3 cartes réalistes IGN État-Major / Réseau RER 1982** : Production et alignement géométrique strict sur les coordonnées JSON de `game/assets/maps/map_idf.png` (`1000×760`), `map_93.png` (`1000×760`) et `map_cradon.png` (`1040×760`), reliées via `"backdrop"` dans `game/data/world/idf.json`, `departments/93.json` et `cities/cradon_les_gonesse.json`.

## [0.2.1] - 2026-11-21
### Assets & Visuels
- **Galerie complète des 6 profils joueur (`player_01..06`)** : Génération, contrôle visuel et détourage RGBA (`526 px` sans socle, nettoyage des poches magenta fermées dans `process_banlieue_assets.py`) des 5 nouveaux portraits BD (`player_02..06.png`) et de leurs 5 pions en pied assortis (`player_02..06_pawn.png`) ; retrait de `"pending_asset"` dans `game/data/player_profiles.json`.
- **Décor isométrique `Ruelle du Relais Municipal`** : Production de `game/assets/locations/ruelle_relais.png` (`1200×896`) assorti à `box_garage.png`, contrôle d'échelle à `162 px` et bascule de `game/data/maps/interiors/ruelle_relais.json` en `render_mode: "backdrop"` (`8×8`).
- **Préparation cartes réalistes IGN / Réseau RER (`world_map_view.gd`)** : Adaptation de `WorldMapView` pour afficher proprement des fonds cartographiques illustrés (`has_backdrop`) et extension de `process_banlieue_assets.py --mode validate` aux cartes N1–N3.

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
