cube(`RelevesClimatiques`, {
  sql_table: `public.fait_releves_climatiques`,

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
    // Dimensions scalaires (attributs pouvant être utilisés dans les filtres ou comme axes)
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
      type: `avg`,
      title: `Température moyenne`
    },
    max_temperature: {
      sql: `temperature_max`,
      type: `max`,
      title: `Température maximale`
    },
    min_temperature: {
      sql: `temperature_min`,
      type: `min`,
      title: `Température minimale`
    },
    amplitude_temperature: {
      sql: `temperature_max - temperature_min`,
      type: `avg`,
      title: `Amplitude thermique moyenne`
    },

    // Humidité
    avg_humidite: {
      sql: `humidite_moyenne`,
      type: `avg`,
      title: `Humidité moyenne`
    },

    // Précipitations
    total_precipitations: {
      sql: `precipitations_jour`,
      type: `sum`,
      title: `Cumul des précipitations`
    },
    avg_precipitations: {
      sql: `precipitations_jour`,
      type: `avg`,
      title: `Précipitations moyennes`
    },

    // Vent
    max_wind_speed: {
      sql: `wind_speed_max`,
      type: `max`,
      title: `Vitesse de vent maximale`
    },

    // Radiation solaire
    total_radiation: {
      sql: `radiation_solaire`,
      type: `sum`,
      title: `Cumul de radiation solaire`
    },
    avg_radiation: {
      sql: `radiation_solaire`,
      type: `avg`,
      title: `Radiation solaire moyenne`
    },

    // IDHC (indice de déficit hydrique cumulé)
    avg_idhc_30j: {
      sql: `idhc_30j`,
      type: `avg`,
      title: `IDHC moyen (30 jours)`
    },
    max_idhc_30j: {
      sql: `idhc_30j`,
      type: `max`,
      title: `IDHC maximum (30 jours)`
    },

    // Jours sans pluie
    max_jours_sans_pluie: {
      sql: `jours_sans_pluie`,
      type: `max`,
      title: `Nombre maximal de jours sans pluie`
    },

    // Score de risque
    avg_score_risque: {
      sql: `score_risque`,
      type: `avg`,
      title: `Score de risque moyen`
    },
    max_score_risque: {
      sql: `score_risque`,
      type: `max`,
      title: `Score de risque maximal`
    },

    // Comptage des alertes (via jointure)
    nombre_alertes: {
      sql: `id_alerte`,
      type: `countDistinct`,
      title: `Nombre d'alertes associées`
    },

    // Mesures calculées métier
    jours_stress_critique: {
      sql: `id_releve`,
      type: `count`,
      filters: [{ sql: `${CUBE}.niveau_stress_hydrique = 'Critique'` }],
      title: `Nombre de jours en stress hydrique critique`
    },
    jours_secheresse_severe: {
      sql: `id_releve`,
      type: `count`,
      filters: [{ sql: `${CUBE}.jours_sans_pluie > 20` }],
      title: `Jours de sécheresse sévère (sans pluie > 20 jours)`
    }
  },

preAggregations: {
  // Pré-agrégation principale pour les dashboards (mensuel par zone)
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
      avg_score_risque,
      jours_stress_critique,
      jours_secheresse_severe
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
  },

  // Pré-agrégation pour les drill-downs journaliers par station
  daily: {
    type: `rollup`,
    measureReferences: [
      avg_temperature,
      total_precipitations,
      avg_humidite,
      max_wind_speed,
      avg_score_risque      // ← remplace score_risque (dimension) par la mesure
    ],
    dimensionReferences: [
      Stations.zone_geo,
      Stations.ville,
      Stations.nom_station
    ],
    timeDimensionReference: Temps.date_complete,
    granularity: `day`       // ← maintenant valide car timeDimensionReference est défini
  }
}


});