# UX Combat & Frise Chronologique de Tension — Spécification `v0.4.2` / `v0.5.1`

> Référence technique et ergonomique pour l'interface de confrontation tactique de *Banlieue* (Cradon-lès-Gonesse, 1980–1984), validée avec le Collège du Studio et `banlieue-combat-ux` (**Option A : Frise-Cartes Unifiée**, enrichie `v0.5.1` par les Jets de rue `%` et actions d'équipement `★`).

---

## 1. Piliers validés (`v0.4.2` + `v0.5.1`)

| Axe | Choix | Principe UX |
|---|---|---|
| **Structure — Option A Unifiée** | **Frise-Cartes Unifiée (`1280×720`)** | Zéro redondance visuelle : la scène isométrique occupe tout l'espace supérieur (`y = 44..394`), suivie de deux espaces dédiés en bas : la **Frise-Cartes Unifiée** (`y = 444..614`) puis les **Actions dans le timing de la frise** (`y = 620..712`). |
| **Fiches complètes sans doublon** | **Portrait + Stats + Hors-frise sur chaque fiche** | Chaque protagoniste n'apparaît qu'une seule fois sur le rail chronologique (de gauche `MAINTENANT` à droite `CRS`). La fiche alliée intègre directement son portrait BD, `Moral / Seuil`, `Attitude / Aura` et ses boutons hors-frise (`⚡ Interruption` et `🛡 Retenir`). |
| **Ciblage & Prévisualisation** | **Ciblage libre + survol non destructif** | Clic direct sur une fiche ennemie du rail (ou `Tab`) ; Résolution segmentée, `intent_label`, alerte `⚠ Contre prête`, et prévisualisation au survol (`Cran X → Y`, impact Résolution, `⚠ CONTRE-INTERRUPTION`). |
| **Tempo de résolution** | **Pas-à-pas strict (`3B`)** | Aucune cascade automatique : chaque crise, action ennemie, renfort ou arrivée du Train Fantôme s'exécute **un beat à la fois** via `step_next_beat()`, laissant le temps de lire le bark et d'interrompre/retenir. |

---

## 2. Gabarit écran `1280×720`

```
+-------------------------------------------------------------------------+
| [y=8..44] BARRE D'ÉTAT FINE (Tour · Bouclier · Échappée · CRS · Journal)|
+-------------------------------------------------------------------------+
|                                                                         |
|              SCÈNE ISOMÉTRIQUE OUVERTE (pleine largeur 1280 px)         |
|              IsoDistrictView recentré (zoom 0.85, zéro colonne droite)  |
|                                                                         |
+-------------------------------------------------------------------------+
| [y=396..438] BARK BD 1 LIGNE  +  Bouton [Espace] Beat suivant ▶         |
+-------------------------------------------------------------------------+
| [y=444..614] ESPACE TIMELINE : FRISE-CARTES UNIFIÉE (Scroll horizontal) |
|   ◄ MAINTENANT (Cran 0) ──────────────────────────────── CRS (Cran +N) ►|
|   [Fiche Allié: Portrait, Mor/Att/Aura, ⚡ Interrupt, 🛡 Retenir]        |
|   [Fiche Ennemi cliquable: Portrait, Pips Résol, Intent, ⚠ Contre]      |
+-------------------------------------------------------------------------+
| [y=620..712] ESPACE ACTIONS DANS LE TIMING DE LA FRISE                  |
|   [1] Tchatche · %  [2] Pression · %  [3] Échappée · %  [4] ★ Equip · % |
|   + Encart Prévisualisation (% + formule 2d6, Faille ⚠, Contre-interrupt)|
+-------------------------------------------------------------------------+
```

### Règles de visibilité
* **`main.gd`** : lors de `encounter_requested`, `_hud.visible = false` et `_iso_view.set_combat_stage_mode(true)` ; au retour (`_on_encounter_finished`, `_enter_title_menu`, `_start_new_game`, `_on_slot_loaded`), restauration inverse.
* **`iso_district_view.gd`** : en `_combat_stage_mode`, `_markers_overlay` est masqué et la caméra passe au zoom `0.85` avec centrage vertical libérant les bandes basses (`Vector2(0.0, 120.0 / cz)`).
* **Tiroir `Journal`** : replié par défaut derrière le bouton `Journal ▸` de la barre haute afin de préserver la scène isométrique.

