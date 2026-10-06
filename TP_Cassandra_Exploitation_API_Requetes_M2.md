# TP — Exploitation des données avec Apache Cassandra

## M2 Big Data & IA — Données distribuées

**Durée indicative :** 3h  
**Travail :** individuel  
**Technologies :** Apache Cassandra, CQL, API du TP précédent, Git

---

## 1. Objectif du TP

Lors du TP précédent, vous avez travaillé sur un **sujet métier** et utilisé une **API pour récupérer des données**.

Dans ce TP, vous allez réutiliser ce même projet pour :

- intégrer les données de votre API dans Cassandra ;
- définir un modèle de données adapté ;
- manipuler les données avec CQL ;
- construire des **requêtes métier** ;
- documenter votre travail dans un dépôt Git.

La chaîne de travail est :

```text
Sujet du TP précédent
        ↓
       API
        ↓
      Données
        ↓
     Cassandra
        ↓
   Requêtes CQL
        ↓
   Besoins métier
        ↓
      Git
```

> **Aucun code n'est fourni dans ce TP.**
> Vous devez réutiliser votre travail précédent et appliquer les notions Cassandra vues en cours et dans le TP de manipulation.

---

# 2. Travail demandé

## Étape 1 — Réutiliser votre API

Reprenez **le sujet et l'API du TP précédent**.

Récupérez les données et identifiez les principales informations disponibles.

Dans votre `README.md`, indiquez simplement :

- le sujet ;
- l'API utilisée ;
- les données récupérées ;
- les principaux champs.

---

## Étape 2 — Stocker les données dans Cassandra

Créez votre keyspace et votre ou vos tables Cassandra.

Votre modèle doit être adapté aux données de votre projet.

Identifiez clairement :

- les principales colonnes ;
- la clé de partition ;
- la clé de clustering si nécessaire.

Importez ensuite les données de votre API dans Cassandra.

Vérifiez que les données sont correctement présentes.

---

# 3. Requêtes CQL

Réalisez les manipulations nécessaires sur vos données.

Votre dépôt doit contenir des requêtes permettant de montrer :

- la consultation des données ;
- une insertion ;
- une modification ;
- une suppression.

Conservez ces requêtes dans un dossier :

```text
queries/
```

---

# 4. Requêtes métier

À partir de votre sujet, identifiez **au moins 5 besoins métier** auxquels Cassandra doit pouvoir répondre.

Pour chaque besoin, écrivez une requête CQL correspondante.

Exemple de présentation dans votre documentation :

```text
REQ-01

Besoin métier :
...

Requête CQL :
...

Clé de partition utilisée :
...

Justification :
...
```

Vous devez appliquer cette démarche pour vos 5 requêtes métier.

Les requêtes doivent être liées à **votre propre sujet et à vos propres données**.

---

# 5. Modélisation Cassandra

Pour vos requêtes métier, réfléchissez à la manière dont vos données sont organisées.

Vous devez être capables d'expliquer brièvement :

- pourquoi vous avez choisi votre clé de partition ;
- pourquoi une clé de clustering est nécessaire ou non ;
- comment votre modèle permet de répondre aux requêtes métier.

> Rappel : avec Cassandra, on pense les tables en fonction des requêtes que l'application doit réaliser.

Évitez d'utiliser `ALLOW FILTERING` simplement pour faire fonctionner une requête. Si vous en avez besoin, vérifiez d'abord si votre modèle peut être amélioré.

---

# 6. Organisation du dépôt Git

Votre dépôt doit avoir une structure simple et propre :

```text
TP-Cassandra/
│
├── README.md
│
├── queries/
│   ├── 01_verification.sql
│   ├── 02_crud.sql
│   ├── 03_requetes_metier.sql
│   └── ...
│
└── documentation/
    └── modelisation.md
```

### `README.md`

Présentez brièvement :

- votre sujet ;
- votre API ;
- vos données ;
- votre modèle Cassandra ;
- vos principales requêtes métier.

### `queries/`

Déposez toutes les requêtes CQL réalisées pendant le TP.

### `documentation/modelisation.md`

Présentez :

- les tables ;
- les clés ;
- les choix de modélisation ;
- les 5 besoins métier et leurs requêtes.

---

# 7. Livrable

Le livrable attendu est **l'URL de votre dépôt GitHub ou GitLab**.

Le dépôt doit contenir :

```text
✓ README.md
✓ Données provenant de votre API intégrées dans Cassandra
✓ Requêtes CQL
✓ Au moins 5 requêtes métier
✓ Documentation du modèle Cassandra
✓ Quelques captures des résultats
```

Le dépôt doit être propre, lisible et correctement organisé.

---


---

# 8. Suite du cours

Ce TP constitue la préparation au prochain travail pratique sur le **cluster Cassandra**.

Vous passerez de :

```text
Cassandra
    ↓
Manipulation des données
    ↓
Requêtes métier
```

à :

```text
Cluster Cassandra
    ↓
Plusieurs nœuds
    ↓
Partitionnement
    ↓
Réplication
    ↓
Replication Factor
    ↓
Consistency Levels
    ↓
Tolérance aux pannes
```
