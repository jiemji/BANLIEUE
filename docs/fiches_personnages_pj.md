# Fiches de Personnages PJ — Spécification de Design (`v0.5.0`)

> Référence ludo-narrative et UX pour les fiches de personnages jouables (Leader + compagnons de bande) de *Banlieue* (Cradon-lès-Gonesse, 1980–1984). Document consolidé avant implémentation Godot 4 (**hybride Option B + Option C · Progression XP + Équipement actif · Carnet de Bande `[F]`**).

---

## 1. Architecture de la Fiche PJ *(Option B + Option C)*

Chaque personnage jouable réunit sur une fiche unique **l'héritage JDR *Zone*** *(simplifié et lisible sans table de localisation)* et **la dimension narrative & relationnelle** :

### A. Les 3 Caractéristiques principales (`1` à `5`)
| Caractéristique | Ce qu'elle mesure dans Cradon-lès-Gonesse | Influence directe en jeu |
|---|---|---|
| **Esprit** | Tête froide, lecture sociale, ruse, sens critique et débrouille technique fine. | Surenchère d'**Attitude** en dialogue, écoute FM, décryptage d'indices, bricole électronique. |
| **Corps** | Carrure, adresse physique, réflexes de rue, mécanique lourde et encaissement. | Poids d'**Aura**, passages physiques/caves, réparation 103 SP, intimidation & rixe. |
| **Énergie** | Tenue nerveuse, endurance nocturne, réserve d'élan et résistance à l'usure. | Cap de **Moral**, résistance aux coups de froid nocturnes et retard de basculement en **Crise d'autonomie**. |

