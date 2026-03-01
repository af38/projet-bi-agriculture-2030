cube(`Stations`, {
  sql: `SELECT * FROM public.dim_station`,

  dimensions: {
    id_station: {
      sql: `id_station`,
      type: `number`,
      primaryKey: true,
      shown: true
    },

    code_station: {
      sql: `code_station`,
      type: `string`
    },

    nom_station: {
      sql: `nom_station`,
      type: `string`
    },

    ville: {
      sql: `ville`,
      type: `string`
    },

    zone_geo: {
      sql: `zone_geo`,
      type: `string`
    },

    altitude: {
      sql: `altitude`,
      type: `number`
    },

    capteur_type: {
      sql: `capteur_type`,
      type: `string`
    },

    latitude: {
      sql: `latitude`,
      type: `number`
    },

    longitude: {
      sql: `longitude`,
      type: `number`
    },

    date_installation: {
      sql: `date_installation`,
      type: `time`
    },

    actif: {
      sql: `actif`,
      type: `boolean`
    }
  }
});