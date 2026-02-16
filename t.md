
## 1. Créer un dump SQL de la base de données finale

Après avoir exécuté tous ses jobs Talend et chargé les données dans PostgreSQL, le développeur ETL génère un dump complet (schéma + données) :

```bash

## Dump de toute la base (à exécuter sur le conteneur en cours d'exécution)

docker exec <nom_conteneur_postgres> pg_dump -U bi_user -d agriculture_dw > ./01_dump.sql
```

Ou bien, si PostgreSQL tourne en local hors Docker, on utilise la commande pg_dump directement.

