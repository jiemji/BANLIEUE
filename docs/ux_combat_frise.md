# UX Combat & Frise Chronologique de Tension — Spécification `v0.6.0`

> Référence technique et ergonomique pour l'interface de confrontation tactique isométrique de *Banlieue* (Cradon-lès-Gonesse, 1980–1984).

---

## 1. Piliers validés (`v0.6.0` — Combat Tactique Isométrique)

| Axe | Choix | Principe UX |
|---|---|---|
| **Frise Chronologique Haute** | **Cartes rectangulaires verticales (`82×104 px`, `y = 8..126`)** | Positionnée tout en haut : chaque carte n'affiche que le **portrait** (PJ ou PNJ), le **nom** et une **jauge** (Moral PJ ou Résolution PNJ). La hauteur dépasse la largeur, avec encadrement doré sur l'acteur au tour. |
| **Scène Centrale Isométrique** | **Quadrillage `2:1` + 2 axes + surbrillance (`y = 126..478`)** | Tous les protagonistes sont déployés sur le quadrillage : **héros présents sur l'axe bas → gauche**, **PNJ sur l'axe haut → droite**. Le personnage actif est mis en surbrillance (halo sol + chevron `▼` + contour épaissi). |
| **Ciblage & Survol Direct sur Pion** | **Clic pion requis + Fiche miroir bas-droite** | Toute option concernant un PJ ou PNJ passe par le **clic direct sur son pion** sur le quadrillage (cibles allumées, clic droit ou `Échap` pour annuler). Survoler un pion (ou sa carte) affiche sa fiche détaillée à **droite en bas** au même format que la fiche active. |
| **Triptyque Bas (`y = 478..712`)** | **Actif (gauche) · Minutes (centre) · Survolé (droite)** | À gauche (`x=10..404`) : stats, actions `[1–6]` (`%` / `★` / `🎯`) et hors-frise du personnage actif (PJ ou PNJ). Au centre (`x=412..868`) : **Minutes du combat** déroulantes, dernier bark et `[Espace]`. À droite (`x=876..1270`) : fiche miroir du personnage survolé + aperçu `🎲 %`. |

---

## 2. Gabarit écran `1280×720`

```
+-----------------------------------------------------------------------------+
| [y=8..126] FRISE CHRONOLOGIQUE HAUTE — Cartes rectangulaires verticales     |
|  Tour · CRS · Échappée | [Portrait+Nom+Jauge] [Portrait+Nom+Jauge] ...      |
+-----------------------------------------------------------------------------+
|                                                                             |
|           SCÈNE CENTRALE (y=126..478) — QUADRILLAGE ISOMÉTRIQUE 2:1         |
|                                        PNJ alignés axe haut → droite        |
|                                                                             |
|     Héros présents alignés axe bas → gauche   (Pion actif en surbrillance)  |
|                                                                             |
+------------------------+-------------------------+--------------------------+
| [x=10..404, y=478..712]| [x=412..868, y=478..712]| [x=876..1270, y=478..712]|
| FICHE PERSONNAGE ACTIF |   MINUTES DU COMBAT     | FICHE PERSONNAGE SURVOLÉ |
| Portrait + Stats utiles| Dernier Bark / Verdict  | Portrait + Stats utiles  |
| Actions [1-6] (★ / 🎯) | Journal déroulant       | Intention / Spécialité   |
| Hors-frise (⚡ / 🛡)    | [Espace] Beat suivant ▶ | Aperçu Jet 🎲 % ciblé    |
+------------------------+-------------------------+--------------------------+
```

### Règles de visibilité & scène isométrique
* **`main.gd`** : lors de `encounter_requested`, `_hud.visible = false`, `_timeline.start_encounter(eid)` puis `_iso_view.set_combat_stage_mode(true)` ; au retour, restauration inverse.
* **`iso_district_view.gd`** : en `_combat_stage_mode`, `_markers_overlay` et `_occluder_nodes` sont masqués, la caméra passe au zoom `0.82` centré dans l'ouverture `y = 126..478`, et `_sync_combat_pawns()` / `_draw_combat_iso_grid()` déploient les pions et les standees PNJ sur les deux axes.

---

## 3. Fiches unifiées & API `TensionTimeline`

* **`get_active_turn_entity()`** : identifie le PJ ou PNJ actif au tour courant (crise prioritaire, action PNJ, allié au cran `0` ou prochain acteur en attente).
* **`get_entity_sheet_data(kind, entity_id)`** : alimente symétriquement la fiche bas-gauche (actif) et la fiche bas-droite (survolé) avec `Moral/Seuil`, `Attitude/Aura`, `Esprit/Corps/Énergie`, compétences marquantes, équipements, ou `Résolution`, `DD Social/Pression`, intention et contre-interruption pour les PNJ.
* **Ciblage sur pion** : `get_action_target_kind()`, `get_interruption_target_kind()`, `get_valid_target_ids()`, `preview_player_action_on()`, `execute_player_action_on()`, `preview_interruption_on()`, `trigger_interruption_on()`.

---

## 4. Contrôles clavier & souris

| Entrée | Action | Condition |
|---|---|---|
| `Clic gauche` pion | Cible et exécute l'option choisie (ou inspecte le PNJ) | Mode combat actif (`126 ≤ y ≤ 478`) |
| `Survol` pion ou carte Frise | Affiche la fiche miroir en bas à droite + aperçu Jet `🎲 %` | Mode combat actif |
| `Clic droit` ou `Échap` | Annule le ciblage en cours | Si ciblage actif (`has_pending_targeting()`) |
| `Espace` / `Entrée` | `step_next_beat()` (beat suivant) | `visible` et `awaiting_step` et hors ciblage |
| `1` – `6` | Sélectionne l'option `[1..6]` de la fiche active (exécute ou passe en clic pion) | `visible` et `not awaiting_step` |
| `Échap` | Menu Pause (`main.gd`) | Hors ciblage, verrouille `combat_input_blocked = true` |
