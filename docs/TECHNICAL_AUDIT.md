# Cortex — audit technique complet

Audit arrêté au **23 août 2026** sur Cortex `0.1.0`, WoW Retail **12.1.0**, interface **120100**, build **12.1.0.69404**. La référence API est la branche `live` de `Gethe/wow-ui-source`, commit [`81d15e42f16f3473131880500e7a8c8eb88fa5e6`](https://github.com/Gethe/wow-ui-source/tree/81d15e42f16f3473131880500e7a8c8eb88fa5e6).

Cet audit couvre le code Lua, le TOC, les événements, les frames, les données persistées et toutes les API WoW effectivement appelées par Cortex. Il ne remplace pas un test dans le client Retail : aucun runtime Lua WoW ni client de jeu n'était disponible dans l'environnement d'audit.

### Revalidation release `0.1.0-alpha` — 29 août 2026

La préparation de release a été recontrôlée sur la branche `live`, commit [`027d26c3406d3de2cbd2b1f67d468fe033a1bcd4`](https://github.com/Gethe/wow-ui-source/tree/027d26c3406d3de2cbd2b1f67d468fe033a1bcd4), build **12.1.0.69497**. Depuis le build 69404, les changements concernent des contrats Unit d'assistance non utilisés par Cortex, l'implémentation Blizzard des auras/private auras et des annotations Secret Value de Voice Chat. Aucun symbole appelé par Cortex n'a changé.

Lua Language Server 3.18.2 a analysé les 81 fichiers du workspace avec la configuration Lua 5.1 : aucune erreur. Le TOC contient toujours 71 entrées, sans fichier manquant ni doublon; les 286 clés enUS/frFR sont alignées, y compris leurs placeholders de format. Les smoke tests restent à exécuter avec un interpréteur Lua compatible, puis dans le client Retail selon la matrice ci-dessous.

## Verdict

- **CRITICAL ouverts : 0**
- **HIGH ouverts : 0** — les problèmes HIGH trouvés ont été corrigés pendant l'audit.
- **MEDIUM ouverts : 12**
- **LOW ouverts : 6**
- **Score de préparation technique : 84/100**
- **GO** pour une validation alpha en jeu.
- **NO-GO** pour une diffusion publique tant que la matrice de tests Retail, combat, instance et taint n'a pas été exécutée.

L'architecture est cohérente pour la taille actuelle : namespace unique, services et modules enregistrés, dépendances initialisées par le registre, collecteurs séparés des règles, UI sans logique de collecte et persistence versionnée. Aucun framework supplémentaire n'est justifié.

## Résultat par domaine

| Domaine | Résultat | Observation |
|---|---|---|
| Architecture | Bon | Flux `API -> Collectors -> Facts -> Context -> Goals/Rules -> UI`; responsabilités globalement nettes |
| Coupling | Acceptable | Quelques actions UI sont résolues tardivement pour éviter des cycles; voir M-06 |
| Event subscriptions | Bon après correction | Événements bornés, modules désinscriptibles, collecteurs coalescés |
| Allocations mémoire | Acceptable | Pas de boucle par frame; copies de tables sur scans et événements internes, voir M-02/M-03/M-07 |
| SavedVariables | Compact mais non borné partout | Historique et snapshots bornés; goals et nombre de personnages non bornés |
| `OnUpdate` | Excellent | Aucun `OnUpdate` dans le code de production |
| Frames | Bon | Création paresseuse et capacités fixes; pas de reconstruction lors d'un refresh |
| Event storms | Bon après correction | Coalescing par tick, ciblage des IDs, filtre `GET_ITEM_INFO_RECEIVED` |
| Recalculs | Bon après correction | Recommendation ciblée par source et fact; graphe reconstruit une fois par passe |
| Cache invalidation | Bon après correction | Un résultat identique restaure le fact sans propager de changement métier |
| Lua/nil handling | Bon statiquement | Guards et `pcall` fréquents; qualité du diagnostic à améliorer |
| Combat lockdown | Bon | Collecteurs différés, UI non protégée, travail différé par clé |
| Taint | Faible risque | Aucun hook, overwrite de fonction Blizzard, template secure ou attribut protégé |
| Secret Values | Conservateur | Valeurs/tables secrètes rejetées; aucun calcul tactique en combat |
| Deprecated APIs | Aucun usage détecté | Les globals legacy utilisés restent confirmés par des callsites Blizzard; annotations exactes à revalider |
| Code dupliqué/mort | Faible | Égalité profonde centralisée; deux points d'extension sans consommateur actuel |
| Dépendances | Bon après correction | Dépendances directes ajoutées; les dépendances UI tardives sont documentées |

## Architecture et dépendances

Ordre logique vérifié dans le TOC :

```text
Namespace / Constants / Locales
  -> Registry / Logger / Profiler / EventBus / Commands
  -> Schema / Migrations / Repositories / Database
  -> Facts / Collectors / Context
  -> Goals / Sharing / Warband / Debrief
  -> Rules / Recommendations / Detective / Planner / Search
  -> UI components / pages / windows / chat
  -> Bootstrap
```

Le bootstrap ne lance les migrations qu'à `ADDON_LOADED` pour l'addon courant. Aucun événement Gear, Currency, Profession ou UI ne réinitialise la base ou ne relance une migration.

Les dépendances manquantes constatées pendant l'audit ont été déclarées :

- `Events -> Profiler`;
- `Search -> Logger`;
- `Detective -> Goals, Recommendations`;
- `ShareCodes -> Goals`;
- `ChatCommands -> Recommendations`.

Le registre détecte les cycles à l'initialisation. Les modules dépendants sont activés avant leur consommateur et un module requis par un autre module actif ne peut pas être désactivé.

## Chemin d'invalidation après correction

```text
PLAYER_EQUIPMENT_CHANGED
  -> GearCollector seulement
  -> FactStore compare les valeurs accessibles
  -> CONTEXT_UPDATED("Gear", changedFactKeys) seulement si changement matériel
  -> RuleEngine vérifie les rules Gear ET leurs factKeys
  -> RecommendationEngine devient dirty seulement si
       gear.missingGems ou gear.upgrades a réellement changé
  -> reconstruction paresseuse du cache
  -> refresh de la page Overview/Session seulement si elle est visible
```

Conséquences vérifiées :

- un changement de seul `character.itemLevel` ne recalcule pas les règles Gems/Upgrade;
- une répétition du même snapshot Gear ne publie pas `CONTEXT_UPDATED`;
- Gear ne dépend ni du collecteur Profession ni du collecteur Warband;
- le snapshot Warband Gear ne copie que l'ilvl;
- le collecteur de contexte Warband ne copie plus tous les snapshots de personnages;
- un snapshot Warband identique ne publie pas `WARBAND_UPDATED`, sauf transition nécessaire de `CACHED` vers `LIVE`;
- la page Warband n'est pas rafraîchie par une invalidation Recommendation;
- les frames UI existantes sont mises à jour, jamais reconstruites;
- aucune migration de base n'est appelée.

## CRITICAL

Aucun problème CRITICAL n'est ouvert après audit.

## HIGH — corrigés

### H-01 — Invalidation Recommendation trop large

**Avant :** toute mise à jour d'une source consommée invalidait toutes les recommandations de cette source, même si le fact utile à la règle n'avait pas changé.

**Correction :** `FactStore:Apply` retourne la liste triée des facts matériellement modifiés. `ContextService` la publie et `RuleEngine:UsesContextChange` croise source et `factKeys`. L'ancien comportement conservateur reste utilisé si un émetteur ne fournit pas la liste.

### H-02 — Snapshots identiques considérés comme de nouveaux états

**Avant :** un refresh après invalidation pouvait propager un résultat identique. Cela réveillait Goals, Recommendations, Warband et UI sans changement métier.

**Correction :** égalité profonde, cycle-safe et Secret-Value-safe dans `Schema.ValuesEqual`; distinction `checkedAt` / `updatedAt`; restauration d'un fact stale sans faux changement.

### H-03 — Reconstructions répétées du graphe de dépendances

**Avant :** les règles pouvaient reconstruire `DependencyGraph` pour chaque goal racine et chaque recherche de blockers dans une seule passe Recommendation.

**Correction :** `RecommendationEngine:Rebuild` reconstruit le graphe une fois. Les appels de règles réutilisent explicitement ce graphe courant. Complexité supprimée : plusieurs rebuilds `O(G + E)` par recommandation deviennent un rebuild par passe.

### H-04 — Propagation Gear vers Warband et UI

**Avant :** un capture Warband réécrivait/publiait même lorsque les données utiles étaient identiques; le fact Warband copiait tous les personnages, timestamps inclus.

**Correction :** capture Warband par champs, comparaison matérielle, publication uniquement sur changement ou transition `LIVE`, et fact Warband réduit à son agrégat réellement consommé. Gear ne déclenche aucun scan Profession.

### H-05 — Coalescing susceptible de perdre un ID d'événement

**Avant :** deux événements ciblés avant le flush pouvaient conserver un seul payload et perdre la première monnaie/faction concernée.

**Correction :** les doublons deviennent une requête `coalesced` sans ID, donc un scan complet correct au prochain tick. Une seule tâche `C_Timer.After(0)` est planifiée.

### H-06 — Tempête globale `GET_ITEM_INFO_RECEIVED`

**Avant :** tout objet chargé par le client pouvait provoquer un scan Gear.

**Correction :** rescan uniquement si le cache Gear est incomplet, si le chargement n'a pas échoué et si l'item correspond à un slot équipé connu. En cas d'information insuffisante, le collecteur reste conservateur.

### H-07 — Dépendances utilisées mais non déclarées

**Correction :** les dépendances directes listées dans la section Architecture ont été ajoutées. Les fermetures UI tardives restantes sont documentées en M-06 car leur déclaration directe créerait une dépendance circulaire.

### H-08 — Référence API Reputation incorrecte dans la documentation

**Avant :** `docs/API_CAPABILITIES.md` nommait `C_ReputationInfo`.

**Correction :** la source générée s'appelle `ReputationInfoDocumentation.lua`, mais déclare le namespace public `C_Reputation`; documentation et code sont maintenant alignés sur le build 69404.

## MEDIUM — ouverts

### M-01 — Taille SavedVariables non bornée pour goals et personnages

`history` est borné à 50 entrées, les références de snapshot à 50, les monnaies Warband à 32, les professions à 8 et les templates/task lists à 50. En revanche, `goals.items`, `characters` et `sessions.byCharacter` n'ont pas de politique d'archivage/suppression. Cela reste raisonnable pour un usage normal, mais une base ancienne ou modifiée manuellement peut croître sans limite.

**Recommandation :** mesurer d'abord en jeu, puis définir une politique explicite d'archivage utilisateur; ne pas supprimer automatiquement des goals ou personnages pendant une migration.

### M-02 — Copie complète de `CortexDB` à l'initialisation

La base est copiée avant migration pour protéger les données d'une migration partiellement échouée. Le compromis est un pic mémoire proportionnel à la taille de la SavedVariable pendant `ADDON_LOADED`.

**Recommandation :** conserver cette sécurité tant que la base reste compacte; réévaluer seulement avec des mesures réelles.

### M-03 — Allocations de l'EventBus

Chaque publication avec abonnés crée une copie de la liste des abonnés pour rendre les désabonnements pendant dispatch sûrs. Le nombre d'abonnés est faible, mais les événements internes très fréquents produiraient des tables temporaires.

**Recommandation :** mesurer avec le profiler avant toute optimisation; ne pas sacrifier la sûreté de mutation prématurément.

### M-04 — Scans complets encore possibles

Currency et Reputation savent mettre à jour un ID précis. Un burst avec plusieurs IDs devient volontairement un full scan. Quest et Weekly rescannent leur surface complète. C'est correct mais peut coûter avec un journal/faction list volumineux.

**Recommandation :** utiliser les durées collecteur; envisager un petit ensemble d'IDs coalescés uniquement si les mesures montrent un coût significatif.

### M-05 — Accès mutable aux facts

`FactStore:Get`, `GetLastKnown` et `GetRecord` exposent les tables internes. Un consommateur pourrait les modifier sans invalidation ni événement.

**Recommandation :** discipline de lecture seule à court terme; passer à des copies ou vues immuables uniquement si un deuxième producteur externe apparaît.

### M-06 — Couplage UI tardif

Navigation, Recommendations, Planner et Search contiennent des actions de commande qui résolvent `MainWindow` au moment du clic. Déclarer `MainWindow` comme dépendance créerait un cycle avec les services que cette fenêtre consomme.

**Recommandation :** acceptable pour l'alpha. Si l'UI se multiplie, introduire un seul événement `OPEN_PAGE` ou un petit routeur d'actions, pas un framework.

### M-07 — Allocations Search et view models

Chaque frappe de la palette reconstruit résultats, scores et certaines closures de providers. Chaque refresh UI reconstruit un view model, mais recycle les frames.

**Recommandation :** ne pas optimiser sans profil; le nombre de résultats et de lignes affichées est borné.

### M-08 — Construction d'un plan avec effet de bord

`SessionPlanner:Build` persiste `unfinishedTasks`. Une simple lecture/actualisation de la page Session modifie donc les SavedVariables.

**Recommandation :** séparer plus tard `Build` et `RememberPlan` si des consommateurs purement analytiques apparaissent. Ce changement touche le contrat fonctionnel et n'a pas été fait dans cet audit.

### M-09 — Diagnostics d'erreurs trop pauvres

Collectors, rules, EventBus et actions utilisent `pcall`, mais le log garde souvent seulement le nom de l'étape, pas le message d'erreur ni la stack. Les erreurs ne cassent pas l'addon, mais le diagnostic en jeu est moins efficace.

**Recommandation :** en DEBUG uniquement, journaliser une forme nettoyée du message retourné par `pcall` ou utiliser le gestionnaire d'erreur Blizzard sans exposer de valeur secrète.

### M-10 — Globals legacy à revalider par build

`GetInventoryItemID`, `GetInventoryItemLink`, `GetProfessions`, `GetProfessionInfo`, `IsInInstance` et `GetInstanceInfo` sont confirmés par les callsites Blizzard du build audité, mais ne disposent pas tous d'un contrat complet dans les docs générées.

**Recommandation :** statut **TO VERIFY** pour leurs annotations Secret exactes à chaque changement de build; les guards runtime et la collecte hors combat restent obligatoires.

### M-11 — Validation Retail/taint manquante

L'analyse statique ne peut pas prouver l'absence d'erreur Lua, de taint ou de différences de timing/cache dans le client.

**Recommandation :** exécuter la matrice de validation en fin de document avant release.

### M-12 — Un module désactivé reste récupérable

`Cortex:GetModule(name)` retourne l'objet enregistré même si le module est désactivé. La désactivation retire les subscriptions et vide certains caches, mais une commande ou une UI peut encore appeler directement ses méthodes. C'est notamment possible pour Recommendations via MainWindow.

**Recommandation :** définir avant release la sémantique produit d'un module désactivé : masquer ses commandes/pages, ou faire retourner une façade inactive. Ne pas changer ce contrat implicitement pendant un audit de performance.

## LOW — ouverts

### L-01 — Événement `FACT_CHANGED` sans abonné actuel

Il sert de point d'extension et au profiling interne, mais aucun module actuel ne l'écoute. À conserver seulement si une future instrumentation fact-level l'utilise.

### L-02 — Wrapper de compatibilité non référencé

`ContextService:RefreshCurrentCharacter` n'est pas appelé dans le dépôt. Il est petit et explicitement nommé compatibility; suppression possible après vérification qu'aucun consommateur externe n'est supporté.

### L-03 — Timestamp de progress goal mis à jour sans changement métier

Une évaluation weekly identique peut modifier `progress.updatedAt` sans publier `GOALS_CHANGED`. Le recalcul Recommendation est évité, mais la table SavedVariables en mémoire change.

### L-04 — `CortexCharacterDB` est seulement un pont legacy

La SavedVariable per-character reste déclarée pour importer un ancien timestamp. Les nouvelles données vivent dans `CortexDB`. Une suppression future nécessite une migration annoncée et ne doit pas être faite silencieusement.

### L-05 — Validation d'anciennes collections persistées

Les nouvelles écritures History/Templates sont bornées. La validation normalise les templates, mais une base manuellement altérée peut encore contenir un historique initial supérieur à 50 jusqu'à la prochaine écriture.

### L-06 — Pas de mesure en octets de `CortexDB`

Le DebugSummary donne les nombres de personnages, sessions et historiques, pas une taille sérialisée. Ajouter un sérialiseur uniquement pour mesurer créerait du code et des allocations non justifiés. La taille doit être observée dans le fichier SavedVariables ou avec les outils mémoire du client pendant le test.

## SavedVariables et mémoire

### Données persistées

`CortexDB` conserve uniquement : settings, identités/snapshots compacts, goals, historique borné, références de sessions, Warband, états de modules et templates. Les facts complets Quest/Currency/Reputation/Gear ne sont pas sauvegardés tels quels.

| Section | Borne actuelle | Risque |
|---|---:|---|
| `history.items` | 50 | Faible |
| `unfinishedGoals` / `unfinishedTasks` | 50 par personnage | Faible |
| monnaies transférables Warband | 32 par personnage | Faible |
| professions Warband | 8 par personnage | Faible |
| templates | 50 par collection | Faible |
| tâches par template/share code | 50 | Faible |
| goals | non borné | Moyen à long terme |
| personnages/sessions | non borné | Faible en usage normal, moyen sur très longue durée |

Le profiler n'est pas persisté; seul son booléen d'activation l'est. Ses métriques disparaissent au reload.

### Mémoire volatile

- `FactStore` garde un snapshot courant et éventuellement une dernière valeur connue stale/unavailable.
- Les plus grosses surfaces potentielles sont les listes Quest, Currency et Reputation.
- `WarbandRepository:GetCharacters` copie les données avant de les exposer.
- Les caches Recommendation, Search et view models sont de petite taille.
- Aucune allocation périodique par frame n'existe.

## Événements et tempêtes

### Core

`ADDON_LOADED`, `PLAYER_LOGIN`, `PLAYER_LOGOUT`, `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`.

### Context

- Character : `PLAYER_LEVEL_UP`;
- Gear : `PLAYER_EQUIPMENT_CHANGED`, `PLAYER_AVG_ITEM_LEVEL_UPDATE`, `GET_ITEM_INFO_RECEIVED`;
- Currency : `CURRENCY_DISPLAY_UPDATE`;
- Quest : `QUEST_LOG_UPDATE`, `QUEST_DATA_LOAD_RESULT`;
- Weekly : `WEEKLY_REWARDS_UPDATE`, `WEEKLY_REWARDS_ITEM_CHANGED`;
- Instance : `PLAYER_ENTERING_WORLD`;
- Profession : `SKILL_LINES_CHANGED`;
- Reputation/Renown : `FACTION_STANDING_CHANGED`, `MAJOR_FACTION_RENOWN_LEVEL_CHANGED`, `MAJOR_FACTION_UNLOCKED`;
- Location : `PLAYER_MAP_CHANGED`, `ZONE_CHANGED`, `ZONE_CHANGED_INDOORS`, `ZONE_CHANGED_NEW_AREA`;
- restrictions : `ADDON_RESTRICTION_STATE_CHANGED`.

### Debrief

`ENCOUNTER_START`, `ENCOUNTER_END`, `PLAYER_REGEN_ENABLED`, `DAMAGE_METER_COMBAT_SESSION_UPDATED`, `DAMAGE_METER_RESET`.

Tous les collecteurs sont hors combat. Les bursts sont coalescés au prochain tick. Les modules qui se désactivent retirent leurs subscriptions internes; Debrief unregister ses événements WoW. Les frames Core/Context vivent pendant toute la session, ce qui est intentionnel.

## Frames et UI

- 31 sites `CreateFrame` en production, principalement des factories appelées un nombre borné de fois.
- MainWindow, CommandPalette et ShareCodeDialog sont créés paresseusement une fois.
- ScrollList utilise des rangées fixes/réutilisées : Overview 3, Session 6, Warband 5+4, Palette 8.
- Aucun `OnUpdate`.
- Aucun template sécurisé, frame protégée, attribut secure ou action de gameplay.
- Un refresh reconstruit seulement le view model et les textes/états visuels.
- Le footer combat est rafraîchi séparément; les pages non visibles ne sont pas recalculées.

## Combat lockdown, taint et Secret Values

- `InCombatLockdown()` est suivi par le Bootstrap; le travail différé est dédupliqué par clé et repris à `PLAYER_REGEN_ENABLED`.
- Context vérifie `C_RestrictedActions.IsAddOnRestrictionActive` pour `Combat`, `Encounter`, `ChallengeMode`, `PvPMatch` et `Map`. `Chat` n'est pas interrogé car Cortex n'utilise aucune communication addon.
- Tous les collecteurs déclarent `requiresOutOfCombat = true`.
- `issecretvalue`, `issecrettable` et `canaccessvalue` sont utilisés en fail-closed. Une table secrète est rejetée même si une partie pourrait être accessible.
- Les comparaisons, copies, rules et persistence refusent les valeurs non accessibles.
- Debrief n'utilise que `C_DamageMeter` après combat; aucun combat log brut n'est enregistré.
- Aucun contournement par addon communication, parsing de représentation, protected action ou journal clandestin.
- Aucun hook, `SetAttribute`, `RegisterStateDriver`, `SecureActionButtonTemplate`, `SetBinding` ou mutation de frame Blizzard.

Risque de taint statique : **faible**. Risque résiduel tant que non testé en jeu : **moyen**.

## Audit des API WoW effectivement appelées

| Domaine | API / événements utilisés | Vérification 12.1.0.69404 | Restrictions / décision |
|---|---|---|---|
| Runtime/UI | `CreateFrame`, méthodes Frame/Region/EditBox/Button, `UIParent`, `DEFAULT_CHAT_FRAME` | APIs UI générées / usage Blizzard | Frames non secure; aucun protected action |
| Temps | `time`, `GetTimePreciseSec`, `C_Timer.After` | `C_Timer.After` généré; timer haute précision présent dans le client | Profiler optionnel; coalescing callback non secret |
| Combat | `InCombatLockdown`, `PLAYER_REGEN_*` | API/runtime Retail établi | Aucun changement protégé; collecteurs différés |
| Restrictions Midnight | `C_RestrictedActions.IsAddOnRestrictionActive`, `Enum.AddOnRestrictionType`, `Enum.AddOnRestrictionState`, `ADDON_RESTRICTION_STATE_CHANGED` | Définitions générées vérifiées | Fail-closed; reprise après état Inactive |
| Secret predicates | `issecretvalue`, `issecrettable`, `canaccessvalue` | `SecretPredicatesDocumentation.lua` | Valeur inaccessible rejetée, jamais formatée/persistée |
| Character | `UnitFullName`, `UnitGUID`, `UnitClass`, `UnitLevel`, `PLAYER_LEVEL_UP` | Unit docs générées | Identité du player; hors combat |
| Gear | `GetInventoryItemID`, `GetInventoryItemLink` | Callsites Blizzard actuels; signature/annotations complètes **TO VERIFY** | Type guards, player uniquement, hors combat |
| Item | `C_Item.GetDetailedItemLevelInfo`, `GetItemUpgradeInfo`, `GetItemNumSockets`, `GetItemGemID`; `GET_ITEM_INFO_RECEIVED` | `ItemDocumentation.lua` vérifié | Cache possible; arguments non contaminés; aucune action d'upgrade |
| Item level | `C_PaperDollInfo.GetInspectItemLevel("player")` | `PaperDollInfoDocumentation.lua` vérifié | Lecture player, hors combat |
| Currency | `C_CurrencyInfo.GetCurrencyListSize`, `GetCurrencyListInfo`, `GetCurrencyInfo`; `CURRENCY_DISPLAY_UPDATE` | `CurrencyInfoDocumentation.lua` vérifié | Update ciblée si ID accessible |
| Quest | `C_QuestLog.GetNumQuestLogEntries`, `GetInfo`, `IsComplete`, `ReadyForTurnIn`, `GetQuestObjectives`; événements Quest | `QuestLogDocumentation.lua` vérifié | `ReadyForTurnIn` nilable; unknown n'est pas converti en false |
| Weekly/Vault | `C_WeeklyRewards.GetActivities`, `CanClaimRewards`, `HasAvailableRewards`; événements Weekly | `WeeklyRewardsDocumentation.lua` vérifié | Lecture uniquement; aucune réclamation |
| Instance | `IsInInstance`, `GetInstanceInfo`, `PLAYER_ENTERING_WORLD` | Callsites Blizzard actuels; signature legacy **TO VERIFY** à chaque build | Métadonnées seulement, hors restrictions actives |
| Profession | `GetProfessions`, `GetProfessionInfo`, `SKILL_LINES_CHANGED` | Callsites `Blizzard_ProfessionsBook`; contrat généré incomplet **TO VERIFY** | Personnage actif, hors combat |
| Reputation | `C_Reputation.GetNumFactions`, `GetFactionDataByIndex`, `GetFactionDataByID`; `FACTION_STANDING_CHANGED` | `ReputationInfoDocumentation.lua`, namespace `C_Reputation` | `AllowedWhenUntainted` sur requêtes ID/index |
| Renown | `C_MajorFactions.GetMajorFactionIDs`, `GetMajorFactionData`; événements MajorFaction | `MajorFactionsDocumentation.lua` vérifié | Hors combat; valeurs accessibles seulement |
| Location | `C_Map.GetBestMapForUnit`, `GetMapInfo`, `GetPlayerMapPosition`, `Vector2D:GetXY`; événements Zone/Map | `MapDocumentation.lua` et vector API vérifiés | Player seulement; position nil/unavailable acceptée |
| Debrief | `C_DamageMeter.IsDamageMeterAvailable`, `GetAvailableCombatSessions`, `GetCombatSessionFromID`, `Enum.DamageMeterType`; événements DamageMeter/Encounter | `DamageMeterDocumentation.lua` vérifié | Sessions `SecretWhenInCombat`; lecture différée après combat |
| Addon communication | aucune | N/A | Aucun prefix, send ou `CHAT_MSG_ADDON` |
| Combat log | aucun | N/A | Aucun CLEU, `C_CombatLog` ou parser |
| Globals requis | `SlashCmdList`, `SLASH_CORTEX1`, `BINDING_NAME_CORTEX_COMMAND_PALETTE`, `CortexDB`, `CortexCharacterDB` | Contrats addon/SavedVariables/bindings | Seuls globals écrits; aucun `_G.Cortex` |

Aucun symbole appelé par Cortex n'a été identifié comme deprecated dans la source `live` auditée. Les APIs marquées **TO VERIFY** ne sont pas devinées : elles ont un callsite Blizzard actuel, mais leur contrat généré/annotations exactes n'est pas complet.

## Profiling DEBUG léger

Le service `Profiler` est **désactivé par défaut** (`settings.profiling = false`). Lorsqu'il est désactivé, il n'alloue aucune table de métrique par événement; les hooks font seulement un service lookup et un retour immédiat.

Commandes :

```text
/cortex debug profile on
/cortex debug profile off
/cortex debug profile show
/cortex debug profile reset
```

Mesures disponibles :

- durée totale, moyenne, maximum, dernière durée et nombre d'appels par collector;
- durée de `RecommendationEngine:Rebuild`;
- durée du refresh MainWindow et de chaque page;
- durée de refresh CommandPalette;
- nombre d'événements traités par `wow.core`, `wow.context`, `wow.debrief` et l'EventBus interne.

Les données de profiling restent en mémoire et ne sont pas écrites dans `CortexDB`.

## Contrôles statiques exécutés

- 71 entrées TOC contrôlées; **0 fichier manquant**.
- ordre TOC relu contre les dépendances enregistrées.
- 73 fichiers Lua au total, tests inclus.
- 276 clés de locale enUS et 276 frFR; **0 clé divergente**.
- 0 `OnUpdate`.
- 0 usage Combat Log, addon communication, secure template, protected attribute ou binding mutation dans le Lua.
- 32 sites `CreateFrame` tests inclus, dont 31 en production.
- écritures globales limitées aux SavedVariables, slash command et libellé de binding requis.
- guards nil/Secret et `pcall` relus sur tous les collecteurs, rules et Debrief.

Les smoke tests n'ont pas été exécutés : aucun interpréteur Lua/LuaJIT/luac ni parseur Lua compatible n'est installé dans l'environnement. Une exécution standalone ne prouverait de toute façon pas la compatibilité runtime WoW.

## Matrice de validation Retail obligatoire

1. Login et `/reload` avec base absente, schema courant, ancienne migration et schema futur read-only.
2. `/cortex`, navigation clavier, déplacement/scale, fermeture ESC et persistance de position.
3. Gear : équiper/retirer, cache item froid, changement d'ilvl, gemme vide, upgrade track; vérifier un seul rebuild utile.
4. Currency/Reputation/Quest : bursts d'événements et absence de scan croisé Profession/Warband inutile.
5. Entrée/sortie combat, encounter, Mythic+, donjon/raid et changement de carte restreinte.
6. Debrief : victoire, wipe, Damage Meter indisponible, session ambiguë, reset et valeurs secrètes après combat.
7. Enable/disable de chaque module et dépendances.
8. `/cortex debug profile on`, observer durées/counts, puis confirmer zéro métrique nouvelle après `off`.
9. Affichage des erreurs Lua activé; contrôler erreurs, taint/protected-action warnings, CPU, mémoire et chat spam.
10. Inspecter la taille réelle de `CortexDB` après plusieurs personnages et plusieurs jours.

## Sources principales

- [`version.txt` — 12.1.0.69404](https://raw.githubusercontent.com/Gethe/wow-ui-source/live/version.txt)
- [`Blizzard_APIDocumentationGenerated`](https://github.com/Gethe/wow-ui-source/tree/81d15e42f16f3473131880500e7a8c8eb88fa5e6/Interface/AddOns/Blizzard_APIDocumentationGenerated)
- [`ItemDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/81d15e42f16f3473131880500e7a8c8eb88fa5e6/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua)
- [`ReputationInfoDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/81d15e42f16f3473131880500e7a8c8eb88fa5e6/Interface/AddOns/Blizzard_APIDocumentationGenerated/ReputationInfoDocumentation.lua)
- [`RestrictedActionsDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/81d15e42f16f3473131880500e7a8c8eb88fa5e6/Interface/AddOns/Blizzard_APIDocumentationGenerated/RestrictedActionsDocumentation.lua)
- [`SecretPredicatesDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/81d15e42f16f3473131880500e7a8c8eb88fa5e6/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecretPredicatesDocumentation.lua)
- [`DamageMeterDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/81d15e42f16f3473131880500e7a8c8eb88fa5e6/Interface/AddOns/Blizzard_APIDocumentationGenerated/DamageMeterDocumentation.lua)
