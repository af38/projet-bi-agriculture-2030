-- KPI 1: Température max moyenne par zone (si zone_geo dans dim_station)
SELECT
  t.date_complete,
  s.zone_geo,
  AVG(f.temperature_max) AS avg_temp_max
FROM public.fait_releves_climatiques f
JOIN public.dim_temps t ON t.id_temps = f.id_temps
JOIN public.dim_station s ON s.id_station = f.id_station
GROUP BY t.date_complete, s.zone_geo
ORDER BY t.date_complete, s.zone_geo;

-- KPI 2: Nombre d'alertes par gravité (severity_index)
SELECT
  a.severity_index,
  COUNT(*) AS nb_alertes
FROM public.fait_releves_climatiques f
JOIN public.dim_alerte a ON a.id_alerte = f.id_alerte
GROUP BY a.severity_index
ORDER BY nb_alertes DESC;

-- KPI 3: Top stations à risque (score_risque)
SELECT
  s.nom_station,
  s.ville,
  MAX(f.score_risque) AS max_score
FROM public.fait_releves_climatiques f
JOIN public.dim_station s ON s.id_station = f.id_station
GROUP BY s.nom_station, s.ville
ORDER BY max_score DESC
LIMIT 10;
