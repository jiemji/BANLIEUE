# Pitch Bible — *Banlieue*

*Document de synthèse ludo-narrative — mis à jour au fil des chantiers.*

## 1. High Concept & Piliers de Design
> **Pitch en une phrase** : À **Cradon-lès-Gonesse**, banlieue rouge fictive intercalée sur le « Y » du RER B Nord entre 1980 et 1984, menez une bande modulable depuis votre Box-Garage entre comédie sociale gouailleuse le jour et tension urbaine hantée d'étrange ambigu la nuit.

### Les 4 Piliers Fondamentaux
1. **Cradon-lès-Gonesse, la Banlieue « Hors-Carte » (1980–1984, RER B Nord)** : Une commune fictive au nom rigolo, greffée dans la vraie géographie de grande couronne nord (triangle *Aulnay-sous-Bois / Sevran / Villepinte*), avec sa propre station pile sur le « Y » de la bifurcation du RER B Nord « comme si elle avait toujours existé » — entre grands ensembles, canal de l'Ourcq, ancienne Poudrerie de 140 ha, grèves de Citroën Aulnay et avions de Roissy, plus 2 à 3 échappées ciblées en RER.
2. **La Bascule Jour / Nuit (Douce-Amère → Électrique)** : Le jour appartient à la gouaille, au bistrot, au système D et aux galères tendres ou absurdes (*Margerin, Renaud, Zone*) ; la nuit, les mêmes rues basculent dans la tension sèche, les patrouilles, les rixes et les phénomènes troubles (*La Haine, Ma 6-T va crack-er*).
3. **La Bande Modulable, Noyau Serré & Box-Garage Évolutif** : Un leader façonné par le joueur accompagné de 2 potes d'enfance choisis parmi un vivier de 6 figures locales (recrutables au fil du jeu jusqu'à 5–6 membres max), jouables groupés (`3+`) ou séparés librement (`2+1`, `1+1+1`) depuis un QG évolutif (*le Box-Garage de la Cité*).
4. **L'Étrange 100 % Ambigu & Onirisme Nocturne** : Chaque phénomène *chelou* (trains fantômes de la bifurcation, fréquence FM sans antenne, lueurs de la Poudrerie, rumeurs de cité) garde toujours une explication rationnelle 1980–84 défendable au matin, tout en glissant vers un onirisme vertigineux la nuit ou lorsque le **Moral** plonge (*Twin Peaks / Stalker* de banlieue).

