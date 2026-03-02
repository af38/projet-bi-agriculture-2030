# Projet BI - Agriculture Résilience 2030

## 👥 Équipe projet

| Nom                      | Rôle                                   |
| ------------------------ | -------------------------------------- |
| @moncefbrg               | Analyste métier                        |
| @AbdelwafiHub            | Développeur ETL                        |
| @af38                    | Développeur Visualisation              |

---

## 📋 Description du projet

Dans le cadre de l'initiative **« Agriculture-Résilience 2030 »** du Ministère de l'Agriculture et du Développement Durable, ce projet vise à concevoir une solution permettant de croiser des données météorologiques historiques avec des indicateurs de risques locaux.

L'objectif est de fournir aux décideurs régionaux un outil de pilotage stratégique pour :

- **Anticiper les besoins en irrigation** en analysant le déficit hydrique.
- **Alerter sur les anomalies de température** impactant les cultures sensibles.
- **Optimiser la gestion des risques** pour les assureurs agricoles.

---

## 🏗️ Architecture technique

```

[Sources de données] → [Talend ETL] → [PostgreSQL DW] → [Cube.js OLAP] → [Metabase] → [Utilisateurs]

```

### Composants utilisés

- **Talend Open Studio** : Extraction, transformation et chargement des données (ETL).
- **PostgreSQL** : Data Warehouse avec modélisation en étoile.
- **Cube.js** (optionnel) : Couche OLAP pour les performances et le caching.
- **Metabase** : Visualisation et dashboards interactifs.
- **Docker** : Conteneurisation de l'environnement complet.

---

## 🚀 Installation et démarrage rapide

### Prérequis

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Git](https://git-scm.com/)

### Étapes d'installation

1. **Cloner le dépôt**

   ```bash
   git clone https://github.com/af38/projet-bi-agriculture-2030.git
   cd projet-bi-agriculture
   ```

2. **Configurer les variables d'environnement**

   ```bash
   cp .env.example .env
   # Éditer .env avec vos mots de passe
   ```

3. **Lancer l'environnement avec Docker**

   ```bash
   docker-compose up -d
   ```

4. **Vérifier que les données sont bien chargées**

   ```bash
   docker-compose exec postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "SELECT COUNT(*) FROM fact_quotidien;"
   ```

   *(Le résultat devrait être > 0)*

5. **Accéder aux interfaces**
   - **Metabase** : <http://localhost:3000>
   - **Cube.js Playground** (si activé) : <http://localhost:4000>

---

## 📊 Dashboards disponibles

Quatre tableaux de bord interactifs ont été créés dans Metabase :

| Dashboard          | Description                                                               |
| ------------------ | ------------------------------------------------------------------------- |
| **Vue d'ensemble** | Indicateurs clés, carte des risques, évolution température/précipitations |
| **Irrigation**     | Suivi du déficit hydrique par zone, corrélations température/déficit      |
| **Alertes**        | Historique et sévérité des événements météo                               |
| **Qualité**        | Surveillance de la fiabilité des capteurs                                 |

---

## 📈 Jeux de données simulés

Le projet inclut des données simulées représentant :

- **stations météo** réparties dans 3 zones (Haouz, Gharb, Souss-Massa)
- **relevés horaires** sur 2 ans (température, humidité, vent)
- **alertes** avec différents niveaux de sévérité (RAS, Jaune, Orange, Rouge)

---

## 📝 Licence

Ce projet est réalisé à but éducatif dans le cadre d'un module de formation en Business Intelligence. Tous droits réservés à l'équipe projet.

---
