-- ########################################################################################################################
-- évolution (température, précipitations)
-- ########################################################################################################################
SELECT
  (
    FLOOR((("Dim Temps - ID Temps"."annee" - 2024.0) / 1.0)) * 1.0
  ) + 2024.0 AS "Dim Temps - ID Temps__annee",
  FLOOR(("Dim Temps - ID Temps"."mois" / 2.0)) * 2.0 AS "Dim Temps - ID Temps__mois",
  AVG(
    "public"."fait_releves_climatiques"."temperature_moy"
  ) AS "avg",
  SUM(
    "public"."fait_releves_climatiques"."precipitations_jour"
  ) AS "sum"
FROM
  "public"."fait_releves_climatiques"
  LEFT JOIN (
    SELECT
      "public"."dim_temps"."id_temps" AS "id_temps",
      "public"."dim_temps"."date_complete" AS "date_complete",
      "public"."dim_temps"."annee" AS "annee",
      "public"."dim_temps"."mois" AS "mois",
      "public"."dim_temps"."jour" AS "jour",
      "public"."dim_temps"."trimestre" AS "trimestre",
      "public"."dim_temps"."semaine_annee" AS "semaine_annee",
      "public"."dim_temps"."jour_semaine" AS "jour_semaine",
      "public"."dim_temps"."est_weekend" AS "est_weekend",
      "public"."dim_temps"."saison" AS "saison"
    FROM
      "public"."dim_temps"
  ) AS "Dim Temps - ID Temps" ON "public"."fait_releves_climatiques"."id_temps" = "Dim Temps - ID Temps"."id_temps"
GROUP BY
  (
    FLOOR((("Dim Temps - ID Temps"."annee" - 2024.0) / 1.0)) * 1.0
  ) + 2024.0,
  FLOOR(("Dim Temps - ID Temps"."mois" / 2.0)) * 2.0
ORDER BY
  (
    FLOOR((("Dim Temps - ID Temps"."annee" - 2024.0) / 1.0)) * 1.0
  ) + 2024.0 ASC,
  FLOOR(("Dim Temps - ID Temps"."mois" / 2.0)) * 2.0 ASC

--   ########################################################################################################################
--   Dim Station + Fait Releves Climatiques, Max of Fait Releves Climatiques - ID Station → Temperature Max, Grouped by Ville
--   ########################################################################################################################

  SELECT
  "public"."dim_station"."ville" AS "ville",
  MAX(
    "Fait Releves Climatiques - ID Station"."temperature_max"
  ) AS "max"
FROM
  "public"."dim_station"
  LEFT JOIN (
    SELECT
      "public"."fait_releves_climatiques"."id_releve" AS "id_releve",
      "public"."fait_releves_climatiques"."id_temps" AS "id_temps",
      "public"."fait_releves_climatiques"."id_station" AS "id_station",
      "public"."fait_releves_climatiques"."id_alerte" AS "id_alerte",
      "public"."fait_releves_climatiques"."temperature_max" AS "temperature_max",
      "public"."fait_releves_climatiques"."temperature_min" AS "temperature_min",
      "public"."fait_releves_climatiques"."temperature_moy" AS "temperature_moy",
      "public"."fait_releves_climatiques"."humidite_moyenne" AS "humidite_moyenne",
      "public"."fait_releves_climatiques"."precipitations_jour" AS "precipitations_jour",
      "public"."fait_releves_climatiques"."wind_speed_max" AS "wind_speed_max",
      "public"."fait_releves_climatiques"."radiation_solaire" AS "radiation_solaire",
      "public"."fait_releves_climatiques"."idhc_30j" AS "idhc_30j",
      "public"."fait_releves_climatiques"."jours_sans_pluie" AS "jours_sans_pluie",
      "public"."fait_releves_climatiques"."score_risque" AS "score_risque",
      "public"."fait_releves_climatiques"."niveau_stress_hydrique" AS "niveau_stress_hydrique",
      "public"."fait_releves_climatiques"."qualite_donnee" AS "qualite_donnee",
      "public"."fait_releves_climatiques"."source_donnee" AS "source_donnee",
      "public"."fait_releves_climatiques"."date_chargement" AS "date_chargement",
      "public"."fait_releves_climatiques"."date_maj" AS "date_maj"
    FROM
      "public"."fait_releves_climatiques"
  ) AS "Fait Releves Climatiques - ID Station" ON "public"."dim_station"."id_station" = "Fait Releves Climatiques - ID Station"."id_station"
GROUP BY
  "public"."dim_station"."ville"
ORDER BY
  "public"."dim_station"."ville" ASC


