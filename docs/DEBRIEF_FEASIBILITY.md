# Cortex Debrief — faisabilité Retail 12.x / Midnight

## Périmètre vérifié

- Vérification effectuée le 23 août 2026 contre `Gethe/wow-ui-source`, branche `live`.
- Version observée : Retail 12.1.0, build 69404, commit `81d15e4`.
- Sources primaires : documentation API générée et code de l'interface Blizzard.
- Cette analyse ne considère comme utilisable qu'un contrat public dont le nom, les arguments, les retours et les restrictions ont été vérifiés.
- `TO VERIFY` signifie que Cortex ne doit pas utiliser l'API tant que son contrat public n'est pas suffisamment décrit.

## Définitions

- **SUPPORTED** : donnée explicitement exposée par une API publique vérifiée et utilisable dans le cadre décrit.
- **LIMITED** : donnée conditionnelle, incomplète, ambiguë, ou dont une partie du contrat reste `TO VERIFY`.
- **IMPOSSIBLE** : aucune source publique conforme ne permet de produire la donnée demandée avec la précision attendue.

`SUPPORTED` ne signifie jamais « disponible pendant le combat ». Les lectures `C_DamageMeter` documentées `SecretWhenInCombat` sont exclusivement post-combat dans Cortex.

## Verdict synthétique

| Fonctionnalité | Statut | API / événement vérifié | Restriction combat | Risque Secret Value | Décision Cortex |
|---|---|---|---|---|---|
| Résultat d'une rencontre reconnue | **SUPPORTED** | `ENCOUNTER_END(encounterID, encounterName, difficultyID, groupSize, success, encounterUnitStatus)` | L'événement peut arriver avant la fin effective du lockdown ; Cortex ne fait aucune action protégée | Faible ; champs accessibles uniquement après validation | Conserver seulement les métadonnées explicites et `success` |
| Durée d'une session de combat native | **SUPPORTED** | `C_DamageMeter.GetAvailableCombatSessions()`, `DamageMeterAvailableCombatSession.durationSeconds`, `DamageMeterCombatSession.durationSeconds` | Lecture détaillée seulement hors combat | Élevé en combat, faible après validation hors combat | Lire la durée native post-combat lorsqu'une session est identifiable sans ambiguïté |
| Durée exacte de toute rencontre | **LIMITED** | Source native ci-dessus ; chronométrage `ENCOUNTER_START` → `ENCOUNTER_END` possible conceptuellement, horloge précise **TO VERIFY** | Aucun échantillonnage de combat autorisé | Faible pour les événements, mais corrélation de session non garantie | Ne pas prétendre couvrir les combats sans session native correspondante |
| Nombre de morts et moment des morts | **SUPPORTED** | `C_DamageMeter.GetCombatSessionFromID(sessionID, Enum.DamageMeterType.Deaths)` ; `DamageMeterCombatSource.deathTimeSeconds`, `deathRecapID` | `GetCombatSessionFromID` est `SecretWhenInCombat` | Élevé en combat ; contrôler chaque valeur après combat | Copier un résumé compact après combat uniquement |
| Séquence causale d'une mort | **LIMITED** | `C_DeathRecap.GetRecapEvents(recapID)` existe, mais `DeathRecapEventInfo` ne documente aucun champ | Arguments autorisés seulement non contaminés ; disponibilité exacte **TO VERIFY** | Contrat opaque | Ne pas implémenter tant que la structure publique n'est pas vérifiable |
| Interruptions réussies | **SUPPORTED** | `Enum.DamageMeterType.Interrupts`, `C_DamageMeter.GetCombatSessionFromID` | Lecture détaillée seulement hors combat | Élevé en combat | Exposer les totaux natifs post-combat, sans reconstruire de timeline |
| Interruptions manquées | **IMPOSSIBLE** | Aucune statistique native vérifiée ne décrit les casts interruptibles non interrompus | Nécessiterait une observation détaillée du combat | Très élevé | Saisie utilisateur, outil externe, ou statistique native future uniquement |
| Utilisation générique des défensifs | **IMPOSSIBLE** | Aucun type `DamageMeterType` ne représente les casts de défensifs | Nécessiterait journal/timeline/aura tracking de combat | Très élevé | Ne pas inférer un usage défensif à partir des soins, dégâts subis ou absorptions |
| Absorptions produites | **SUPPORTED** | `Enum.DamageMeterType.Absorbs`, `C_DamageMeter.GetCombatSessionFromID` | Lecture détaillée seulement hors combat | Élevé en combat | Statistique native distincte ; ne jamais la présenter comme liste complète des défensifs |
| Dégâts évitables natifs | **SUPPORTED** | `Enum.DamageMeterType.AvoidableDamageTaken`, `DamageMeterCombatSpell.isAvoidable` | Lecture détaillée seulement hors combat | Élevé en combat | Montrer la valeur native, avec attribution explicite à Blizzard |
| « Erreurs importantes » génériques | **IMPOSSIBLE** | Aucune API publique vérifiée ne fournit un jugement tactique complet | Exigerait reconstruction du combat ou heuristiques en combat | Très élevé | Limiter Cortex à « dégâts évitables signalés par le Damage Meter natif » ; saisie utilisateur ou outil externe pour le reste |
| Historique/timeline détaillé du combat | **IMPOSSIBLE** | `COMBAT_LOG_EVENT`, `COMBAT_LOG_EVENT_UNFILTERED` et les fonctions `C_CombatLogSecure` sont marqués `HasRestrictions` | Restreint par le client | Critique | Aucun enregistrement, parsing, cache ou reconstruction dans Cortex |
| Partage de télémétrie de combat entre addons | **IMPOSSIBLE** | Les API de communication ne rendent pas une donnée interdite licite ou accessible | Ne contourne aucune restriction | Critique | Aucun protocole Cortex pour échanger des données de combat restreintes |

