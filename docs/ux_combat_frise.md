# UX Combat & Frise Chronologique de Tension — Spécification `v0.10.0`

> Référence technique et ergonomique pour l'interface de confrontation tactique isométrique de *Banlieue* (Cradon-lès-Gonesse & 93, 1980–1984).

---

## 1. Piliers validés (`v0.6.0` → `v0.10.0` — Combat Tactique Isométrique)

| Axe | Choix | Principe UX |
|---|---|---|
| **Frise Chronologique Haute** | **Cartes rectangulaires verticales (`82×104 px`, `y = 8..126`)** | Positionnée tout en haut : portrait (PJ ou PNJ), nom, jauge (Moral PJ ou Résolution PNJ) et badge `💫` si Assommé. La hauteur dépasse la largeur, avec encadrement doré sur l'acteur au tour. |
| **Grille Tactique & Déplacement (`v0.8.0`)** | **Coordonnées entières `8×8` + `PM = 2–3` / tour** | `TensionTimeline` porte la position `(grid_x, grid_y)` de chaque pion. Pendant son tour, un PJ dispose de `2` ou `3 PM` (selon `Corps` / `Caves & Esquive`) pour cliquer une case bleue accessible avant ou après son action. |
| **Portées & Arsenal 1982 (`v0.8.0`)** | **3 bandes + Tir sur outil équipé** | **Corps à corps** (`1` case), **Lancer** (`2–4` cases), **Tir** (`2–6` cases, **verrouillé à un outil de tir 1982** comme le *Lance-pierre artisanal* ou les *Pétards Mammouth*), **Charge** (`2–5` cases), **Tchatche** (`1–5` cases) et **Échappée** (toute portée). |
| **Charge & Interception 10 s (`v0.8.0`)** | **Symétrie PJ/PNJ · Assommé (`-2 rangs`)** | Une **Charge** fait bondir l'acteur sur la case adjacente libre la plus proche d'un adversaire. Si l'adversaire déclenche et réussit son **Interception**, le chargeur est **Assommé**, la charge échoue et il recule de **`+2 crans` (`-2 rangs`)** sur la Frise. Lors d'une Charge PNJ → PJ, un **bandeau d'alerte de `10,0 s`** + flèche rouge sur la grille laissent au joueur le temps de déclencher l'Interception depuis tout PJ avec Réaction prête (ou d'encaisser). |
| **Couverts (`🛡`) & Interactifs (`⚙`) (`v0.10.0`)** | **Terrain tactique piloté par JSON** | Les `cover_tiles[]` octroient `+defense_bonus` au DD contre les attaques `min_range >= 2` et amortissent de `moral_absorb` les dégâts moraux des PJ abrités (badges `🛡` sur grille et fiches). Les `combat_interactables[]` (`⚙`) s'activent à portée (`max_range`) par clic sur la case ou bouton dédié (Jet de rue `2d6`). |
| **Triptyque Bas (`y = 478..712`)** | **Actif (gauche) · Minutes (centre) · Survolé (droite)** | À gauche (`x=10..404`) : stats, PM restants, actions filtrées par portée (`%` / `★` / `🎯` / `🔒`), interactifs `⚙`, fin de tour et hors-frise. Au centre (`x=412..868`) : **Minutes du combat**, dernier bark et `[Espace]`. À droite (`x=876..1270`) : fiche miroir du personnage survolé, **distance en cases**, statut couvert `🛡`, avertissement d'interception sur Charge et aperçu `🎲 %`. |

---

## 2. Gabarit écran `1280×720`

```
+-----------------------------------------------------------------------------+
| [y=8..126] FRISE CHRONOLOGIQUE HAUTE — Cartes rectangulaires verticales     |
|  Tour · CRS · Échappée | [Portrait+Nom+Jauge] [Portrait+Nom+Jauge] ...      |
+-----------------------------------------------------------------------------+
|  [Alerte Charge PNJ 10,0 s (si active) : Barre + Boutons Intercepter]       |
|           SCÈNE CENTRALE (y=126..478) — QUADRILLAGE ISOMÉTRIQUE 8×8         |
|   Cases bleues = PM atteignables · Flèche rouge = trajectoire Charge PNJ    |
|   Héros mobiles (dép. gy=6) ↔ PNJ mobiles (dép. gy=2) · Badge 💫 Assommé    |
+------------------------+-------------------------+--------------------------+
| [x=10..404, y=478..712]| [x=412..868, y=478..712]| [x=876..1270, y=478..712]|
| FICHE PERSONNAGE ACTIF |   MINUTES DU COMBAT     | FICHE PERSONNAGE SURVOLÉ |
| Portrait · PM · Stats  | Dernier Bark / Verdict  | Portrait · Dist. (cases) |
| Actions (1c/2-4c/2-6c) | Journal déroulant       | Intention / Contre / 💫  |
| Fin tour · Hors-frise  | [Espace] Beat suivant ▶ | Aperçu Jet 🎲 % ciblé    |
+------------------------+-------------------------+--------------------------+
```

### Règles de portée & de résolution Charge (`v0.8.0`)

| Action | Compétence / Carac. | Portée (Chebyshev) | Condition / Effet |
|---|---|---|---|
| **Corps à corps** (`act_pression`) | `baston_pression` (`Corps`) | `1` case | `-2/-3` Résol + recul `+1/+2 crans` |
| **Lancer** (`act_lancer`) | `caves_esquive` (`Corps`) | `2–4` cases | Jet canette/pavé : `-2/-3` Résol (+1 cran si Coup d'éclat), `+1` avec *Pétards Mammouth* |
| **Tir** (`act_tir`) | `systeme_d` (`Esprit`) | `2–6` cases | **Exige un outil `ranged_shoot`** : `-2/-3` Résol, coupe `counter_ready` en Coup d'éclat |
| **Charge** (`act_charge`) | `baston_pression` (`Corps`) | `2–5` cases | Saute sur case adjacente libre → choc `-3/-4` Résol (+1/+2 crans). Stoppé si intercepté → **Assommé + `+2 crans` (`-2 rangs`)** |
| **Tchatche** (`act_tchatche`) | `tchatche` (`Esprit`) | `1–5` cases | `-2/-3` Résol (`+1` si Faveur/dossier) |
| **Échappée** (`act_repli`) | `caves_esquive` (`Corps`) | Toute portée | `+2/+3` crans CRS, `+1` Échappée |

### Règles de visibilité & scène isométrique
* **`main.gd`** : lors de `encounter_requested`, `_hud.visible = false`, `_timeline.start_encounter(eid)` puis `_iso_view.set_combat_stage_mode(true)` ; au retour, restauration inverse. Met en pause le chrono de Charge PNJ (`charge_timer_paused`) si un menu modal s'ouvre.
* **`iso_district_view.gd`** : en `_combat_stage_mode`, `_markers_overlay` et `_occluder_nodes` sont masqués, la caméra passe au zoom `0.82` centré dans l'ouverture `y = 126..478`, et `_sync_combat_pawns()` / `_draw_combat_iso_grid()` affichent les pions interpolés sur leurs vraies cases `(grid_x, grid_y)`, les cases de déplacement atteignables, la flèche de charge et la case d'atterrissage.

---

## 3. Fiches unifiées & API `TensionTimeline`

* **`get_active_turn_entity()`** : identifie le PJ ou PNJ actif au tour courant (fenêtre de Charge PNJ active, crise prioritaire, action PNJ, allié au cran `0` ou prochain acteur en attente).
* **`get_entity_sheet_data(kind, entity_id)`** : alimente symétriquement la fiche bas-gauche (actif) et la fiche bas-droite (survolé) avec `grid_x`, `grid_y`, `stunned`, `move_points_left`, `move_points_max`, `Moral/Seuil`, `Attitude/Aura`, `Esprit/Corps/Énergie`, compétences marquantes, équipements, ou `Résolution`, `DD Social/Pression`, intention et contre-interruption pour les PNJ.
* **Déplacement & Ciblage sur grille** : `get_reachable_cells_for_active_ally()`, `move_active_ally_to()`, `end_active_ally_turn_wait()`, `get_action_range()`, `get_valid_target_ids_for_action()`, `find_closest_adjacent_cell()`.
* **Couverts & Interactifs de décor (`v0.10.0`)** : `get_cover_at_cell()`, `get_entity_cover_info()`, `get_combat_interactable_at()`, `get_available_combat_interactables()`, `trigger_combat_interactable()`.
* **Fenêtre Charge PNJ 10 s** : signaux `charge_window_started`, `charge_window_ticked`, `charge_window_ended`, méthodes `is_charge_window_active()`, `get_charge_interceptor_candidates()`, `trigger_charge_interception()`, `resolve_pending_enemy_charge()`.

---

## 4. Contrôles clavier & souris

| Entrée | Action | Condition |
|---|---|---|
| `Clic gauche` case bleue | Déplace le PJ actif sur une case accessible (`PM`) | Tour PJ actif, hors ciblage et hors alerte Charge |
| `Clic gauche` pion | Cible et exécute l'action / Déclenche l'interception sur le PNJ en charge / Inspecte | Mode combat actif (`126 ≤ y ≤ 478`) |
| `Survol` pion, case ou carte Frise | Fiche miroir bas-droite + distance en cases + aperçu `🎲 %` / atterrissage Charge | Mode combat actif |
| `Clic droit` ou `Échap` | Annule le ciblage en cours | Si ciblage actif (`has_pending_targeting()`) |
| `Espace` / `Entrée` | `step_next_beat()` (beat suivant) | `visible` et `awaiting_step` et hors ciblage et hors Charge 10 s |
| `1` – `9` | Sélectionne l'option `[1..9]` de la fiche active (exécute ou passe en clic pion) | `visible` et `not awaiting_step` et hors Charge 10 s |
| `Échap` | Menu Pause (`main.gd`) — met en pause le chrono 10 s | Hors ciblage, verrouille `combat_input_blocked = true` |
