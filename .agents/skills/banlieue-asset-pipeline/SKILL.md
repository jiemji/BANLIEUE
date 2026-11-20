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

### B. Sprite Personnage en Pied RGBA (`526 px` paddé) → `game/assets/pawns/<id>_pawn.png`
1. **Référence stricte obligatoire** : passer `game/assets/portraits/<id>.png` à `image-generator` (même visage, coupe de cheveux et haut de vêtement).
2. **Brief de génération** :
   * Corps entier debout de la tête aux chaussures avec marge généreuse sur les 4 côtés, angle **3/4 face avec légère plongée** cohérente avec un diorama isométrique.
   * **Contour d'encre noire fermé tout autour de la silhouette**, **SANS bordure blanche/crème**, **SANS socle/support gris sous les pieds**, **SANS ombre portée au sol**, **SANS décor**.
   * Isolé centré sur un **fond 100 % plat, uniforme, uni magenta pur (`#FF00FF`)**.
3. **Post-traitement & détourage RGBA** :
   `python ".agents/skills/banlieue-asset-pipeline/scripts/process_banlieue_assets.py" --mode clean_pawn --src "<raw>" --dst "game/assets/pawns/<id>_pawn.png"`
   *(Ajouter `--strip-standee` uniquement si une image brute contient encore un socle gris et une bordure crème.)*
   Produit une texture RGBA **`500 px` personnage + `16 px` marge haut/côtés + `10 px` marge bas = `526 px`**.

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
  2. Câbler `"portrait"` / `"pawn"` dans `game/data/characters.json` ou `"backdrop"` / `"hotspots"` / `"lights"` dans `game/data/locations.json`.
  3. Lancer :
     `python ".agents/skills/banlieue-asset-pipeline/scripts/process_banlieue_assets.py" --mode validate --game-root "e:\JDR\BANLIEUE\game"`
