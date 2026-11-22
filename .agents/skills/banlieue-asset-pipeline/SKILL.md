---
name: banlieue-asset-pipeline
description: >-
  Pipeline graphique et d'intégration Godot 4 validé pour Banlieue (Cradon-lès-Gonesse, 1980–1984).
  Utiliser pour produire des portraits BD, des sprites de personnages en pied détourés RGBA (526 px
  sans socle ni bordure épaisse, prêts pour le shader contour 2 px et l'ombre 4h) ou des décors
  isométriques 2:1 assortis à Box-Garage.
---

# Pipeline Assets 2D — *Banlieue* (Cradon-lès-Gonesse, 1980–1984)

## 1. ADN Stylistique Validé
* **Trait & Texture** : Bande dessinée franco-belge nerveuse inspirée de **Frank Margerin** (encre noire expressive et fermée), mêlée au hachurage brut de **fanzine français 80s (*Zone*)**, lavis de gouache délavée et léger grain pellicule 16mm 1982.
* **Palette** : Bétons beiges/gris, ocres usés et denims de banlieue parisienne, rehaussés par les 4 couleurs-signaux du jeu (*orange sodium `#f28c28`*, *rouge fanzine `#d92b2b`*, *bleu électrique `#4aa3df`*, *halo pâle Poudrerie*).
* **Interdits absolus** : **ZÉRO** texte, lettre, chiffre, bulle de BD, watermark, téléphone portable ou vêtement moderne.

---

## 2. Les 3 Gabarits de Production

### A. Portrait BD (`1:1`, `1024×1024`) → `game/assets/portraits/<id>.png`
1. **Références obligatoires à passer à `image-generator`** :
   `game/assets/portraits/karim.png`, `game/assets/portraits/nadia.png`, `game/assets/portraits/leader.png`.
2. **Cadrage** : Buste/épaules centré, visage expressif, vêtements authentiques Île-de-France 1980–1984, fond béton/hachures encre dans la teinte du personnage.
3. **Post-traitement** :
   `python ".agents/skills/banlieue-asset-pipeline/scripts/process_banlieue_assets.py" --mode portrait --src "<raw>" --dst "game/assets/portraits/<id>.png"`

### B. Pions Modulaires 3 Parties (`256×526` RGBA) → `game/assets/modular/{heads,tops,bottoms}/`
> **Portraits BD vs Pions modulaires** : les **portraits BD `1024×1024`** restent conservés pour les dialogues, la frise et les fiches. L'assemblage en 3 calques (`head` + `top` + `bottom`) sert à la **fiche d'inventaire `[F]`**, à l'aperçu Nouvelle Partie et à la **représentation en pied des PJ et PNJ sur la grille intérieure ou de combat**.

1. **Référence stricte de pose & proportions** : passer `game/assets/pawns/leader_pawn.png` (et le portrait du PNJ s'il existe) à `image-generator`.
2. **Brief de génération** :
   * Corps entier debout de la tête aux chaussures, pose canonique identique à `leader_pawn.png` (angle **3/4 face légère plongée**, bras le long du corps légèrement écartés des hanches, proportions tête/buste/jambes verrouillées).
   * **Contour d'encre noire fermé**, **SANS bordure blanche/crème**, **SANS socle gris sous les pieds**, **SANS ombre portée au sol**, **SANS décor**.
   * Isolé centré sur **fond plat uniforme `#FF00FF`**.
3. **Post-traitement & découpe canonique `256×526`** :
   * Détourage d'abord : `python ".agents/skills/banlieue-asset-pipeline/scripts/process_banlieue_assets.py" --mode clean_pawn --src "<raw>" --dst "<clean_526.png>"`
   * Découpe en 3 calques alignés sur **`X = 128`** et **`chin_y = 101`** :
     `python ".agents/skills/banlieue-asset-pipeline/scripts/process_banlieue_assets.py" --mode split_pawn --src "<clean_526.png>" --head-dst "game/assets/modular/heads/<id>.png" --top-dst "game/assets/modular/tops/<top_id>.png" --bottom-dst "game/assets/modular/bottoms/<bot_id>.png"`
   * Découpe en lot des 12 pions de référence : `--mode split_all_pawns` ; planche-contact mix & match : `--mode preview_modular --dst "<preview.png>"`.
4. **Conventions des 3 calques `256×526` RGBA** :
   * `heads/<id>.png` : visage, cheveux (dont mèches latérales) + colonne cou descendant jusqu'à `y ≈ 136`.
   * `tops/<id>.png` : col/épaules/buste jusqu'à la taille (`y ≈ 265`) + **les deux bras et mains** (`y ≈ 326`), avec l'ouverture de peau du cou vide dans le V du col (sans cacher cols, écharpes ni casques).
   * `bottoms/<id>.png` : jambes + hanches + chaussures (`y ≈ 252..516`), sans avant-bras sur les cuisses, prêt à recevoir n'importe quel haut par-dessus.
   * Assemblage runtime : `DataLoader.assemble_modular_pawn(head, top, bottom)` compose les 4 passes en une seule `ImageTexture` `256×526` mise en cache pour que `pawn_outline.gdshader` trace **un contour `2 px` continu sans couture interne** et une **ombre `4h` unique**.

### C. Décor Isométrique 2:1 (`4:3`, `1200×896`) → `game/assets/locations/<loc_id>.png`
1. **Référence stricte obligatoire** : `game/assets/locations/box_garage.png`.
2. **Contraintes d'échelle critiques** :
   * Vue isométrique en coupe 3/4 de dessus (**grille 30° / 2:1**) flottant centrée sur fond uni `#141418`.
   * Hauteur de mur standard ~2,45 m (pour que nos personnages affichés à **`162 px`** dans `870×650` correspondent exactement à ~1,75 m, soit ~2/3 de mur et ~1,75× un dossier de canapé/comptoir).
   * **ZÉRO personnage, ZÉRO texte, ZÉRO interface**.
3. **Post-traitement** :
   `python ".agents/skills/banlieue-asset-pipeline/scripts/process_banlieue_assets.py" --mode backdrop --src "<raw>" --dst "game/assets/locations/<loc_id>.png"`

---

## 3. Contrats Moteur Godot 4 & Validation

* **Contour dynamique `2.0 px`** : géré en temps réel par `game/shaders/pawn_outline.gdshader` via `game/scripts/world/pawn_actor.gd` (*crème repos, orange sodium déplacement, jaune dialogue/interaction, bleu guet, rouge Stress*). Le padding transparent du PNG (`16 px` / `10 px`) empêche toute coupure du contour.
* **Ombre silhouette orientée `4h` (`+30°`)** : projetée automatiquement par `pawn_actor.gd` depuis la texture RGBA ; s'oriente dynamiquement si le lieu déclare des sources dans `"lights": [{"grid_x": ..., "grid_y": ..., "radius": 320, "strength": 1.0}]` de `game/data/locations.json`.
* **Contrôle obligatoire avant livraison** :
  1. Inspecter chaque PNG final avec `read_file` (vérifier absence de halo, bottes/chaussures intactes, zéro speckle flottant).
  2. Câbler les pièces dans `game/data/characters.json` (`"appearance"` + `"default_equipment"`), `game/data/equipment.json` (`"slot": "look_top" | "look_bottom"` + `"sprite"`), `game/data/timeline_encounters.json` (`"appearance"` des ennemis) ou `"backdrop"` / `"hotspots"` / `"lights"` dans les JSON de `game/data/maps/interiors/`. Conserver `"portrait"` intact (`1024×1024`).
  3. Lancer :
     `python ".agents/skills/banlieue-asset-pipeline/scripts/process_banlieue_assets.py" --mode validate --game-root "e:\JDR\BANLIEUE\game"`
