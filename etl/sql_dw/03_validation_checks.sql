-- 1) Comptages
SELECT 'dim_temps' AS table, COUNT(*) FROM public.dim_temps
UNION ALL SELECT 'dim_station', COUNT(*) FROM public.dim_station
UNION ALL SELECT 'dim_alerte', COUNT(*) FROM public.dim_alerte
UNION ALL SELECT 'fait_releves_climatiques', COUNT(*) FROM public.fait_releves_climatiques;

-- 2) Missing FK (temps, station, alerte)
SELECT COUNT(*) AS missing_temps
FROM public.fait_releves_climatiques f
LEFT JOIN public.dim_temps t ON t.id_temps = f.id_temps
WHERE t.id_temps IS NULL;

SELECT COUNT(*) AS missing_station
FROM public.fait_releves_climatiques f
LEFT JOIN public.dim_station s ON s.id_station = f.id_station
WHERE s.id_station IS NULL;

SELECT COUNT(*) AS missing_alerte
FROM public.fait_releves_climatiques f
LEFT JOIN public.dim_alerte a ON a.id_alerte = f.id_alerte
WHERE f.id_alerte IS NOT NULL AND a.id_alerte IS NULL;

-- 3) Duplicats au grain
SELECT id_temps, id_station, COUNT(*) AS nb
FROM public.fait_releves_climatiques
GROUP BY id_temps, id_station
HAVING COUNT(*) > 1
ORDER BY nb DESC;

-- 4) Contrôles de domaines (exemples)
SELECT COUNT(*) AS temp_aberrante
FROM public.fait_releves_climatiques
WHERE temperature_max > 60 OR temperature_min < -50;

SELECT COUNT(*) AS humidite_aberrante
FROM public.fait_releves_climatiques
WHERE humidite_moyenne < 0 OR humidite_moyenne > 100;