## Détail des sources autorisées

### 1. Cycle de rencontre

`EncounterInfoDocumentation.lua` documente :

- `ENCOUNTER_START(encounterID, encounterName, difficultyID, groupSize)` ;
- `ENCOUNTER_END(encounterID, encounterName, difficultyID, groupSize, success, encounterUnitStatus)` ;
- `BOSS_KILL(encounterID, encounterName)`.

Ces événements sont des métadonnées de cycle de rencontre, pas un flux de combat. Cortex peut enregistrer le résultat explicite de `ENCOUNTER_END`. Il ne doit pas analyser `encounterUnitStatus.remainingHealthPercent` pour fabriquer une explication tactique ; cette donnée n'est pas nécessaire au MVP Debrief.

Limites :

- ils couvrent les rencontres reconnues par le client, pas tous les combats du monde ouvert ;
- `success` est un nombre fourni par l'événement ; Cortex le normalise seulement vers succès/échec, sans inférence ;
- `BOSS_KILL` peut confirmer une victoire mais ne remplace pas `ENCOUNTER_END` pour un résultat complet.

### 2. Damage Meter natif de Midnight

`DamageMeterDocumentation.lua` documente :

- `C_DamageMeter.IsDamageMeterAvailable()` ;
- `C_DamageMeter.GetAvailableCombatSessions()` ;
- `C_DamageMeter.GetCombatSessionFromID(sessionID, type)` ;
- `C_DamageMeter.GetCombatSessionFromType(sessionType, type)` ;
- `C_DamageMeter.GetCombatSessionSourceFromID(...)` et `...FromType(...)` ;
- `C_DamageMeter.GetSessionDurationSeconds(sessionType)` ;
- `DAMAGE_METER_COMBAT_SESSION_UPDATED(type, sessionID)` ;
- `DAMAGE_METER_CURRENT_SESSION_UPDATED` et `DAMAGE_METER_RESET`.

Les lectures de sessions détaillées sont `SecretWhenInCombat = true`. Le périmètre Cortex est donc :

1. ne jamais appeler ces lectures pendant `InCombatLockdown()` ;
2. attendre une sortie de combat explicite ;
3. vérifier `C_DamageMeter.IsDamageMeterAvailable()` ;
4. refuser toute table ou valeur secrète/inaccessible ;
5. copier uniquement des scalaires nécessaires dans une structure Cortex non secrète ;
6. abandonner proprement le résumé si la session ne peut pas être associée sans ambiguïté.

La première implémentation exige exactement une session disponible dont le nom accessible correspond au nom de la rencontre. Cette règle est une validation conservatrice de Cortex, pas une garantie supplémentaire de l'API. Plusieurs pulls portant le même nom produisent donc `AMBIGUOUS` plutôt qu'une attribution potentiellement fausse.

Les catégories vérifiées dans `DamageMeterConstantsDocumentation.lua` sont :

`DamageDone`, `Dps`, `HealingDone`, `Hps`, `Absorbs`, `Interrupts`, `Dispels`, `DamageTaken`, `AvoidableDamageTaken`, `Deaths`, `EnemyDamageTaken`.

Il n'existe pas de catégorie publique vérifiée pour :

- casts de défensifs ;
- défensifs disponibles mais non utilisés ;
- interruptions manquées ;
- erreurs de placement ;
- erreurs de rotation ;
- attribution générale de responsabilité.

### 3. Informations de mort

La catégorie native `Deaths` expose des sources agrégées avec `deathRecapID` et `deathTimeSeconds`. Cette partie est utilisable post-combat.

