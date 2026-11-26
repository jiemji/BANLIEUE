# *Banlieue* — Guide Pratique de Modding & Création de Scénario

> **Objectif** : Créer un nouveau scénario jouable, un lieu isométrique N4, une commune N3, un personnage ou une tenue modulaire en **5 minutes** et **sans modifier une seule ligne de GDScript** dans `game/scripts/`.
>
> Modèle prêt à copier : [\_template\_scenario](file:///e:/JDR/BANLIEUE/game/data/scenarios/_template_scenario/scenario.json).

---

## 1. Créer un nouveau scénario en 5 minutes

1. **Dupliquer le gabarit** : copier le dossier `game/data/scenarios/_template_scenario/` vers `game/data/scenarios/mon_scenario/` (nom en minuscules sans `_` ni `.` au début).
   > **Convention** : tout dossier commençant par `_` ou `.` est automatiquement ignoré par `DataLoader.discover_scenarios()` dans le menu *Nouvelle Partie*, tout en restant vérifié par le validateur.
2. **Adapter l'identifiant du manifeste** : dans `mon_scenario/scenario.json`, remplacer `"id": "_template_scenario"` par `"id": "mon_scenario"`, puis renseigner `title`, `subtitle`, `era`, `synopsis`, `start_hierarchy`, `intro_dialogue_id` et `endings`.
3. **(Optionnel) Ordonner l'affichage** : ajouter `"mon_scenario"` dans [scenarios\_index.json](file:///e:/JDR/BANLIEUE/game/data/scenarios_index.json) (sinon le pack est quand même découvert automatiquement par ordre alphabétique).
4. **Valider avant de lancer Godot** :
   ```powershell
   python "e:\JDR\BANLIEUE\.agents\skills\banlieue-asset-pipeline\scripts\process_banlieue_assets.py" --mode validate --game-root "e:\JDR\BANLIEUE\game" --scenario mon_scenario
   ```

---

## 2. Arborescence d'un Pack Isolé (`game/data/scenarios/<id>/`)

| Fichier / Dossier | Rôle dans le pack | Remarque de résolution de chemin |
|---|---|---|
| `scenario.json` | Manifeste, coffre de départ, transitions Jour/Crépuscule/Nuit, fins (`endings`) | `id` doit correspondre exactement au nom du dossier |
| `radio_fm.json` | Stations FM (`freq`, `day_lines`, `night_lines`, `night_only`, `white_noise_ambience`) | Uniquement les fréquences propres au scénario |
| `rules/*.json` | `skills.json`, `specialties.json`, `props_catalog.json`, `combat_actions.json` | Tous les `.json` du dossier sont fusionnés |
| `equipment/*.json` | Catalogue d'objets (`look_top`, `look_bottom`, `tool`, `fetish`) + actions `★` | Peut embarquer un bloc `combat_action` en ligne |
| `characters/characters.json` | Fiches PJ/PNJ (`appearance`, `characteristics`, `skills`, `crisis`, `relations`) | `leader_char_id` du manifeste doit exister ici |
| `characters/player_profiles.json` | Portraits de création de personnage et archétypes jouables | `specialty_id` et `default_equipment` validés contre le pack |
| `world/idf.json` + `departments/*.json` + `cities/*.json` | Atlas N1 → N2 → N3 (`world_root_file`) | Les chemins `child_file` et `interior_file` sont relatifs au pack |
| `maps/interiors/*.json` | Décors isométriques N4 (`modular` ou `backdrop`), `props`, `hotspots`, `npcs`, `exits` | Chaque fichier déclare `parent_city_id` et `lights` |
| `dialogues/*.json` | Arbre de dialogues (`conditions`, `skill_check` `2d6`, `effects`, `fail_effects`) | Tous les `.json` du dossier sont fusionnés |
| `encounters/*.json` | Combats sur la Frise (`escalation_clock`, `escape_config`, `enemies`, `outcomes`) | Peut référencer un `custom_script` relatif au pack |
| `scripts/*.gd` | Hooks GDScript optionnels (`extends RefCounted`) propres au scénario | Ex. [demo\_hook.gd](file:///e:/JDR/BANLIEUE/game/data/scenarios/_template_scenario/scripts/demo_hook.gd) |

---

## 3. Recettes rapides (Copier / Coller)

### A. Ajouter une tenue modulaire (`look_top` / `look_bottom`) + action `★` inline

* Contrainte image : **PNG `256×526` RGBA**, coins `(0,0)` et `(255,525)` transparents (`alpha == 0`), déposé dans `game/assets/modular/tops/` ou `bottoms/` (ou dans un sous-dossier `assets/` de ton pack).
* Ajouter l'objet dans `equipment/equipment.json`. Pour donner une capacité tactique `★` sans éditer `rules/combat_actions.json`, imbriquer `"combat_action"` directement **à l'intérieur** de `unlocks_actions[0]` :

```json
{
  "id": "blouson_custom",
  "name": "Blouson custom ★",
  "slot": "look_top",
  "sprite": "res://assets/modular/tops/imper_vigile.png",
  "desc": "Veste coupée pour passer les contrôles.",
  "stat_mods": { "aura": 1 },
  "skill_mods": { "tchatche": 1 },
  "unlocks_skills": [],
  "unlocks_actions": [
    {
      "id": "act_equip_blouson_custom",
      "label": "Coup de Bluff",
      "desc": "1x/rencontre : coupe la garde et -2 résolution.",
      "combat_action": {
        "is_equipment": true,
        "once_per_encounter": true,
        "short_label": "Coup de Bluff",
        "title": "Coup de Bluff (Blouson)",
        "target_kind": "enemy",
        "min_range": 1,
        "max_range": 5,
        "skill": "tchatche",
        "dc_source": "enemy_social",
        "roll_bonuses": [{ "type": "fixed", "val": 2, "label": "Blouson" }],
        "on_success": {
          "effects": [
            { "op": "cut_counter" },
            { "op": "damage_resolve", "amount": 2, "brilliant_amount": 3, "scope": "target" }
          ],
          "log": "{actor} bluffe {target} (-{dmg} résol., garde coupée) !"
        },
        "on_fail": {
          "effects": [{ "op": "damage_resolve", "amount": 1, "scope": "target" }],
          "log": "Bluff moyen sur {target} (-1 résol.)."
        },
        "on_flaw": {
          "shake": true,
          "buzz": true,
          "effects": [{ "op": "modify_moral", "target": "self", "amount": -4, "use_shield": true }],
          "log": "Couac ({actor}) : -4 Moral !"
        }
      }
    }
  ]
}
```

### B. Ajouter un personnage (Compagnon ou PNJ)

1. Préparer un portrait **`1024×1024`** (`portrait`) et 3 calques **`256×526` RGBA** (`head`, `default_top`, `default_bottom`).
2. Ajouter la fiche dans `characters/characters.json` avec `specialty_id` (existant dans `rules/specialties.json`), `default_equipment` (cohérent avec chaque slot) et un bloc `crisis` (`log` + `effects[]`).
3. Pour le placer dans un décor N4, ajouter son entrée dans `npcs[]` du fichier `maps/interiors/<lieu>.json` (`char_id`, `grid_x`, `grid_y`, `dialogue_id`, `phase`, et optionnellement `hide_if_in_squad: true`).

### C. Ajouter un décor N4 ou une commune N3

* **Décor N4 (`maps/interiors/<id>.json`)** :
  * Mode **`"modular"`** : renseigner `grid_w`, `grid_h`, `blocked_cells`, `lights`, et `props[]` en piochant dans les types de `rules/props_catalog.json` (`wall_back`, `workbench`, `arcade`, `counter`, `lock_gate`, `brazier`, `oil_drum`, `pallet_stack`, etc.).
  * Mode **`"backdrop"`** : image **`1200×896`**, renseigner `"backdrop": "res://assets/locations/mon_decor.png"` et calibrer `occluders[]` (`sort_y_px` ou `always_front`, avec `polygon_px`).
  * Penser à l'ajouter dans `locations_order[]` et `children[]` du fichier ville `world/cities/<ville>.json`.
* **Commune N3 (`world/cities/<ville>.json`)** :
  * Plan papier IGN/RATP sans texte de taille **`1040×760`**.
  * Déclarer la commune dans `world/departments/93.json` avec `"status": "playable"` (ou `"locked"` déblocable en jeu via l'effet dialogue `"unlock_location": "<id>"`) et `"child_file": "world/cities/<ville>.json"`.
  * L'`id` de la commune doit être identique dans `93.json`, dans `world/cities/<ville>.json`, et dans le `parent_city_id` de ses intérieurs N4.

### D. Briques d'effets de combat JSON (`TensionTimeline`) & Hooks `custom_script`

Les tableaux `effects[]` (actions de combat, spécialités, crises d'autonomie, attaques ennemies et expiration d'horloge) acceptent nativement ces opérations :

| Opération (`op`) | Paramètres principaux | Effet |
|---|---|---|
| `damage_resolve` | `amount`, `brilliant_amount`, `crit_bonus`, `scaled_bonus`, `scope` (`target` / `other_enemies` / `all_enemies`) | Réduit la Résolution ennemie |
| `push_ticks` | `amount`, `crit_amount`, `scaled_bonus`, `only_if_brilliant` | Repousse la cible sur la Frise (+crans) |
| `cut_counter` | `only_if_brilliant` | Annule la contre-interruption / garde active |
| `set_counter_ready` | `value` (`true` / `false`) | Active ou coupe la garde |
| `modify_escalation_clock` | `amount`, `brilliant_amount`, `scaled_bonus`, `min_val` | Ajoute ou retire des crans à l'horloge |
| `advance_escape` | `amount` | Fait progresser la jauge d'échappée |
| `add_shield` | `amount`, `absorb` | Ajoute un bouclier d'Interposition |
| `modify_moral` | `target` (`self` / `all_allies` / `ally_target` / `crisis_ally` / `target_ally` / `second_ally`), `amount`, `use_shield` | Modifie le Moral |
| `delay_crises` | `amount`, `target` (`all` / `ally_target` / `self`) | Retarde le déclenchement des crises en attente |
| `cancel_crisis` | *(aucun)* | Annule la crise ciblée |
| `advance_turn_counter` | `amount` | Avance le compteur de tours (`timed_events`) |
| `modify_notoriete` | `amount` | Ajuste la Notoriété de la bande |
| `set_flag` | `flag`, `value` | Active ou désactive un flag `GameState` |

Pour un comportement sur mesure (boss, événement scénarisé), déclarer `"custom_script": "scripts/mon_hook.gd"` sur une rencontre, une action, une spécialité ou un ennemi. Méthodes reconnues : `on_encounter_start`, `on_action_execute`, `on_specialty_trigger`, `on_enemy_turn`, `on_crisis_execute`.

* **Couverts & Obstacles tactiques (`cover_tiles[]`)** sur une rencontre :
  * `{ "x": 2, "y": 4, "label": "Pilier béton", "defense_bonus": 2, "moral_absorb": 2, "blocks_movement": true }`
  * Un couvert bas (`blocks_movement: false`) protège l'occupant de sa case ; un obstacle (`blocks_movement: true`) bloque le passage et protège ses cases adjacentes (`+defense_bonus` au DD contre attaques `min_range >= 2`, `-moral_absorb` aux chocs moraux PJ).
* **Éléments interactifs de décor en combat (`combat_interactables[]`)** :
  * `{ "id": "prop_extincteur_quai", "label": "Extincteur", "x": 1, "y": 5, "max_range": 2, "cost_tick": 2, "skill": "systeme_d", "dc": 9, "one_shot": true, "effects": [...], "fail_effects": [...] }`
  * Déclenchable par clic direct sur la case ou via le bouton `⚙` de la fiche active.

### E. Pipeline graphique Python ([process\_banlieue\_assets.py](file:///e:/JDR/BANLIEUE/.agents/skills/banlieue-asset-pipeline/scripts/process_banlieue_assets.py))

```powershell
# Détourer un sprite #FF00FF sans socle en 526 px de haut
python "e:\JDR\BANLIEUE\.agents\skills\banlieue-asset-pipeline\scripts\process_banlieue_assets.py" --mode clean_pawn --src "brut.jpg" --dst "clean.png" --strip-standee

# Découper en 3 calques modulaires 256x526 (tête / haut / bas)
python "e:\JDR\BANLIEUE\.agents\skills\banlieue-asset-pipeline\scripts\process_banlieue_assets.py" --mode split_pawn --src "clean.png" --head-dst "head.png" --top-dst "top.png" --bottom-dst "bottom.png"

# Redimensionner un portrait (1024x1024) ou un décor N4 (1200x896)
python "e:\JDR\BANLIEUE\.agents\skills\banlieue-asset-pipeline\scripts\process_banlieue_assets.py" --mode portrait --src "raw_portrait.jpg" --dst "game\assets\portraits\mon_perso.png"
python "e:\JDR\BANLIEUE\.agents\skills\banlieue-asset-pipeline\scripts\process_banlieue_assets.py" --mode backdrop --src "raw_decor.jpg" --dst "game\assets\locations\mon_decor.png"
```

---

## 4. Checklist Anti-Erreurs

* **Préfixe `_` / `.`** : ne pas laisser de `_` au début du dossier final si tu veux qu'il apparaisse dans l'écran *Nouvelle Partie*.
* **Validation `0` erreur** : toujours passer `--mode validate` avant de commiter ; vérifie tous les liens `dialogue_id`, `interior_file`, `portrait`, `256×526` RGBA à coins transparents et `res://` existants.
* **Import de Cassette (Option 3A)** : si tu souhaites que le scénario accepte les sauvegardes d'un autre épisode, garde les identifiants de base des 10 compétences dans `rules/skills.json` et `allow_import_cassette: true` dans `scenario.json`.
* **GDScript strict dans `scripts/*.gd`** : le validateur interdit l'opérateur `:=` sur toute valeur `Variant` (`.get(...)`, `.call(...)`, `JSON.parse_string(...)`, indexation `[...]`) — toujours typer explicitement (`var val: String = str(...)`).