> **Articulation avec les jauges de scène** :
> * **`Attitude`** *(ex-FAVE)*, **`Aura`** *(ex-FASA)*, **`Moral / Seuil Stress`** et la **Spécialité Frise** restent les valeurs opérationnelles lues directement en exploration, dialogue et sur la **Frise-Cartes Unifiée** ([ux_combat_frise.md](file:///e:/JDR/BANLIEUE/docs/ux_combat_frise.md)).
> * `Esprit / Corps / Énergie` fournissent la charpente de fiche JDR et servent de socle aux tests de compétences, bonus d'équipement et paliers narratifs.

### B. Compétences de rue (`-3` à `+5`) — Profil, Acquisition & Échelle bipolaire
Les compétences vont de **`-3` (point noir / handicap concret)** à **`+5` (référence absolue du 93)** :
* **Dépendantes du profil** : chaque archétype de Leader et chaque compagnon débute avec **ses forces** (`+1` à `+4`) et **ses failles assumées** (`-1` à `-3`), reflétant son vécu (ex. Manu est à `+4` en *Mécanique & 103 SP* mais `-3` en *Ondes & Électronique* ; Karim est à `+3` en *Caves, Toits & Esquive* mais `-2` en *Nerfs & Tenue nocturne*).
* **Non figées** : toute compétence absente démarre à **`0`** *(brouillon / système D nu)* ; elle peut être acquise ou redressée en cours de partie via **XP** *(auprès d'un mentor ou au Box-Garage)* ou débloquée/modifiée par **l'équipement**.

| Score | Signification sur le bitume | Effet typique (dialogue / exploration / Frise) |
|---|---|---|
| **`-3`** | **Point noir / Blocage** | Gaffe assurée ou refus instinctif ; bloque certains jets sans aide ni matériel adapté. |
| **`-2` / `-1`** | **Maladresse / Faille** | Malus de poids social ou de coût (`+Francs`, `-Moral` en cas d'échec ou friction de groupe). |
| **`0`** | **Neutre / Tout-venant** | Accès standard aux options de base sans avantage ni pénalité. |
| **`+1` / `+2`** | **Débrouillard·e / Habitué·e** | Ouvre les choix spécialisés courants et fiabilise le *Système D* quotidien. |
| **`+3` / `+4`** | **Pointure locale** | Débloque des raccourcis réservés, des répliques sans dépense de Francs/Faveurs et des bonus sur la Frise. |
| **`+5`** | **Légende de Cradon** | Maîtrise signature : retourne une scène tendue par sa seule présence ou réputation. |

### C. Catalogue des 10 Compétences de rue
| ID | Nom affiché | Carac. | Domaines couverts |
|---|---|---|---|
| `tchatche` | **Tchatche & Baratin** | `Esprit` | Argot, mensonge à chaud, bluff municipal, moquerie face au S.O. |
| `systeme_d` | **Système D & Débrouille** | `Esprit` | Crochetage, fausse panne, faux tracts/laissez-passer, récup. |
| `ondes_radio` | **Ondes & Électronique** | `Esprit` | Tuner FM, enregistrements cassettes, bornes d'arcade, tableaux électriques. |
| `lecture_rue` | **Flair & Connaissance du milieu** | `Esprit` | Lire une embrouille avant qu'elle pète, réseaux d'anciens, filatures. |
| `mecanique_mob` | **Mécanique & 103 SP** | `Corps` | Réglage 2-temps, dépannage d'atelier, vitesse de renfort, bidouilles garage. |
| `baston_pression` | **Caisse & Coup de pression** | `Corps` | Bras de fer, tenue d'un barrage, matraque/parade, encaissement S.O. |
| `caves_esquive` | **Caves, Toits & Esquive** | `Corps` | Se faufiler sans bruit, brèches Poudrerie, course & fuite devant CRS. |
| `sang_froid_nerfs` | **Nerfs & Tenue nocturne** | `Énergie` | Contenir la montée de Stress, affronter l'étrange de la Poudrerie/RER. |
| `solidarite_bande` | **Entraide & Moral de groupe** | `Énergie` | Remonter le moral au Box-Garage, désamorcer les frictions internes. |
| `jeux_culture` | **Flipper, Baby & Culture 80s** | `Énergie` | Claque au *Galaxian*, musique/rock/smurf, fanzines, détente du soir. |

---

## 2. Fiches de Départ Validées *(Forces `+` & Failles `-`)*

### A. Les 4 Archétypes du Leader
| Archétype | Caractéristiques (`E / C / Én`) | Jauges & Frise | Compétences initiales | Équipement de départ |
|---|---|---|---|---|
| **L'Enfant de la Dalle**<br>*(Débrouillard·e du Parking)* | `Esprit 3 · Corps 3 · Énergie 4` | `Attitude 62 · Aura 3`<br>`Moral 72 (Seuil 28)`<br>*Réflexe de rue* (`+10 F`) | `caves_esquive +3`<br>`systeme_d +2`, `lecture_rue +1`<br>`baston_pression -1`, `ondes_radio -1` | **Parka passe-partout** *(Look)*<br>**Trousseau des caves** *(Outil)* |
| **La Grande Gueule du Bourg**<br>*(Habitué·e du Comptoir)* | `Esprit 4 · Corps 2 · Énergie 3` | `Attitude 70 · Aura 3`<br>`Moral 68 (Seuil 30)`<br>*Baratin / Déconcentration* (`+1 Faveur`) | `tchatche +4`<br>`jeux_culture +2`, `lecture_rue +1`<br>`caves_esquive -1`, `mecanique_mob -2` | **Blouson jean élimé** *(Look)*<br>**Carnet de dettes du Balto** *(Fétiche)* |
| **Les Mains-Noires**<br>*(Enfant de l'Atelier & Chaîne)* | `Esprit 2 · Corps 4 · Énergie 4` | `Attitude 60 · Aura 4`<br>`Moral 74 (Seuil 26)`<br>*Menace / Interposition* (`+1 Aura`) | `mecanique_mob +3`<br>`baston_pression +3`, `sang_froid_nerfs +2`<br>`ondes_radio -2`, `tchatche -1` | **Bleu & Perfecto d'atelier** *(Look)*<br>**Clé à molette 12–14** *(Outil)* |
| **L'Échappé·e des Pavillons**<br>*(La Fissure du Lotissement)* | `Esprit 4 · Corps 2 · Énergie 3` | `Attitude 66 · Aura 2`<br>`Moral 64 (Seuil 32)`<br>*Sang-froid / Coup d'avance* (`+15 F`) | `sang_froid_nerfs +3`<br>`lecture_rue +3`, `tchatche +2`<br>`baston_pression -2`, `mecanique_mob -1` | **Coupe-vent de lycée** *(Look)*<br>**Badge MJC / Pass Mairie** *(Fétiche)* |

### B. Les 6 Compagnons de Bande
| Compagnon | Caractéristiques (`E / C / Én`) | Jauges & Faille de Stress | Compétences initiales | Équipement de départ |
|---|---|---|---|---|
| **Karim** *(19 ans)*<br>*L'Étincelle — La Dalle & B-Boys* | `Esprit 2 · Corps 4 · Énergie 3` | `Attitude 60 · Aura 4`<br>`Moral 56 (Seuil 40)`<br>*Haine / Embrasement* · `Moquerie` | `caves_esquive +3`, `solidarite_bande +3`, `tchatche +2`, `jeux_culture +1`<br>`sang_froid_nerfs -2`, `ondes_radio -1` | **Survêtement & Baskets** *(Look)*<br>**Ghetto-blaster K7** *(Fétiche)* |
| **Nadia** *(18 ans)*<br>*La Fréquence — Tour B & MJC* | `Esprit 4 · Corps 2 · Énergie 3` | `Attitude 58 · Aura 2`<br>`Moral 66 (Seuil 32)`<br>*Paranoïa / Lunatisme* · `Réflexe de rue` | `ondes_radio +4`, `systeme_d +3`, `caves_esquive +2`<br>`baston_pression -2`, `solidarite_bande -1` | **Duffle-coat à poches** *(Look)*<br>**Walkman bidouillé FM** *(Outil)* |
| **Manu** *(19 ans)*<br>*Le Mécano — Bananes du Garage* | `Esprit 2 · Corps 5 · Énergie 3` | `Attitude 64 · Aura 5`<br>`Moral 68 (Seuil 34)`<br>*Sauvagerie / Fierté* · `Coup de clé` | `mecanique_mob +4`, `baston_pression +3`, `lecture_rue +1`<br>`ondes_radio -3`, `caves_esquive -1` | **Perfecto graisseux** *(Look)*<br>**103 SP préparée** *(Outil)* |
| **Zoé** *(18 ans)*<br>*La Keponne — Squat du Canal* | `Esprit 4 · Corps 2 · Énergie 3` | `Attitude 62 · Aura 4`<br>`Moral 62 (Seuil 34)`<br>*Inconscience / Provocation* · `Provocation` | `systeme_d +3`, `tchatche +3`, `jeux_culture +2`<br>`sang_froid_nerfs -2`, `mecanique_mob -1` | **Cuir clouté & badges** *(Look)*<br>**Kit pochoir & fanzines** *(Outil)* |
| **Franck** *(24 ans)*<br>*Le Grand — Vieux de la Rouge* | `Esprit 3 · Corps 4 · Énergie 2` | `Attitude 78 · Aura 5`<br>`Moral 52 (Seuil 28)`<br>*Défaitisme / Alcoolisme* · `Carrure d'aîné` | `lecture_rue +4`, `baston_pression +3`, `solidarite_bande +2`<br>`caves_esquive -2`, `sang_froid_nerfs -1` | **Veste de chantier Citroën** *(Look)*<br>**Vieux plan RATP 1979** *(Fétiche)* |
| **Ludo** *(18 ans)*<br>*Le Caméléon — Fracture MJC/LEP* | `Esprit 3 · Corps 2 · Énergie 3` | `Attitude 52 · Aura 3`<br>`Moral 58 (Seuil 35)`<br>*Peur / Fuite en avant* · `Baratin` | `tchatche +3`, `jeux_culture +3`, `lecture_rue +2`<br>`baston_pression -2`, `sang_froid_nerfs -1` | **Blouson collège revers** *(Look)*<br>**Pièce porte-bonheur flipper** *(Fétiche)* |

---

## 3. Progression Hybride : XP (`Option B`) & Équipement à Effets Actifs (`Option A`)

### A. Expérience (`XP`) & Montée des compétences
* **Gains d'XP** :
  * Clore un nœud d'enquête / recrutement / résolution sociale : **`+15 à +25 XP`** pour les PJ du groupe présent *(et `+10 XP` partagés à la bande au retour au Box-Garage)*.
  * Survivre ou retourner une confrontation sur la Frise : **`+25 à +40 XP`** *(réduit de moitié si débandade CRS)*.
* **Coût d'amélioration sur la fiche** *(plafond `+5`)* :
  * Combler une faille négative (**`-3 → -2 → -1 → 0`**) : **`30 XP`** par palier.
  * Progresser dans une compétence maîtrisée (**`0 → +1 → +2 → +3 → +4 → +5`**) : **`40 / 60 / 90 / 130 / 180 XP`**.
  * **Acquérir une nouvelle compétence hors profil** : possible dès qu'un compagnon/lieu mentor l'enseigne (ex. Manu pour `mecanique_mob`, Nadia pour `ondes_radio`, Zoé pour `systeme_d`) ou via un temps mort au Box-Garage au coût de **`50 XP`** *(débloque le rang `+1`)* — **ou temporairement sans XP via un équipement adapté**.

### B. Les 3 Emplacements d'Équipement & Effets Actifs
Chaque PJ dispose de **3 emplacements** partageables/rangeables dans le coffre du **Box-Garage** :
1. **`Look / Blouson`** : modifie l'**Aura**, la lecture tribale dans les quartiers et certains seuils de dialogue.
2. **`Outil / Bricole`** : apporte des **bonus de compétence** ou **débloque de nouvelles compétences / actions jouables**.
3. **`Objet fétiche`** : stabilise le **Moral**, relève la résistance nocturne ou ouvre une réplique / action de récupération.

| Exemple d'équipement | Emplacement | Bonus chiffré | Nouvelle compétence ou action débloquée |
|---|---|---|---|
| **Perfecto clouté 1982** | `Look` | `+1 Aura`, `+1 baston_pression` | Débloque la réplique `[Intimidation Look]` face aux Skins / S.O. |
| **Parka anonyme à capuche** | `Look` | `+1 caves_esquive`, `-1 Notoriété subie` *(rôle discret)* | Permet l'action `[Infiltration discrète]` devant les patrouilles CRS. |
| **Walkman Sony bricolé + K7** | `Outil` | `+2 ondes_radio` | Rend `ondes_radio` utilisable même à `0` et ouvre `[Enregistrer la Fréquence]` la nuit. |
| **Clé passe-partout des chaufferies** | `Outil` | `+2 caves_esquive` | Débloque `[Couper par les caves]` (+1 avance Échappée dès le début d'une Frise en ville). |
| **Bombe de peinture & pochoir** | `Outil` | `+1 systeme_d` | Débloque `[Bomber un mot d'ordre]` (détourne une patrouille ou gagne +1 Faveur kepon). |
| **Cassettes Radio Lucien / TDK** | `Fétiche` | `+8 Moral max` ou `Seuil Stress -3` | Débloque `[Pause musique au Box]` (+6 Moral à un pote en crise au retour de virée). |

### C. Traits & Cicatrices de vécu
Les scènes décisives inscrivent sur la fiche des **Traits permanents** *(ex. « Sang-froid du Quai Y » : +1 `sang_froid_nerfs` de nuit ; « Cousin grillé au Relais » : `-1` Aura face au S.O. mais `+2` en `lecture_rue` sur la Mairie ; « Cambouis 2-temps » : +1 cran renfort en 103 SP)*.

---

## 4. Volet Narratif & Thermomètre Relationnel *(Option C)*

Sur la page gauche de la fiche, chaque PJ expose :
* **Identité complète** : prénom, âge, rôle, tribu, lieu d'attache, origine familiale & enjeu intime (*arc évolutif* : *En cours / Fissuré / Résolu*).
* **Thermomètre relationnel avec les autres membres présents** :
  * **Soudés** *(symbole vert)* : bonus passif au Moral quand réunis dans le même sous-groupe.
  * **Complémentaires** *(bleu)* : ouvre des scènes binôme au Box-Garage ou en ville.
  * **Paire explosive / Friction** *(orange/rouge)* : alerte claire des **4 duos sensibles** (`Zoé ↔ Manu`, `Karim ↔ Ludo`, `Franck ↔ Karim/Zoé`, `Nadia ↔ Manu`) avec indication de l'état courant (*Latente / Apaisée / Vive*).

---

## 5. UX — « Carnet de Bande / Fanzine photocopié 1982 » *(Option A)*

* **Ouverture** : touche **`[F]`** en partie active (`IN_GAME`) ou bouton **`Fiches PJ`** dans la barre haute du [hud_overlay.gd](file:///e:/JDR/BANLIEUE/game/scripts/ui/hud_overlay.gd).
* **Gabarit double-page (`1280×720`)** : modale centrée (`1040×600`) au style papier jauni/encre noire/agrafe rouge *Zone* :

```text
+-----------------------------------------------------------------------+
|  [Toi] [Karim] [Nadia] [Manu] [Zoé] [Franck]        XP dispo: 45  [✕] |
+-----------------------------------+-----------------------------------+
|  PAGE GAUCHE — IDENTITÉ & BASE    |  PAGE DROITE — COMPÉTENCES & MATOS|
|  +----------+  Nom · Âge · Tribu  |  COMPÉTENCES (-3..+5)   [+ XP]    |
|  | Portrait |  Lieu d'attache     |  • Tchatche & Baratin   [+2] (+)  |
|  |   BD     |  Esp:4 | Cor:2 | Én:3|  • Système D            [+3] (+)  |
|  +----------+  Att.66 · Aura 2    |  • Caves & Esquive      [-1] (+)  |
|  [Pion]        Moral 66/100 (S.32)|  ...                              |
|                                   | --------------------------------- |
|  HISTOIRE & ARC PERSONNEL         |  SPÉCIALITÉ FRISE & ACTIONS       |
|  Bio sociale + faille de Stress   |  ⚡ Réflexe de rue (+actions matos)|
|                                   | --------------------------------- |
|  RELATIONS DANS LA BANDE          |  ÉQUIPEMENT (3 emplacements)      |
|  • Karim [Soudés] · Manu [Tension]|  [Look] [Outil] [Fétiche] (+Coffre)|
|                                   |  TRAITS : • Sang-froid du Quai Y  |
+-----------------------------------+-----------------------------------+
```

* **Arbitrage clavier** : `F` ouvre/ferme le Carnet en `IN_GAME` (verrouille `_iso_view` et `_world_map_view` via `_update_input_lock()`) ; `Échap` referme d'abord le Carnet s'il est ouvert avant de basculer vers `PAUSE_MENU`. `Gauche / Droite` bascule d'un onglet PJ à l'autre.

---

## 6. Contrat de Données Cible pour l'Implémentation (`v0.5.0`)

1. **`game/data/characters.json` & `player_profiles.json`** *(rétrocompatible)* :
   * Ajouter `"age"`, `"home_location"`, `"bio"`, `"characteristics": {"esprit": 3, "corps": 3, "energie": 4}`, `"skills": {...}`, `"default_equipment": {"look": "", "tool": "", "fetish": ""}` et `"relationships": {...}`.
2. **`game/data/equipment.json`** *(nouveau fichier)* :
   * Catalogue Data-Driven des objets (`id`, `slot` `"look"|"tool"|"fetish"`, `name`, `desc`, `stat_mods`, `skill_mods`, `unlocks_actions`).
3. **`GameState` & `SaveManager`** :
   * Stocker par membre dans `member_states[cid]` (ou `member_progression[cid]`) : `xp`, `skills` modifiés, `equipment` équipé, `traits` et `box_stash` (coffre partagé du Box-Garage), sérialisés dans `slot_1..3.json`.