`C_DeathRecap.GetRecapEvents` est public, mais la structure retournée `DeathRecapEventInfo` possède une liste de champs vide dans la documentation générée observée. Cortex ne doit donc ni supposer les clés utilisées par Blizzard, ni copier une implémentation interne instable. Cette analyse détaillée reste **TO VERIFY** et n'est pas implémentée.

### 4. Combat Log

`CombatLogDocumentation.lua` marque `COMBAT_LOG_EVENT` et `COMBAT_LOG_EVENT_UNFILTERED` avec `HasRestrictions = true`. `CombatLogSecureDocumentation.lua` marque aussi les opérations `C_CombatLogSecure` (`GetCurrentEventInfo`, `GetCurrentEntryInfo`, navigation et filtres) avec `HasRestrictions = true`.

Conséquences :

- Cortex ne s'enregistre à aucun événement de combat log pour Debrief ;
- Cortex ne parcourt pas les entrées du journal après combat pour reconstruire une timeline ;
- Cortex n'utilise pas `Blizzard_DeprecatedCombatLog` ;
- Cortex ne transforme pas du texte de chat, un tooltip, une chaîne formatée ou une représentation visuelle en télémétrie ;
- Cortex ne conserve pas de données secrètes pour tenter de les exploiter après la rencontre.

### 5. Addon communication

La communication addon n'accorde aucun droit supplémentaire sur la donnée source. Une valeur interdite localement reste interdite si un autre addon tente de la sérialiser ou de la transmettre. Cortex Debrief n'émet et ne reçoit aucune télémétrie de combat dans le but de compléter ses analyses.

### 6. Actions protégées et combat lockdown

Debrief est passif. Il ne doit :

- ni lancer une action de jeu ;
- ni modifier d'attribut sécurisé ;
- ni changer de binding ;
- ni déplacer/reconfigurer un frame protégé ;
- ni afficher une décision tactique pendant le combat.

Pendant le combat, Cortex peut seulement retenir les métadonnées explicites de cycle de rencontre et marquer un rafraîchissement nécessaire. Toute lecture du Damage Meter et toute publication du récapitulatif ont lieu après `PLAYER_REGEN_ENABLED`.

## Périmètre d'implémentation autorisé

La première version conforme peut implémenter uniquement :

- les métadonnées explicites de `ENCOUNTER_START` / `ENCOUNTER_END` ;
- le résultat explicite de la rencontre ;
- la durée native d'une session associée sans ambiguïté ;
- les agrégats post-combat `Deaths`, `Interrupts`, `Absorbs` et `AvoidableDamageTaken` ;
- un état clair `AVAILABLE`, `UNAVAILABLE` ou `AMBIGUOUS` pour chaque groupe de statistiques ;
- un résumé en mémoire et un historique compact, sans événements bruts ni timeline.

Ne sont pas autorisés dans cette version :

- `C_DeathRecap.GetRecapEvents` ;
- tout Combat Log ;
- l'analyse des défensifs ;
- les interruptions manquées ;
- un moteur de « mistakes » ;
- une recommandation tactique ;
- la communication de données de combat.

## Alternatives conformes pour les fonctions non disponibles

| Besoin | Alternative conforme |
|---|---|
| Comprendre une mort en détail | Ouvrir le récapitulatif natif Blizzard ; saisie manuelle d'une note ; journal externe analysé hors addon |
| Vérifier l'usage de défensifs | Auto-évaluation du joueur ; revue vidéo ; outil externe autorisé exploitant un journal produit hors du runtime addon |
| Identifier les interruptions manquées | Saisie utilisateur, statistiques natives futures, ou analyse externe après la session |
| Diagnostiquer une erreur tactique | Afficher uniquement les dégâts évitables que Blizzard qualifie lui-même ainsi ; compléter par une note utilisateur |
| Produire une timeline complète | Outil externe dédié ; Cortex peut seulement proposer un lien ou un champ de référence saisi par l'utilisateur, sans importer automatiquement une donnée interdite |

## Références primaires

- [`version.txt`](https://github.com/Gethe/wow-ui-source/blob/live/version.txt)
- [`EncounterInfoDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/EncounterInfoDocumentation.lua)
- [`DamageMeterDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/DamageMeterDocumentation.lua)
- [`DamageMeterConstantsDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/DamageMeterConstantsDocumentation.lua)
- [`CombatLogDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/CombatLogDocumentation.lua)
- [`CombatLogSecureDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/CombatLogSecureDocumentation.lua)
- [`DeathRecapDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/DeathRecapDocumentation.lua)
- [`Blizzard_DamageMeter/DamageMeterSessionWindow.lua`](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_DamageMeter/DamageMeterSessionWindow.lua)
