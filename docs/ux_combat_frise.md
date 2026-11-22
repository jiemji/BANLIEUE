# UX Combat & Frise Chronologique de Tension — Spécification `v0.4.0`

> Référence technique et ergonomique pour l'interface de confrontation tactique de *Banlieue* (Cradon-lès-Gonesse, 1980–1984), validée avec le Collège du Studio et `banlieue-combat-ux`.

---

## 1. Piliers validés (`1A / 2A / 3B / 4A`)

| Axe | Choix | Principe UX |
|---|---|---|
| **1A — Mise en scène** | **Scène ouverte / HUD cinémascope (`1280×720`)** | Le HUD d'exploration est masqué en combat ; `IsoDistrictView` reste pleinement visible et centré au milieu de l'écran derrière une ceinture périphérique légère inspirée bande magnétique & fanzine 1982. |
| **2A — Ciblage & Lisibilité** | **Ciblage libre + prévisualisation au survol** | Clic direct sur carte ennemie ou pion du rail (ou `Tab`) ; jauges de Résolution segmentées, `intent_label`, badge rouge `counter_label`, et prévisualisation non destructive (`Cran X → Y`, dégâts, `⚠ CONTRE-INTERRUPTION`). |
| **3B — Tempo de résolution** | **Pas-à-pas strict** | Aucune cascade automatique : chaque crise, action ennemie, renfort ou arrivée du Train Fantôme s'exécute **un beat à la fois** via `step_next_beat()`, laissant le temps de lire le bark et d'interrompre/retenir. |
| **4A — Bande & Crises** | **Interruptions & Crises sur portraits** | Le dock inférieur regroupe jusqu'à 6 cartes alliées avec portrait BD, jauge de Moral, indicateur de Stress, bouton d'Interruption direct, secousse fanzine et bouton `🛡 Retenir` intégré en cas de Crise d'autonomie. |

---

## 2. Gabarit écran `1280×720`

```
+-------------------------------------------------------------------------+
| [y=8..116] RAIL BANDE MAGNÉTIQUE (crans, pions, CRS, Évasion, Journal)   |
+---------------------------------------------------+---------------------+
|                                                   | [x=958..1268]       |
|                                                   | [y=124..446]        |
|          SCÈNE ISOMÉTRIQUE OUVERTE                | CARTES ENNEMIES     |
|          (IsoDistrictView centré z=0.88)          | cliquables          |
|                                                   | (Résolution,        |
|                                                   |  Intention, Contre) |
+---------------------------------------------------+---------------------+
| [y=442..486] BARK BD 1 LIGNE  +  Bouton [Espace] Beat suivant ▶         |
+-------------------------------------------------------------------------+
| [y=492..712] DOCK TACTIQUE BAS                                          |
|   [Portraits bande (1..6) : Moral/Stress/Interrupt/🛡 Retenir] | [1..4]  |
|   [Scroll horizontal]                                        | [Aperçu] |
+-------------------------------------------------------------------------+
```

### Règles de visibilité
* **`main.gd`** : lors de `encounter_requested`, `_hud.visible = false` et `_iso_view.set_combat_stage_mode(true)` ; au retour (`_on_encounter_finished`, `_enter_title_menu`, `_start_new_game`, `_on_slot_loaded`), restauration inverse.
* **`iso_district_view.gd`** : en `_combat_stage_mode`, `_markers_overlay` est masqué et la caméra passe au zoom `0.88` avec centrage compensant uniquement le dock bas et le bandeau haut (`Vector2(0.0, 56.0 / z)`).
* **Tiroir `Journal`** : replié par défaut derrière un bouton dans le bandeau haut afin de libérer la scène isométrique.

---

## 3. Ciblage libre & Prévisualisation au survol (`2A`)

### Ciblage
* L'état `selected_target_id` pointe toujours vers un ennemi actif (`resolve > 0`). Si la cible tombe à 0 ou devient invalide, la première cible active restante est automatiquement sélectionnée.
* **`act_tchatche`**, **`act_pression`**, l'interruption **`moquerie`** (Karim) et l'interruption **`sang_froid`** (Leader) s'appliquent à `get_selected_target()`.