---

## 3. Spécification des Fiches Unifiées (`get_ordered_rail_entries`)

`TensionTimeline.get_ordered_rail_entries()` retourne une seule entrée par acteur, triée par `tick` croissant puis `sort_rank` croissant (`0` = acteur/crise au tour actif, `1` = allié en crise, `2` = allié présent, `3` = ennemi actif, `4` = renfort, `5` = patrouille CRS) :
* **Fiche Allié (`kind == "ally"`)** : regroupe `portrait`, `moral`, `moral_max`, `stress_threshold`, `attitude`, `aura`, `reaction_ready`, `specialty_name`, et fusionne les champs de crise (`in_crisis`, `crisis_ticks`, `crisis_label`) sur la même carte sans créer d'entrée séparée `kind == "crisis"`.
* **Fiche Ennemi (`kind == "enemy"`)** : regroupe `portrait`, `resolve`, `resolve_max`, `role`, `intent`, `counter_ready`, `counter_label` et `selected`.

---

## 4. Ciblage libre & Prévisualisation au survol

### Ciblage
* `selected_target_id` pointe toujours vers un ennemi actif (`resolve > 0`) et se réaligne automatiquement s'il tombe à 0.
* **`act_tchatche`**, **`act_pression`**, **`moquerie`** et **`sang_froid`** visent `get_selected_target()`.

### Prévisualisation en lecture seule (`v0.5.1` Jets de rue `%` & Failles)
`preview_player_action(action_id)`, `preview_interruption(char_id)` et `preview_restrain(crisis_char_id)` retournent un `Dictionary` sans muter `TensionTimeline` (`valid`, `reason`, `target_id`, `target_name`, `from_tick`, `to_tick`, `resolve_delta`, `crs_delta`, `shield_delta`, `escape_delta`, `moral_delta`, `counter_warning`, `counter_label`, `chance_pct`, `roll_formula`, `is_flaw`, `fail_summary`, `is_equipment`, `used`, `summary`), affiché à la fois dans l'encart de prévisualisation bas-droite (avec alerte rouge `⚠ FAILLE` si la compétence effective est `< 0`) et directement sur la fiche ciblée de la Frise.
* **Actions d'équipement `★` (`[1–6]`)** : chaque équipement équipé ouvrant une action tactique (`get_available_actions_for_actor()`) apparaît en bouton doré `★ ... · XX%`, jouable `1×` par confrontation et par porteur.
* **Interruptions hors-tour fiables modulées par compétences** : sans hasard (`Moquerie` `-2` si `tchatche ≥ 3`, `Interposition` `-8` si `baston_pression ≥ 3` ou `Corps ≥ 4`, `Réflexe de rue` `+3` CRS si `caves_esquive ≥ 3`, `Sang-froid` `+12` Moral si `sang_froid_nerfs ≥ 3`).

---

## 5. Boucle pas-à-pas strict `awaiting_step` & Raccourcis clavier

1. Après `start_encounter()`, `execute_player_action()`, `trigger_interruption()` ou `restrain_crisis()`, `_sync_step_state()` fixe `awaiting_step = (_pending_crisis_ids.size() > 0) or (_pending_enemy_ids.size() > 0) or get_acting_ally().is_empty()`.
2. Chaque appel à **`step_next_beat()`** résout un seul beat (1 crise dans `_pending_crisis_ids`, sinon 1 ennemi dans `_pending_enemy_ids`, sinon 1 cran temporel via `_advance_one_world_tick()`).

| Touche | Action | Condition |
|---|---|---|
| `Espace` / `Entrée` | `step_next_beat()` (beat suivant) | `visible` et `not input_blocked` et `awaiting_step` |
| `Tab` | `cycle_target()` (ennemi suivant) | `visible` et `not input_blocked` |
| `1` – `6` | Actions tactiques du timing actif (base + `★` équipement + `Filer`) | `visible` et `not input_blocked` et `not awaiting_step` |
| `Échap` | Menu Pause (`main.gd`) | Verrouille `TimelinePanel.input_blocked = true` |
