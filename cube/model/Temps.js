cube(`Temps`, {
  sql_table: `public.dim_temps`,

  dimensions: {
    id_temps: {
      sql: `id_temps`,
      type: `number`,
      primaryKey: true,
      shown: true
    },
    date_complete: {
      sql: `date_complete`,
      type: `time`
    },
    annee: {
      sql: `annee`,
      type: `number`
    },
    mois: {
      sql: `mois`,
      type: `number`
    },
    jour: {
      sql: `jour`,
      type: `number`
    },
    trimestre: {
      sql: `trimestre`,
      type: `number`
    },
    semaine_annee: {
      sql: `semaine_annee`,
      type: `number`
    },
    jour_semaine: {
      sql: `jour_semaine`,
      type: `string`
    },
    est_weekend: {
      sql: `est_weekend`,
      type: `boolean`
    },
    saison: {
      sql: `saison`,
      type: `string`
    }
  }
});