### Prévisualisation en lecture seule
Les méthodes `preview_player_action(action_id)`, `preview_interruption(char_id)` et `preview_restrain(crisis_char_id)` retournent un `Dictionary` sans muter `TensionTimeline` :
* **`valid`** (`bool`) & **`reason`** (`String`) si indisponible.
* **`target_name`** (`String`) : nom de l'ennemi ciblé ou du membre en crise.
* **`from_tick` / `to_tick`** (`int`) : glissement projeté sur la frise (`Cran X → Y`).
* **`resolve_delta`** (`int`) : impact estimé sur la Résolution de la cible.
* **`crs_delta` / `shield_delta` / `escape_delta`** (`int`) : variation de pression CRS, bouclier d'interposition ou progression d'évasion.
* **`counter_warning`** (`bool`) & **`counter_label`** (`String`) : alerte rouge si la cible porte `has_counter_interrupt = true` et risque de déclencher une contre-interruption.

---

## 4. Boucle pas-à-pas strict `awaiting_step` (`3B`)

1. Après `start_encounter()`, `execute_player_action()`, `trigger_interruption()` ou `restrain_crisis()`, la frise met à jour :
   * `_pending_crisis_ids` : membres ayant atteint le seuil de Crise d'autonomie et présents dans `crisis_queue`.
   * `_pending_enemy_ids` : ennemis actifs positionnés sur `tick == 0`.
2. `_sync_step_state()` fixe `awaiting_step = (_pending_crisis_ids.size() > 0) or (_pending_enemy_ids.size() > 0) or get_acting_ally().is_empty()` et renseigne `pending_beat_label` pour l'affichage sur le bouton `▶`.
3. Chaque appel à **`step_next_beat()`** exécute **exactement un beat** :
   * Priorité 1 : résoudre le premier membre dans `_pending_crisis_ids` (`_execute_autonomous_crisis`).
   * Priorité 2 : exécuter l'intention du premier ennemi dans `_pending_enemy_ids`.
   * Priorité 3 : avancer le rail d'un cran (`_advance_one_world_tick`), vérifier Train Fantôme / renforts, recharger `_pending_crisis_ids` et `_pending_enemy_ids`.
4. À chaque événement significatif, `TensionTimeline` met à jour `last_event` et émet `combat_feedback_emitted(event_data)` (utilisé par `TimelinePanel` pour le bark BD/vibration fanzine et par `main.gd` pour une micro-secousse caméra respectant `SettingsManager.screen_shake`).

---

## 5. Portraits alliés, Interruptions & Crises (`4A`) & Raccourcis clavier

### Cartes alliées (Dock bas)
Chaque carte portrait affiche :
* Portrait du personnage (`DataLoader.get_character(id).portrait`), nom et rôle.
* Badge **`EN TOUR`** lorsqu'il s'agit de l'allié actif (`get_acting_ally()`).
* Jauge de **Moral** et indicateur numérique de **Stress**.
* Bouton d'Interruption dédié sous le portrait (`trigger_interruption(id)`), prévisualisable au survol (`preview_interruption(id)`).
* Si l'allié est en `crisis_queue` : cadre alerte rouge fanzine + micro-vibration (si `SettingsManager.screen_shake`) + bouton direct **`🛡 Retenir`** (`restrain_crisis(id)`).

### Raccourcis clavier
| Touche | Action | Condition |
|---|---|---|
| `Espace` / `Entrée` | `step_next_beat()` (beat suivant) | `visible` et `not input_blocked` et `awaiting_step` |
| `Tab` | `cycle_target()` (ennemi suivant) | `visible` et `not input_blocked` |
| `1` – `4` | Actions tactiques du tour (index 0..3) | `visible` et `not input_blocked` et `not awaiting_step` |
| `Échap` | Menu Pause (`main.gd`) | Verrouille `TimelinePanel.input_blocked = true` |
