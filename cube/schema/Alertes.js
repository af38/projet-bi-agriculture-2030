cube(`Alertes`, {
  sql: `SELECT * FROM public.dim_alerte`,

  dimensions: {
    id_alerte: {
      sql: `id_alerte`,
      type: `number`,
      primaryKey: true,
      shown: true
    },

    type_precip: {
      sql: `type_precip`,
      type: `string`
    },

    severity_index: {
      sql: `severity_index`,
      type: `string`
    },

    niveau_urgence: {
      sql: `niveau_urgence`,
      type: `number`
    },

    code_couleur: {
      sql: `code_couleur`,
      type: `string`
    },

    description: {
      sql: `description`,
      type: `string`
    }
  }
});