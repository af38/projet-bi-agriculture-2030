-- Inventaire des schémas / tables
\dt staging.*
\dt public.*

-- Détails dimensions
\d+ public.dim_temps
\d+ public.dim_station
\d+ public.dim_alerte

-- Si dim_region existe encore, décommente :
-- \d+ public.dim_region

-- Détails table de faits
\d+ public.fait_releves_climatiques