## 2. Identité, Tonalité & Références
* **Genre & format de session** : Exploration urbaine, enquête sociale, choix moraux et tension/mouvement improvisé (hybride Exploration/Enquête + Action d'urgence).
* **Architecture technique *(Jalon 0)*** *(voir [architecture_technique.md](file:///e:/JDR/BANLIEUE/docs/architecture_technique.md))* : **Godot Engine 4 / GDScript 2.0** (`GL Compatibility`), vue **2D Isométrique / 3/4 de dessus**, cœur **100 % Data-Driven (JSON)** isolé dans `game/` autour du niveau-pilote *« Couvre-Feu au Galaxian »*.
* **Ambiance & promesse émotionnelle** : Comédie sociale douce-amère et tendre pour les gens d'en bas le jour ; pression de rue, paranoïa et vertige discret la nuit.
* **Direction artistique & sonore** *(voir [direction_artistique_sonore.md](file:///e:/JDR/BANLIEUE/docs/direction_artistique_sonore.md))* : Trait encré BD nerveuse (*Margerin × ZoneScreen*) marié à un **grain argentique 1982**, bascule du jour en gouache délavée vers une nuit quasi noir & blanc percée de 4 couleurs-signaux (*orange sodium, rouge fanzine, bleu électrique, halo Poudrerie*), étrangeté par **petits détails qui clochent**, et paysage sonore **100 % diégétique + grille FM libre le jour** basculant en **Cold Wave / synthé analogique 1982 la nuit**.
* **Lignes rouges (ce que le jeu n'est PAS)** : Pas un jeu de baston purement bourrin (la posture précède toujours les coups), pas de surnaturel ou de science-fiction explicite qui briserait l'ancrage 1980–84, ni misérabilisme sans humour ni caricature gratuite.
* **Œuvres repères & ce qu'on en retient** :
  * *La Haine* & *Ma 6-T va crack-er* : cocotte-minute urbaine, camaraderie électrique, tension constante face à l'autorité.
  * Bandes dessinées de **Frank Margerin** (*Lucien*, *Ricky*, *Radio Lucien*) : tendresse narquoise, mobylettes 103 SP, groupes de rock amateurs, galères quotidiennes qui tournent à l'épopée.
  * Chansons de **Renaud** (1977–1983 : *Laisse béton*, *Dans mon HLM*, *Banlieue rouge*, *Marche à l'ombre*) : argot ciselé, galerie de voisins hauts en couleur, colère sociale douce-amère.
  * JDR **Zone** (Siroz, dossier `Références/`) : tribus des années 80 (Rockers/Loubards, Punks, Skins/Redskins, jeunes de cité & premiers smurfeurs/b-boys, Babas), « monstres » du quotidien (concierge, maire/milice, CRS, éducs, tauliers), mécaniques **Attitude/Aura**, **Moral & Stress**, **Système D**, **Notoriété**, et étrange ambigu.

## 3. Univers & Arc Dramatique
* **Contexte / Monde** : **Cradon-lès-Gonesse** (Île-de-France, **1980–1984**) — sur fond de désillusion post-1981, tournant de la rigueur de 1983, radios libres FM et interconnexion du RER B Nord. Coincée entre **Aulnay-sous-Bois, Sevran et Villepinte** pile sur le « Y » de la bifurcation RER B, la ville représente 85 % du terrain de jeu, complétée par **2 à 3 échappées ciblées en RER B** (*Paris Gare du Nord/Les Halles*, *Citroën Aulnay en grève*, *friches de Roissy / Parc des Expositions*). Territoire découpé en **4 secteurs** (voir [monde_et_economie.md](file:///e:/JDR/BANLIEUE/docs/monde_et_economie.md)) :
  * *La Dalle & la Cité* : **Box-Garage QG**, hall Tour B, caves/chaufferies, toits.
  * *Le Vieux Bourg & la Gare RER* : gare « du Y », troquet neutre (*Chez Bébert / Le Balto*), *Relais Municipal*, salle de jeux (*Le Galaxian*), MJC et lycée/LEP.
  * *Le Canal de l'Ourcq & la Zone Industrielle* : Garage des Bananes, Entrepôt-Squat des Kepons, casse auto et écluse.
  * *La Lisière Pavillonnaire & l'Ancienne Poudrerie* : lotissements ouvriers, grilles et vieux bunkers des 140 ha fermés en 1973, champs sous avions.
* **Forces en présence** *(guerre froide tendue dès le Jour 1 + mosaïque familiale et de palier poreuse)* :
  * *5 Tribus (1980–84)* : **Les Bananes du Garage** (Rockers/Loubards), **Les Kepons du Canal** (Punks/squat), **La Dalle & les Premiers B-Boys** (tours & naissance du smurf), **La Fracture MJC** (Skins pro-mairie vs Redskins/Babas), **Les Vieux de la Rouge** (ouvriers grévistes, cheminots, tauliers).
  * *« Monstres » du quotidien* : Concierge-Cerbère de la Tour B, Maire clientéliste & Service d'Ordre municipal (S.O.), CRS/inspecteurs en civil, Contrôleurs RER, Parents/Profs/Éducateur MJC.
* **Rôle du joueur & bande** : Un personnage principal librement composé (prénom/surnom + choix d'un portrait diversifié avec pion assorti, 100 % découplé de l'histoire) parmi **4 archétypes aux histoires personnelles distinctes** (*L'Enfant de la Dalle*, *La Grande Gueule du Bourg*, *Les Mains-Noires*, *L'Échappé·e des Pavillons* — voir [structure_menus_et_ecrans.md](file:///e:/JDR/BANLIEUE/docs/structure_menus_et_ecrans.md)), démarrant au Box-Garage avec **Karim & Nadia** pour le niveau-pilote et complété par un vivier de **6 compagnons** (**Manu, Nadia, Karim, Zoé, Franck, Ludo**) recrutables jusqu'à un noyau serré de **5–6 membres max** (voir [personnages_et_relations.md](file:///e:/JDR/BANLIEUE/docs/personnages_et_relations.md)).
* **Conflit central & structure narrative** : *Volontairement ouvert — reporté au Backlog créatif à la demande du créateur.* Horizon thématique déjà posé via **4 grands dénouements collectifs doux-amers** (*On tient le mur*, *Premier train du matin*, *Jusqu'ici tout va bien*, *Hors-Carte*).

## 4. Boucle de Gameplay & Systèmes Clés
* **Verbes d'action fondamentaux** : **Zoner** (explorer cité, troquets, friches), **Tchatche / Bluff** (*Attitude/Aura*), **Capter** (pister rumeurs, indices et bande FM), **Bricoler** (*Système D*), **Scinder / Regrouper** (`3+`, `2+1`, `1+1+1` en **bascule libre à la volée**), **Filer / Improviser** (esquive, poursuite, raccourcis par caves/toits/mobylette, rixe d'urgence).
* **Boucle courte — Frise chronologique de Tension** *(éprouvée dans [niveau_pilote.md](file:///e:/JDR/BANLIEUE/docs/niveau_pilote.md))* : Tour-par-tour cinématographique continu sans coupure entre social (*Attitude/Aura*) et action d'urgence — lecture des intentions adverses en avance, **Interruptions hors-tour par spécialités** (déconcentration, moquerie, menace/interposition, réflexe de rue — 1 réaction par cycle), et **préavis lisible** (1–2 crans) des **Crises d'autonomie** avant dérapage.
* **Boucle moyenne (Cycle Jour / Nuit & Box-Garage)** :
  * **Le Jour** : enquête en **bascule libre à la volée** entre sous-groupes scindés, petits plans, réparation de 103 SP et *Système D* (économie de poche : **Francs**, **Faveurs/Dettes**, **Bricole/Fringues**), remontée du **Moral** (bistrot, flipper, Box-Garage) et désamorçage des frictions internes.
  * **Sas crépusculaire → La Nuit** : transition sensorielle marquée ; les mêmes lieux passent sous pression — zones interdites accessibles, contrôles, ondes pirates, glissement onirique et frises tendues.
* **Boucle longue (progression / territoire)** : L'équipement du **Box-Garage** et la **Notoriété** (*Zone*) ouvrent le **recrutement** (cohabitation à mériter entre profils opposés) et de nouveaux accès tribaux tout en attirant davantage le S.O., les CRS et les rivaux ; le **Moral** individuel oscille entre solidarité et **Stress / Crises d'autonomie** (*Zone*), façonnant l'un des **4 grands destins collectifs**.

## 5. Cohérence Ludo-Narrative
* **Attitude / Aura avant l'impact** : La rue est d'abord un théâtre de dégaine, de réputation et de tchatche ; la violence reste l'accident ou l'ultime recours quand la posture échoue.
* **Grouper vs scinder la bande (`3+` / `2+1` / `1+1+1`)** : Rester ensemble donne du poids social et permet de retenir un compagnon au bord d'une **Crise d'autonomie**, mais rend la bande très voyante ; se séparer couvre plus de terrain et ménage les territoires tribaux (ou les paires explosives), au prix d'une vulnérabilité accrue la nuit.
* **Moral, Stress & Crises d'autonomie** : Le poids du quotidien (galères, humiliations, nuits au poste ou frictions familiales) pousse les potes à agir par eux-mêmes au pire moment (*effet Vinz*) et nourrit l'onirisme nocturne de Cradon-lès-Gonesse.
* **Notoriété, Cohabitation & Recrutement** : Chaque nouvelle recrue ouvre les portes d'une sous-culture (garage, squat, toit de tour, radio libre, grévistes, MJC), mais élargir la bande attise les frictions internes à mériter au Box-Garage et expose plus vite aux patrouilles.

## 6. Backlog Créatif (Points en Suspens)
* [x] **Nom définitif de la ville & ancrage RER B Nord** → **Cradon-lès-Gonesse**, au « Y » de la bifurcation entre *Aulnay-sous-Bois*, *Sevran* et *Villepinte*, avec 2–3 échappées RER B (voir `docs/monde_et_economie.md`).
* [x] **Cartographie des strates, QG évolutif, tribus, économie Système D & catalogue des phénomènes ambigus** → Chantier C consolidé dans `docs/monde_et_economie.md`.
* [x] **Casting des 6 compagnons (2 au départ + recrutables), création du leader par 4 archétypes & portraits libres, Crises d'autonomie & 4 grands destins** → Chantier A consolidé dans `docs/personnages_et_relations.md`.
* [x] **Scène / Niveau-Pilote (*« Couvre-Feu au Galaxian »*) : Frise chronologique à Interruptions hors-tour, bascule libre & pièges de design arbitrés** → Chantier B consolidé dans `docs/niveau_pilote.md`.
* [x] **Direction artistique, palette Jour/Nuit, petits détails étranges, son Cold Wave 1982 & grille bande FM** → Chantier E consolidé dans `docs/direction_artistique_sonore.md`.
* [x] **Structure du jeu, Écran d'accueil vivant, Menu Principal (3 slots manuels / Options) & Écran « Nouvelle partie »** → Spécification consolidée dans `docs/structure_menus_et_ecrans.md`.
* [ ] **Scénario principal, étincelle dramatique & échelle temporelle** (pistes en réserve : *La Radio Fantôme & la disparition*, *Le Grand Chantier*, *L'Incident de trop*, ou autre ; format cocotte-minute sur 3–5 jours vs chronique d'un été — Chantier D `docs/scenario_acte1.md`).
* [x] **Phase Technique (🛠️ Léo — Architecture & Jalon 0)** → Stack validée (**Godot 4 / GDScript, 2D Isométrique, Data-Driven JSON**) dans `docs/architecture_technique.md` et prototype initialisé dans `game/project.godot`.