-- ########################################################################################################################
-- stations selon le risque
-- ########################################################################################################################
SELECT
  s.nom_station,
  s.ville,
  s.zone_geo,
  s.latitude,
  s.longitude,
  a.priorite,
  a.code_couleur,
  a.score_risque
FROM dim_station s
LEFT JOIN v_alertes_urgentes a ON s.nom_station = a.nom_station;

-- ########################################################################################################################
-- Tendance des températures sur les 30 derniers jours
-- ########################################################################################################################
SELECT
  "public"."mv_dashboard_kpis"."date_complete" AS "date_complete",
  AVG("public"."mv_dashboard_kpis"."temperature_moy") AS "avg"
FROM
  "public"."mv_dashboard_kpis"
GROUP BY
  "public"."mv_dashboard_kpis"."date_complete"
ORDER BY
  "public"."mv_dashboard_kpis"."date_complete" ASC

-- ########################################################################################################################
-- Tableau des alertes urgentes
-- ########################################################################################################################
SELECT
  "source"."date_complete" AS "date_complete",
  "source"."nom_station" AS "nom_station",
  "source"."zone_geo" AS "zone_geo",
  "source"."temperature_max" AS "temperature_max",
  "source"."idhc_30j" AS "idhc_30j",
  "source"."score_risque" AS "score_risque",
  "source"."severity_index" AS "severity_index",
  "source"."code_couleur" AS "code_couleur",
  "source"."priorite" AS "priorite"
FROM
  (
    SELECT
      date_complete,
      nom_station,
      zone_geo,
      temperature_max,
      idhc_30j,
      score_risque,
      severity_index,
      code_couleur,
      priorite
    FROM
      v_alertes_urgentes
    WHERE
      priorite = 'URGENT'
    ORDER BY
      date_complete DESC
  ) AS "source"
LIMIT
  1048575

-- ########################################################################################################################
-- Histogramme du nombre d’alertes par niveau d’urgence
-- ########################################################################################################################
SELECT
  a.niveau_urgence,
  a.code_couleur,
  COUNT(*) AS nb_alertes
FROM fait_releves_climatiques f
JOIN dim_alerte a ON f.id_alerte = a.id_alerte
GROUP BY a.niveau_urgence, a.code_couleur;

-- ########################################################################################################################
-- Tendance mensuelle du nombre d’alertes par niveau d’urgence
-- ########################################################################################################################
SELECT
    annee,
    mois,
    severity_index,
    code_couleur,
    COUNT(*) AS nombre_alertes
FROM mv_dashboard_kpis
WHERE severity_index IS NOT NULL   -- on exclut les lignes sans alerte
GROUP BY annee, mois, severity_index, code_couleur
ORDER BY annee, mois, severity_index;

-- ########################################################################################################################
-- Déficit Hydrique (IDHC) moyen par zone
-- ########################################################################################################################
SELECT
  "public"."mv_dashboard_kpis"."zone_geo" AS "zone_geo",
  AVG("public"."mv_dashboard_kpis"."idhc_30j") AS "avg"
FROM
  "public"."mv_dashboard_kpis"
GROUP BY
  "public"."mv_dashboard_kpis"."zone_geo"
ORDER BY
  "public"."mv_dashboard_kpis"."zone_geo" ASC

-- ########################################################################################################################
-- Évolution de score risque par mois
-- ########################################################################################################################
SELECT
  CAST(
    DATE_TRUNC(
      'month',
      "public"."mv_dashboard_kpis"."date_complete"
    ) AS date
  ) AS "date_complete",
  "public"."mv_dashboard_kpis"."zone_geo" AS "zone_geo",
  AVG("public"."mv_dashboard_kpis"."score_risque") AS "avg"
FROM
  "public"."mv_dashboard_kpis"
GROUP BY
  CAST(
    DATE_TRUNC(
      'month',
      "public"."mv_dashboard_kpis"."date_complete"
    ) AS date
  ),
  "public"."mv_dashboard_kpis"."zone_geo"
ORDER BY
  CAST(
    DATE_TRUNC(
      'month',
      "public"."mv_dashboard_kpis"."date_complete"
    ) AS date
  ) ASC,
  "public"."mv_dashboard_kpis"."zone_geo" ASC
-- ########################################################################################################################
-- Corrélation entre température maximale et IDHC
-- ########################################################################################################################
SELECT
    zone_geo,
    temperature_max,
    idhc_30j,
    date_complete
FROM mv_dashboard_kpis
WHERE idhc_30j IS NOT NULL
  AND temperature_max IS NOT NULL
ORDER BY date_complete DESC;