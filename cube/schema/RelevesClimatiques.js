cube(`RelevesClimatiques`, {
  sql: `SELECT * FROM public.fait_releves_climatiques`,

  joins: {
    Stations: {
      relationship: `belongsTo`,
      sql: `${CUBE}.id_station = ${Stations}.id_station`
    },
    Temps: {
      relationship: `belongsTo`,
      sql: `${CUBE}.id_temps = ${Temps}.id_temps`
    },
    Alertes: {
      relationship: `belongsTo`,
      sql: `${CUBE}.id_alerte = ${Alertes}.id_alerte`
    }
  },

  dimensions: {
    id_releve: {
      sql: `id_releve`,
      type: `number`,
      primaryKey: true,
      shown: true
    },

    // On peut exposer les clés étrangères si besoin
    id_temps: {
      sql: `id_temps`,
      type: `number`,
      shown: false  // généralement inutile car on joint via la dimension
    },
    id_station: {
      sql: `id_station`,
      type: `number`,
      shown: false
    },
    id_alerte: {
      sql: `id_alerte`,
      type: `number`,
      shown: false
    },

    // Dimensions scalaires (attributs non agrégés)
    temperature_max: {
      sql: `temperature_max`,
      type: `number`
    },
    temperature_min: {
      sql: `temperature_min`,
      type: `number`
    },
    temperature_moy: {
      sql: `temperature_moy`,
      type: `number`
    },
    humidite_moyenne: {
      sql: `humidite_moyenne`,
      type: `number`
    },
    precipitations_jour: {
      sql: `precipitations_jour`,
      type: `number`
    },
    wind_speed_max: {
      sql: `wind_speed_max`,
      type: `number`
    },
    radiation_solaire: {
      sql: `radiation_solaire`,
      type: `number`
    },
    idhc_30j: {
      sql: `idhc_30j`,
      type: `number`
    },
    jours_sans_pluie: {
      sql: `jours_sans_pluie`,
      type: `number`
    },
    score_risque: {
      sql: `score_risque`,
      type: `number`
    },
    niveau_stress_hydrique: {
      sql: `niveau_stress_hydrique`,
      type: `string`
    },
    qualite_donnee: {
      sql: `qualite_donnee`,
      type: `string`
    },
    source_donnee: {
      sql: `source_donnee`,
      type: `string`
    }
  },

  measures: {
    count: {
      type: `count`,
      drillMembers: [id_releve]
    },

    // Températures
    avg_temperature: {
      sql: `temperature_moy`,
      type: `avg`
    },
    max_temperature: {
      sql: `temperature_max`,
      type: `max`
    },
    min_temperature: {
      sql: `temperature_min`,
      type: `min`
    },
    amplitude_temperature: {
      sql: `temperature_max - temperature_min`,
      type: `avg`,
      title: `Amplitude thermique moyenne`
    },

    // Humidité
    avg_humidite: {
      sql: `humidite_moyenne`,
      type: `avg`
    },

    // Précipitations
    total_precipitations: {
      sql: `precipitations_jour`,
      type: `sum`
    },
    avg_precipitations: {
      sql: `precipitations_jour`,
      type: `avg`
    },

    // Vent
    max_wind_speed: {
      sql: `wind_speed_max`,
      type: `max`
    },

    // Radiation solaire (cumulée ou moyenne)
    total_radiation: {
      sql: `radiation_solaire`,
      type: `sum`
    },
    avg_radiation: {
      sql: `radiation_solaire`,
      type: `avg`
    },

    // Indice de déficit hydrique cumulé (IDHC)
    avg_idhc_30j: {
      sql: `idhc_30j`,
      type: `avg`,
      title: `IDHC moyen (30 jours)`
    },
    max_idhc_30j: {
      sql: `idhc_30j`,
      type: `max`
    },

    // Jours sans pluie (maximum sur la période)
    max_jours_sans_pluie: {
      sql: `jours_sans_pluie`,
      type: `max`
    },

    // Score de risque
    avg_score_risque: {
      sql: `score_risque`,
      type: `avg`
    },
    max_score_risque: {
      sql: `score_risque`,
      type: `max`
    },

    // Comptage des alertes (via jointure)
    nombre_alertes: {
      sql: `${Alertes}.id_alerte`,
      type: `countDistinct`,
      title: `Nombre d'alertes associées`
    }
  },

  // Pré-agrégations recommandées pour les performances
  preAggregations: {
    main: {
      type: `rollup`,
      measureReferences: [
        count,
        avg_temperature,
        max_temperature,
        min_temperature,
        total_precipitations,
        avg_humidite,
        max_wind_speed,
        avg_idhc_30j,
        avg_score_risque
      ],
      dimensionReferences: [
        Temps.annee,
        Temps.mois,
        Temps.saison,
        Stations.zone_geo,
        Stations.ville,
        Alertes.severity_index
      ],
      timeDimensionReference: Temps.date_complete,
      granularity: `month`
    }
  }
});