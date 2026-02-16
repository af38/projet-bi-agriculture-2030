--
-- PostgreSQL database dump
--

-- Dumped from database version 16.11
-- Dumped by pg_dump version 16.11

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA IF NOT EXISTS public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: refresh_dashboard_mv(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_dashboard_mv() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  REFRESH MATERIALIZED VIEW public.mv_dashboard_kpis;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: dim_alerte; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dim_alerte (
    id_alerte integer NOT NULL,
    type_precip character varying(20) NOT NULL,
    severity_index character varying(10) NOT NULL,
    niveau_urgence smallint NOT NULL,
    code_couleur character varying(10) GENERATED ALWAYS AS (
CASE niveau_urgence
    WHEN 0 THEN 'GREEN'::text
    WHEN 1 THEN 'YELLOW'::text
    WHEN 2 THEN 'ORANGE'::text
    WHEN 3 THEN 'RED'::text
    ELSE NULL::text
END) STORED,
    description text
);


--
-- Name: dim_alerte_id_alerte_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dim_alerte_id_alerte_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dim_alerte_id_alerte_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dim_alerte_id_alerte_seq OWNED BY public.dim_alerte.id_alerte;


--
-- Name: dim_station; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dim_station (
    id_station integer NOT NULL,
    code_station character varying(20) NOT NULL,
    nom_station character varying(120) NOT NULL,
    ville character varying(80) NOT NULL,
    zone_geo character varying(80) NOT NULL,
    altitude integer,
    capteur_type character varying(30),
    latitude numeric(9,6),
    longitude numeric(9,6),
    date_installation date,
    actif boolean DEFAULT true NOT NULL
);


--
-- Name: dim_station_id_station_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dim_station_id_station_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dim_station_id_station_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dim_station_id_station_seq OWNED BY public.dim_station.id_station;


--
-- Name: dim_temps; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dim_temps (
    id_temps integer NOT NULL,
    date_complete date NOT NULL,
    annee smallint NOT NULL,
    mois smallint NOT NULL,
    jour smallint NOT NULL,
    trimestre smallint NOT NULL,
    semaine_annee smallint NOT NULL,
    jour_semaine character varying(10) NOT NULL,
    est_weekend boolean NOT NULL,
    saison character varying(10) NOT NULL
);


--
-- Name: dim_temps_id_temps_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dim_temps_id_temps_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dim_temps_id_temps_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dim_temps_id_temps_seq OWNED BY public.dim_temps.id_temps;


--
-- Name: fait_releves_climatiques; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fait_releves_climatiques (
    id_releve bigint NOT NULL,
    id_temps integer NOT NULL,
    id_station integer NOT NULL,
    id_alerte integer,
    temperature_max numeric(6,2),
    temperature_min numeric(6,2),
    temperature_moy numeric(6,2),
    humidite_moyenne numeric(6,2),
    precipitations_jour numeric(8,2),
    wind_speed_max numeric(8,2),
    radiation_solaire numeric(10,2),
    idhc_30j numeric(10,2),
    jours_sans_pluie integer,
    score_risque numeric(6,2),
    niveau_stress_hydrique character varying(20),
    qualite_donnee character varying(20),
    source_donnee character varying(30) DEFAULT 'ETL_TALEND'::character varying NOT NULL,
    date_chargement timestamp with time zone DEFAULT now() NOT NULL,
    date_maj timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_temp_coherence CHECK (((temperature_max IS NULL) OR (temperature_min IS NULL) OR (temperature_max >= temperature_min))),
    CONSTRAINT chk_temp_moy CHECK (((temperature_moy IS NULL) OR (temperature_min IS NULL) OR (temperature_max IS NULL) OR ((temperature_moy >= temperature_min) AND (temperature_moy <= temperature_max))))
);


--
-- Name: fait_releves_climatiques_id_releve_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.fait_releves_climatiques_id_releve_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fait_releves_climatiques_id_releve_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.fait_releves_climatiques_id_releve_seq OWNED BY public.fait_releves_climatiques.id_releve;


--
-- Name: mv_dashboard_kpis; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.mv_dashboard_kpis AS
 SELECT t.date_complete,
    t.annee,
    t.mois,
    t.saison,
    s.nom_station,
    s.ville,
    s.zone_geo,
    f.temperature_max,
    f.temperature_moy,
    f.humidite_moyenne,
    f.precipitations_jour,
    f.idhc_30j,
        CASE
            WHEN (f.idhc_30j < (50)::numeric) THEN 'Normal'::text
            WHEN ((f.idhc_30j >= (50)::numeric) AND (f.idhc_30j <= (100)::numeric)) THEN 'Modéré'::text
            ELSE 'Critique'::text
        END AS categorie_idhc,
        CASE
            WHEN (f.temperature_max > (45)::numeric) THEN 'Extrême'::text
            WHEN (f.temperature_max > (40)::numeric) THEN 'Alerte'::text
            ELSE 'Normal'::text
        END AS statut_temperature,
        CASE
            WHEN (f.jours_sans_pluie > 20) THEN 'Sécheresse sévère'::text
            WHEN (f.jours_sans_pluie > 10) THEN 'Sécheresse modérée'::text
            ELSE 'Normal'::text
        END AS statut_secheresse,
    a.severity_index,
    a.code_couleur,
    f.score_risque,
        CASE
            WHEN (f.score_risque < (25)::numeric) THEN 'Faible'::text
            WHEN (f.score_risque < (50)::numeric) THEN 'Modéré'::text
            WHEN (f.score_risque < (75)::numeric) THEN 'Élevé'::text
            ELSE 'Critique'::text
        END AS categorie_risque,
    f.niveau_stress_hydrique,
    f.qualite_donnee
   FROM (((public.fait_releves_climatiques f
     JOIN public.dim_temps t ON ((f.id_temps = t.id_temps)))
     JOIN public.dim_station s ON ((f.id_station = s.id_station)))
     LEFT JOIN public.dim_alerte a ON ((f.id_alerte = a.id_alerte)))
  WHERE (1 = 1)
  WITH NO DATA;


--
-- Name: v_alertes_urgentes; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_alertes_urgentes AS
 SELECT s.nom_station,
    s.ville,
    s.zone_geo,
    t.date_complete,
    f.temperature_max,
    f.idhc_30j,
    f.jours_sans_pluie,
    f.score_risque,
    a.severity_index,
    a.code_couleur,
        CASE
            WHEN ((f.temperature_max > (40)::numeric) OR (f.idhc_30j > (100)::numeric) OR (f.score_risque > (75)::numeric)) THEN 'URGENT'::text
            ELSE 'SURVEILLANCE'::text
        END AS priorite
   FROM (((public.fait_releves_climatiques f
     JOIN public.dim_temps t ON ((f.id_temps = t.id_temps)))
     JOIN public.dim_station s ON ((f.id_station = s.id_station)))
     LEFT JOIN public.dim_alerte a ON ((f.id_alerte = a.id_alerte)));


--
-- Name: dim_alerte id_alerte; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dim_alerte ALTER COLUMN id_alerte SET DEFAULT nextval('public.dim_alerte_id_alerte_seq'::regclass);


--
-- Name: dim_station id_station; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dim_station ALTER COLUMN id_station SET DEFAULT nextval('public.dim_station_id_station_seq'::regclass);


--
-- Name: dim_temps id_temps; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dim_temps ALTER COLUMN id_temps SET DEFAULT nextval('public.dim_temps_id_temps_seq'::regclass);


--
-- Name: fait_releves_climatiques id_releve; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fait_releves_climatiques ALTER COLUMN id_releve SET DEFAULT nextval('public.fait_releves_climatiques_id_releve_seq'::regclass);


--
-- Data for Name: dim_alerte; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.dim_alerte (id_alerte, type_precip, severity_index, niveau_urgence, description) FROM stdin;
1	Pluie	RAS	0	\N
2	Aucune	RAS	0	\N
\.


--
-- Data for Name: dim_station; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.dim_station (id_station, code_station, nom_station, ville, zone_geo, altitude, capteur_type, latitude, longitude, date_installation, actif) FROM stdin;
1	13	Station Tadla 1	Béni Mellal	Tadla	310	Analogique	\N	\N	\N	t
2	6	Station Gharb 3	Kenitra	Gharb	107	Analogique	\N	\N	\N	t
3	12	Station Oriental 3	Oujda	Oriental	408	Analogique	\N	\N	\N	t
4	7	Station Souss-Massa 1	Agadir	Souss-Massa	158	Digital	\N	\N	\N	t
5	15	Station Tadla 3	Béni Mellal	Tadla	303	Analogique	\N	\N	\N	t
6	1	Station Haouz 1	Marrakech	Haouz	402	Analogique	\N	\N	\N	t
7	2	Station Haouz 2	Marrakech	Haouz	488	Digital	\N	\N	\N	t
8	14	Station Tadla 2	Béni Mellal	Tadla	374	Digital	\N	\N	\N	t
9	11	Station Oriental 2	Oujda	Oriental	531	Digital	\N	\N	\N	t
10	10	Station Oriental 1	Oujda	Oriental	450	Digital	\N	\N	\N	t
11	4	Station Gharb 1	Kenitra	Gharb	180	Analogique	\N	\N	\N	t
12	3	Station Haouz 3	Marrakech	Haouz	374	Digital	\N	\N	\N	t
13	5	Station Gharb 2	Kenitra	Gharb	87	Analogique	\N	\N	\N	t
14	9	Station Souss-Massa 3	Agadir	Souss-Massa	154	Analogique	\N	\N	\N	t
15	8	Station Souss-Massa 2	Agadir	Souss-Massa	370	Analogique	\N	\N	\N	t
\.


--
-- Data for Name: dim_temps; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.dim_temps (id_temps, date_complete, annee, mois, jour, trimestre, semaine_annee, jour_semaine, est_weekend, saison) FROM stdin;
1	2024-02-16	2024	2	16	1	7	Vendredi	f	Hiver
2	2024-05-17	2024	5	17	2	20	Vendredi	f	Printemps
3	2024-05-03	2024	5	3	2	18	Vendredi	f	Printemps
4	2024-07-04	2024	7	4	3	27	Jeudi	f	Eté
5	2024-06-19	2024	6	19	2	25	Mercredi	f	Eté
6	2024-07-01	2024	7	1	3	27	Lundi	f	Eté
7	2024-08-02	2024	8	2	3	31	Vendredi	f	Eté
8	2024-05-09	2024	5	9	2	19	Jeudi	f	Printemps
9	2024-11-02	2024	11	2	4	44	Samedi	t	Automne
10	2024-12-17	2024	12	17	4	51	Mardi	f	Hiver
11	2024-02-15	2024	2	15	1	7	Jeudi	f	Hiver
12	2024-12-07	2024	12	7	4	49	Samedi	t	Hiver
13	2024-06-21	2024	6	21	2	25	Vendredi	f	Eté
14	2024-07-12	2024	7	12	3	28	Vendredi	f	Eté
15	2024-11-15	2024	11	15	4	46	Vendredi	f	Automne
16	2024-12-26	2024	12	26	4	52	Jeudi	f	Hiver
17	2024-09-18	2024	9	18	3	38	Mercredi	f	Automne
18	2024-01-20	2024	1	20	1	3	Samedi	t	Hiver
19	2024-05-16	2024	5	16	2	20	Jeudi	f	Printemps
20	2024-11-12	2024	11	12	4	46	Mardi	f	Automne
21	2024-03-09	2024	3	9	1	10	Samedi	t	Printemps
22	2024-01-10	2024	1	10	1	2	Mercredi	f	Hiver
23	2024-11-21	2024	11	21	4	47	Jeudi	f	Automne
24	2024-03-08	2024	3	8	1	10	Vendredi	f	Printemps
25	2024-06-18	2024	6	18	2	25	Mardi	f	Eté
26	2024-07-27	2024	7	27	3	30	Samedi	t	Eté
27	2024-12-14	2024	12	14	4	50	Samedi	t	Hiver
28	2024-05-07	2024	5	7	2	19	Mardi	f	Printemps
29	2024-11-08	2024	11	8	4	45	Vendredi	f	Automne
30	2024-09-20	2024	9	20	3	38	Vendredi	f	Automne
31	2024-02-27	2024	2	27	1	9	Mardi	f	Hiver
32	2024-07-05	2024	7	5	3	27	Vendredi	f	Eté
33	2024-01-05	2024	1	5	1	1	Vendredi	f	Hiver
34	2024-05-23	2024	5	23	2	21	Jeudi	f	Printemps
35	2024-01-19	2024	1	19	1	3	Vendredi	f	Hiver
36	2024-12-21	2024	12	21	4	51	Samedi	t	Hiver
37	2024-03-20	2024	3	20	1	12	Mercredi	f	Printemps
38	2024-01-16	2024	1	16	1	3	Mardi	f	Hiver
39	2024-06-02	2024	6	2	2	22	Dimanche	t	Eté
40	2024-04-12	2024	4	12	2	15	Vendredi	f	Printemps
41	2024-10-02	2024	10	2	4	40	Mercredi	f	Automne
42	2024-11-22	2024	11	22	4	47	Vendredi	f	Automne
43	2024-04-06	2024	4	6	2	14	Samedi	t	Printemps
44	2024-08-22	2024	8	22	3	34	Jeudi	f	Eté
45	2024-08-17	2024	8	17	3	33	Samedi	t	Eté
46	2024-03-26	2024	3	26	1	13	Mardi	f	Printemps
47	2024-09-21	2024	9	21	3	38	Samedi	t	Automne
48	2024-07-20	2024	7	20	3	29	Samedi	t	Eté
49	2024-05-10	2024	5	10	2	19	Vendredi	f	Printemps
50	2024-08-25	2024	8	25	3	34	Dimanche	t	Eté
51	2024-12-04	2024	12	4	4	49	Mercredi	f	Hiver
52	2024-04-22	2024	4	22	2	17	Lundi	f	Printemps
53	2024-05-02	2024	5	2	2	18	Jeudi	f	Printemps
54	2024-04-13	2024	4	13	2	15	Samedi	t	Printemps
55	2024-09-27	2024	9	27	3	39	Vendredi	f	Automne
56	2024-04-17	2024	4	17	2	16	Mercredi	f	Printemps
57	2024-03-19	2024	3	19	1	12	Mardi	f	Printemps
58	2024-12-24	2024	12	24	4	52	Mardi	f	Hiver
59	2024-06-06	2024	6	6	2	23	Jeudi	f	Eté
60	2024-12-16	2024	12	16	4	51	Lundi	f	Hiver
61	2024-06-24	2024	6	24	2	26	Lundi	f	Eté
62	2024-01-27	2024	1	27	1	4	Samedi	t	Hiver
63	2024-02-05	2024	2	5	1	6	Lundi	f	Hiver
64	2024-05-27	2024	5	27	2	22	Lundi	f	Printemps
65	2024-01-09	2024	1	9	1	2	Mardi	f	Hiver
66	2024-07-06	2024	7	6	3	27	Samedi	t	Eté
67	2024-11-05	2024	11	5	4	45	Mardi	f	Automne
68	2024-07-18	2024	7	18	3	29	Jeudi	f	Eté
69	2024-04-07	2024	4	7	2	14	Dimanche	t	Printemps
70	2024-08-07	2024	8	7	3	32	Mercredi	f	Eté
71	2024-05-15	2024	5	15	2	20	Mercredi	f	Printemps
72	2024-10-19	2024	10	19	4	42	Samedi	t	Automne
73	2024-04-26	2024	4	26	2	17	Vendredi	f	Printemps
74	2024-08-13	2024	8	13	3	33	Mardi	f	Eté
75	2024-05-13	2024	5	13	2	20	Lundi	f	Printemps
76	2024-02-08	2024	2	8	1	6	Jeudi	f	Hiver
77	2024-11-19	2024	11	19	4	47	Mardi	f	Automne
78	2024-11-14	2024	11	14	4	46	Jeudi	f	Automne
79	2024-04-03	2024	4	3	2	14	Mercredi	f	Printemps
80	2024-02-13	2024	2	13	1	7	Mardi	f	Hiver
81	2024-06-10	2024	6	10	2	24	Lundi	f	Eté
82	2024-12-12	2024	12	12	4	50	Jeudi	f	Hiver
83	2024-06-07	2024	6	7	2	23	Vendredi	f	Eté
84	2024-06-13	2024	6	13	2	24	Jeudi	f	Eté
85	2024-09-03	2024	9	3	3	36	Mardi	f	Automne
86	2024-03-11	2024	3	11	1	11	Lundi	f	Printemps
87	2024-05-06	2024	5	6	2	19	Lundi	f	Printemps
88	2024-10-04	2024	10	4	4	40	Vendredi	f	Automne
89	2024-09-02	2024	9	2	3	36	Lundi	f	Automne
90	2024-04-19	2024	4	19	2	16	Vendredi	f	Printemps
91	2024-01-24	2024	1	24	1	4	Mercredi	f	Hiver
92	2024-04-01	2024	4	1	2	14	Lundi	f	Printemps
93	2024-12-03	2024	12	3	4	49	Mardi	f	Hiver
94	2024-11-17	2024	11	17	4	46	Dimanche	t	Automne
95	2024-11-10	2024	11	10	4	45	Dimanche	t	Automne
96	2024-06-12	2024	6	12	2	24	Mercredi	f	Eté
97	2024-10-24	2024	10	24	4	43	Jeudi	f	Automne
98	2024-02-04	2024	2	4	1	5	Dimanche	t	Hiver
99	2024-12-02	2024	12	2	4	49	Lundi	f	Hiver
100	2024-07-16	2024	7	16	3	29	Mardi	f	Eté
101	2024-04-15	2024	4	15	2	16	Lundi	f	Printemps
102	2024-01-15	2024	1	15	1	3	Lundi	f	Hiver
103	2024-03-10	2024	3	10	1	10	Dimanche	t	Printemps
104	2024-05-22	2024	5	22	2	21	Mercredi	f	Printemps
105	2024-09-26	2024	9	26	3	39	Jeudi	f	Automne
106	2024-12-01	2024	12	1	4	48	Dimanche	t	Hiver
107	2024-11-23	2024	11	23	4	47	Samedi	t	Automne
108	2024-05-24	2024	5	24	2	21	Vendredi	f	Printemps
109	2024-10-03	2024	10	3	4	40	Jeudi	f	Automne
110	2024-01-02	2024	1	2	1	1	Mardi	f	Hiver
111	2024-10-06	2024	10	6	4	40	Dimanche	t	Automne
112	2024-06-20	2024	6	20	2	25	Jeudi	f	Eté
113	2024-12-13	2024	12	13	4	50	Vendredi	f	Hiver
114	2024-12-10	2024	12	10	4	50	Mardi	f	Hiver
115	2024-06-16	2024	6	16	2	24	Dimanche	t	Eté
116	2024-08-14	2024	8	14	3	33	Mercredi	f	Eté
117	2024-10-16	2024	10	16	4	42	Mercredi	f	Automne
118	2024-01-21	2024	1	21	1	3	Dimanche	t	Hiver
119	2024-04-14	2024	4	14	2	15	Dimanche	t	Printemps
120	2024-11-06	2024	11	6	4	45	Mercredi	f	Automne
121	2024-04-09	2024	4	9	2	15	Mardi	f	Printemps
122	2024-03-05	2024	3	5	1	10	Mardi	f	Printemps
123	2024-11-13	2024	11	13	4	46	Mercredi	f	Automne
124	2024-01-13	2024	1	13	1	2	Samedi	t	Hiver
125	2024-02-02	2024	2	2	1	5	Vendredi	f	Hiver
126	2024-04-25	2024	4	25	2	17	Jeudi	f	Printemps
127	2024-01-08	2024	1	8	1	2	Lundi	f	Hiver
128	2024-11-27	2024	11	27	4	48	Mercredi	f	Automne
129	2024-12-22	2024	12	22	4	51	Dimanche	t	Hiver
130	2024-01-03	2024	1	3	1	1	Mercredi	f	Hiver
131	2024-05-14	2024	5	14	2	20	Mardi	f	Printemps
132	2024-08-16	2024	8	16	3	33	Vendredi	f	Eté
133	2024-12-09	2024	12	9	4	50	Lundi	f	Hiver
134	2024-02-10	2024	2	10	1	6	Samedi	t	Hiver
135	2024-03-06	2024	3	6	1	10	Mercredi	f	Printemps
136	2024-02-14	2024	2	14	1	7	Mercredi	f	Hiver
137	2024-03-23	2024	3	23	1	12	Samedi	t	Printemps
138	2024-03-22	2024	3	22	1	12	Vendredi	f	Printemps
139	2024-02-23	2024	2	23	1	8	Vendredi	f	Hiver
140	2024-10-11	2024	10	11	4	41	Vendredi	f	Automne
141	2024-11-24	2024	11	24	4	47	Dimanche	t	Automne
142	2024-03-03	2024	3	3	1	9	Dimanche	t	Printemps
143	2024-08-23	2024	8	23	3	34	Vendredi	f	Eté
144	2024-11-09	2024	11	9	4	45	Samedi	t	Automne
145	2024-03-01	2024	3	1	1	9	Vendredi	f	Printemps
146	2024-10-15	2024	10	15	4	42	Mardi	f	Automne
147	2024-07-11	2024	7	11	3	28	Jeudi	f	Eté
148	2024-09-04	2024	9	4	3	36	Mercredi	f	Automne
149	2024-03-15	2024	3	15	1	11	Vendredi	f	Printemps
150	2024-04-21	2024	4	21	2	16	Dimanche	t	Printemps
151	2024-03-24	2024	3	24	1	12	Dimanche	t	Printemps
152	2024-09-16	2024	9	16	3	38	Lundi	f	Automne
153	2024-03-21	2024	3	21	1	12	Jeudi	f	Printemps
154	2024-08-09	2024	8	9	3	32	Vendredi	f	Eté
155	2024-02-11	2024	2	11	1	6	Dimanche	t	Hiver
156	2024-09-08	2024	9	8	3	36	Dimanche	t	Automne
157	2024-01-18	2024	1	18	1	3	Jeudi	f	Hiver
158	2024-11-11	2024	11	11	4	46	Lundi	f	Automne
159	2024-06-14	2024	6	14	2	24	Vendredi	f	Eté
160	2024-06-15	2024	6	15	2	24	Samedi	t	Eté
161	2024-07-19	2024	7	19	3	29	Vendredi	f	Eté
162	2024-09-24	2024	9	24	3	39	Mardi	f	Automne
163	2024-01-04	2024	1	4	1	1	Jeudi	f	Hiver
164	2024-08-24	2024	8	24	3	34	Samedi	t	Eté
165	2024-01-26	2024	1	26	1	4	Vendredi	f	Hiver
166	2024-02-20	2024	2	20	1	8	Mardi	f	Hiver
167	2024-02-19	2024	2	19	1	8	Lundi	f	Hiver
168	2024-01-25	2024	1	25	1	4	Jeudi	f	Hiver
169	2024-08-15	2024	8	15	3	33	Jeudi	f	Eté
170	2024-07-21	2024	7	21	3	29	Dimanche	t	Eté
171	2024-03-14	2024	3	14	1	11	Jeudi	f	Printemps
172	2024-06-23	2024	6	23	2	25	Dimanche	t	Eté
173	2024-10-25	2024	10	25	4	43	Vendredi	f	Automne
174	2024-01-11	2024	1	11	1	2	Jeudi	f	Hiver
175	2024-12-08	2024	12	8	4	49	Dimanche	t	Hiver
176	2024-07-17	2024	7	17	3	29	Mercredi	f	Eté
177	2024-09-22	2024	9	22	3	38	Dimanche	t	Automne
178	2024-12-25	2024	12	25	4	52	Mercredi	f	Hiver
179	2024-10-21	2024	10	21	4	43	Lundi	f	Automne
180	2024-08-10	2024	8	10	3	32	Samedi	t	Eté
181	2024-12-15	2024	12	15	4	50	Dimanche	t	Hiver
182	2024-08-03	2024	8	3	3	31	Samedi	t	Eté
183	2024-08-27	2024	8	27	3	35	Mardi	f	Eté
184	2024-12-27	2024	12	27	4	52	Vendredi	f	Hiver
185	2024-08-20	2024	8	20	3	34	Mardi	f	Eté
186	2024-10-20	2024	10	20	4	42	Dimanche	t	Automne
187	2024-09-17	2024	9	17	3	38	Mardi	f	Automne
188	2024-09-11	2024	9	11	3	37	Mercredi	f	Automne
189	2024-01-17	2024	1	17	1	3	Mercredi	f	Hiver
190	2024-05-20	2024	5	20	2	21	Lundi	f	Printemps
191	2024-08-18	2024	8	18	3	33	Dimanche	t	Eté
192	2024-03-12	2024	3	12	1	11	Mardi	f	Printemps
193	2024-02-21	2024	2	21	1	8	Mercredi	f	Hiver
194	2024-04-20	2024	4	20	2	16	Samedi	t	Printemps
195	2024-06-05	2024	6	5	2	23	Mercredi	f	Eté
196	2024-09-23	2024	9	23	3	39	Lundi	f	Automne
197	2024-09-06	2024	9	6	3	36	Vendredi	f	Automne
198	2024-11-16	2024	11	16	4	46	Samedi	t	Automne
199	2024-11-25	2024	11	25	4	48	Lundi	f	Automne
200	2024-02-07	2024	2	7	1	6	Mercredi	f	Hiver
201	2024-11-01	2024	11	1	4	44	Vendredi	f	Automne
202	2024-02-06	2024	2	6	1	6	Mardi	f	Hiver
203	2024-10-27	2024	10	27	4	43	Dimanche	t	Automne
204	2024-05-01	2024	5	1	2	18	Mercredi	f	Printemps
205	2024-08-26	2024	8	26	3	35	Lundi	f	Eté
206	2024-07-07	2024	7	7	3	27	Dimanche	t	Eté
207	2024-10-17	2024	10	17	4	42	Jeudi	f	Automne
208	2024-05-05	2024	5	5	2	18	Dimanche	t	Printemps
209	2024-12-06	2024	12	6	4	49	Vendredi	f	Hiver
210	2024-02-24	2024	2	24	1	8	Samedi	t	Hiver
211	2024-08-12	2024	8	12	3	33	Lundi	f	Eté
212	2024-05-08	2024	5	8	2	19	Mercredi	f	Printemps
213	2024-06-11	2024	6	11	2	24	Mardi	f	Eté
214	2024-12-18	2024	12	18	4	51	Mercredi	f	Hiver
215	2024-02-22	2024	2	22	1	8	Jeudi	f	Hiver
216	2024-03-04	2024	3	4	1	10	Lundi	f	Printemps
217	2024-08-19	2024	8	19	3	34	Lundi	f	Eté
218	2024-01-06	2024	1	6	1	1	Samedi	t	Hiver
219	2024-07-26	2024	7	26	3	30	Vendredi	f	Eté
220	2024-09-14	2024	9	14	3	37	Samedi	t	Automne
221	2024-11-03	2024	11	3	4	44	Dimanche	t	Automne
222	2024-12-20	2024	12	20	4	51	Vendredi	f	Hiver
223	2024-08-05	2024	8	5	3	32	Lundi	f	Eté
224	2024-10-13	2024	10	13	4	41	Dimanche	t	Automne
225	2024-08-11	2024	8	11	3	32	Dimanche	t	Eté
226	2024-08-06	2024	8	6	3	32	Mardi	f	Eté
227	2024-05-21	2024	5	21	2	21	Mardi	f	Printemps
228	2024-07-25	2024	7	25	3	30	Jeudi	f	Eté
229	2024-06-01	2024	6	1	2	22	Samedi	t	Eté
230	2024-08-08	2024	8	8	3	32	Jeudi	f	Eté
231	2024-08-04	2024	8	4	3	31	Dimanche	t	Eté
232	2024-04-11	2024	4	11	2	15	Jeudi	f	Printemps
233	2024-10-18	2024	10	18	4	42	Vendredi	f	Automne
234	2024-04-02	2024	4	2	2	14	Mardi	f	Printemps
235	2024-07-02	2024	7	2	3	27	Mardi	f	Eté
236	2024-10-10	2024	10	10	4	41	Jeudi	f	Automne
237	2024-11-18	2024	11	18	4	47	Lundi	f	Automne
238	2024-06-27	2024	6	27	2	26	Jeudi	f	Eté
239	2024-05-11	2024	5	11	2	19	Samedi	t	Printemps
240	2024-01-23	2024	1	23	1	4	Mardi	f	Hiver
241	2024-02-18	2024	2	18	1	7	Dimanche	t	Hiver
242	2024-06-09	2024	6	9	2	23	Dimanche	t	Eté
243	2024-02-03	2024	2	3	1	5	Samedi	t	Hiver
244	2024-07-10	2024	7	10	3	28	Mercredi	f	Eté
245	2024-04-24	2024	4	24	2	17	Mercredi	f	Printemps
246	2024-07-24	2024	7	24	3	30	Mercredi	f	Eté
247	2024-11-20	2024	11	20	4	47	Mercredi	f	Automne
248	2024-10-14	2024	10	14	4	42	Lundi	f	Automne
249	2024-03-16	2024	3	16	1	11	Samedi	t	Printemps
250	2024-10-08	2024	10	8	4	41	Mardi	f	Automne
251	2024-05-26	2024	5	26	2	21	Dimanche	t	Printemps
252	2024-03-07	2024	3	7	1	10	Jeudi	f	Printemps
253	2024-09-07	2024	9	7	3	36	Samedi	t	Automne
254	2024-04-10	2024	4	10	2	15	Mercredi	f	Printemps
255	2024-12-19	2024	12	19	4	51	Jeudi	f	Hiver
256	2024-01-07	2024	1	7	1	1	Dimanche	t	Hiver
257	2024-03-25	2024	3	25	1	13	Lundi	f	Printemps
258	2024-03-13	2024	3	13	1	11	Mercredi	f	Printemps
259	2024-08-01	2024	8	1	3	31	Jeudi	f	Eté
260	2024-09-12	2024	9	12	3	37	Jeudi	f	Automne
261	2024-07-22	2024	7	22	3	30	Lundi	f	Eté
262	2024-03-17	2024	3	17	1	11	Dimanche	t	Printemps
263	2024-05-18	2024	5	18	2	20	Samedi	t	Printemps
264	2024-10-23	2024	10	23	4	43	Mercredi	f	Automne
265	2024-12-11	2024	12	11	4	50	Mercredi	f	Hiver
266	2024-01-22	2024	1	22	1	4	Lundi	f	Hiver
267	2024-01-12	2024	1	12	1	2	Vendredi	f	Hiver
268	2024-02-12	2024	2	12	1	7	Lundi	f	Hiver
269	2024-09-09	2024	9	9	3	37	Lundi	f	Automne
270	2024-07-09	2024	7	9	3	28	Mardi	f	Eté
271	2024-06-03	2024	6	3	2	23	Lundi	f	Eté
272	2024-07-13	2024	7	13	3	28	Samedi	t	Eté
273	2024-09-15	2024	9	15	3	37	Dimanche	t	Automne
274	2024-10-12	2024	10	12	4	41	Samedi	t	Automne
275	2024-02-09	2024	2	9	1	6	Vendredi	f	Hiver
276	2024-09-01	2024	9	1	3	35	Dimanche	t	Automne
277	2024-01-14	2024	1	14	1	2	Dimanche	t	Hiver
278	2024-06-22	2024	6	22	2	25	Samedi	t	Eté
279	2024-11-04	2024	11	4	4	45	Lundi	f	Automne
280	2024-09-13	2024	9	13	3	37	Vendredi	f	Automne
281	2024-03-27	2024	3	27	1	13	Mercredi	f	Printemps
282	2024-07-14	2024	7	14	3	28	Dimanche	t	Eté
283	2024-07-08	2024	7	8	3	28	Lundi	f	Eté
284	2024-10-01	2024	10	1	4	40	Mardi	f	Automne
285	2024-02-01	2024	2	1	1	5	Jeudi	f	Hiver
286	2024-10-09	2024	10	9	4	41	Mercredi	f	Automne
287	2024-05-19	2024	5	19	2	20	Dimanche	t	Printemps
288	2024-11-26	2024	11	26	4	48	Mardi	f	Automne
289	2024-01-01	2024	1	1	1	1	Lundi	f	Hiver
290	2024-05-12	2024	5	12	2	19	Dimanche	t	Printemps
291	2024-06-04	2024	6	4	2	23	Mardi	f	Eté
292	2024-12-23	2024	12	23	4	52	Lundi	f	Hiver
293	2024-12-05	2024	12	5	4	49	Jeudi	f	Hiver
294	2024-09-25	2024	9	25	3	39	Mercredi	f	Automne
295	2024-06-08	2024	6	8	2	23	Samedi	t	Eté
296	2024-09-19	2024	9	19	3	38	Jeudi	f	Automne
297	2024-04-18	2024	4	18	2	16	Jeudi	f	Printemps
298	2024-10-05	2024	10	5	4	40	Samedi	t	Automne
299	2024-03-18	2024	3	18	1	12	Lundi	f	Printemps
300	2024-05-04	2024	5	4	2	18	Samedi	t	Printemps
301	2024-03-02	2024	3	2	1	9	Samedi	t	Printemps
302	2024-07-03	2024	7	3	3	27	Mercredi	f	Eté
303	2024-04-04	2024	4	4	2	14	Jeudi	f	Printemps
304	2024-06-25	2024	6	25	2	26	Mardi	f	Eté
305	2024-06-17	2024	6	17	2	25	Lundi	f	Eté
306	2024-04-08	2024	4	8	2	15	Lundi	f	Printemps
307	2024-10-26	2024	10	26	4	43	Samedi	t	Automne
308	2024-04-23	2024	4	23	2	17	Mardi	f	Printemps
309	2024-04-27	2024	4	27	2	17	Samedi	t	Printemps
310	2024-02-25	2024	2	25	1	8	Dimanche	t	Hiver
311	2024-06-26	2024	6	26	2	26	Mercredi	f	Eté
312	2024-02-26	2024	2	26	1	9	Lundi	f	Hiver
313	2024-09-05	2024	9	5	3	36	Jeudi	f	Automne
314	2024-05-25	2024	5	25	2	21	Samedi	t	Printemps
315	2024-08-21	2024	8	21	3	34	Mercredi	f	Eté
316	2024-10-07	2024	10	7	4	41	Lundi	f	Automne
317	2024-07-15	2024	7	15	3	29	Lundi	f	Eté
318	2024-07-23	2024	7	23	3	30	Mardi	f	Eté
319	2024-04-05	2024	4	5	2	14	Vendredi	f	Printemps
320	2024-10-22	2024	10	22	4	43	Mardi	f	Automne
321	2024-09-10	2024	9	10	3	37	Mardi	f	Automne
322	2024-04-16	2024	4	16	2	16	Mardi	f	Printemps
323	2024-06-30	2024	6	30	2	26	Dimanche	t	Eté
324	2024-11-07	2024	11	7	4	45	Jeudi	f	Automne
325	2024-02-17	2024	2	17	1	7	Samedi	t	Hiver
\.


--
-- Data for Name: fait_releves_climatiques; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.fait_releves_climatiques (id_releve, id_temps, id_station, id_alerte, temperature_max, temperature_min, temperature_moy, humidite_moyenne, precipitations_jour, wind_speed_max, radiation_solaire, idhc_30j, jours_sans_pluie, score_risque, niveau_stress_hydrique, qualite_donnee, source_donnee, date_chargement, date_maj) FROM stdin;
1	289	6	2	12.60	8.70	10.65	36.85	0.00	11.90	0.00	0.00	1	12.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2	110	6	2	26.90	26.90	26.90	56.90	0.00	0.30	0.00	0.00	2	7.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3	33	6	2	34.50	24.10	29.30	55.40	0.00	23.50	0.00	0.00	3	27.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
4	218	6	2	32.30	28.10	30.20	42.05	0.00	24.80	0.00	0.00	4	30.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
5	256	6	2	22.50	22.50	22.50	54.20	0.00	3.20	0.00	0.00	5	11.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
6	127	6	2	28.00	24.50	26.25	54.85	0.00	13.30	0.00	0.00	6	21.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
7	65	6	2	27.70	27.70	27.70	64.80	0.00	2.00	0.00	0.00	7	16.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
8	22	6	2	26.50	12.40	18.10	47.93	0.00	5.70	0.00	0.00	8	21.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
9	174	6	2	26.50	11.50	20.10	55.30	0.00	15.00	0.00	0.00	9	25.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
10	267	6	2	23.40	23.40	23.40	21.30	0.00	7.80	0.00	0.00	10	29.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
11	124	6	2	20.00	20.00	20.00	73.50	0.00	3.40	0.00	0.00	11	21.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
12	277	6	2	33.60	11.00	19.13	52.57	0.00	15.70	0.00	0.00	12	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
13	102	6	2	33.80	6.40	20.10	47.95	0.00	6.90	0.00	0.00	13	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
14	189	6	2	11.10	11.10	11.10	67.90	0.00	4.60	0.00	0.00	14	26.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
15	35	6	2	34.90	34.90	34.90	70.60	0.00	2.00	0.00	0.00	15	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
16	266	6	2	22.30	22.30	22.30	42.20	0.00	16.20	0.00	0.00	16	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
17	91	6	2	32.20	32.20	32.20	39.90	0.00	0.80	0.00	0.00	17	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
18	165	6	2	23.80	23.80	23.80	64.90	0.00	8.30	0.00	0.00	18	35.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
19	62	6	2	27.40	23.70	25.87	51.57	0.00	20.40	0.00	0.00	19	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
20	125	6	2	17.10	17.10	17.10	51.00	0.00	9.00	0.00	0.00	20	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
21	98	6	2	24.30	24.30	24.30	51.20	0.00	5.00	0.00	0.00	21	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
22	202	6	2	25.70	20.40	23.05	39.80	0.00	42.60	0.00	0.00	22	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
23	200	6	2	30.40	6.10	18.25	61.65	0.00	7.60	0.00	0.00	23	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
24	76	6	2	25.30	9.30	17.30	42.30	0.00	6.20	0.00	0.00	24	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
25	275	6	2	34.10	34.10	34.10	13.60	0.00	10.90	0.00	0.00	25	61.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
26	134	6	2	10.20	10.20	10.20	69.50	0.00	8.60	0.00	0.00	26	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
27	268	6	2	26.30	25.30	25.80	27.25	0.00	7.10	0.00	0.00	27	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
28	136	6	2	12.00	12.00	12.00	37.60	0.00	11.10	0.00	0.00	28	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
29	11	6	2	29.90	13.10	21.50	25.05	0.00	23.90	0.00	0.00	29	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
30	1	6	2	27.40	12.80	21.63	58.20	0.00	5.60	0.00	0.00	30	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
31	325	6	2	27.10	27.10	27.10	48.50	0.00	12.70	0.00	0.00	31	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
32	241	6	2	32.00	32.00	32.00	66.90	0.00	20.60	0.00	0.00	32	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
33	167	6	2	25.50	25.50	25.50	81.10	0.00	10.80	0.00	0.00	33	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
34	166	6	2	33.30	22.60	28.80	41.07	0.00	2.50	0.00	0.00	34	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
35	193	6	2	27.60	27.60	27.60	66.30	0.00	9.40	0.00	0.00	35	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
36	139	6	2	22.30	22.30	22.30	49.80	0.00	1.00	0.00	0.00	36	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
37	210	6	2	22.40	11.80	17.10	31.50	0.00	11.10	0.00	0.00	37	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
38	312	6	2	27.60	27.60	27.60	58.60	0.00	8.60	0.00	0.00	38	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
39	31	6	2	24.30	24.30	24.30	36.70	0.00	11.70	0.00	0.00	39	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
40	145	6	2	23.40	6.10	17.37	56.17	0.00	7.30	0.00	0.00	40	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
41	301	6	2	21.30	21.30	21.30	30.40	0.00	10.10	0.00	0.00	41	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
42	142	6	2	26.80	24.10	25.45	62.35	0.00	11.60	0.00	0.00	42	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
43	216	6	2	27.30	27.30	27.30	55.80	0.00	5.80	0.00	0.00	43	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
44	122	6	2	31.90	31.90	31.90	43.90	0.00	1.20	0.00	0.00	44	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
45	135	6	2	22.20	21.00	21.60	45.45	0.00	12.10	0.00	0.00	45	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
46	252	6	2	16.70	16.70	16.70	64.30	0.00	2.00	0.00	0.00	46	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
47	21	6	2	27.30	27.30	27.30	61.40	0.00	6.70	0.00	0.00	47	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
48	103	6	2	27.90	27.90	27.90	29.70	0.00	7.50	0.00	0.00	48	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
49	86	6	2	12.90	12.90	12.90	47.30	0.00	32.50	0.00	0.00	49	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
50	149	6	2	22.90	22.90	22.90	69.60	0.00	3.50	0.00	0.00	50	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
51	249	6	2	23.00	21.70	22.35	41.95	0.00	2.30	0.00	0.00	51	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
52	262	6	2	20.90	20.90	20.90	56.30	0.00	8.80	0.00	0.00	52	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
53	299	6	2	20.70	20.70	20.70	74.10	0.00	1.60	0.00	0.00	53	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
54	57	6	2	29.70	4.10	16.90	50.95	0.00	14.70	0.00	0.00	54	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
55	37	6	2	20.20	20.20	20.20	42.30	0.00	14.00	0.00	0.00	55	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
56	153	6	2	25.80	25.80	25.80	45.50	0.00	2.80	0.00	0.00	56	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
57	138	6	2	29.80	23.30	26.17	30.70	0.00	23.80	0.00	0.00	57	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
58	137	6	2	27.70	27.70	27.70	50.20	0.00	1.90	0.00	0.00	58	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
59	151	6	2	35.00	35.00	35.00	27.00	0.00	15.70	0.00	0.00	59	61.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
60	46	6	2	12.70	12.70	12.70	58.10	0.00	11.70	0.00	0.00	60	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
61	281	6	2	27.50	27.50	27.50	51.90	0.00	31.60	0.00	0.00	61	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
62	234	6	2	24.30	10.90	15.53	63.90	0.00	30.60	0.00	0.00	62	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
63	79	6	2	27.80	14.40	21.10	54.85	0.00	17.90	0.00	0.00	63	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
64	303	6	2	30.90	30.90	30.90	20.50	0.00	8.20	0.00	0.00	64	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
65	43	6	2	30.50	30.50	30.50	86.00	0.00	46.20	0.00	0.00	65	60.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
66	232	6	2	25.10	20.40	22.83	54.63	0.00	13.40	0.00	0.00	66	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
67	40	6	2	25.90	24.10	25.00	73.35	0.00	17.00	0.00	0.00	67	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
68	54	6	2	29.20	13.70	21.45	49.30	0.00	8.40	0.00	0.00	68	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
69	119	6	2	23.80	12.80	19.60	51.53	0.00	29.30	0.00	0.00	69	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
70	101	6	2	10.80	10.80	10.80	63.90	0.00	22.50	0.00	0.00	70	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
71	322	6	2	31.80	27.50	29.65	52.25	0.00	10.20	0.00	0.00	71	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
72	56	6	2	31.20	28.30	29.43	41.57	0.00	22.40	0.00	0.00	72	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
73	297	6	2	29.30	29.30	29.30	48.00	0.00	6.00	0.00	0.00	73	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
74	194	6	2	27.00	25.70	26.53	41.47	0.00	22.60	0.00	0.00	74	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
75	150	6	2	29.20	29.20	29.20	50.70	0.00	4.60	0.00	0.00	75	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
76	308	6	2	28.10	27.20	27.65	51.55	0.00	17.00	0.00	0.00	76	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
77	126	6	2	24.30	8.00	14.97	45.27	0.00	34.10	0.00	0.00	77	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
78	73	6	2	37.40	34.80	36.10	36.75	0.00	20.30	0.00	0.00	78	63.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
79	309	6	2	35.00	35.00	35.00	44.90	0.00	25.60	0.00	0.00	79	61.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
80	204	6	2	36.70	14.10	25.40	44.20	0.00	1.10	0.00	0.00	80	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
81	53	6	2	15.60	15.60	15.60	25.70	0.00	16.60	0.00	0.00	81	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
82	3	6	2	28.20	28.20	28.20	49.80	0.00	5.50	0.00	0.00	82	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
83	300	6	2	11.80	11.80	11.80	49.80	0.00	21.10	0.00	0.00	83	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
84	212	6	2	30.40	30.40	30.40	47.80	0.00	3.60	0.00	0.00	84	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
85	8	6	2	21.80	9.00	13.73	60.20	0.00	21.80	0.00	0.00	85	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
86	239	6	2	31.10	31.10	31.10	72.60	0.00	2.00	0.00	0.00	86	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
87	75	6	2	31.70	27.20	29.45	53.95	0.00	15.60	0.00	0.00	87	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
88	131	6	2	31.50	14.90	23.00	46.74	0.00	22.30	0.00	0.00	88	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
89	19	6	2	10.50	10.50	10.50	50.20	0.00	24.50	0.00	0.00	89	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
90	2	6	2	28.20	24.70	26.13	57.63	0.00	19.10	0.00	0.00	90	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
91	263	6	2	17.20	17.20	17.20	46.90	0.00	5.50	0.00	0.00	91	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
92	190	6	2	30.30	30.30	30.30	59.30	0.00	14.20	0.00	0.00	92	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
93	227	6	2	20.50	9.80	15.15	41.75	0.00	4.20	0.00	0.00	93	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
94	104	6	2	16.40	12.50	14.45	64.85	0.00	8.00	0.00	0.00	94	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
95	108	6	2	27.20	27.20	27.20	41.00	0.00	7.90	0.00	0.00	95	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
96	251	6	2	28.30	28.30	28.30	49.10	0.00	7.60	0.00	0.00	96	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
97	64	6	2	21.60	21.60	21.60	43.80	0.00	2.40	0.00	0.00	97	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
98	39	6	2	24.60	24.60	24.60	45.30	0.00	23.20	0.00	0.00	98	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
99	291	6	2	29.50	29.50	29.50	75.10	0.00	1.90	0.00	0.00	99	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
100	59	6	2	26.70	26.70	26.70	40.50	0.00	0.50	0.00	0.00	100	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
101	83	6	2	12.40	12.40	12.40	53.10	0.00	6.90	0.00	0.00	101	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
102	242	6	2	32.10	32.10	32.10	47.10	0.00	34.30	0.00	0.00	102	60.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
103	84	6	2	33.00	21.80	28.13	47.65	0.00	5.80	0.00	0.00	103	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
104	159	6	2	33.00	20.00	26.50	59.85	0.00	35.80	0.00	0.00	104	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
105	160	6	2	30.20	14.60	21.87	65.57	0.00	3.50	0.00	0.00	105	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
106	305	6	2	28.20	28.20	28.20	53.70	0.00	26.00	0.00	0.00	106	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
107	25	6	2	27.10	27.10	27.10	54.30	0.00	3.40	0.00	0.00	107	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
108	5	6	2	30.30	21.70	25.20	40.97	0.00	32.70	0.00	0.00	108	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
109	112	6	2	24.00	7.40	15.70	47.85	0.00	9.10	0.00	0.00	109	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
110	13	6	2	24.50	24.50	24.50	38.30	0.00	25.50	0.00	0.00	110	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
111	278	6	2	29.70	26.70	28.20	29.80	0.00	4.90	0.00	0.00	111	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
112	304	6	2	29.90	13.90	21.90	46.95	0.00	11.10	0.00	0.00	112	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
113	311	6	2	27.80	27.80	27.80	52.50	0.00	4.00	0.00	0.00	113	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
114	238	6	2	10.80	10.80	10.80	35.10	0.00	32.00	0.00	0.00	114	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
115	6	6	2	27.00	13.30	22.58	61.90	0.00	18.80	0.00	0.00	115	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
116	235	6	2	24.60	8.60	16.60	22.25	0.00	5.70	0.00	0.00	116	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
117	32	6	2	24.00	24.00	24.00	53.60	0.00	9.80	0.00	0.00	117	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
118	66	6	2	32.90	23.70	28.30	64.55	0.00	32.50	0.00	0.00	118	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
119	206	6	2	34.00	34.00	34.00	65.80	0.00	40.50	0.00	0.00	119	62.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
120	283	6	2	13.10	9.70	11.40	38.85	0.00	7.30	0.00	0.00	120	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
121	244	6	2	27.10	26.70	26.90	49.55	0.00	5.30	0.00	0.00	121	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
122	147	6	2	30.50	30.50	30.50	65.80	0.00	5.40	0.00	0.00	122	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
123	272	6	2	31.40	26.10	28.75	50.85	0.00	22.90	0.00	0.00	123	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
124	282	6	2	17.50	17.50	17.50	53.90	0.00	1.70	0.00	0.00	124	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
125	317	6	2	21.60	21.60	21.60	33.80	0.00	25.50	0.00	0.00	125	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
126	176	6	2	34.70	9.60	19.70	41.63	0.00	9.30	0.00	0.00	126	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
127	48	6	2	25.70	9.10	17.40	42.50	0.00	4.20	0.00	0.00	127	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
128	261	6	2	32.90	21.60	27.25	33.55	0.00	54.70	0.00	0.00	128	70.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
129	246	6	2	26.40	20.30	23.45	47.25	0.00	32.20	0.00	0.00	129	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
130	26	6	2	30.90	9.10	24.35	52.95	0.00	15.50	0.00	0.00	130	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
131	182	6	2	24.90	24.90	24.90	24.30	0.00	5.10	0.00	0.00	131	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
132	231	6	2	26.30	9.90	18.10	48.60	0.00	8.90	0.00	0.00	132	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
133	223	6	2	12.40	12.40	12.40	33.90	0.00	21.70	0.00	0.00	133	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
134	226	6	2	27.40	27.40	27.40	45.30	0.00	2.60	0.00	0.00	134	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
135	230	6	2	36.90	22.30	28.30	23.23	0.00	11.20	0.00	0.00	135	62.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
136	180	6	2	25.20	25.20	25.20	56.90	0.00	7.00	0.00	0.00	136	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
137	211	6	2	9.50	9.50	9.50	53.40	0.00	12.40	0.00	0.00	137	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
138	74	6	2	26.30	26.30	26.30	48.90	0.00	3.40	0.00	0.00	138	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
139	116	6	2	14.90	14.90	14.90	58.80	0.00	30.40	0.00	0.00	139	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
140	169	6	2	19.30	19.30	19.30	47.90	0.00	16.70	0.00	0.00	140	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
141	132	6	2	31.10	30.40	30.75	49.55	0.00	9.40	0.00	0.00	141	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
142	45	6	2	31.30	31.30	31.30	51.90	0.00	2.00	0.00	0.00	142	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
143	191	6	2	23.00	23.00	23.00	44.50	0.00	0.90	0.00	0.00	143	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
144	185	6	2	21.10	10.40	15.75	51.55	0.00	34.00	0.00	0.00	144	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
145	315	6	2	34.90	28.70	32.40	33.53	0.00	8.40	0.00	0.00	145	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
146	143	6	2	24.50	20.30	22.40	45.45	0.00	7.80	0.00	0.00	146	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
147	164	6	2	11.30	11.30	11.30	25.80	0.00	1.40	0.00	0.00	147	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
148	50	6	2	20.80	20.80	20.80	57.70	0.00	44.20	0.00	0.00	148	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
149	205	6	2	30.90	27.50	29.20	74.85	0.00	0.50	0.00	0.00	149	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
150	276	6	2	37.20	37.20	37.20	49.90	0.00	1.20	0.00	0.00	150	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
151	85	6	2	24.00	22.80	23.40	56.05	0.00	41.00	0.00	0.00	151	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
152	313	6	2	26.20	26.20	26.20	26.10	0.00	20.80	0.00	0.00	152	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
153	197	6	2	24.40	24.40	24.40	62.90	0.00	0.60	0.00	0.00	153	35.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
154	253	6	2	8.00	8.00	8.00	56.40	0.00	2.00	0.00	0.00	154	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
155	156	6	2	13.00	13.00	13.00	67.40	0.00	16.40	0.00	0.00	155	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
156	321	6	2	13.20	13.20	13.20	34.30	0.00	12.00	0.00	0.00	156	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
157	188	6	2	36.40	8.90	22.65	42.85	0.00	45.30	0.00	0.00	157	71.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
158	280	6	2	31.60	25.00	27.70	41.55	0.00	29.20	0.00	0.00	158	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
159	273	6	2	7.60	7.60	7.60	57.80	0.00	43.00	0.00	0.00	159	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
160	152	6	2	10.90	10.90	10.90	50.70	0.00	9.50	0.00	0.00	160	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
161	296	6	2	22.70	22.70	22.70	52.40	0.00	9.40	0.00	0.00	161	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
162	30	6	2	29.60	29.60	29.60	48.00	0.00	4.50	0.00	0.00	162	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
163	47	6	2	11.30	11.30	11.30	45.50	0.00	3.50	0.00	0.00	163	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
164	177	6	2	33.80	22.70	28.25	35.30	0.00	22.20	0.00	0.00	164	60.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
165	196	6	2	25.20	25.20	25.20	76.20	0.00	6.10	0.00	0.00	165	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
166	294	6	2	28.30	28.30	28.30	22.80	0.00	5.40	0.00	0.00	166	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
167	105	6	2	12.70	12.70	12.70	38.40	0.00	9.20	0.00	0.00	167	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
168	55	6	2	24.60	21.70	23.15	59.05	0.00	21.50	0.00	0.00	168	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
169	284	6	2	31.70	31.70	31.70	70.30	0.00	6.50	0.00	0.00	169	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
170	41	6	2	38.00	11.80	24.90	52.60	0.00	4.00	0.00	0.00	170	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
171	109	6	2	22.80	22.80	22.80	28.60	0.00	2.90	0.00	0.00	171	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
172	88	6	2	36.60	26.70	31.65	54.75	0.00	16.80	0.00	0.00	172	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
173	298	6	2	27.20	27.20	27.20	55.90	0.00	24.50	0.00	0.00	173	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
174	316	6	2	24.50	24.50	24.50	75.50	0.00	2.60	0.00	0.00	174	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
175	250	6	2	23.90	23.90	23.90	26.60	0.00	2.40	0.00	0.00	175	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
176	140	6	2	22.90	21.90	22.40	49.55	0.00	38.10	0.00	0.00	176	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
177	248	6	2	33.00	33.00	33.00	67.80	0.00	30.50	0.00	0.00	177	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
178	146	6	2	38.70	23.20	30.95	43.45	0.00	25.30	0.00	0.00	178	65.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
179	117	6	2	27.30	14.50	20.90	54.55	0.00	17.00	0.00	0.00	179	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
180	207	6	2	33.50	33.50	33.50	50.20	0.00	6.40	0.00	0.00	180	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
181	186	6	2	9.00	9.00	9.00	34.60	0.00	16.00	0.00	0.00	181	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
182	179	6	2	32.60	32.60	32.60	59.30	0.00	6.30	0.00	0.00	182	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
183	320	6	2	24.70	24.70	24.70	65.90	0.00	5.60	0.00	0.00	183	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
184	97	6	2	35.00	19.10	27.05	43.65	0.00	40.20	0.00	0.00	184	67.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
185	173	6	2	33.40	19.70	26.55	43.65	0.00	7.70	0.00	0.00	185	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
186	307	6	2	23.80	5.50	14.65	67.90	0.00	22.70	0.00	0.00	186	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
187	203	6	2	25.40	25.40	25.40	39.80	0.00	3.30	0.00	0.00	187	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
188	201	6	2	22.90	22.90	22.90	34.70	0.00	0.70	0.00	0.00	188	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
189	9	6	2	27.40	13.30	20.35	49.30	0.00	14.10	0.00	0.00	189	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
190	279	6	2	33.10	33.10	33.10	39.80	0.00	10.70	0.00	0.00	190	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
191	67	6	2	33.70	13.80	24.17	56.73	0.00	21.70	0.00	0.00	191	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
192	120	6	2	16.50	16.50	16.50	43.30	0.00	4.30	0.00	0.00	192	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
193	29	6	2	24.50	24.50	24.50	60.30	0.00	22.00	0.00	0.00	193	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
194	144	6	2	26.30	26.30	26.30	47.90	0.00	18.40	0.00	0.00	194	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
195	95	6	2	29.80	23.60	26.70	38.85	0.00	36.80	0.00	0.00	195	60.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
196	158	6	2	7.80	7.80	7.80	48.30	0.00	7.10	0.00	0.00	196	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
197	20	6	2	26.90	21.30	24.13	43.43	0.00	11.70	0.00	0.00	197	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
198	123	6	2	31.80	24.70	27.33	48.03	0.00	25.80	0.00	0.00	198	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
199	78	6	2	19.30	10.80	15.05	54.85	0.00	3.40	0.00	0.00	199	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
200	94	6	2	33.50	33.50	33.50	38.10	0.00	3.00	0.00	0.00	200	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
201	247	6	2	22.30	22.30	22.30	31.00	0.00	0.30	0.00	0.00	201	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
202	23	6	2	27.20	27.20	27.20	70.10	0.00	23.00	0.00	0.00	202	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
203	42	6	2	22.70	22.70	22.70	47.50	0.00	11.50	0.00	0.00	203	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
204	107	6	2	32.60	32.60	32.60	69.00	0.00	2.50	0.00	0.00	204	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
205	141	6	2	15.50	8.60	12.05	64.80	0.00	22.80	0.00	0.00	205	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
206	199	6	2	34.10	34.10	34.10	35.00	0.00	11.80	0.00	0.00	206	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
207	51	6	2	25.40	14.90	20.15	40.50	0.00	8.50	0.00	0.00	207	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
208	209	6	2	11.70	11.70	11.70	76.70	0.00	0.40	0.00	0.00	208	35.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
209	12	6	2	28.10	23.90	25.97	45.57	0.00	18.30	0.00	0.00	209	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
210	175	6	2	19.10	19.10	19.10	36.30	0.00	6.10	0.00	0.00	210	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
211	133	6	2	29.40	29.40	29.40	46.70	0.00	22.80	0.00	0.00	211	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
212	265	6	2	28.50	24.00	26.25	52.45	0.00	37.60	0.00	0.00	212	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
213	181	6	2	33.30	33.30	33.30	58.60	0.00	20.80	0.00	0.00	213	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
214	10	6	2	31.10	8.50	19.63	52.17	0.00	18.70	0.00	0.00	214	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
215	222	6	2	12.70	12.70	12.70	40.60	0.00	4.70	0.00	0.00	215	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
216	36	6	2	23.70	23.70	23.70	42.30	0.00	3.80	0.00	0.00	216	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
217	292	6	2	28.40	28.40	28.40	64.90	0.00	32.50	0.00	0.00	217	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
218	58	6	2	29.90	13.60	21.75	64.75	0.00	18.20	0.00	0.00	218	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
219	184	6	2	23.70	14.20	20.30	48.47	0.00	7.10	0.00	0.00	219	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
220	110	7	2	36.60	19.40	26.83	45.07	0.00	5.40	0.00	0.00	1	21.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
221	163	7	2	25.40	25.40	25.40	47.80	0.00	3.90	0.00	0.00	2	8.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
222	33	7	2	8.10	8.10	8.10	55.50	0.00	0.50	0.00	0.00	3	6.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
223	218	7	2	24.50	24.50	24.50	57.10	0.00	2.40	0.00	0.00	4	9.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
224	256	7	2	33.30	13.80	24.83	59.87	0.00	14.20	0.00	0.00	5	24.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
225	65	7	2	22.10	22.10	22.10	41.50	0.00	1.30	0.00	0.00	6	15.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
226	22	7	2	9.60	9.60	9.60	31.30	0.00	0.60	0.00	0.00	7	19.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
227	124	7	2	35.70	24.80	30.25	42.70	0.00	26.30	0.00	0.00	8	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
228	277	7	2	32.80	19.90	26.47	50.77	0.00	11.60	0.00	0.00	9	32.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
229	102	7	2	27.70	14.10	20.90	40.95	0.00	2.70	0.00	0.00	10	26.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
230	38	7	2	26.70	26.70	26.70	46.40	0.00	3.40	0.00	0.00	11	26.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
231	18	7	2	25.70	25.70	25.70	54.90	0.00	0.90	0.00	0.00	12	23.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
232	118	7	2	5.50	5.50	5.50	36.70	0.00	9.70	0.00	0.00	13	32.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
233	240	7	2	25.80	25.80	25.80	69.70	0.00	10.50	0.00	0.00	14	30.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
234	91	7	2	32.90	20.30	26.60	58.05	0.00	5.60	0.00	0.00	15	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
235	168	7	2	26.60	11.30	18.95	54.30	0.00	20.80	0.00	0.00	16	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
236	62	7	2	24.10	8.30	16.20	37.90	0.00	10.40	0.00	0.00	17	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
237	285	7	2	29.10	29.10	29.10	60.70	0.00	0.20	0.00	0.00	18	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
238	125	7	2	33.20	33.20	33.20	60.40	0.00	28.00	0.00	0.00	19	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
239	98	7	2	34.30	27.10	30.70	48.15	0.00	7.10	0.00	0.00	20	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
240	200	7	2	24.70	24.70	24.70	64.80	0.00	8.80	0.00	0.00	21	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
241	275	7	2	32.80	26.00	29.40	66.05	0.00	15.80	0.00	0.00	22	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
242	155	7	2	31.30	26.00	28.65	61.95	0.00	15.00	0.00	0.00	23	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
243	268	7	2	30.30	10.80	21.23	57.20	0.00	25.70	0.00	0.00	24	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
244	80	7	2	11.70	11.70	11.70	57.00	0.00	6.20	0.00	0.00	25	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
245	136	7	2	24.10	24.10	24.10	58.00	0.00	6.30	0.00	0.00	26	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
246	1	7	2	32.20	19.60	25.90	39.10	0.00	16.70	0.00	0.00	27	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
247	325	7	2	24.10	24.10	24.10	24.10	0.00	5.00	0.00	0.00	28	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
248	241	7	2	34.30	10.40	22.93	49.95	0.00	12.10	0.00	0.00	29	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
249	167	7	2	26.10	19.20	22.07	41.80	0.00	11.00	0.00	0.00	30	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
250	166	7	2	11.40	11.40	11.40	58.10	0.00	9.10	0.00	0.00	31	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
251	310	7	2	34.90	27.70	31.27	75.00	0.00	20.60	0.00	0.00	32	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
252	312	7	2	27.30	27.30	27.30	75.10	0.00	6.90	0.00	0.00	33	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
253	31	7	2	32.20	29.50	30.85	27.75	0.00	19.20	0.00	0.00	34	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
254	145	7	2	37.30	37.30	37.30	44.50	0.00	6.20	0.00	0.00	35	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
255	122	7	2	25.40	25.40	25.40	49.60	0.00	2.40	0.00	0.00	36	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
256	252	7	2	13.80	13.80	13.80	59.80	0.00	9.30	0.00	0.00	37	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
257	24	7	2	32.00	32.00	32.00	47.00	0.00	7.70	0.00	0.00	38	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
258	21	7	2	25.20	15.50	20.35	56.75	0.00	24.20	0.00	0.00	39	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
259	86	7	2	9.90	9.90	9.90	55.60	0.00	12.70	0.00	0.00	40	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
260	192	7	2	25.00	12.40	20.63	36.43	0.00	7.40	0.00	0.00	41	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
261	149	7	2	25.10	21.50	23.30	40.45	0.00	2.60	0.00	0.00	42	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
262	262	7	2	30.80	30.80	30.80	45.60	0.00	6.30	0.00	0.00	43	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
263	57	7	2	24.30	24.30	24.30	44.60	0.00	10.20	0.00	0.00	44	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
264	37	7	2	32.80	25.20	29.00	59.05	0.00	8.30	0.00	0.00	45	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
265	138	7	2	24.90	24.90	24.90	47.10	0.00	0.50	0.00	0.00	46	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
266	137	7	2	23.50	14.90	19.20	59.10	0.00	36.60	0.00	0.00	47	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
267	151	7	2	31.80	31.80	31.80	44.80	0.00	0.70	0.00	0.00	48	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
268	257	7	2	31.20	23.60	27.40	41.45	0.00	18.60	0.00	0.00	49	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
269	46	7	2	32.10	32.10	32.10	38.90	0.00	54.40	0.00	0.00	50	68.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
270	281	7	2	29.30	29.30	29.30	54.00	0.00	10.10	0.00	0.00	51	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
271	92	7	2	10.90	10.90	10.90	52.70	0.00	4.30	0.00	0.00	52	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
272	234	7	2	14.30	14.30	14.30	51.40	0.00	40.00	0.00	0.00	53	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
273	319	7	2	24.00	24.00	24.00	56.10	0.00	0.40	0.00	0.00	54	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
274	43	7	2	25.90	17.90	21.90	46.00	0.00	12.00	0.00	0.00	55	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
275	306	7	2	25.50	11.10	20.00	48.83	0.00	14.10	0.00	0.00	56	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
276	121	7	2	22.30	22.30	22.30	40.20	0.00	5.10	0.00	0.00	57	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
277	254	7	2	11.40	7.70	9.55	44.40	0.00	10.20	0.00	0.00	58	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
278	54	7	2	28.40	7.30	20.77	49.73	0.00	16.90	0.00	0.00	59	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
279	119	7	2	31.00	10.80	18.60	46.05	0.00	49.00	0.00	0.00	60	65.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
280	101	7	2	24.50	24.50	24.50	36.00	0.00	11.40	0.00	0.00	61	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
281	322	7	2	31.80	22.30	26.53	55.03	0.00	14.50	0.00	0.00	62	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
282	297	7	2	27.30	26.00	26.65	48.45	0.00	11.20	0.00	0.00	63	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
283	90	7	2	13.90	13.90	13.90	29.30	0.00	3.90	0.00	0.00	64	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
284	150	7	2	14.50	14.50	14.50	70.70	0.00	23.70	0.00	0.00	65	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
285	308	7	2	35.20	11.70	21.57	48.03	0.00	25.30	0.00	0.00	66	60.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
286	245	7	2	35.50	35.50	35.50	57.00	0.00	20.50	0.00	0.00	67	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
287	309	7	2	21.30	21.30	21.30	7.70	0.00	10.90	0.00	0.00	68	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
288	204	7	2	30.30	30.30	30.30	38.00	0.00	11.10	0.00	0.00	69	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
289	53	7	2	23.00	23.00	23.00	64.40	0.00	9.60	0.00	0.00	70	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
290	3	7	2	34.80	34.80	34.80	32.40	0.00	0.40	0.00	0.00	71	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
291	87	7	2	24.10	17.70	20.90	45.00	0.00	24.90	0.00	0.00	72	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
292	28	7	2	18.40	18.40	18.40	51.20	0.00	12.00	0.00	0.00	73	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
293	212	7	2	35.30	32.70	34.00	55.40	0.00	24.60	0.00	0.00	74	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
294	8	7	2	25.30	25.30	25.30	56.20	0.00	2.20	0.00	0.00	75	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
295	290	7	2	27.60	27.60	27.60	49.00	0.00	6.20	0.00	0.00	76	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
296	75	7	2	24.60	24.60	24.60	43.80	0.00	11.80	0.00	0.00	77	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
297	131	7	2	12.40	12.40	12.40	50.50	0.00	5.00	0.00	0.00	78	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
298	71	7	2	12.40	9.50	10.95	31.05	0.00	7.90	0.00	0.00	79	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
299	19	7	2	32.90	32.90	32.90	48.50	0.00	4.40	0.00	0.00	80	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
300	263	7	2	32.30	32.30	32.30	39.10	0.00	1.10	0.00	0.00	81	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
301	287	7	2	35.50	35.50	35.50	43.30	0.00	10.90	0.00	0.00	82	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
302	190	7	2	10.90	10.90	10.90	37.60	0.00	18.50	0.00	0.00	83	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
303	227	7	2	27.00	10.20	18.87	62.77	0.00	23.90	0.00	0.00	84	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
304	104	7	2	23.10	23.10	23.10	44.60	0.00	30.10	0.00	0.00	85	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
305	34	7	2	31.30	26.30	28.22	54.82	0.00	14.20	0.00	0.00	86	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
306	314	7	2	28.90	14.20	21.55	39.75	0.00	4.80	0.00	0.00	87	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
307	64	7	2	31.20	31.20	31.20	50.20	0.00	6.60	0.00	0.00	88	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
308	229	7	2	23.00	12.20	17.60	37.45	0.00	8.40	0.00	0.00	89	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
309	39	7	2	33.90	33.90	33.90	26.90	0.00	18.40	0.00	0.00	90	60.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
310	291	7	2	21.80	21.80	21.80	49.50	0.00	1.00	0.00	0.00	91	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
311	59	7	2	34.70	14.40	25.38	41.65	0.00	13.50	0.00	0.00	92	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
312	295	7	2	35.30	35.30	35.30	58.80	0.00	22.00	0.00	0.00	93	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
313	242	7	2	29.60	14.90	22.50	58.70	0.00	10.30	0.00	0.00	94	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
314	96	7	2	23.80	23.80	23.80	66.40	0.00	9.80	0.00	0.00	95	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
315	84	7	2	30.00	14.50	23.90	39.23	0.00	4.40	0.00	0.00	96	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
316	160	7	2	22.90	22.90	22.90	57.50	0.00	35.00	0.00	0.00	97	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
317	115	7	2	23.00	23.00	23.00	58.00	0.00	3.60	0.00	0.00	98	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
318	305	7	2	27.00	24.50	25.75	49.50	0.00	18.70	0.00	0.00	99	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
319	25	7	2	34.00	7.90	21.90	46.67	0.00	16.90	0.00	0.00	100	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
320	5	7	2	25.80	25.80	25.80	56.30	0.00	1.40	0.00	0.00	101	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
321	112	7	2	24.90	16.70	20.80	70.30	0.00	7.60	0.00	0.00	102	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
322	13	7	2	34.00	29.50	31.75	56.80	0.00	12.20	0.00	0.00	103	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
323	278	7	2	11.10	11.10	11.10	40.50	0.00	0.50	0.00	0.00	104	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
324	172	7	2	30.00	30.00	30.00	61.40	0.00	0.10	0.00	0.00	105	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
325	61	7	2	32.40	29.50	30.95	47.55	0.00	11.50	0.00	0.00	106	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
326	304	7	2	24.20	24.20	24.20	24.90	0.00	43.30	0.00	0.00	107	60.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
327	311	7	2	25.60	25.60	25.60	39.70	0.00	4.90	0.00	0.00	108	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
328	238	7	2	33.60	11.20	25.25	62.78	0.00	10.00	0.00	0.00	109	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
329	6	7	2	26.10	26.10	26.10	27.50	0.00	20.50	0.00	0.00	110	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
330	235	7	2	26.70	26.70	26.70	63.50	0.00	11.60	0.00	0.00	111	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
331	4	7	2	36.80	36.80	36.80	19.80	0.00	2.80	0.00	0.00	112	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
332	66	7	2	32.80	22.20	27.43	56.80	0.00	29.80	0.00	0.00	113	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
333	206	7	2	36.00	23.60	29.80	32.50	0.00	23.50	0.00	0.00	114	64.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
334	283	7	2	34.40	12.30	23.35	42.55	0.00	24.50	0.00	0.00	115	60.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
335	244	7	2	37.30	26.00	31.65	53.80	0.00	9.20	0.00	0.00	116	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
336	14	7	2	23.90	23.90	23.90	51.40	0.00	3.00	0.00	0.00	117	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
337	272	7	2	28.80	28.80	28.80	44.00	0.00	12.50	0.00	0.00	118	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
338	282	7	2	5.50	5.50	5.50	45.50	0.00	3.20	0.00	0.00	119	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
339	317	7	2	27.40	27.40	27.40	48.20	0.00	4.70	0.00	0.00	120	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
340	176	7	2	37.50	10.70	24.10	61.75	0.00	14.80	0.00	0.00	121	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
341	68	7	2	17.80	17.80	17.80	48.30	0.00	5.30	0.00	0.00	122	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
342	48	7	2	33.10	23.70	28.40	48.15	0.00	14.20	0.00	0.00	123	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
343	170	7	2	18.10	18.10	18.10	55.70	0.00	13.10	0.00	0.00	124	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
344	261	7	2	21.50	11.90	16.70	48.40	0.00	7.10	0.00	0.00	125	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
345	318	7	2	21.30	14.60	17.95	56.50	0.00	15.40	0.00	0.00	126	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
346	246	7	2	26.50	19.80	23.57	45.87	0.00	7.10	0.00	0.00	127	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
347	219	7	2	25.40	25.40	25.40	62.90	0.00	27.70	0.00	0.00	128	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
348	26	7	2	27.70	11.40	19.17	45.27	0.00	30.80	0.00	0.00	129	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
349	259	7	2	19.30	19.30	19.30	51.20	0.00	42.60	0.00	0.00	130	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
350	182	7	2	25.70	25.70	25.70	60.30	0.00	3.60	0.00	0.00	131	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
351	223	7	2	13.60	13.60	13.60	57.60	0.00	5.30	0.00	0.00	132	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
352	70	7	2	13.30	13.30	13.30	14.10	0.00	4.20	0.00	0.00	133	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
353	154	7	2	32.80	32.80	32.80	28.30	0.00	6.90	0.00	0.00	134	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
354	225	7	2	36.00	17.50	26.75	57.15	0.00	19.00	0.00	0.00	135	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
355	74	7	2	29.10	15.90	22.50	45.95	0.00	24.30	0.00	0.00	136	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
356	45	7	2	14.10	14.10	14.10	65.90	0.00	12.60	0.00	0.00	137	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
357	217	7	2	32.20	26.00	28.30	74.40	0.00	20.40	0.00	0.00	138	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
358	185	7	2	29.30	29.30	29.30	43.80	0.00	9.20	0.00	0.00	139	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
359	315	7	2	33.10	19.60	26.35	44.90	0.00	20.10	0.00	0.00	140	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
360	143	7	2	24.30	24.30	24.30	65.50	0.00	2.80	0.00	0.00	141	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
361	50	7	2	18.10	18.10	18.10	36.60	0.00	16.70	0.00	0.00	142	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
362	205	7	2	34.50	34.50	34.50	54.60	0.00	4.80	0.00	0.00	143	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
363	183	7	2	34.20	34.20	34.20	55.50	0.00	6.60	0.00	0.00	144	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
364	276	7	2	36.30	21.80	28.13	31.60	0.00	4.20	0.00	0.00	145	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
365	89	7	2	30.40	30.40	30.40	35.40	0.00	3.80	0.00	0.00	146	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
366	148	7	2	32.10	32.10	32.10	48.00	0.00	26.00	0.00	0.00	147	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
367	313	7	2	9.60	9.60	9.60	42.40	0.00	8.40	0.00	0.00	148	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
368	197	7	2	26.70	26.70	26.70	49.60	0.00	12.70	0.00	0.00	149	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
369	253	7	2	24.90	24.90	24.90	58.30	0.00	2.80	0.00	0.00	150	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
370	156	7	2	20.00	10.60	15.30	53.95	0.00	6.00	0.00	0.00	151	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
371	188	7	2	15.10	13.40	14.25	55.15	0.00	9.90	0.00	0.00	152	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
372	260	7	2	19.40	12.10	15.75	54.05	0.00	10.40	0.00	0.00	153	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
373	220	7	2	26.40	14.40	20.40	42.80	0.00	10.00	0.00	0.00	154	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
374	273	7	2	11.00	11.00	11.00	50.60	0.00	9.20	0.00	0.00	155	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
375	152	7	2	29.20	29.20	29.20	65.60	0.00	3.20	0.00	0.00	156	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
376	187	7	2	27.10	27.10	27.10	39.10	0.00	25.50	0.00	0.00	157	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
377	296	7	2	31.40	12.20	22.90	45.10	0.00	10.30	0.00	0.00	158	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
378	30	7	2	26.50	22.90	24.70	62.25	0.00	5.20	0.00	0.00	159	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
379	47	7	2	23.40	5.10	13.27	59.03	0.00	6.30	0.00	0.00	160	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
380	55	7	2	23.00	23.00	23.00	69.90	0.00	1.30	0.00	0.00	161	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
381	284	7	2	12.60	12.60	12.60	46.80	0.00	1.30	0.00	0.00	162	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
382	109	7	2	25.90	10.10	18.00	43.35	0.00	4.80	0.00	0.00	163	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
383	298	7	2	7.40	7.40	7.40	64.00	0.00	9.70	0.00	0.00	164	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
384	316	7	2	27.10	4.10	15.02	44.66	0.00	7.10	0.00	0.00	165	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
385	250	7	2	29.20	24.70	26.95	55.80	0.00	13.90	0.00	0.00	166	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
386	286	7	2	33.70	24.60	29.15	41.80	0.00	3.30	0.00	0.00	167	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
387	236	7	2	26.50	26.50	26.50	63.70	0.00	0.50	0.00	0.00	168	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
388	140	7	2	27.20	15.50	21.35	37.20	0.00	7.00	0.00	0.00	169	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
389	274	7	2	36.10	36.10	36.10	49.00	0.00	20.90	0.00	0.00	170	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
390	146	7	2	24.80	24.80	24.80	61.40	0.00	2.00	0.00	0.00	171	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
391	117	7	2	29.30	27.60	28.45	39.90	0.00	22.80	0.00	0.00	172	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
392	233	7	2	28.00	23.10	25.27	40.03	0.00	15.20	0.00	0.00	173	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
393	72	7	2	31.70	27.90	29.80	49.00	0.00	6.20	0.00	0.00	174	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
394	186	7	2	30.80	30.80	30.80	65.00	0.00	1.00	0.00	0.00	175	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
395	179	7	2	24.00	24.00	24.00	44.10	0.00	5.00	0.00	0.00	176	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
396	264	7	2	23.60	23.60	23.60	61.00	0.00	17.00	0.00	0.00	177	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
397	97	7	2	26.90	26.90	26.90	36.10	0.00	13.80	0.00	0.00	178	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
398	173	7	2	20.00	20.00	20.00	35.30	0.00	7.40	0.00	0.00	179	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
399	307	7	2	37.80	32.00	34.90	65.50	0.00	9.80	0.00	0.00	180	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
400	203	7	2	35.40	28.60	32.00	47.75	0.00	27.80	0.00	0.00	181	61.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
401	279	7	2	29.10	14.90	22.53	44.70	0.00	32.60	0.00	0.00	182	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
402	324	7	2	23.60	23.60	23.60	61.30	0.00	2.30	0.00	0.00	183	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
403	144	7	2	14.60	14.60	14.60	27.80	0.00	0.10	0.00	0.00	184	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
404	95	7	2	29.10	25.50	27.30	41.00	0.00	6.70	0.00	0.00	185	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
405	158	7	2	13.90	13.90	13.90	46.10	0.00	2.50	0.00	0.00	186	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
406	20	7	2	33.10	24.10	28.60	67.55	0.00	24.20	0.00	0.00	187	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
407	123	7	2	25.60	25.60	25.60	58.30	0.00	13.60	0.00	0.00	188	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
408	78	7	2	26.80	26.80	26.80	44.90	0.00	0.50	0.00	0.00	189	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
409	15	7	2	30.10	16.30	23.20	52.50	0.00	29.50	0.00	0.00	190	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
410	237	7	2	27.10	23.90	25.50	62.95	0.00	2.10	0.00	0.00	191	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
411	247	7	2	21.50	21.50	21.50	33.90	0.00	7.00	0.00	0.00	192	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
412	23	7	2	24.30	23.90	24.10	38.40	0.00	22.10	0.00	0.00	193	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
413	107	7	2	27.00	10.90	20.90	50.80	0.00	14.40	0.00	0.00	194	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
414	141	7	2	26.00	26.00	26.00	22.40	0.00	36.00	0.00	0.00	195	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
415	199	7	2	30.90	30.90	30.90	59.50	0.00	8.60	0.00	0.00	196	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
416	106	7	2	28.30	9.80	21.70	45.28	0.00	30.80	0.00	0.00	197	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
417	93	7	2	26.10	26.10	26.10	38.40	0.00	4.80	0.00	0.00	198	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
418	51	7	2	24.20	24.20	24.20	66.30	0.00	40.80	0.00	0.00	199	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
419	293	7	2	24.50	24.50	24.50	46.50	0.00	10.90	0.00	0.00	200	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
420	209	7	2	35.20	26.10	30.65	55.70	0.00	17.00	0.00	0.00	201	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
421	12	7	2	15.40	15.40	15.40	63.70	0.00	3.10	0.00	0.00	202	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
422	175	7	2	29.30	23.70	26.50	50.85	0.00	10.40	0.00	0.00	203	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
423	133	7	2	31.20	31.20	31.20	59.00	0.00	5.10	0.00	0.00	204	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
424	114	7	2	25.30	21.30	23.30	44.40	0.00	11.70	0.00	0.00	205	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
425	265	7	2	14.30	14.30	14.30	56.30	0.00	0.50	0.00	0.00	206	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
426	82	7	2	28.00	28.00	28.00	42.00	0.00	2.40	0.00	0.00	207	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
427	27	7	2	13.00	13.00	13.00	65.20	0.00	16.60	0.00	0.00	208	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
428	181	7	2	13.40	13.40	13.40	40.20	0.00	12.10	0.00	0.00	209	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
429	10	7	2	32.80	32.80	32.80	61.10	0.00	12.30	0.00	0.00	210	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
430	214	7	2	20.50	20.50	20.50	65.80	0.00	8.50	0.00	0.00	211	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
431	222	7	2	28.70	28.70	28.70	78.80	0.00	4.60	0.00	0.00	212	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
432	129	7	2	33.00	19.90	26.45	56.75	0.00	12.50	0.00	0.00	213	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
433	292	7	2	23.40	8.60	16.00	34.10	0.00	14.80	0.00	0.00	214	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
434	58	7	2	30.80	30.80	30.80	39.80	0.00	11.50	0.00	0.00	215	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
435	178	7	2	29.20	7.10	16.83	41.27	0.00	22.80	0.00	0.00	216	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
436	16	7	2	26.20	19.30	22.75	34.55	0.00	12.30	0.00	0.00	217	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
437	289	12	2	27.80	27.80	27.80	61.80	3.20	4.50	0.00	3.20	0	2.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
438	163	12	2	24.70	24.70	24.70	34.90	3.20	1.90	0.00	6.40	0	0.00	Élevé	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
439	33	12	2	11.90	11.90	11.90	50.60	3.20	1.40	0.00	9.60	0	0.00	Élevé	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
440	218	12	2	37.20	26.30	31.75	47.90	6.40	11.60	0.00	16.00	0	6.00	Modéré	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
441	256	12	2	26.70	12.30	19.50	47.35	6.40	31.60	0.00	22.40	0	0.00	Modéré	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
442	127	12	2	32.80	32.80	32.80	58.60	3.20	1.40	0.00	25.60	0	0.00	Modéré	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
443	65	12	2	27.50	2.30	14.90	49.25	6.40	5.50	0.00	32.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
444	22	12	2	38.00	25.00	31.50	66.15	6.40	4.60	0.00	38.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
445	174	12	2	32.60	23.60	28.53	46.87	9.60	21.40	0.00	48.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
446	124	12	2	27.40	27.40	27.40	59.00	3.20	5.00	0.00	51.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
447	102	12	2	26.70	26.70	26.70	57.80	3.20	6.30	0.00	54.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
448	38	12	2	20.50	7.10	13.80	46.25	6.40	2.60	0.00	60.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
449	189	12	2	21.20	17.00	19.10	60.30	6.40	13.40	0.00	67.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
450	157	12	2	32.40	13.90	22.53	43.90	9.60	24.40	0.00	76.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
451	35	12	2	22.30	22.30	22.30	53.20	3.20	0.70	0.00	80.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
452	18	12	2	26.70	26.70	26.70	61.10	3.20	21.00	0.00	83.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
453	266	12	2	8.70	8.70	8.70	27.20	3.20	12.20	0.00	86.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
454	240	12	2	28.70	28.70	28.70	64.30	3.20	3.20	0.00	89.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
455	91	12	2	33.20	28.30	30.75	54.30	6.40	12.90	0.00	96.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
456	168	12	2	34.50	11.20	23.47	50.67	9.60	16.20	0.00	105.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
457	125	12	2	27.60	27.60	27.60	52.90	3.20	3.40	0.00	105.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
458	243	12	2	25.80	25.80	25.80	42.70	3.20	4.80	0.00	105.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
459	98	12	2	32.90	21.80	27.35	43.15	6.40	21.90	0.00	108.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
460	200	12	2	35.70	29.00	32.35	34.10	6.40	26.50	0.00	99.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
461	76	12	2	35.40	20.10	27.80	56.43	12.80	19.00	0.00	105.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
462	275	12	2	22.60	22.60	22.60	50.30	3.20	4.50	0.00	102.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
463	155	12	2	15.90	15.90	15.90	24.00	3.20	28.50	0.00	96.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
464	268	12	2	27.90	27.90	27.90	56.40	3.20	17.10	0.00	96.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
465	136	12	2	9.70	9.70	9.70	32.30	3.20	8.60	0.00	96.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
466	11	12	2	32.50	32.50	32.50	46.90	3.20	1.60	0.00	92.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
467	1	12	2	20.80	13.90	17.35	66.80	6.40	9.80	0.00	92.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
468	325	12	2	24.80	24.80	24.80	58.70	3.20	3.50	0.00	86.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
469	241	12	2	38.60	24.00	30.63	38.97	9.60	4.70	0.00	92.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
470	167	12	2	13.10	11.70	12.60	63.27	9.60	8.00	0.00	99.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
471	166	12	2	32.70	23.50	28.10	42.65	6.40	19.10	0.00	105.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
472	193	12	2	23.00	9.50	16.30	58.50	12.80	15.10	0.00	115.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
473	139	12	2	28.10	28.10	28.10	46.10	3.20	4.70	0.00	108.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
474	210	12	2	13.60	12.30	12.95	28.50	6.40	8.30	0.00	105.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
475	310	12	2	24.10	24.10	24.10	34.40	3.20	5.50	0.00	108.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
476	312	12	2	8.50	8.50	8.50	51.00	3.20	13.30	0.00	112.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
477	31	12	2	33.80	31.20	32.50	49.50	6.40	19.60	0.00	118.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
478	301	12	2	29.10	26.20	27.65	60.20	6.40	16.80	0.00	124.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
479	216	12	2	29.90	22.90	26.40	62.75	6.40	32.20	0.00	124.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
480	122	12	2	34.40	34.40	34.40	57.60	3.20	36.30	0.00	121.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
481	252	12	2	30.60	30.60	30.60	62.70	3.20	4.80	0.00	124.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
482	24	12	2	25.30	25.30	25.30	50.80	3.20	23.10	0.00	121.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
483	21	12	2	24.10	11.30	17.70	63.35	6.40	5.30	0.00	115.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
484	103	12	2	35.00	35.00	35.00	57.00	3.20	5.70	0.00	115.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
485	86	12	2	34.60	28.60	31.60	23.95	6.40	18.10	0.00	118.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
486	171	12	2	27.20	27.20	27.20	67.50	3.20	5.50	0.00	115.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
487	249	12	2	27.70	26.00	26.85	49.65	6.40	7.10	0.00	112.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
488	262	12	2	24.70	13.60	19.37	43.30	9.60	51.50	0.00	118.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
489	57	12	2	8.20	8.20	8.20	54.10	3.20	4.70	0.00	102.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
490	37	12	2	35.00	30.10	32.55	40.75	6.40	37.10	0.00	102.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
491	153	12	2	14.80	14.80	14.80	54.20	3.20	4.70	0.00	92.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
492	151	12	2	30.50	30.50	30.50	57.40	3.20	44.50	0.00	86.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
493	257	12	2	35.40	28.60	32.00	45.70	6.40	4.20	0.00	89.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
494	46	12	2	32.60	8.00	20.30	50.05	6.40	30.80	0.00	92.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
495	281	12	2	24.10	24.10	24.10	37.40	3.20	4.20	0.00	89.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
496	234	12	2	16.40	16.40	16.40	55.10	3.20	12.20	0.00	80.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
497	79	12	2	28.50	28.50	28.50	53.00	3.20	17.00	0.00	80.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
498	303	12	2	25.40	12.10	18.75	51.40	6.40	10.80	0.00	86.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
499	43	12	2	25.20	8.40	16.80	38.60	6.40	21.50	0.00	86.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
500	69	12	2	24.60	24.60	24.60	23.60	3.20	6.80	0.00	83.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
501	121	12	2	30.50	14.70	20.37	38.73	9.60	16.60	0.00	89.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
502	254	12	2	29.50	14.00	21.75	66.05	6.40	6.50	0.00	89.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
503	232	12	2	22.00	22.00	22.00	43.40	3.20	14.50	0.00	92.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
504	54	12	2	34.40	34.40	34.40	34.10	3.20	12.90	0.00	92.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
505	119	12	2	34.60	29.20	31.90	30.65	6.40	21.90	0.00	99.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
506	322	12	2	13.00	13.00	13.00	53.50	3.20	11.10	0.00	86.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
507	56	12	2	25.80	22.20	24.00	42.20	6.40	58.40	0.00	92.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
508	297	12	2	30.70	30.70	30.70	38.40	3.20	10.20	0.00	92.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
509	150	12	2	23.70	15.60	19.65	26.25	6.40	24.10	0.00	89.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
510	52	12	2	31.40	22.60	25.90	52.37	9.60	9.70	0.00	99.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
511	308	12	2	33.70	29.90	31.80	34.40	6.40	40.40	0.00	102.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
512	73	12	2	28.90	8.50	20.00	49.03	9.60	5.00	0.00	96.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
513	309	12	2	23.70	23.70	23.70	57.50	3.20	3.20	0.00	99.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
514	204	12	2	24.90	24.90	24.90	37.40	3.20	6.20	0.00	102.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
515	53	12	2	24.30	24.30	24.30	45.90	3.20	8.40	0.00	102.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
516	3	12	2	29.40	24.30	26.85	53.65	6.40	14.70	0.00	105.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
517	208	12	2	5.80	5.80	5.80	52.10	3.20	3.10	0.00	102.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
518	87	12	2	34.20	25.20	29.17	52.57	9.60	5.40	0.00	105.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
519	28	12	2	26.10	26.10	26.10	30.40	3.20	3.00	0.00	105.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
520	8	12	2	26.30	26.30	26.30	63.50	3.20	0.90	0.00	99.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
521	49	12	2	26.80	25.80	26.30	50.45	6.40	15.10	0.00	99.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
522	239	12	2	15.00	15.00	15.00	62.50	3.20	20.60	0.00	99.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
523	290	12	2	31.30	25.40	27.50	66.03	9.60	11.00	0.00	108.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
524	75	12	2	10.20	10.20	10.20	35.20	3.20	6.00	0.00	108.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
525	71	12	2	25.40	25.40	25.40	57.60	3.20	24.90	0.00	105.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
526	19	12	2	13.10	13.10	13.10	70.60	3.20	7.90	0.00	105.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
527	2	12	2	30.00	30.00	30.00	68.70	3.20	7.30	0.00	102.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
528	287	12	2	25.20	25.20	25.20	37.90	3.20	10.10	0.00	102.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
529	190	12	2	20.70	20.70	20.70	67.50	3.20	2.50	0.00	105.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
530	104	12	2	30.30	30.30	30.30	72.90	3.20	6.90	0.00	92.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
531	34	12	2	22.50	22.50	22.50	53.00	3.20	0.30	0.00	89.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
532	108	12	2	35.30	35.30	35.30	46.00	3.20	5.90	0.00	92.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
533	314	12	2	26.90	21.60	24.25	56.95	6.40	22.80	0.00	99.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
534	251	12	2	24.00	13.20	19.67	49.83	9.60	4.70	0.00	99.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
535	64	12	2	15.00	15.00	15.00	66.00	3.20	13.30	0.00	99.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
536	229	12	2	25.20	24.60	24.90	40.15	6.40	6.60	0.00	99.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
537	39	12	2	23.20	12.50	17.85	40.10	6.40	12.80	0.00	99.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
538	83	12	2	28.30	28.30	28.30	38.50	3.20	11.60	0.00	86.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
539	295	12	2	28.80	28.80	28.80	59.40	3.20	1.10	0.00	86.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
540	213	12	2	27.50	27.50	27.50	53.30	3.20	11.70	0.00	70.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
541	96	12	2	24.70	23.90	24.30	48.55	6.40	4.40	0.00	73.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
542	84	12	2	14.70	14.70	14.70	80.60	3.20	0.80	0.00	76.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
543	159	12	2	27.70	27.70	27.70	36.30	3.20	14.50	0.00	76.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
544	160	12	2	15.60	15.60	15.60	51.70	3.20	2.10	0.00	76.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
545	25	12	2	10.80	10.80	10.80	57.70	3.20	2.10	0.00	73.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
546	5	12	2	29.20	29.20	29.20	37.10	3.20	34.10	0.00	73.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
547	112	12	2	23.40	22.00	22.70	42.70	6.40	18.10	0.00	80.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
548	13	12	2	14.80	14.80	14.80	46.70	3.20	5.30	0.00	80.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
549	172	12	2	26.50	26.50	26.50	39.20	3.20	6.90	0.00	76.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
550	304	12	2	29.70	29.70	29.70	71.70	3.20	0.10	0.00	64.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
551	238	12	2	35.50	35.50	35.50	47.30	3.20	4.60	0.00	64.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
552	6	12	2	11.30	11.30	11.30	30.20	3.20	11.80	0.00	60.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
553	235	12	2	37.00	7.70	22.35	40.25	6.40	8.10	0.00	60.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
554	302	12	2	14.00	14.00	14.00	35.00	3.20	11.20	0.00	64.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
555	4	12	2	31.40	12.30	21.85	39.15	6.40	33.00	0.00	70.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
556	206	12	2	27.90	17.70	22.80	62.95	6.40	24.90	0.00	73.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
557	283	12	2	30.50	30.50	30.50	50.50	3.20	0.40	0.00	73.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
558	244	12	2	31.10	15.80	23.20	50.97	9.60	28.00	0.00	83.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
559	147	12	2	14.60	14.10	14.35	36.90	6.40	11.20	0.00	86.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
560	272	12	2	27.40	24.70	26.05	40.10	6.40	24.70	0.00	83.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
561	176	12	2	31.40	31.40	31.40	55.00	3.20	17.00	0.00	80.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
562	161	12	2	25.50	25.50	25.50	25.70	3.20	0.70	0.00	76.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
563	48	12	2	34.00	10.20	22.10	49.20	6.40	35.20	0.00	76.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
564	261	12	2	30.50	13.30	24.63	58.53	9.60	7.40	0.00	83.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
565	318	12	2	17.40	17.40	17.40	61.80	3.20	5.70	0.00	83.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
566	246	12	2	14.20	14.20	14.20	47.40	3.20	5.50	0.00	86.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
567	228	12	2	29.60	29.60	29.60	55.70	3.20	1.10	0.00	86.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
568	259	12	2	33.50	26.80	30.15	53.85	6.40	4.20	0.00	80.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
569	182	12	2	32.90	32.90	32.90	45.80	3.20	4.40	0.00	73.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
570	223	12	2	25.30	25.30	25.30	52.40	3.20	3.90	0.00	76.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
571	226	12	2	15.40	15.40	15.40	45.90	3.20	11.50	0.00	73.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
572	154	12	2	32.90	32.90	32.90	52.10	3.20	0.30	0.00	64.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
573	225	12	2	12.80	12.80	12.80	44.80	3.20	1.20	0.00	60.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
574	211	12	2	26.20	8.60	17.40	40.60	6.40	11.90	0.00	60.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
575	74	12	2	32.00	24.00	28.00	41.45	6.40	9.60	0.00	67.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
576	169	12	2	30.20	30.20	30.20	37.10	3.20	19.30	0.00	70.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
577	132	12	2	32.60	20.40	26.63	41.45	12.80	19.80	0.00	80.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
578	45	12	2	29.00	4.40	16.70	43.70	6.40	17.80	0.00	86.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
579	191	12	2	4.00	4.00	4.00	54.60	3.20	6.50	0.00	86.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
580	185	12	2	23.30	22.10	22.70	49.25	6.40	13.00	0.00	86.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
581	315	12	2	32.40	10.30	24.43	55.83	9.60	6.80	0.00	86.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
582	44	12	2	12.10	12.10	12.10	76.90	3.20	21.70	0.00	86.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
583	164	12	2	28.40	22.20	25.50	38.47	9.60	20.30	0.00	89.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
584	205	12	2	31.00	31.00	31.00	70.90	3.20	8.90	0.00	92.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
585	183	12	2	24.90	24.90	24.90	70.80	3.20	5.80	0.00	96.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
586	276	12	2	31.40	7.60	23.13	49.03	9.60	9.30	0.00	99.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
587	89	12	2	29.20	29.20	29.20	34.30	3.20	5.70	0.00	99.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
588	85	12	2	19.90	19.90	19.90	67.40	3.20	9.20	0.00	102.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
589	313	12	2	24.60	24.60	24.60	42.90	3.20	2.30	0.00	99.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
590	253	12	2	20.50	20.50	20.50	40.20	3.20	0.80	0.00	102.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
591	156	12	2	22.00	9.80	15.90	46.80	6.40	9.20	0.00	105.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
592	269	12	2	29.00	22.80	25.90	56.15	6.40	13.20	0.00	112.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
593	188	12	2	22.90	22.90	22.90	42.70	3.20	14.70	0.00	105.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
594	260	12	2	28.40	27.30	27.85	49.30	6.40	21.60	0.00	105.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
595	280	12	2	33.90	33.30	33.60	66.55	6.40	70.80	0.00	112.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
596	220	12	2	23.20	23.20	23.20	38.90	3.20	4.10	0.00	112.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
597	273	12	2	35.80	28.10	31.95	60.80	6.40	4.10	0.00	105.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
598	187	12	2	21.20	21.20	21.20	21.50	3.20	11.10	0.00	99.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
599	17	12	2	16.40	16.40	16.40	36.30	3.20	10.40	0.00	102.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
600	296	12	2	30.10	30.10	30.10	37.70	3.20	52.80	0.00	99.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
601	30	12	2	27.90	27.90	27.90	56.60	3.20	6.80	0.00	92.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
602	162	12	2	28.60	28.60	28.60	54.50	3.20	12.80	0.00	83.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
603	294	12	2	25.70	25.70	25.70	35.00	3.20	1.30	0.00	83.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
604	105	12	2	11.50	11.50	11.50	80.40	3.20	12.90	0.00	83.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
605	55	12	2	26.30	17.50	21.90	60.90	6.40	11.20	0.00	89.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
606	41	12	2	24.70	24.70	24.70	52.80	3.20	21.90	0.00	80.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
607	88	12	2	25.50	25.50	25.50	28.90	3.20	10.20	0.00	80.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
608	298	12	2	8.70	8.70	8.70	50.00	3.20	6.00	0.00	80.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
609	316	12	2	24.50	22.50	23.50	69.45	6.40	5.70	0.00	83.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
610	286	12	2	35.00	23.60	27.47	45.67	9.60	10.90	0.00	80.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
611	140	12	2	32.00	26.00	29.00	29.60	6.40	19.30	0.00	83.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
612	224	12	2	28.60	13.70	21.15	72.80	6.40	4.70	0.00	76.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
613	248	12	2	23.70	23.60	23.65	50.75	6.40	19.10	0.00	80.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
614	146	12	2	27.20	27.20	27.20	52.70	3.20	5.30	0.00	76.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
615	207	12	2	32.10	31.40	31.75	39.75	6.40	9.90	0.00	80.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
616	233	12	2	13.60	13.60	13.60	29.50	3.20	19.60	0.00	80.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
617	72	12	2	32.20	32.20	32.20	47.80	3.20	1.50	0.00	80.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
618	186	12	2	11.50	11.50	11.50	58.70	3.20	4.30	0.00	80.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
619	179	12	2	35.20	9.00	22.10	35.35	6.40	6.30	0.00	86.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
620	97	12	2	36.90	35.30	36.10	54.05	6.40	3.80	0.00	89.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
621	307	12	2	26.30	20.90	23.43	45.53	9.60	7.80	0.00	92.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
622	203	12	2	26.60	24.30	25.45	68.35	6.40	5.00	0.00	92.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
623	201	12	2	25.20	22.50	23.93	51.87	9.60	15.20	0.00	99.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
624	9	12	2	25.80	25.80	25.80	42.30	3.20	14.50	0.00	102.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
625	120	12	2	37.70	24.30	31.00	61.15	6.40	30.70	0.00	96.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
626	324	12	2	11.80	11.80	11.80	60.00	3.20	2.60	0.00	99.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
627	29	12	2	21.40	21.40	21.40	13.20	3.20	11.70	0.00	92.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
628	158	12	2	7.90	7.90	7.90	60.20	3.20	2.80	0.00	89.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
629	20	12	2	29.70	28.10	28.90	55.20	6.40	4.90	0.00	89.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
630	123	12	2	33.10	22.60	27.85	51.95	6.40	15.80	0.00	89.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
631	78	12	2	27.60	27.60	27.60	28.10	3.20	7.10	0.00	89.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
632	198	12	2	30.00	25.10	27.55	22.55	6.40	12.20	0.00	89.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
633	94	12	2	29.90	13.40	21.70	46.07	9.60	48.40	0.00	96.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
634	237	12	2	29.00	29.00	29.00	43.00	3.20	1.30	0.00	96.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
635	247	12	2	32.40	32.40	32.40	51.80	3.20	9.90	0.00	89.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
636	107	12	2	23.10	23.10	23.10	60.50	3.20	1.40	0.00	86.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
637	141	12	2	9.50	9.50	9.50	23.30	3.20	13.90	0.00	89.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
638	288	12	2	33.00	33.00	33.00	48.30	3.20	3.60	0.00	76.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
639	128	12	2	21.60	21.60	21.60	83.00	3.20	52.30	0.00	80.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
640	106	12	2	36.40	25.20	31.57	51.47	9.60	9.20	0.00	80.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
641	99	12	2	28.90	28.90	28.90	52.50	3.20	9.20	0.00	80.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
642	93	12	2	36.70	20.60	28.65	34.85	6.40	8.40	0.00	86.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
643	51	12	2	33.20	10.90	22.05	65.95	6.40	6.40	0.00	92.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
644	293	12	2	24.80	11.40	18.10	58.60	6.40	4.70	0.00	99.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
645	209	12	2	25.60	12.30	18.95	47.70	6.40	11.00	0.00	99.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
646	175	12	2	25.50	6.00	15.75	22.65	6.40	11.50	0.00	99.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
647	133	12	2	21.20	21.20	21.20	57.10	3.20	1.30	0.00	102.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
648	114	12	2	30.30	30.30	30.30	33.00	3.20	3.90	0.00	105.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
649	265	12	2	24.50	24.50	24.50	50.90	3.20	6.10	0.00	105.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
650	82	12	2	31.70	24.00	27.07	53.33	9.60	24.50	0.00	108.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
651	113	12	2	8.60	7.40	8.00	57.15	6.40	16.00	0.00	108.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
652	27	12	2	32.70	23.00	27.85	52.75	6.40	6.40	0.00	112.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
653	60	12	2	28.50	24.70	26.60	25.15	6.40	7.70	0.00	112.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
654	10	12	2	30.00	12.80	18.57	56.83	9.60	19.90	0.00	112.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
655	214	12	2	24.20	16.80	20.83	49.07	9.60	13.70	0.00	118.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
656	255	12	2	33.30	33.30	33.30	19.30	3.20	55.10	0.00	121.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
657	222	12	2	35.60	12.60	26.37	31.97	9.60	29.20	0.00	128.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
658	36	12	2	4.50	4.50	4.50	22.90	3.20	21.00	0.00	131.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
659	292	12	2	15.50	12.30	13.90	60.95	6.40	9.00	0.00	134.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
660	289	11	2	31.40	31.40	31.40	34.00	0.00	9.10	0.00	0.00	1	19.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
661	110	11	2	29.60	13.40	22.97	53.43	0.00	50.60	0.00	0.00	2	30.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
662	130	11	2	33.10	33.10	33.10	63.90	0.00	11.00	0.00	0.00	3	19.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
663	163	11	2	25.60	9.90	17.75	54.25	0.00	15.20	0.00	0.00	4	15.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
664	33	11	2	30.90	23.20	28.30	36.97	0.00	22.30	0.00	0.00	5	30.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
665	218	11	2	21.80	21.80	21.80	65.90	0.00	13.20	0.00	0.00	6	16.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
666	124	11	2	23.90	23.90	23.90	31.80	0.00	4.00	0.00	0.00	7	20.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
667	102	11	2	31.10	26.20	28.65	68.35	0.00	9.90	0.00	0.00	8	25.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
668	38	11	2	24.60	24.60	24.60	57.50	0.00	33.40	0.00	0.00	9	30.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
669	189	11	2	26.20	26.20	26.20	56.10	0.00	8.30	0.00	0.00	10	23.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
670	157	11	2	13.80	13.80	13.80	46.70	0.00	13.80	0.00	0.00	11	28.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
671	35	11	2	9.00	9.00	9.00	52.20	0.00	63.20	0.00	0.00	12	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
672	18	11	2	26.40	26.40	26.40	53.00	0.00	1.90	0.00	0.00	13	27.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
673	118	11	2	34.60	11.90	19.03	29.35	0.00	33.60	0.00	0.00	14	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
674	266	11	2	24.10	20.20	22.15	65.50	0.00	29.40	0.00	0.00	15	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
675	240	11	2	25.00	25.00	25.00	47.70	0.00	8.00	0.00	0.00	16	34.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
676	168	11	2	33.60	33.60	33.60	62.90	0.00	10.00	0.00	0.00	17	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
677	62	11	2	32.50	25.20	28.85	47.20	0.00	20.60	0.00	0.00	18	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
678	63	11	2	16.30	16.30	16.30	52.00	0.00	1.50	0.00	0.00	19	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
679	202	11	2	24.70	22.70	23.70	37.90	0.00	9.30	0.00	0.00	20	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
680	200	11	2	12.30	12.30	12.30	55.10	0.00	6.60	0.00	0.00	21	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
681	76	11	2	29.20	24.70	26.95	53.70	0.00	3.20	0.00	0.00	22	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
682	275	11	2	29.40	22.30	25.85	59.00	0.00	16.00	0.00	0.00	23	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
683	268	11	2	28.70	28.70	28.70	52.60	0.00	7.00	0.00	0.00	24	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
684	136	11	2	23.40	13.70	18.55	37.80	0.00	11.30	0.00	0.00	25	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
685	11	11	2	29.90	29.90	29.90	10.60	0.00	2.30	0.00	0.00	26	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
686	1	11	2	25.90	25.90	25.90	47.50	0.00	7.70	0.00	0.00	27	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
687	241	11	2	29.70	29.70	29.70	34.50	0.00	17.60	0.00	0.00	28	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
688	166	11	2	32.20	32.20	32.20	57.60	0.00	7.00	0.00	0.00	29	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
689	193	11	2	32.50	32.50	32.50	58.70	0.00	37.20	0.00	0.00	30	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
690	215	11	2	22.60	12.20	19.07	47.97	0.00	20.40	0.00	0.00	31	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
691	139	11	2	34.60	25.40	30.00	39.75	0.00	61.80	0.00	0.00	32	71.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
692	210	11	2	23.20	23.20	23.20	29.10	0.00	5.40	0.00	0.00	33	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
693	310	11	2	23.90	23.90	23.90	66.00	0.00	23.80	0.00	0.00	34	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
694	312	11	2	28.60	28.60	28.60	13.30	0.00	0.50	0.00	0.00	35	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
695	31	11	2	29.80	10.20	20.00	41.75	0.00	3.50	0.00	0.00	36	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
696	145	11	2	31.80	25.10	28.45	60.60	0.00	11.10	0.00	0.00	37	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
697	142	11	2	34.20	12.80	23.50	44.55	0.00	5.20	0.00	0.00	38	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
698	216	11	2	33.70	10.00	23.33	52.60	0.00	37.40	0.00	0.00	39	62.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
699	122	11	2	30.20	30.20	30.20	28.30	0.00	0.30	0.00	0.00	40	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
700	135	11	2	31.20	31.20	31.20	72.30	0.00	1.30	0.00	0.00	41	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
701	103	11	2	27.70	10.90	19.30	39.60	0.00	26.60	0.00	0.00	42	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
702	192	11	2	37.10	7.70	22.40	36.90	0.00	17.10	0.00	0.00	43	62.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
703	171	11	2	26.30	12.70	19.50	67.20	0.00	11.90	0.00	0.00	44	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
704	149	11	2	32.60	9.80	23.33	64.73	0.00	14.40	0.00	0.00	45	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
705	249	11	2	20.20	20.20	20.20	29.90	0.00	5.70	0.00	0.00	46	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
706	262	11	2	25.10	25.10	25.10	48.90	0.00	17.00	0.00	0.00	47	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
707	57	11	2	33.80	30.80	32.30	57.35	0.00	7.00	0.00	0.00	48	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
708	37	11	2	28.00	16.40	22.20	42.65	0.00	11.40	0.00	0.00	49	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
709	153	11	2	24.90	24.10	24.50	49.05	0.00	27.40	0.00	0.00	50	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
710	138	11	2	37.30	24.70	30.47	30.17	0.00	19.30	0.00	0.00	51	64.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
711	137	11	2	34.00	26.10	30.05	47.90	0.00	35.50	0.00	0.00	52	63.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
712	281	11	2	22.90	11.30	17.10	44.10	0.00	15.10	0.00	0.00	53	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
713	79	11	2	33.40	29.20	31.30	75.15	0.00	13.60	0.00	0.00	54	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
714	303	11	2	25.60	25.60	25.60	51.40	0.00	26.20	0.00	0.00	55	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
715	319	11	2	26.30	5.40	19.23	57.07	0.00	16.00	0.00	0.00	56	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
716	43	11	2	26.20	11.80	20.70	49.30	0.00	34.60	0.00	0.00	57	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
717	306	11	2	30.90	14.60	22.75	59.25	0.00	6.10	0.00	0.00	58	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
718	121	11	2	31.90	21.30	25.87	58.70	0.00	7.70	0.00	0.00	59	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
719	40	11	2	35.90	32.00	33.95	56.50	0.00	40.60	0.00	0.00	60	65.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
720	54	11	2	33.60	15.20	24.40	61.55	0.00	28.90	0.00	0.00	61	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
721	322	11	2	22.40	22.40	22.40	56.60	0.00	21.20	0.00	0.00	62	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
722	297	11	2	10.00	10.00	10.00	37.00	0.00	16.20	0.00	0.00	63	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
723	90	11	2	19.80	10.00	14.90	51.90	0.00	3.40	0.00	0.00	64	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
724	194	11	2	22.10	22.10	22.10	67.50	0.00	4.80	0.00	0.00	65	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
725	52	11	2	9.40	9.40	9.40	39.70	0.00	30.90	0.00	0.00	66	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
726	245	11	2	34.00	16.70	25.63	38.67	0.00	17.00	0.00	0.00	67	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
727	126	11	2	27.80	26.20	26.73	61.33	0.00	9.10	0.00	0.00	68	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
728	309	11	2	33.50	33.50	33.50	11.20	0.00	28.20	0.00	0.00	69	67.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
729	204	11	2	28.90	25.30	27.10	41.55	0.00	23.10	0.00	0.00	70	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
730	53	11	2	21.60	9.10	15.35	43.10	0.00	14.00	0.00	0.00	71	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
731	3	11	2	10.70	10.70	10.70	62.00	0.00	21.90	0.00	0.00	72	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
732	300	11	2	37.60	24.50	31.05	44.35	0.00	23.00	0.00	0.00	73	63.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
733	208	11	2	16.70	16.70	16.70	48.80	0.00	18.60	0.00	0.00	74	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
734	28	11	2	33.00	20.00	27.45	51.88	0.00	34.40	0.00	0.00	75	60.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
735	212	11	2	26.50	10.30	18.40	67.25	0.00	20.50	0.00	0.00	76	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
736	8	11	2	32.60	32.60	32.60	48.60	0.00	13.00	0.00	0.00	77	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
737	239	11	2	38.90	38.90	38.90	51.80	0.00	7.10	0.00	0.00	78	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
738	290	11	2	36.30	24.40	30.35	51.80	0.00	10.50	0.00	0.00	79	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
739	131	11	2	31.90	14.40	23.15	54.35	0.00	22.50	0.00	0.00	80	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
740	19	11	2	14.10	14.10	14.10	40.70	0.00	18.80	0.00	0.00	81	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
741	2	11	2	14.60	14.60	14.60	60.20	0.00	0.90	0.00	0.00	82	35.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
742	263	11	2	25.00	25.00	25.00	51.30	0.00	10.00	0.00	0.00	83	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
743	287	11	2	27.20	23.90	25.55	68.70	0.00	35.70	0.00	0.00	84	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
744	190	11	2	27.80	24.20	26.00	42.40	0.00	10.50	0.00	0.00	85	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
745	227	11	2	36.70	19.70	28.20	46.25	0.00	5.60	0.00	0.00	86	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
746	104	11	2	24.50	24.50	24.50	47.70	0.00	15.00	0.00	0.00	87	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
747	108	11	2	29.90	10.80	21.60	48.14	0.00	12.80	0.00	0.00	88	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
748	314	11	2	32.70	32.70	32.70	44.70	0.00	9.70	0.00	0.00	89	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
749	251	11	2	26.50	26.50	26.50	51.20	0.00	34.10	0.00	0.00	90	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
750	64	11	2	37.00	37.00	37.00	34.10	0.00	2.70	0.00	0.00	91	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
751	229	11	2	29.80	25.90	27.85	58.30	0.00	9.80	0.00	0.00	92	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
752	39	11	2	32.80	32.80	32.80	35.90	0.00	16.00	0.00	0.00	93	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
753	271	11	2	26.90	26.90	26.90	65.80	0.00	3.20	0.00	0.00	94	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
754	291	11	2	39.70	26.50	33.10	26.65	0.00	10.70	0.00	0.00	95	64.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
755	295	11	2	25.90	25.90	25.90	67.30	0.00	4.70	0.00	0.00	96	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
756	213	11	2	25.60	25.60	25.60	55.10	0.00	3.90	0.00	0.00	97	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
757	159	11	2	10.20	8.70	9.45	67.90	0.00	12.30	0.00	0.00	98	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
758	160	11	2	7.90	7.90	7.90	48.70	0.00	10.10	0.00	0.00	99	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
759	115	11	2	17.00	17.00	17.00	19.70	0.00	7.90	0.00	0.00	100	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
760	305	11	2	13.40	13.30	13.35	60.10	0.00	0.80	0.00	0.00	101	35.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
761	25	11	2	24.50	24.50	24.50	41.80	0.00	13.10	0.00	0.00	102	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
762	5	11	2	19.80	19.80	19.80	41.30	0.00	4.00	0.00	0.00	103	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
763	304	11	2	25.90	14.10	18.83	57.27	0.00	19.70	0.00	0.00	104	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
764	311	11	2	23.30	23.30	23.30	40.00	0.00	2.00	0.00	0.00	105	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
765	238	11	2	8.80	8.80	8.80	46.70	0.00	29.40	0.00	0.00	106	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
766	6	11	2	37.30	12.50	24.97	54.63	0.00	20.60	0.00	0.00	107	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
767	4	11	2	33.70	33.70	33.70	71.00	0.00	3.00	0.00	0.00	108	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
768	66	11	2	24.70	24.70	24.70	36.40	0.00	18.90	0.00	0.00	109	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
769	270	11	2	24.80	24.80	24.80	43.90	0.00	6.50	0.00	0.00	110	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
770	244	11	2	26.10	26.10	26.10	28.30	0.00	4.60	0.00	0.00	111	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
771	147	11	2	10.80	10.80	10.80	44.80	0.00	9.10	0.00	0.00	112	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
772	14	11	2	29.10	10.30	19.70	48.10	0.00	11.30	0.00	0.00	113	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
773	272	11	2	31.90	31.90	31.90	60.90	0.00	12.40	0.00	0.00	114	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
774	282	11	2	11.70	11.70	11.70	60.70	0.00	1.70	0.00	0.00	115	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
775	317	11	2	29.30	20.00	25.57	37.80	0.00	4.90	0.00	0.00	116	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
776	100	11	2	9.00	9.00	9.00	43.30	0.00	7.00	0.00	0.00	117	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
777	176	11	2	35.90	35.90	35.90	47.30	0.00	0.70	0.00	0.00	118	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
778	68	11	2	24.00	21.90	22.95	54.00	0.00	16.40	0.00	0.00	119	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
779	48	11	2	29.70	15.00	22.68	58.40	0.00	24.40	0.00	0.00	120	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
780	318	11	2	22.90	22.90	22.90	44.10	0.00	0.90	0.00	0.00	121	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
781	246	11	2	28.20	28.20	28.20	62.10	0.00	17.00	0.00	0.00	122	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
782	228	11	2	19.30	19.30	19.30	68.30	0.00	0.00	0.00	0.00	123	35.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
783	219	11	2	31.30	31.30	31.30	29.20	0.00	0.60	0.00	0.00	124	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
784	26	11	2	27.80	13.30	22.60	50.23	0.00	20.90	0.00	0.00	125	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
785	259	11	2	37.40	24.70	31.05	43.10	0.00	17.30	0.00	0.00	126	61.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
786	182	11	2	12.50	12.50	12.50	48.60	0.00	9.10	0.00	0.00	127	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
787	223	11	2	27.10	27.10	27.10	74.80	0.00	4.90	0.00	0.00	128	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
788	226	11	2	29.90	22.60	26.25	62.50	0.00	12.60	0.00	0.00	129	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
789	70	11	2	8.80	2.70	5.75	59.00	0.00	15.80	0.00	0.00	130	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
790	154	11	2	26.20	26.20	26.20	45.80	0.00	3.60	0.00	0.00	131	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
791	211	11	2	27.00	27.00	27.00	37.10	0.00	25.40	0.00	0.00	132	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
792	74	11	2	24.10	24.10	24.10	64.80	0.00	1.60	0.00	0.00	133	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
793	169	11	2	13.90	13.90	13.90	55.00	0.00	10.20	0.00	0.00	134	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
794	132	11	2	22.60	22.60	22.60	45.40	0.00	8.60	0.00	0.00	135	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
795	217	11	2	33.00	28.90	30.95	52.60	0.00	64.80	0.00	0.00	136	66.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
796	185	11	2	13.80	13.80	13.80	47.90	0.00	16.00	0.00	0.00	137	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
797	315	11	2	31.90	31.90	31.90	62.90	0.00	14.50	0.00	0.00	138	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
798	44	11	2	27.50	26.90	27.20	56.55	0.00	29.80	0.00	0.00	139	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
799	143	11	2	13.30	7.30	10.30	44.10	0.00	38.40	0.00	0.00	140	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
800	164	11	2	15.50	15.50	15.50	37.30	0.00	19.50	0.00	0.00	141	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
801	205	11	2	13.90	13.90	13.90	46.90	0.00	6.50	0.00	0.00	142	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
802	276	11	2	33.60	33.60	33.60	47.00	0.00	5.90	0.00	0.00	143	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
803	253	11	2	21.10	21.10	21.10	29.20	0.00	16.40	0.00	0.00	144	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
804	156	11	2	21.90	15.00	18.45	51.60	0.00	4.40	0.00	0.00	145	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
805	269	11	2	13.10	13.10	13.10	50.60	0.00	14.20	0.00	0.00	146	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
806	280	11	2	22.40	22.40	22.40	52.60	0.00	34.90	0.00	0.00	147	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
807	220	11	2	33.40	15.60	26.77	43.30	0.00	9.60	0.00	0.00	148	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
808	273	11	2	24.20	24.20	24.20	44.10	0.00	7.00	0.00	0.00	149	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
809	187	11	2	24.70	24.70	24.70	66.90	0.00	2.50	0.00	0.00	150	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
810	17	11	2	21.10	9.60	15.40	40.23	0.00	46.10	0.00	0.00	151	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
811	177	11	2	24.00	11.20	17.60	36.05	0.00	9.10	0.00	0.00	152	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
812	196	11	2	34.30	34.30	34.30	60.40	0.00	11.90	0.00	0.00	153	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
813	162	11	2	14.30	14.30	14.30	36.50	0.00	13.10	0.00	0.00	154	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
814	294	11	2	23.90	23.90	23.90	40.60	0.00	5.10	0.00	0.00	155	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
815	105	11	2	32.40	12.90	22.65	48.85	0.00	3.00	0.00	0.00	156	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
816	55	11	2	32.30	32.30	32.30	62.00	0.00	15.50	0.00	0.00	157	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
817	284	11	2	31.50	31.50	31.50	48.00	0.00	7.30	0.00	0.00	158	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
818	41	11	2	9.50	9.50	9.50	43.50	0.00	6.20	0.00	0.00	159	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
819	88	11	2	22.80	22.80	22.80	42.20	0.00	2.10	0.00	0.00	160	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
820	298	11	2	9.00	9.00	9.00	36.80	0.00	10.80	0.00	0.00	161	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
821	250	11	2	22.00	22.00	22.00	29.00	0.00	12.30	0.00	0.00	162	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
822	286	11	2	29.50	29.50	29.50	50.20	0.00	6.50	0.00	0.00	163	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
823	140	11	2	22.10	22.10	22.10	36.30	0.00	2.90	0.00	0.00	164	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
824	274	11	2	25.50	20.20	22.85	57.15	0.00	25.20	0.00	0.00	165	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
825	224	11	2	32.50	17.50	25.07	61.83	0.00	9.10	0.00	0.00	166	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
826	248	11	2	28.40	26.70	27.55	68.35	0.00	27.20	0.00	0.00	167	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
827	146	11	2	30.10	13.00	21.55	49.20	0.00	30.80	0.00	0.00	168	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
828	207	11	2	22.60	22.60	22.60	51.10	0.00	21.80	0.00	0.00	169	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
829	72	11	2	25.00	12.70	18.85	59.75	0.00	11.50	0.00	0.00	170	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
830	186	11	2	25.80	25.80	25.80	39.50	0.00	0.70	0.00	0.00	171	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
831	264	11	2	27.80	10.80	21.27	51.63	0.00	9.00	0.00	0.00	172	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
832	97	11	2	35.40	35.40	35.40	56.70	0.00	13.80	0.00	0.00	173	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
833	173	11	2	24.60	9.10	16.85	53.00	0.00	8.30	0.00	0.00	174	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
834	307	11	2	35.30	14.40	26.42	50.18	0.00	16.20	0.00	0.00	175	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
835	203	11	2	23.70	23.70	23.70	49.50	0.00	4.20	0.00	0.00	176	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
836	201	11	2	29.30	27.70	28.50	60.50	0.00	4.00	0.00	0.00	177	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
837	9	11	2	10.40	10.40	10.40	33.10	0.00	12.40	0.00	0.00	178	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
838	120	11	2	26.60	25.50	26.05	45.50	0.00	19.10	0.00	0.00	179	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
839	324	11	2	26.70	21.80	24.25	59.35	0.00	6.30	0.00	0.00	180	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
840	29	11	2	32.20	27.50	29.85	50.45	0.00	12.70	0.00	0.00	181	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
841	95	11	2	28.60	28.60	28.60	40.60	0.00	1.30	0.00	0.00	182	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
842	158	11	2	6.30	6.30	6.30	68.80	0.00	18.80	0.00	0.00	183	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
843	123	11	2	28.40	28.40	28.40	57.80	0.00	2.10	0.00	0.00	184	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
844	15	11	2	26.00	26.00	26.00	37.30	0.00	10.80	0.00	0.00	185	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
845	198	11	2	23.70	22.90	23.30	27.05	0.00	4.70	0.00	0.00	186	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
846	94	11	2	35.20	13.10	26.23	48.93	0.00	26.20	0.00	0.00	187	60.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
847	237	11	2	28.60	12.60	22.07	47.13	0.00	19.20	0.00	0.00	188	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
848	77	11	2	33.40	33.40	33.40	41.80	0.00	6.50	0.00	0.00	189	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
849	107	11	2	27.30	8.60	17.95	40.55	0.00	15.00	0.00	0.00	190	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
850	141	11	2	32.30	22.70	27.50	38.85	0.00	18.20	0.00	0.00	191	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
851	199	11	2	11.70	11.00	11.35	55.15	0.00	12.70	0.00	0.00	192	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
852	288	11	2	31.20	25.70	28.97	44.47	0.00	33.20	0.00	0.00	193	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
853	128	11	2	31.20	21.80	26.50	74.40	0.00	7.60	0.00	0.00	194	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
854	106	11	2	26.40	23.70	25.05	49.35	0.00	4.00	0.00	0.00	195	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
855	93	11	2	17.00	7.40	12.20	40.50	0.00	11.40	0.00	0.00	196	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
856	293	11	2	32.40	9.90	21.15	47.25	0.00	8.80	0.00	0.00	197	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
857	209	11	2	23.00	23.00	23.00	42.60	0.00	12.80	0.00	0.00	198	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
858	114	11	2	25.00	25.00	25.00	35.30	0.00	19.70	0.00	0.00	199	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
859	265	11	2	27.30	27.30	27.30	53.90	0.00	7.90	0.00	0.00	200	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
860	82	11	2	36.30	18.60	27.58	50.80	0.00	18.70	0.00	0.00	201	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
861	113	11	2	23.50	23.50	23.50	56.50	0.00	31.30	0.00	0.00	202	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
862	181	11	2	33.10	25.50	29.30	48.90	0.00	10.90	0.00	0.00	203	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
863	60	11	2	24.40	10.10	17.25	50.80	0.00	20.80	0.00	0.00	204	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
864	10	11	2	22.00	15.20	19.57	41.63	0.00	24.20	0.00	0.00	205	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
865	214	11	2	24.70	24.70	24.70	38.40	0.00	24.30	0.00	0.00	206	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
866	255	11	2	31.70	7.50	19.60	57.05	0.00	11.50	0.00	0.00	207	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
867	36	11	2	30.10	13.30	25.05	50.78	0.00	15.20	0.00	0.00	208	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
868	129	11	2	34.30	23.40	28.85	51.25	0.00	8.90	0.00	0.00	209	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
869	58	11	2	24.70	24.70	24.70	31.50	0.00	8.30	0.00	0.00	210	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
870	178	11	2	31.20	22.90	26.00	43.67	0.00	12.40	0.00	0.00	211	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
871	16	11	2	29.00	29.00	29.00	67.20	0.00	9.60	0.00	0.00	212	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
872	184	11	2	29.50	26.40	27.95	40.05	0.00	15.60	0.00	0.00	213	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
873	110	13	2	15.80	15.80	15.80	28.10	0.00	4.30	0.00	0.00	1	11.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
874	130	13	2	22.50	14.10	18.30	36.30	0.00	21.50	0.00	0.00	2	17.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
875	163	13	2	28.50	16.90	24.40	35.47	0.00	19.90	0.00	0.00	3	23.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
876	33	13	2	26.00	20.80	23.40	63.45	0.00	11.40	0.00	0.00	4	13.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
877	218	13	2	20.10	20.10	20.10	38.80	0.00	21.20	0.00	0.00	5	22.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
878	256	13	2	28.30	28.30	28.30	60.50	0.00	4.10	0.00	0.00	6	16.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
879	127	13	2	20.00	19.30	19.65	75.05	0.00	16.60	0.00	0.00	7	19.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
880	65	13	2	27.00	27.00	27.00	60.90	0.00	4.90	0.00	0.00	8	18.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
881	22	13	2	27.40	27.40	27.40	51.70	0.00	2.00	0.00	0.00	9	21.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
882	174	13	2	27.30	11.30	21.23	37.73	0.00	26.30	0.00	0.00	10	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
883	124	13	2	23.90	23.90	23.90	52.90	0.00	7.30	0.00	0.00	11	24.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
884	277	13	2	7.90	7.90	7.90	47.00	0.00	7.10	0.00	0.00	12	27.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
885	102	13	2	10.60	10.60	10.60	37.90	0.00	7.20	0.00	0.00	13	31.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
886	189	13	2	25.40	25.40	25.40	53.80	0.00	6.60	0.00	0.00	14	29.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
887	157	13	2	11.20	11.20	11.20	74.90	0.00	18.20	0.00	0.00	15	34.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
888	118	13	2	29.80	25.70	27.75	67.20	0.00	11.60	0.00	0.00	16	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
889	266	13	2	25.70	14.20	19.95	52.30	0.00	14.10	0.00	0.00	17	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
890	91	13	2	16.50	16.50	16.50	67.20	0.00	6.50	0.00	0.00	18	34.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
891	168	13	2	23.10	23.10	23.10	64.10	0.00	0.50	0.00	0.00	19	33.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
892	165	13	2	33.80	33.80	33.80	58.90	0.00	3.40	0.00	0.00	20	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
893	62	13	2	36.40	31.60	34.00	60.15	0.00	11.30	0.00	0.00	21	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
894	285	13	2	30.00	7.20	21.43	49.60	0.00	12.90	0.00	0.00	22	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
895	125	13	2	36.60	17.10	27.93	51.37	0.00	9.10	0.00	0.00	23	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
896	243	13	2	28.50	26.60	27.55	40.30	0.00	7.00	0.00	0.00	24	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
897	98	13	2	24.00	24.00	24.00	55.10	0.00	21.30	0.00	0.00	25	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
898	63	13	2	33.50	33.50	33.50	34.90	0.00	3.20	0.00	0.00	26	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
899	275	13	2	15.80	15.80	15.80	79.50	0.00	8.20	0.00	0.00	27	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
900	134	13	2	30.20	27.70	28.95	50.70	0.00	4.30	0.00	0.00	28	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
901	155	13	2	28.80	21.40	25.10	48.10	0.00	8.70	0.00	0.00	29	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
902	268	13	2	22.80	15.30	19.05	39.05	0.00	33.80	0.00	0.00	30	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
903	80	13	2	21.20	13.70	16.50	52.37	0.00	5.40	0.00	0.00	31	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
904	136	13	2	35.60	35.60	35.60	42.10	0.00	7.20	0.00	0.00	32	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
905	1	13	2	21.70	20.70	21.20	59.40	0.00	13.10	0.00	0.00	33	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
906	325	13	2	28.00	28.00	28.00	34.00	0.00	28.90	0.00	0.00	34	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
907	241	13	2	27.60	23.20	25.40	53.60	0.00	6.50	0.00	0.00	35	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
908	166	13	2	26.80	14.80	20.80	52.80	0.00	6.80	0.00	0.00	36	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
909	215	13	2	21.00	9.80	15.40	57.95	0.00	9.80	0.00	0.00	37	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
910	139	13	2	33.00	33.00	33.00	73.20	0.00	16.30	0.00	0.00	38	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
911	210	13	2	8.70	8.70	8.70	81.60	0.00	2.90	0.00	0.00	39	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
912	312	13	2	26.90	13.10	20.00	45.40	0.00	32.90	0.00	0.00	40	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
913	31	13	2	37.30	8.10	24.13	55.73	0.00	12.50	0.00	0.00	41	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
914	301	13	2	36.00	36.00	36.00	53.30	0.00	1.40	0.00	0.00	42	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
915	142	13	2	28.80	28.80	28.80	28.70	0.00	27.90	0.00	0.00	43	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
916	122	13	2	23.30	23.30	23.30	65.60	0.00	7.90	0.00	0.00	44	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
917	252	13	2	26.50	22.50	24.50	61.70	0.00	5.20	0.00	0.00	45	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
918	24	13	2	27.80	20.30	24.05	55.85	0.00	6.90	0.00	0.00	46	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
919	21	13	2	28.00	28.00	28.00	51.90	0.00	3.90	0.00	0.00	47	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
920	86	13	2	26.40	26.40	26.40	68.60	0.00	12.50	0.00	0.00	48	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
921	192	13	2	26.30	12.00	19.15	48.20	0.00	1.90	0.00	0.00	49	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
922	171	13	2	23.90	23.90	23.90	37.10	0.00	25.40	0.00	0.00	50	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
923	249	13	2	25.00	24.80	24.90	61.10	0.00	5.60	0.00	0.00	51	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
924	262	13	2	23.50	23.50	23.50	32.00	0.00	30.80	0.00	0.00	52	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
925	57	13	2	29.00	6.70	17.85	54.05	0.00	13.70	0.00	0.00	53	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
926	137	13	2	22.40	12.00	17.20	32.30	0.00	1.80	0.00	0.00	54	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
927	257	13	2	30.20	30.20	30.20	55.00	0.00	2.50	0.00	0.00	55	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
928	46	13	2	26.70	21.00	23.85	48.65	0.00	18.40	0.00	0.00	56	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
929	234	13	2	12.40	12.40	12.40	33.50	0.00	4.30	0.00	0.00	57	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
930	79	13	2	33.90	6.60	21.70	45.13	0.00	26.20	0.00	0.00	58	60.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
931	319	13	2	36.40	29.80	33.10	43.25	0.00	21.30	0.00	0.00	59	61.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
932	306	13	2	23.30	23.30	23.30	38.20	0.00	9.30	0.00	0.00	60	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
933	121	13	2	25.30	25.30	25.30	58.90	0.00	0.20	0.00	0.00	61	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
934	254	13	2	10.80	10.80	10.80	58.40	0.00	2.70	0.00	0.00	62	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
935	40	13	2	25.80	25.80	25.80	52.80	0.00	17.50	0.00	0.00	63	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
936	54	13	2	24.00	12.00	18.00	42.50	0.00	19.30	0.00	0.00	64	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
937	119	13	2	34.10	9.30	25.18	51.75	0.00	4.20	0.00	0.00	65	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
938	101	13	2	32.90	32.00	32.45	34.55	0.00	14.70	0.00	0.00	66	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
939	322	13	2	34.70	30.20	32.45	61.55	0.00	16.10	0.00	0.00	67	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
940	297	13	2	28.40	28.40	28.40	61.30	0.00	21.80	0.00	0.00	68	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
941	194	13	2	21.00	13.10	17.05	43.45	0.00	12.40	0.00	0.00	69	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
942	150	13	2	33.60	33.60	33.60	61.00	0.00	9.40	0.00	0.00	70	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
943	245	13	2	12.50	12.50	12.50	79.80	0.00	12.40	0.00	0.00	71	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
944	126	13	2	12.00	12.00	12.00	67.70	0.00	22.10	0.00	0.00	72	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
945	309	13	2	20.70	20.70	20.70	47.40	0.00	16.10	0.00	0.00	73	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
946	204	13	2	21.40	21.40	21.40	24.80	0.00	16.90	0.00	0.00	74	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
947	53	13	2	35.80	29.70	32.75	33.80	0.00	5.40	0.00	0.00	75	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
948	3	13	2	12.40	12.40	12.40	50.40	0.00	12.20	0.00	0.00	76	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
949	300	13	2	23.80	23.80	23.80	43.40	0.00	12.10	0.00	0.00	77	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
950	208	13	2	26.00	14.40	18.87	42.70	0.00	18.30	0.00	0.00	78	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
951	87	13	2	22.30	22.30	22.30	15.90	0.00	0.80	0.00	0.00	79	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
952	28	13	2	20.80	11.70	16.25	65.80	0.00	20.70	0.00	0.00	80	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
953	212	13	2	23.40	21.20	22.30	44.55	0.00	10.30	0.00	0.00	81	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
954	8	13	2	21.40	21.40	21.40	35.40	0.00	6.30	0.00	0.00	82	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
955	49	13	2	12.20	12.20	12.20	65.30	0.00	1.20	0.00	0.00	83	35.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
956	239	13	2	32.30	32.30	32.30	47.20	0.00	3.30	0.00	0.00	84	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
957	131	13	2	23.10	23.10	23.10	43.50	0.00	36.10	0.00	0.00	85	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
958	71	13	2	29.40	12.10	20.75	38.40	0.00	8.00	0.00	0.00	86	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
959	19	13	2	34.40	34.40	34.40	42.10	0.00	7.10	0.00	0.00	87	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
960	2	13	2	37.40	24.20	30.33	62.27	0.00	26.60	0.00	0.00	88	61.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
961	263	13	2	12.00	12.00	12.00	37.20	0.00	15.00	0.00	0.00	89	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
962	287	13	2	22.90	19.40	21.15	60.00	0.00	5.50	0.00	0.00	90	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
963	190	13	2	29.40	29.40	29.40	54.70	0.00	17.10	0.00	0.00	91	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
964	104	13	2	13.10	13.10	13.10	41.50	0.00	10.80	0.00	0.00	92	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
965	314	13	2	25.40	15.30	20.35	46.20	0.00	5.30	0.00	0.00	93	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
966	64	13	2	29.10	29.10	29.10	57.70	0.00	9.20	0.00	0.00	94	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
967	39	13	2	29.60	10.10	21.00	66.67	0.00	41.90	0.00	0.00	95	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
968	271	13	2	25.00	25.00	25.00	33.20	0.00	13.50	0.00	0.00	96	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
969	291	13	2	16.40	16.40	16.40	73.80	0.00	18.00	0.00	0.00	97	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
970	195	13	2	23.40	21.10	22.25	38.65	0.00	17.80	0.00	0.00	98	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
971	59	13	2	22.60	22.60	22.60	31.00	0.00	1.00	0.00	0.00	99	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
972	83	13	2	31.50	31.50	31.50	50.30	0.00	3.00	0.00	0.00	100	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
973	295	13	2	22.20	13.80	18.00	47.10	0.00	15.40	0.00	0.00	101	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
974	242	13	2	29.00	23.80	26.40	33.60	0.00	14.30	0.00	0.00	102	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
975	213	13	2	28.50	14.70	21.60	41.70	0.00	16.30	0.00	0.00	103	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
976	159	13	2	25.50	25.50	25.50	55.60	0.00	17.50	0.00	0.00	104	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
977	160	13	2	22.90	22.90	22.90	18.50	0.00	2.70	0.00	0.00	105	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
978	115	13	2	27.70	27.70	27.70	45.00	0.00	0.40	0.00	0.00	106	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
979	25	13	2	36.70	12.80	24.30	55.13	0.00	25.00	0.00	0.00	107	60.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
980	13	13	2	24.50	24.50	24.50	28.70	0.00	11.20	0.00	0.00	108	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
981	278	13	2	26.60	26.60	26.60	34.90	0.00	0.20	0.00	0.00	109	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
982	61	13	2	25.50	25.50	25.50	77.80	0.00	18.60	0.00	0.00	110	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
983	304	13	2	14.10	6.20	10.15	44.15	0.00	9.40	0.00	0.00	111	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
984	311	13	2	23.40	21.10	22.25	63.60	0.00	11.10	0.00	0.00	112	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
985	238	13	2	24.80	6.40	14.73	59.90	0.00	14.70	0.00	0.00	113	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
986	6	13	2	38.30	7.30	20.40	44.33	0.00	20.50	0.00	0.00	114	63.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
987	235	13	2	23.40	23.40	23.40	24.80	0.00	3.70	0.00	0.00	115	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
988	302	13	2	30.30	30.30	30.30	53.60	0.00	8.80	0.00	0.00	116	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
989	4	13	2	13.10	13.10	13.10	64.30	0.00	2.80	0.00	0.00	117	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
990	32	13	2	35.10	35.10	35.10	61.80	0.00	3.20	0.00	0.00	118	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
991	206	13	2	27.20	27.20	27.20	32.60	0.00	2.90	0.00	0.00	119	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
992	283	13	2	31.20	31.20	31.20	20.50	0.00	5.20	0.00	0.00	120	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
993	270	13	2	8.50	8.50	8.50	49.80	0.00	14.30	0.00	0.00	121	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
994	244	13	2	34.40	21.30	27.85	54.40	0.00	32.60	0.00	0.00	122	61.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
995	147	13	2	10.80	10.80	10.80	62.30	0.00	26.70	0.00	0.00	123	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
996	272	13	2	26.60	26.60	26.60	41.90	0.00	23.80	0.00	0.00	124	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
997	282	13	2	31.30	30.10	30.70	53.95	0.00	10.10	0.00	0.00	125	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
998	100	13	2	22.80	22.80	22.80	53.10	0.00	8.90	0.00	0.00	126	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
999	176	13	2	28.60	28.60	28.60	62.60	0.00	1.70	0.00	0.00	127	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1000	68	13	2	27.30	27.30	27.30	51.70	0.00	0.50	0.00	0.00	128	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1001	48	13	2	31.40	31.40	31.40	33.70	0.00	0.30	0.00	0.00	129	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1002	261	13	2	34.60	16.00	23.33	53.50	0.00	24.00	0.00	0.00	130	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1003	318	13	2	32.90	27.50	30.20	38.35	0.00	24.50	0.00	0.00	131	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1004	219	13	2	24.90	24.90	24.90	30.00	0.00	9.60	0.00	0.00	132	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1005	223	13	2	35.00	35.00	35.00	34.50	0.00	3.20	0.00	0.00	133	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1006	70	13	2	32.60	32.60	32.60	22.40	0.00	9.20	0.00	0.00	134	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1007	154	13	2	31.90	31.90	31.90	70.20	0.00	8.60	0.00	0.00	135	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1008	211	13	2	22.90	11.20	17.05	40.20	0.00	17.30	0.00	0.00	136	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1009	74	13	2	23.60	23.60	23.60	59.70	0.00	18.70	0.00	0.00	137	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1010	116	13	2	34.90	21.80	26.97	59.37	0.00	8.70	0.00	0.00	138	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1011	132	13	2	30.40	30.40	30.40	43.90	0.00	23.30	0.00	0.00	139	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1012	45	13	2	28.50	9.00	17.20	45.53	0.00	10.80	0.00	0.00	140	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1013	191	13	2	27.60	8.70	18.15	21.35	0.00	3.30	0.00	0.00	141	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1014	217	13	2	37.10	37.10	37.10	44.40	0.00	4.70	0.00	0.00	142	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1015	44	13	2	28.80	13.20	23.68	69.93	0.00	19.50	0.00	0.00	143	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1016	143	13	2	32.80	20.80	27.47	48.53	0.00	33.60	0.00	0.00	144	60.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1017	164	13	2	27.40	27.40	27.40	65.30	0.00	15.60	0.00	0.00	145	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1018	205	13	2	27.80	27.80	27.80	67.40	0.00	20.20	0.00	0.00	146	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1019	183	13	2	28.10	28.10	28.10	72.90	0.00	3.00	0.00	0.00	147	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1020	89	13	2	21.90	21.90	21.90	58.00	0.00	9.10	0.00	0.00	148	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1021	85	13	2	30.50	30.50	30.50	54.70	0.00	1.70	0.00	0.00	149	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1022	148	13	2	33.10	29.10	31.10	54.35	0.00	11.60	0.00	0.00	150	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1023	197	13	2	31.50	28.30	29.90	45.60	0.00	6.90	0.00	0.00	151	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1024	269	13	2	14.30	14.30	14.30	69.40	0.00	9.50	0.00	0.00	152	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1025	321	13	2	9.60	6.70	8.15	62.20	0.00	6.60	0.00	0.00	153	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1026	188	13	2	20.70	20.70	20.70	75.90	0.00	25.10	0.00	0.00	154	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1027	220	13	2	7.60	5.40	6.50	32.85	0.00	15.00	0.00	0.00	155	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1028	273	13	2	29.00	29.00	29.00	66.30	0.00	1.80	0.00	0.00	156	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1029	17	13	2	25.60	25.60	25.60	50.30	0.00	10.00	0.00	0.00	157	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1030	296	13	2	28.10	28.10	28.10	57.60	0.00	6.90	0.00	0.00	158	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1031	30	13	2	10.30	10.30	10.30	77.70	0.00	14.50	0.00	0.00	159	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1032	47	13	2	23.30	23.30	23.30	61.20	0.00	27.20	0.00	0.00	160	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1033	177	13	2	23.00	13.10	18.05	47.75	0.00	4.70	0.00	0.00	161	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1034	196	13	2	32.70	20.70	27.14	46.50	0.00	15.90	0.00	0.00	162	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1035	162	13	2	35.30	16.20	25.75	54.45	0.00	1.20	0.00	0.00	163	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1036	294	13	2	32.00	25.50	28.75	58.55	0.00	12.90	0.00	0.00	164	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1037	105	13	2	35.30	20.60	27.95	59.35	0.00	7.30	0.00	0.00	165	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1038	55	13	2	9.70	7.60	8.65	43.05	0.00	6.90	0.00	0.00	166	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1039	284	13	2	26.50	26.50	26.50	55.80	0.00	9.50	0.00	0.00	167	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1040	41	13	2	12.10	12.10	12.10	81.60	0.00	0.50	0.00	0.00	168	35.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1041	109	13	2	32.80	28.90	30.85	20.55	0.00	4.80	0.00	0.00	169	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1042	88	13	2	23.20	23.20	23.20	39.10	0.00	11.30	0.00	0.00	170	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1043	298	13	2	22.50	22.50	22.50	48.40	0.00	2.50	0.00	0.00	171	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1044	316	13	2	31.50	9.20	18.63	46.70	0.00	11.50	0.00	0.00	172	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1045	286	13	2	24.30	24.30	24.30	45.50	0.00	20.70	0.00	0.00	173	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1046	236	13	2	22.10	22.10	22.10	40.10	0.00	3.70	0.00	0.00	174	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1047	274	13	2	22.10	16.30	19.20	47.35	0.00	3.90	0.00	0.00	175	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1048	224	13	2	25.90	25.90	25.90	66.70	0.00	5.60	0.00	0.00	176	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1049	248	13	2	31.50	31.50	31.50	61.10	0.00	21.00	0.00	0.00	177	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1050	146	13	2	28.70	23.00	25.85	31.85	0.00	14.00	0.00	0.00	178	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1051	117	13	2	28.60	28.60	28.60	47.70	0.00	6.80	0.00	0.00	179	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1052	233	13	2	26.70	22.90	24.80	47.35	0.00	81.00	0.00	0.00	180	60.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1053	72	13	2	32.80	32.80	32.80	49.10	0.00	0.80	0.00	0.00	181	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1054	186	13	2	27.10	27.10	27.10	30.80	0.00	10.90	0.00	0.00	182	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1055	179	13	2	29.80	22.20	26.00	50.70	0.00	27.90	0.00	0.00	183	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1056	320	13	2	30.60	30.60	30.60	61.30	0.00	2.20	0.00	0.00	184	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1057	264	13	2	30.90	30.90	30.90	82.70	0.00	0.30	0.00	0.00	185	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1058	173	13	2	33.50	13.10	23.30	60.45	0.00	37.40	0.00	0.00	186	60.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1059	201	13	2	26.90	13.40	20.15	55.00	0.00	7.60	0.00	0.00	187	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1060	9	13	2	37.70	26.00	32.53	54.03	0.00	15.60	0.00	0.00	188	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1061	279	13	2	21.80	21.80	21.80	62.70	0.00	0.80	0.00	0.00	189	35.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1062	120	13	2	33.70	9.00	20.80	53.05	0.00	22.10	0.00	0.00	190	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1063	324	13	2	15.20	15.20	15.20	23.40	0.00	3.70	0.00	0.00	191	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1064	29	13	2	28.20	28.20	28.20	49.60	0.00	14.70	0.00	0.00	192	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1065	158	13	2	33.70	26.60	30.15	60.95	0.00	8.60	0.00	0.00	193	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1066	20	13	2	29.40	27.60	28.50	55.05	0.00	1.10	0.00	0.00	194	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1067	123	13	2	23.80	23.80	23.80	43.60	0.00	6.50	0.00	0.00	195	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1068	198	13	2	22.10	22.10	22.10	37.60	0.00	31.70	0.00	0.00	196	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1069	94	13	2	21.90	21.90	21.90	51.10	0.00	16.20	0.00	0.00	197	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1070	237	13	2	30.20	30.20	30.20	37.90	0.00	5.80	0.00	0.00	198	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1071	247	13	2	34.90	25.20	28.93	36.43	0.00	24.30	0.00	0.00	199	62.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1072	23	13	2	7.80	7.80	7.80	58.90	0.00	2.30	0.00	0.00	200	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1073	42	13	2	35.90	23.70	29.80	50.25	0.00	13.40	0.00	0.00	201	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1074	107	13	2	35.00	33.60	34.30	65.15	0.00	22.90	0.00	0.00	202	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1075	141	13	2	25.00	25.00	25.00	37.60	0.00	20.20	0.00	0.00	203	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1076	199	13	2	16.00	16.00	16.00	63.60	0.00	8.80	0.00	0.00	204	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1077	128	13	2	11.30	11.30	11.30	73.50	0.00	37.60	0.00	0.00	205	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1078	106	13	2	33.90	20.30	26.32	60.20	0.00	13.20	0.00	0.00	206	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1079	93	13	2	23.90	13.20	20.27	50.43	0.00	16.10	0.00	0.00	207	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1080	293	13	2	30.70	15.90	23.30	42.90	0.00	10.10	0.00	0.00	208	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1081	12	13	2	34.10	11.90	26.37	58.43	0.00	8.50	0.00	0.00	209	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1082	133	13	2	33.90	14.50	24.57	55.33	0.00	30.30	0.00	0.00	210	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1083	265	13	2	8.80	8.80	8.80	56.30	0.00	2.50	0.00	0.00	211	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1084	82	13	2	37.00	37.00	37.00	76.60	0.00	2.00	0.00	0.00	212	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1085	113	13	2	24.60	11.00	17.80	51.75	0.00	8.10	0.00	0.00	213	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1086	181	13	2	28.40	28.40	28.40	49.30	0.00	3.10	0.00	0.00	214	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1087	10	13	2	33.10	33.10	33.10	42.10	0.00	24.70	0.00	0.00	215	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1088	214	13	2	28.30	10.50	19.40	39.65	0.00	16.30	0.00	0.00	216	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1089	255	13	2	24.90	15.00	19.95	41.75	0.00	4.40	0.00	0.00	217	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1090	36	13	2	31.50	24.70	28.47	70.60	0.00	15.90	0.00	0.00	218	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1091	58	13	2	26.00	26.00	26.00	51.70	0.00	10.50	0.00	0.00	219	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1092	178	13	2	31.30	31.30	31.30	68.30	0.00	5.30	0.00	0.00	220	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1093	184	13	2	21.20	16.50	18.85	65.80	0.00	1.30	0.00	0.00	221	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1094	110	2	2	28.50	6.20	17.35	48.60	0.00	5.10	0.00	0.00	1	11.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1095	130	2	2	20.90	13.00	16.95	41.95	0.00	15.30	0.00	0.00	2	14.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1096	163	2	2	36.00	36.00	36.00	67.70	0.00	10.50	0.00	0.00	3	23.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1097	256	2	2	9.80	9.80	9.80	61.60	0.00	5.80	0.00	0.00	4	9.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1098	22	2	2	23.00	23.00	23.00	32.70	0.00	1.40	0.00	0.00	5	15.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1099	267	2	2	25.30	25.30	25.30	1.20	0.00	4.50	0.00	0.00	6	26.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1100	124	2	2	11.10	11.10	11.10	51.60	0.00	20.70	0.00	0.00	7	22.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1101	277	2	2	31.10	22.50	26.80	40.70	0.00	3.40	0.00	0.00	8	27.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1102	102	2	2	24.60	24.60	24.60	52.20	0.00	1.90	0.00	0.00	9	18.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1103	189	2	2	11.60	11.60	11.60	43.80	0.00	16.50	0.00	0.00	10	28.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1104	157	2	2	25.80	25.80	25.80	28.70	0.00	2.50	0.00	0.00	11	28.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1105	35	2	2	25.40	13.80	19.60	57.75	0.00	19.30	0.00	0.00	12	30.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1106	118	2	2	32.10	32.10	32.10	41.00	0.00	9.20	0.00	0.00	13	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1107	91	2	2	24.60	24.60	24.60	29.80	0.00	18.60	0.00	0.00	14	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1108	168	2	2	30.40	30.40	30.40	62.20	0.00	2.00	0.00	0.00	15	34.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1109	165	2	2	29.70	10.20	22.67	54.63	0.00	16.20	0.00	0.00	16	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1110	62	2	2	30.80	30.80	30.80	50.70	0.00	12.10	0.00	0.00	17	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1111	285	2	2	29.30	29.30	29.30	46.70	0.00	18.50	0.00	0.00	18	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1112	125	2	2	30.80	14.60	25.18	44.48	0.00	10.90	0.00	0.00	19	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1113	98	2	2	26.90	26.90	26.90	33.60	0.00	8.00	0.00	0.00	20	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1114	202	2	2	35.60	11.90	22.06	50.56	0.00	17.10	0.00	0.00	21	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1115	200	2	2	27.60	27.60	27.60	67.70	0.00	9.10	0.00	0.00	22	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1116	134	2	2	31.10	9.00	20.05	55.80	0.00	25.30	0.00	0.00	23	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1117	268	2	2	24.70	24.70	24.70	48.80	0.00	7.40	0.00	0.00	24	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1118	80	2	2	29.30	22.90	26.10	37.95	0.00	17.80	0.00	0.00	25	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1119	136	2	2	38.30	9.30	23.80	43.90	0.00	8.10	0.00	0.00	26	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1120	325	2	2	23.40	23.40	23.40	41.90	0.00	4.20	0.00	0.00	27	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1121	167	2	2	30.10	30.10	30.10	31.30	0.00	3.90	0.00	0.00	28	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1122	166	2	2	24.00	24.00	24.00	80.70	0.00	5.30	0.00	0.00	29	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1123	193	2	2	22.90	13.80	18.35	44.25	0.00	18.50	0.00	0.00	30	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1124	215	2	2	25.80	25.80	25.80	52.60	0.00	23.80	0.00	0.00	31	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1125	312	2	2	20.10	20.10	20.10	52.90	0.00	11.20	0.00	0.00	32	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1126	145	2	2	27.30	27.30	27.30	71.00	0.00	11.10	0.00	0.00	33	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1127	301	2	2	33.20	33.20	33.20	71.10	0.00	2.20	0.00	0.00	34	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1128	142	2	2	26.90	7.50	20.13	46.43	0.00	8.50	0.00	0.00	35	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1129	122	2	2	29.90	11.30	20.60	45.40	0.00	57.70	0.00	0.00	36	64.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1130	24	2	2	26.90	23.70	25.30	53.05	0.00	17.60	0.00	0.00	37	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1131	103	2	2	25.10	10.20	16.27	44.67	0.00	13.70	0.00	0.00	38	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1132	192	2	2	30.10	7.90	17.10	53.43	0.00	19.60	0.00	0.00	39	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1133	258	2	2	8.60	8.60	8.60	65.20	0.00	2.00	0.00	0.00	40	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1134	171	2	2	33.20	33.20	33.20	30.00	0.00	13.00	0.00	0.00	41	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1135	149	2	2	30.40	25.00	27.70	53.85	0.00	7.60	0.00	0.00	42	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1136	249	2	2	32.20	13.40	22.80	68.15	0.00	7.80	0.00	0.00	43	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1137	37	2	2	26.60	23.10	24.85	56.40	0.00	25.10	0.00	0.00	44	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1138	153	2	2	22.70	22.70	22.70	69.80	0.00	7.30	0.00	0.00	45	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1139	138	2	2	25.60	13.70	19.65	56.60	0.00	40.40	0.00	0.00	46	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1140	151	2	2	23.40	8.50	15.95	54.15	0.00	10.00	0.00	0.00	47	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1141	257	2	2	27.60	27.60	27.60	63.00	0.00	10.50	0.00	0.00	48	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1142	46	2	2	31.90	9.10	22.13	51.77	0.00	42.60	0.00	0.00	49	62.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1143	92	2	2	27.10	27.10	27.10	53.10	0.00	28.90	0.00	0.00	50	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1144	234	2	2	8.70	8.70	8.70	67.70	0.00	11.90	0.00	0.00	51	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1145	303	2	2	28.50	22.90	26.37	48.77	0.00	40.20	0.00	0.00	52	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1146	319	2	2	21.90	21.90	21.90	39.60	0.00	5.10	0.00	0.00	53	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1147	69	2	2	31.80	15.10	25.13	40.53	0.00	10.50	0.00	0.00	54	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1148	306	2	2	9.90	9.90	9.90	51.20	0.00	7.50	0.00	0.00	55	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1149	121	2	2	14.60	14.60	14.60	41.10	0.00	5.20	0.00	0.00	56	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1150	254	2	2	32.90	32.90	32.90	44.80	0.00	8.90	0.00	0.00	57	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1151	40	2	2	14.30	14.30	14.30	51.80	0.00	12.40	0.00	0.00	58	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1152	54	2	2	31.00	13.70	22.35	46.00	0.00	17.60	0.00	0.00	59	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1153	119	2	2	16.80	16.80	16.80	42.70	0.00	3.80	0.00	0.00	60	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1154	322	2	2	26.60	14.60	20.60	44.35	0.00	0.10	0.00	0.00	61	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1155	56	2	2	35.10	35.10	35.10	56.10	0.00	18.00	0.00	0.00	62	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1156	194	2	2	30.60	13.00	21.80	43.50	0.00	7.00	0.00	0.00	63	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1157	73	2	2	29.00	25.00	27.00	53.65	0.00	23.50	0.00	0.00	64	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1158	309	2	2	26.80	25.90	26.35	36.40	0.00	10.20	0.00	0.00	65	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1159	204	2	2	25.10	8.70	16.90	46.35	0.00	7.80	0.00	0.00	66	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1160	53	2	2	12.20	12.20	12.20	48.00	0.00	7.90	0.00	0.00	67	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1161	3	2	2	27.20	27.20	27.20	46.20	0.00	3.90	0.00	0.00	68	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1162	300	2	2	34.20	34.20	34.20	56.40	0.00	13.60	0.00	0.00	69	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1163	208	2	2	23.30	15.90	19.60	52.25	0.00	12.20	0.00	0.00	70	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1164	87	2	2	24.10	24.10	24.10	42.80	0.00	27.80	0.00	0.00	71	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1165	212	2	2	31.50	20.00	27.57	44.73	0.00	8.60	0.00	0.00	72	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1166	8	2	2	24.40	8.20	12.90	48.75	0.00	17.40	0.00	0.00	73	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1167	239	2	2	17.20	17.20	17.20	41.60	0.00	13.40	0.00	0.00	74	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1168	75	2	2	17.80	17.80	17.80	45.00	0.00	6.50	0.00	0.00	75	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1169	71	2	2	20.20	20.20	20.20	69.20	0.00	27.50	0.00	0.00	76	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1170	19	2	2	10.10	10.10	10.10	81.70	0.00	1.40	0.00	0.00	77	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1171	2	2	2	33.00	25.80	29.13	43.53	0.00	23.30	0.00	0.00	78	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1172	287	2	2	3.90	3.90	3.90	46.20	0.00	5.40	0.00	0.00	79	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1173	190	2	2	33.10	23.70	28.40	43.50	0.00	26.80	0.00	0.00	80	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1174	227	2	2	35.10	32.20	33.65	46.45	0.00	45.40	0.00	0.00	81	68.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1175	104	2	2	18.10	8.00	13.05	47.20	0.00	9.80	0.00	0.00	82	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1176	34	2	2	23.70	11.80	17.75	58.95	0.00	1.40	0.00	0.00	83	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1177	64	2	2	21.30	20.90	21.10	45.70	0.00	15.90	0.00	0.00	84	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1178	229	2	2	26.60	26.20	26.40	37.45	0.00	10.90	0.00	0.00	85	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1179	39	2	2	21.40	21.40	21.40	63.60	0.00	20.40	0.00	0.00	86	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1180	271	2	2	31.30	27.30	29.30	54.25	0.00	24.50	0.00	0.00	87	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1181	291	2	2	18.50	18.50	18.50	50.20	0.00	24.30	0.00	0.00	88	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1182	195	2	2	25.30	12.90	19.10	43.40	0.00	1.80	0.00	0.00	89	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1183	59	2	2	32.60	32.60	32.60	56.80	0.00	6.00	0.00	0.00	90	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1184	83	2	2	22.00	0.90	11.45	61.70	0.00	29.00	0.00	0.00	91	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1185	242	2	2	25.10	25.10	25.10	50.10	0.00	4.60	0.00	0.00	92	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1186	81	2	2	23.10	9.50	16.30	32.50	0.00	12.20	0.00	0.00	93	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1187	84	2	2	35.20	17.40	25.73	56.17	0.00	23.80	0.00	0.00	94	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1188	159	2	2	29.60	9.70	16.87	50.40	0.00	23.90	0.00	0.00	95	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1189	115	2	2	30.90	24.10	27.50	55.25	0.00	5.40	0.00	0.00	96	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1190	5	2	2	35.20	35.20	35.20	74.40	0.00	2.10	0.00	0.00	97	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1191	13	2	2	36.10	32.70	34.40	58.55	0.00	4.70	0.00	0.00	98	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1192	278	2	2	13.10	13.10	13.10	31.10	0.00	0.40	0.00	0.00	99	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1193	172	2	2	29.70	29.70	29.70	38.90	0.00	6.70	0.00	0.00	100	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1194	61	2	2	12.80	12.80	12.80	49.60	0.00	6.40	0.00	0.00	101	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1195	304	2	2	33.50	12.40	24.90	43.50	0.00	53.90	0.00	0.00	102	69.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1196	311	2	2	35.00	26.80	30.90	58.10	0.00	10.50	0.00	0.00	103	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1197	6	2	2	25.30	25.30	25.30	54.60	0.00	45.60	0.00	0.00	104	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1198	235	2	2	8.30	8.30	8.30	19.20	0.00	22.00	0.00	0.00	105	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1199	4	2	2	35.10	35.10	35.10	37.10	0.00	2.60	0.00	0.00	106	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1200	66	2	2	26.00	12.00	20.40	69.27	0.00	15.60	0.00	0.00	107	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1201	206	2	2	33.70	13.10	23.40	43.25	0.00	5.90	0.00	0.00	108	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1202	283	2	2	15.70	15.70	15.70	49.00	0.00	21.10	0.00	0.00	109	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1203	270	2	2	28.20	11.00	22.27	61.93	0.00	5.50	0.00	0.00	110	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1204	244	2	2	22.30	22.30	22.30	78.90	0.00	44.90	0.00	0.00	111	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1205	282	2	2	25.50	25.50	25.50	66.20	0.00	10.30	0.00	0.00	112	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1206	317	2	2	32.20	14.80	23.50	59.80	0.00	35.00	0.00	0.00	113	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1207	100	2	2	31.30	31.30	31.30	44.00	0.00	1.40	0.00	0.00	114	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1208	176	2	2	35.20	35.20	35.20	43.10	0.00	10.00	0.00	0.00	115	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1209	68	2	2	35.20	29.50	32.35	58.75	0.00	12.20	0.00	0.00	116	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1210	261	2	2	28.30	25.10	26.70	71.10	0.00	2.10	0.00	0.00	117	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1211	318	2	2	24.20	24.20	24.20	36.70	0.00	18.00	0.00	0.00	118	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1212	246	2	2	34.00	23.60	27.30	40.68	0.00	10.20	0.00	0.00	119	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1213	228	2	2	9.40	9.40	9.40	57.10	0.00	0.70	0.00	0.00	120	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1214	26	2	2	35.10	31.30	33.20	38.80	0.00	5.70	0.00	0.00	121	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1215	259	2	2	31.90	31.90	31.90	69.30	0.00	16.40	0.00	0.00	122	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1216	7	2	2	26.60	26.60	26.60	57.20	0.00	16.50	0.00	0.00	123	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1217	182	2	2	28.00	28.00	28.00	55.90	0.00	5.50	0.00	0.00	124	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1218	231	2	2	37.50	27.60	32.55	56.85	0.00	4.40	0.00	0.00	125	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1219	223	2	2	29.50	12.00	20.75	52.65	0.00	10.30	0.00	0.00	126	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1220	226	2	2	34.30	31.50	32.90	51.15	0.00	5.40	0.00	0.00	127	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1221	230	2	2	29.70	22.10	26.40	63.43	0.00	12.20	0.00	0.00	128	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1222	154	2	2	30.50	13.00	21.53	46.60	0.00	9.50	0.00	0.00	129	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1223	225	2	2	31.60	27.30	29.45	60.75	0.00	16.20	0.00	0.00	130	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1224	74	2	2	22.20	22.20	22.20	74.00	0.00	2.10	0.00	0.00	131	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1225	116	2	2	27.80	27.80	27.80	48.20	0.00	2.80	0.00	0.00	132	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1226	169	2	2	19.10	19.10	19.10	48.00	0.00	11.80	0.00	0.00	133	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1227	132	2	2	13.20	13.20	13.20	73.00	0.00	4.70	0.00	0.00	134	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1228	45	2	2	25.10	25.10	25.10	62.50	0.00	4.80	0.00	0.00	135	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1229	191	2	2	27.40	20.00	23.70	34.40	0.00	4.00	0.00	0.00	136	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1230	217	2	2	28.80	28.80	28.80	14.70	0.00	3.00	0.00	0.00	137	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1231	185	2	2	25.20	25.20	25.20	52.30	0.00	11.20	0.00	0.00	138	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1232	164	2	2	35.50	12.90	24.87	47.87	0.00	7.40	0.00	0.00	139	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1233	50	2	2	33.20	33.20	33.20	66.20	0.00	32.20	0.00	0.00	140	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1234	205	2	2	26.40	13.70	20.05	51.45	0.00	17.80	0.00	0.00	141	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1235	276	2	2	22.60	22.60	22.60	43.90	0.00	4.20	0.00	0.00	142	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1236	148	2	2	23.90	19.40	21.65	33.65	0.00	7.70	0.00	0.00	143	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1237	313	2	2	34.00	34.00	34.00	42.20	0.00	35.90	0.00	0.00	144	64.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1238	253	2	2	29.00	13.20	21.10	37.65	0.00	7.10	0.00	0.00	145	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1239	269	2	2	19.00	19.00	19.00	54.30	0.00	17.30	0.00	0.00	146	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1240	321	2	2	23.20	15.30	19.25	37.15	0.00	6.40	0.00	0.00	147	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1241	188	2	2	22.10	22.10	22.10	39.90	0.00	6.20	0.00	0.00	148	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1242	260	2	2	28.30	24.60	26.98	53.85	0.00	8.60	0.00	0.00	149	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1243	280	2	2	23.10	23.10	23.10	47.30	0.00	7.80	0.00	0.00	150	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1244	220	2	2	34.80	22.20	29.80	40.40	0.00	2.70	0.00	0.00	151	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1245	273	2	2	31.40	31.40	31.40	81.50	0.00	8.50	0.00	0.00	152	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1246	187	2	2	28.30	23.40	25.85	56.25	0.00	10.30	0.00	0.00	153	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1247	17	2	2	27.90	11.70	19.80	35.95	0.00	9.80	0.00	0.00	154	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1248	296	2	2	28.20	28.20	28.20	23.70	0.00	30.80	0.00	0.00	155	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1249	30	2	2	30.80	30.80	30.80	55.00	0.00	5.10	0.00	0.00	156	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1250	47	2	2	33.60	29.80	31.70	58.85	0.00	14.30	0.00	0.00	157	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1251	177	2	2	32.90	23.20	28.05	32.05	0.00	12.40	0.00	0.00	158	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1252	196	2	2	9.80	9.80	9.80	35.50	0.00	29.00	0.00	0.00	159	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1253	162	2	2	24.30	24.30	24.30	72.40	0.00	3.70	0.00	0.00	160	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1254	294	2	2	27.70	22.00	24.85	40.75	0.00	7.80	0.00	0.00	161	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1255	105	2	2	27.70	27.70	27.70	61.50	0.00	8.40	0.00	0.00	162	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1256	111	2	2	35.20	24.10	29.50	50.20	0.00	12.30	0.00	0.00	163	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1257	316	2	2	31.00	28.60	29.80	53.35	0.00	5.00	0.00	0.00	164	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1258	250	2	2	35.60	14.30	24.95	51.10	0.00	17.50	0.00	0.00	165	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1259	286	2	2	32.80	28.90	30.85	55.85	0.00	9.80	0.00	0.00	166	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1260	236	2	2	28.20	22.50	25.35	54.60	0.00	62.10	0.00	0.00	167	60.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1261	140	2	2	28.00	28.00	28.00	77.40	0.00	19.60	0.00	0.00	168	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1262	224	2	2	9.60	9.60	9.60	32.00	0.00	20.70	0.00	0.00	169	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1263	248	2	2	29.10	5.80	17.45	44.00	0.00	15.50	0.00	0.00	170	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1264	146	2	2	17.20	17.20	17.20	26.10	0.00	1.20	0.00	0.00	171	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1265	117	2	2	26.00	15.70	20.85	34.00	0.00	2.80	0.00	0.00	172	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1266	207	2	2	30.90	29.50	30.20	38.40	0.00	7.70	0.00	0.00	173	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1267	233	2	2	27.80	8.00	17.90	41.85	0.00	10.40	0.00	0.00	174	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1268	72	2	2	16.40	16.40	16.40	37.20	0.00	48.90	0.00	0.00	175	60.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1269	186	2	2	27.40	24.40	25.90	55.25	0.00	51.00	0.00	0.00	176	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1270	179	2	2	26.90	26.80	26.85	59.90	0.00	5.20	0.00	0.00	177	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1271	320	2	2	24.30	9.80	17.05	51.75	0.00	42.20	0.00	0.00	178	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1272	264	2	2	25.80	13.00	19.40	33.35	0.00	13.80	0.00	0.00	179	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1273	97	2	2	27.50	27.50	27.50	45.40	0.00	31.90	0.00	0.00	180	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1274	173	2	2	32.70	32.70	32.70	30.30	0.00	6.90	0.00	0.00	181	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1275	203	2	2	35.30	35.30	35.30	67.80	0.00	5.50	0.00	0.00	182	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1276	9	2	2	24.70	24.70	24.70	66.60	0.00	10.90	0.00	0.00	183	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1277	221	2	2	24.20	24.20	24.20	72.70	0.00	14.30	0.00	0.00	184	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1278	324	2	2	26.20	23.70	24.95	57.35	0.00	16.20	0.00	0.00	185	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1279	144	2	2	13.00	13.00	13.00	48.40	0.00	3.00	0.00	0.00	186	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1280	95	2	2	32.40	28.20	30.30	51.60	0.00	25.80	0.00	0.00	187	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1281	158	2	2	31.30	27.40	29.77	53.17	0.00	18.20	0.00	0.00	188	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1282	15	2	2	30.00	13.50	21.75	44.65	0.00	17.20	0.00	0.00	189	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1283	198	2	2	23.40	20.60	22.00	45.15	0.00	44.70	0.00	0.00	190	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1284	94	2	2	26.80	26.80	26.80	39.10	0.00	0.40	0.00	0.00	191	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1285	237	2	2	24.90	24.90	24.90	59.40	0.00	22.30	0.00	0.00	192	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1286	77	2	2	12.80	12.80	12.80	46.70	0.00	2.70	0.00	0.00	193	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1287	247	2	2	25.00	25.00	25.00	56.50	0.00	1.50	0.00	0.00	194	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1288	23	2	2	20.80	20.80	20.80	94.10	0.00	4.30	0.00	0.00	195	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1289	107	2	2	28.80	11.30	20.07	46.00	0.00	31.10	0.00	0.00	196	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1290	141	2	2	22.20	22.20	22.20	61.10	0.00	0.80	0.00	0.00	197	35.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1291	199	2	2	26.50	22.10	24.30	56.65	0.00	13.50	0.00	0.00	198	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1292	288	2	2	20.20	20.20	20.20	77.20	0.00	1.00	0.00	0.00	199	35.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1293	106	2	2	30.70	30.70	30.70	23.60	0.00	1.80	0.00	0.00	200	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1294	99	2	2	30.60	25.00	27.80	42.10	0.00	18.10	0.00	0.00	201	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1295	93	2	2	28.60	27.90	28.25	40.25	0.00	4.70	0.00	0.00	202	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1296	209	2	2	24.40	24.40	24.40	53.10	0.00	3.70	0.00	0.00	203	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1297	133	2	2	27.70	27.70	27.70	53.80	0.00	29.90	0.00	0.00	204	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1298	114	2	2	30.30	5.70	21.13	60.33	0.00	17.10	0.00	0.00	205	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1299	82	2	2	23.50	23.50	23.50	39.10	0.00	0.30	0.00	0.00	206	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1300	113	2	2	29.70	6.40	20.07	57.13	0.00	9.80	0.00	0.00	207	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1301	27	2	2	35.00	27.60	31.57	47.77	0.00	14.10	0.00	0.00	208	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1302	181	2	2	25.50	25.50	25.50	57.60	0.00	3.50	0.00	0.00	209	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1303	60	2	2	25.80	25.80	25.80	40.90	0.00	11.00	0.00	0.00	210	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1304	10	2	2	11.50	11.50	11.50	49.20	0.00	2.00	0.00	0.00	211	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1305	214	2	2	25.60	25.60	25.60	42.90	0.00	2.30	0.00	0.00	212	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1306	222	2	2	24.90	24.90	24.90	45.30	0.00	5.10	0.00	0.00	213	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1307	36	2	2	31.50	31.50	31.50	64.40	0.00	12.30	0.00	0.00	214	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1308	129	2	2	21.80	21.80	21.80	45.60	0.00	5.20	0.00	0.00	215	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1309	292	2	2	29.80	12.10	23.43	61.17	0.00	15.90	0.00	0.00	216	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1310	58	2	2	8.90	8.90	8.90	66.40	0.00	13.00	0.00	0.00	217	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1311	16	2	2	25.30	22.80	24.05	51.10	0.00	21.10	0.00	0.00	218	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1312	184	2	2	27.10	27.10	27.10	22.20	0.00	19.10	0.00	0.00	219	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1313	289	4	2	27.40	27.40	27.40	72.00	0.00	8.70	0.00	0.00	1	8.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1314	110	4	2	31.70	26.30	29.60	45.53	0.00	8.20	0.00	0.00	2	18.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1315	163	4	2	25.20	25.20	25.20	61.90	0.00	1.60	0.00	0.00	3	6.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1316	33	4	2	14.90	6.70	10.80	51.75	0.00	29.10	0.00	0.00	4	20.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1317	218	4	2	26.10	10.80	18.45	49.55	0.00	33.20	0.00	0.00	5	26.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1318	127	4	2	25.50	20.80	23.15	49.75	0.00	5.80	0.00	0.00	6	16.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1319	65	4	2	34.00	34.00	34.00	66.70	0.00	14.60	0.00	0.00	7	29.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1320	22	4	2	8.00	8.00	8.00	70.10	0.00	15.70	0.00	0.00	8	20.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1321	174	4	2	27.20	17.80	22.50	58.30	0.00	6.00	0.00	0.00	9	21.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1322	277	4	2	38.10	27.20	32.65	46.00	0.00	8.50	0.00	0.00	10	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1323	102	4	2	34.70	34.70	34.70	58.80	0.00	9.40	0.00	0.00	11	35.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1324	38	4	2	20.60	20.60	20.60	69.00	0.00	2.40	0.00	0.00	12	22.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1325	157	4	2	23.70	22.40	23.05	45.50	0.00	8.50	0.00	0.00	13	29.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1326	35	4	2	19.00	19.00	19.00	73.20	0.00	3.20	0.00	0.00	14	26.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1327	18	4	2	27.20	27.20	27.20	40.50	0.00	3.00	0.00	0.00	15	34.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1328	266	4	2	23.20	23.20	23.20	59.20	0.00	7.80	0.00	0.00	16	31.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1329	240	4	2	26.80	26.80	26.80	62.80	0.00	34.70	0.00	0.00	17	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1330	91	4	2	32.30	25.40	28.85	52.10	0.00	29.80	0.00	0.00	18	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1331	165	4	2	36.70	12.90	19.55	45.23	0.00	29.80	0.00	0.00	19	63.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1332	62	4	2	26.00	8.40	17.20	57.75	0.00	29.80	0.00	0.00	20	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1333	125	4	2	24.90	24.90	24.90	41.50	0.00	3.40	0.00	0.00	21	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1334	243	4	2	25.90	25.90	25.90	37.50	0.00	18.00	0.00	0.00	22	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1335	63	4	2	24.50	24.50	24.50	37.20	0.00	10.60	0.00	0.00	23	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1336	202	4	2	20.60	20.60	20.60	39.40	0.00	3.00	0.00	0.00	24	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1337	76	4	2	26.20	26.20	26.20	82.10	0.00	5.60	0.00	0.00	25	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1338	134	4	2	36.40	12.50	24.90	41.83	0.00	10.30	0.00	0.00	26	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1339	155	4	2	35.40	35.40	35.40	60.30	0.00	27.70	0.00	0.00	27	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1340	325	4	2	32.30	24.70	28.50	53.25	0.00	4.70	0.00	0.00	28	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1341	241	4	2	26.40	10.10	18.25	53.05	0.00	24.00	0.00	0.00	29	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1342	167	4	2	27.40	27.40	27.40	60.10	0.00	2.80	0.00	0.00	30	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1343	193	4	2	7.00	7.00	7.00	76.70	0.00	4.70	0.00	0.00	31	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1344	139	4	2	29.40	10.80	20.10	55.55	0.00	5.70	0.00	0.00	32	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1345	310	4	2	4.80	4.80	4.80	26.60	0.00	5.70	0.00	0.00	33	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1346	312	4	2	27.50	27.50	27.50	81.00	0.00	15.80	0.00	0.00	34	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1347	145	4	2	27.80	19.80	24.67	46.53	0.00	8.50	0.00	0.00	35	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1348	216	4	2	27.60	27.60	27.60	69.30	0.00	1.80	0.00	0.00	36	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1349	122	4	2	12.60	7.40	10.00	37.10	0.00	4.20	0.00	0.00	37	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1350	135	4	2	32.00	32.00	32.00	56.90	0.00	13.50	0.00	0.00	38	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1351	252	4	2	17.70	17.70	17.70	37.90	0.00	1.80	0.00	0.00	39	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1352	24	4	2	24.90	24.90	24.90	58.30	0.00	7.20	0.00	0.00	40	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1353	103	4	2	19.00	9.70	14.35	55.80	0.00	1.40	0.00	0.00	41	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1354	86	4	2	34.20	33.10	33.65	53.90	0.00	5.10	0.00	0.00	42	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1355	192	4	2	36.30	27.20	31.75	60.55	0.00	10.40	0.00	0.00	43	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1356	171	4	2	27.10	9.30	18.20	65.70	0.00	12.70	0.00	0.00	44	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1357	149	4	2	35.60	35.60	35.60	51.60	0.00	4.40	0.00	0.00	45	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1358	249	4	2	30.90	22.50	26.70	50.50	0.00	16.40	0.00	0.00	46	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1359	262	4	2	25.90	9.90	17.90	61.55	0.00	8.00	0.00	0.00	47	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1360	299	4	2	29.60	23.90	26.75	59.65	0.00	11.90	0.00	0.00	48	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1361	57	4	2	12.10	12.10	12.10	42.20	0.00	11.20	0.00	0.00	49	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1362	37	4	2	32.10	32.10	32.10	47.00	0.00	0.60	0.00	0.00	50	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1363	137	4	2	11.40	11.40	11.40	12.70	0.00	10.00	0.00	0.00	51	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1364	151	4	2	21.70	20.00	20.85	60.45	0.00	28.70	0.00	0.00	52	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1365	257	4	2	32.80	31.30	32.05	56.00	0.00	29.60	0.00	0.00	53	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1366	46	4	2	31.60	31.60	31.60	35.40	0.00	0.50	0.00	0.00	54	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1367	281	4	2	27.40	27.40	27.40	50.20	0.00	18.20	0.00	0.00	55	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1368	79	4	2	29.90	29.90	29.90	60.00	0.00	49.30	0.00	0.00	56	61.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1369	303	4	2	21.80	21.80	21.80	74.20	0.00	6.20	0.00	0.00	57	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1370	43	4	2	14.90	10.80	12.85	33.10	0.00	21.90	0.00	0.00	58	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1371	69	4	2	30.40	30.40	30.40	20.90	0.00	9.50	0.00	0.00	59	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1372	121	4	2	38.10	38.10	38.10	29.80	0.00	3.70	0.00	0.00	60	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1373	254	4	2	31.90	31.90	31.90	35.90	0.00	17.90	0.00	0.00	61	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1374	54	4	2	37.30	12.80	25.05	49.15	0.00	14.00	0.00	0.00	62	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1375	119	4	2	14.40	14.30	14.35	48.40	0.00	14.10	0.00	0.00	63	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1376	101	4	2	28.00	23.20	25.60	59.25	0.00	17.90	0.00	0.00	64	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1377	322	4	2	9.20	9.20	9.20	40.00	0.00	26.30	0.00	0.00	65	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1378	56	4	2	32.90	31.10	32.00	56.75	0.00	20.70	0.00	0.00	66	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1379	90	4	2	20.50	20.50	20.50	37.20	0.00	22.60	0.00	0.00	67	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1380	194	4	2	29.40	24.30	26.85	60.75	0.00	5.00	0.00	0.00	68	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1381	52	4	2	13.20	13.20	13.20	35.80	0.00	12.60	0.00	0.00	69	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1382	308	4	2	26.20	26.20	26.20	34.40	0.00	20.70	0.00	0.00	70	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1383	245	4	2	30.90	30.90	30.90	49.90	0.00	29.90	0.00	0.00	71	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1384	309	4	2	31.30	12.40	21.85	47.90	0.00	45.40	0.00	0.00	72	63.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1385	3	4	2	35.50	35.50	35.50	49.10	0.00	4.60	0.00	0.00	73	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1386	300	4	2	37.80	28.40	33.10	60.05	0.00	19.70	0.00	0.00	74	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1387	208	4	2	23.90	11.60	17.75	34.60	0.00	7.40	0.00	0.00	75	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1388	87	4	2	33.40	15.70	25.70	53.50	0.00	47.40	0.00	0.00	76	66.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1389	8	4	2	7.70	7.70	7.70	64.70	0.00	11.30	0.00	0.00	77	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1390	239	4	2	30.10	21.20	25.67	55.47	0.00	19.30	0.00	0.00	78	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1391	290	4	2	29.50	29.50	29.50	39.80	0.00	6.60	0.00	0.00	79	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1392	75	4	2	27.10	17.80	24.33	57.50	0.00	11.30	0.00	0.00	80	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1393	131	4	2	35.30	12.60	27.03	55.03	0.00	23.30	0.00	0.00	81	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1394	71	4	2	25.10	25.10	25.10	53.80	0.00	5.70	0.00	0.00	82	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1395	19	4	2	31.60	24.20	27.90	54.75	0.00	2.50	0.00	0.00	83	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1396	2	4	2	30.30	30.30	30.30	78.30	0.00	12.40	0.00	0.00	84	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1397	263	4	2	18.40	18.40	18.40	61.30	0.00	7.90	0.00	0.00	85	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1398	287	4	2	24.00	9.90	16.68	48.88	0.00	11.70	0.00	0.00	86	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1399	190	4	2	32.00	11.90	21.95	47.25	0.00	33.20	0.00	0.00	87	60.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1400	227	4	2	25.70	25.70	25.70	71.20	0.00	6.40	0.00	0.00	88	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1401	104	4	2	26.00	22.50	24.25	50.20	0.00	3.70	0.00	0.00	89	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1402	34	4	2	31.40	31.40	31.40	47.40	0.00	10.30	0.00	0.00	90	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1403	108	4	2	32.00	20.50	26.25	32.30	0.00	6.40	0.00	0.00	91	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1404	314	4	2	32.40	32.40	32.40	41.50	0.00	1.40	0.00	0.00	92	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1405	251	4	2	26.10	7.60	16.85	46.10	0.00	8.80	0.00	0.00	93	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1406	64	4	2	34.60	34.60	34.60	52.80	0.00	0.30	0.00	0.00	94	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1407	39	4	2	25.60	15.40	21.13	42.30	0.00	35.30	0.00	0.00	95	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1408	271	4	2	30.50	28.30	29.40	43.95	0.00	7.10	0.00	0.00	96	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1409	291	4	2	21.80	21.80	21.80	64.20	0.00	14.00	0.00	0.00	97	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1410	195	4	2	25.90	25.90	25.90	74.40	0.00	9.20	0.00	0.00	98	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1411	59	4	2	26.40	24.80	25.60	54.60	0.00	4.60	0.00	0.00	99	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1412	83	4	2	27.10	11.30	18.73	40.67	0.00	18.20	0.00	0.00	100	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1413	295	4	2	26.10	26.10	26.10	65.20	0.00	4.60	0.00	0.00	101	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1414	242	4	2	37.10	8.40	22.75	45.60	0.00	6.30	0.00	0.00	102	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1415	81	4	2	36.60	36.60	36.60	32.00	0.00	15.20	0.00	0.00	103	61.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1416	213	4	2	26.70	9.30	15.83	48.50	0.00	9.50	0.00	0.00	104	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1417	96	4	2	13.30	13.30	13.30	28.10	0.00	1.10	0.00	0.00	105	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1418	160	4	2	7.00	7.00	7.00	43.10	0.00	15.20	0.00	0.00	106	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1419	305	4	2	35.10	14.60	24.40	48.48	0.00	18.10	0.00	0.00	107	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1420	25	4	2	15.50	15.50	15.50	32.80	0.00	1.80	0.00	0.00	108	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1421	112	4	2	27.10	11.70	21.83	55.63	0.00	25.60	0.00	0.00	109	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1422	172	4	2	34.60	21.40	28.00	67.30	0.00	2.70	0.00	0.00	110	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1423	61	4	2	26.70	26.70	26.70	74.00	0.00	7.90	0.00	0.00	111	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1424	6	4	2	11.40	11.40	11.40	20.70	0.00	9.30	0.00	0.00	112	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1425	235	4	2	22.00	17.20	19.60	47.15	0.00	30.40	0.00	0.00	113	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1426	302	4	2	11.00	8.80	9.90	29.70	0.00	43.80	0.00	0.00	114	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1427	32	4	2	15.80	15.80	15.80	66.80	0.00	15.50	0.00	0.00	115	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1428	66	4	2	19.60	19.60	19.60	40.80	0.00	1.30	0.00	0.00	116	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1429	206	4	2	30.30	25.10	27.70	31.65	0.00	19.70	0.00	0.00	117	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1430	283	4	2	37.30	27.90	32.60	61.40	0.00	8.00	0.00	0.00	118	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1431	270	4	2	24.40	24.40	24.40	56.70	0.00	4.90	0.00	0.00	119	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1432	244	4	2	24.30	24.30	24.30	59.50	0.00	1.40	0.00	0.00	120	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1433	14	4	2	35.60	23.10	28.07	43.60	0.00	24.70	0.00	0.00	121	61.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1434	272	4	2	33.30	6.80	20.05	49.75	0.00	19.70	0.00	0.00	122	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1435	282	4	2	30.80	6.80	20.90	56.85	0.00	25.90	0.00	0.00	123	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1436	100	4	2	27.80	21.80	24.93	41.20	0.00	14.40	0.00	0.00	124	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1437	176	4	2	11.00	11.00	11.00	51.50	0.00	7.00	0.00	0.00	125	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1438	161	4	2	26.60	22.30	24.45	43.20	0.00	22.40	0.00	0.00	126	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1439	48	4	2	12.00	12.00	12.00	64.90	0.00	5.30	0.00	0.00	127	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1440	170	4	2	26.70	26.70	26.70	43.60	0.00	5.40	0.00	0.00	128	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1441	318	4	2	26.90	20.00	23.45	43.40	0.00	23.10	0.00	0.00	129	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1442	246	4	2	34.40	34.40	34.40	89.10	0.00	0.40	0.00	0.00	130	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1443	228	4	2	31.10	15.10	24.87	54.77	0.00	26.10	0.00	0.00	131	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1444	219	4	2	26.90	24.50	25.70	68.35	0.00	5.60	0.00	0.00	132	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1445	26	4	2	30.00	30.00	30.00	33.50	0.00	11.20	0.00	0.00	133	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1446	259	4	2	25.50	21.50	23.50	58.95	0.00	4.80	0.00	0.00	134	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1447	7	4	2	26.70	12.10	17.50	51.47	0.00	34.90	0.00	0.00	135	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1448	182	4	2	10.60	10.60	10.60	39.10	0.00	0.50	0.00	0.00	136	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1449	226	4	2	28.80	28.80	28.80	35.20	0.00	10.60	0.00	0.00	137	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1450	70	4	2	10.70	10.70	10.70	53.20	0.00	3.60	0.00	0.00	138	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1451	230	4	2	18.70	18.70	18.70	18.60	0.00	6.50	0.00	0.00	139	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1452	154	4	2	20.30	20.30	20.30	69.70	0.00	0.80	0.00	0.00	140	35.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1453	180	4	2	26.70	26.70	26.70	65.40	0.00	5.30	0.00	0.00	141	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1454	225	4	2	25.90	25.90	25.90	55.60	0.00	4.40	0.00	0.00	142	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1455	116	4	2	29.10	13.60	21.35	50.65	0.00	15.30	0.00	0.00	143	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1456	169	4	2	26.90	18.90	22.90	27.65	0.00	11.20	0.00	0.00	144	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1457	217	4	2	24.60	12.30	18.45	55.85	0.00	11.80	0.00	0.00	145	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1458	185	4	2	26.30	26.30	26.30	46.80	0.00	0.10	0.00	0.00	146	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1459	44	4	2	27.70	14.60	21.15	59.20	0.00	22.60	0.00	0.00	147	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1460	164	4	2	23.70	23.70	23.70	26.60	0.00	9.20	0.00	0.00	148	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1461	50	4	2	33.50	33.50	33.50	52.40	0.00	7.40	0.00	0.00	149	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1462	205	4	2	22.80	22.80	22.80	52.30	0.00	0.40	0.00	0.00	150	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1463	183	4	2	26.80	26.80	26.80	56.10	0.00	7.80	0.00	0.00	151	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1464	276	4	2	29.50	13.70	21.60	64.95	0.00	3.50	0.00	0.00	152	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1465	89	4	2	27.90	27.90	27.90	53.90	0.00	7.10	0.00	0.00	153	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1466	85	4	2	11.80	11.80	11.80	58.20	0.00	8.10	0.00	0.00	154	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1467	148	4	2	24.30	24.30	24.30	55.10	0.00	9.30	0.00	0.00	155	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1468	197	4	2	26.40	26.40	26.40	25.40	0.00	28.80	0.00	0.00	156	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1469	156	4	2	27.40	9.60	21.03	42.57	0.00	10.10	0.00	0.00	157	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1470	321	4	2	28.50	28.50	28.50	47.60	0.00	9.30	0.00	0.00	158	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1471	188	4	2	30.70	18.90	24.80	58.00	0.00	32.50	0.00	0.00	159	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1472	260	4	2	23.40	13.10	18.25	48.65	0.00	21.40	0.00	0.00	160	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1473	280	4	2	30.50	26.80	28.65	38.45	0.00	24.80	0.00	0.00	161	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1474	220	4	2	28.10	25.30	26.70	38.25	0.00	11.40	0.00	0.00	162	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1475	273	4	2	32.00	23.50	27.50	44.43	0.00	20.20	0.00	0.00	163	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1476	187	4	2	23.50	23.50	23.50	35.90	0.00	8.40	0.00	0.00	164	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1477	17	4	2	27.80	27.80	27.80	64.00	0.00	6.00	0.00	0.00	165	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1478	30	4	2	31.50	31.50	31.50	53.80	0.00	13.00	0.00	0.00	166	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1479	196	4	2	31.30	11.70	18.77	62.90	0.00	23.40	0.00	0.00	167	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1480	294	4	2	24.80	24.80	24.80	47.00	0.00	7.80	0.00	0.00	168	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1481	105	4	2	34.90	34.90	34.90	46.40	0.00	6.90	0.00	0.00	169	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1482	284	4	2	5.50	5.50	5.50	40.20	0.00	10.10	0.00	0.00	170	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1483	109	4	2	29.40	29.40	29.40	59.40	0.00	2.70	0.00	0.00	171	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1484	88	4	2	33.60	27.20	30.40	33.05	0.00	24.30	0.00	0.00	172	61.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1485	111	4	2	13.90	13.90	13.90	48.60	0.00	0.60	0.00	0.00	173	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1486	316	4	2	31.60	31.60	31.60	67.80	0.00	74.80	0.00	0.00	174	63.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1487	250	4	2	27.00	27.00	27.00	38.50	0.00	18.20	0.00	0.00	175	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1488	140	4	2	25.20	9.60	15.30	61.27	0.00	44.20	0.00	0.00	176	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1489	248	4	2	12.10	12.10	12.10	48.20	0.00	0.70	0.00	0.00	177	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1490	146	4	2	33.70	12.80	23.80	50.00	0.00	15.70	0.00	0.00	178	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1491	117	4	2	35.90	13.10	24.50	60.20	0.00	12.50	0.00	0.00	179	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1492	207	4	2	33.10	24.60	28.85	51.35	0.00	20.70	0.00	0.00	180	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1493	72	4	2	32.20	32.20	32.20	57.60	0.00	4.90	0.00	0.00	181	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1494	97	4	2	31.30	12.20	21.75	58.70	0.00	6.90	0.00	0.00	182	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1495	307	4	2	34.90	25.00	29.95	53.60	0.00	11.50	0.00	0.00	183	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1496	203	4	2	30.00	21.30	25.65	44.80	0.00	14.70	0.00	0.00	184	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1497	201	4	2	33.70	26.60	30.15	51.70	0.00	3.30	0.00	0.00	185	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1498	9	4	2	13.10	13.10	13.10	57.40	0.00	6.50	0.00	0.00	186	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1499	221	4	2	29.20	25.80	27.50	71.30	0.00	18.60	0.00	0.00	187	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1500	279	4	2	6.30	6.30	6.30	55.60	0.00	9.70	0.00	0.00	188	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1501	67	4	2	24.30	24.30	24.30	42.20	0.00	21.10	0.00	0.00	189	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1502	120	4	2	29.50	29.50	29.50	44.60	0.00	3.00	0.00	0.00	190	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1503	29	4	2	24.40	10.40	19.17	45.93	0.00	1.50	0.00	0.00	191	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1504	144	4	2	33.70	23.50	28.60	50.25	0.00	10.60	0.00	0.00	192	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1505	95	4	2	27.90	9.60	18.75	73.65	0.00	58.30	0.00	0.00	193	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1506	158	4	2	32.40	32.40	32.40	75.20	0.00	0.70	0.00	0.00	194	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1507	123	4	2	32.40	23.20	27.80	41.10	0.00	29.00	0.00	0.00	195	60.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1508	15	4	2	31.20	31.20	31.20	24.40	0.00	6.20	0.00	0.00	196	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1509	198	4	2	35.00	35.00	35.00	33.10	0.00	5.50	0.00	0.00	197	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1510	94	4	2	33.90	33.90	33.90	56.90	0.00	5.40	0.00	0.00	198	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1511	237	4	2	15.70	11.20	13.70	51.63	0.00	18.90	0.00	0.00	199	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1512	77	4	2	27.50	26.50	27.00	41.30	0.00	5.50	0.00	0.00	200	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1513	247	4	2	25.30	25.30	25.30	47.30	0.00	5.60	0.00	0.00	201	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1514	107	4	2	34.60	25.40	30.00	45.15	0.00	15.70	0.00	0.00	202	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1515	141	4	2	20.70	20.70	20.70	33.40	0.00	21.90	0.00	0.00	203	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1516	288	4	2	29.30	27.10	28.20	60.30	0.00	20.30	0.00	0.00	204	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1517	106	4	2	23.10	23.10	23.10	46.40	0.00	9.60	0.00	0.00	205	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1518	99	4	2	24.90	24.90	24.90	40.20	0.00	0.70	0.00	0.00	206	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1519	51	4	2	25.40	25.40	25.40	29.50	0.00	5.50	0.00	0.00	207	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1520	293	4	2	30.40	25.70	28.05	49.70	0.00	33.50	0.00	0.00	208	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1521	175	4	2	28.10	27.20	27.65	67.30	0.00	14.90	0.00	0.00	209	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1522	133	4	2	32.10	28.50	30.30	37.95	0.00	14.00	0.00	0.00	210	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1523	114	4	2	19.50	19.50	19.50	48.50	0.00	9.50	0.00	0.00	211	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1524	265	4	2	31.70	31.70	31.70	42.00	0.00	24.40	0.00	0.00	212	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1525	27	4	2	22.00	22.00	22.00	67.90	0.00	4.10	0.00	0.00	213	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1526	214	4	2	27.70	27.70	27.70	42.80	0.00	5.00	0.00	0.00	214	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1527	255	4	2	28.50	28.50	28.50	32.70	0.00	13.80	0.00	0.00	215	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1528	222	4	2	22.90	22.90	22.90	34.90	0.00	0.50	0.00	0.00	216	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1529	36	4	2	28.90	28.90	28.90	38.20	0.00	19.00	0.00	0.00	217	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1530	129	4	2	26.10	26.10	26.10	49.20	0.00	6.20	0.00	0.00	218	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1531	58	4	2	23.20	21.90	22.55	58.40	0.00	10.10	0.00	0.00	219	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1532	16	4	2	22.10	8.70	15.40	66.20	0.00	13.20	0.00	0.00	220	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1533	110	15	2	25.60	11.60	18.60	37.00	3.40	6.50	0.00	3.40	0	5.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1534	163	15	2	28.30	28.30	28.30	59.10	1.70	1.70	0.00	5.10	0	0.00	Élevé	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1535	33	15	2	24.50	24.50	24.50	48.20	1.70	11.10	0.00	6.80	0	0.00	Élevé	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1536	218	15	2	28.30	14.30	23.03	46.27	5.10	7.50	0.00	11.90	0	0.00	Élevé	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1537	256	15	2	12.10	12.10	12.10	17.30	1.70	4.00	0.00	13.60	0	0.00	Élevé	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1538	127	15	2	22.70	22.70	22.70	57.80	1.70	2.10	0.00	15.30	0	0.00	Modéré	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1539	65	15	2	20.20	20.20	20.20	50.00	1.70	1.40	0.00	17.00	0	0.00	Modéré	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1540	174	15	2	34.60	9.70	23.87	37.90	5.10	30.30	0.00	22.10	0	7.00	Modéré	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1541	267	15	2	29.70	12.00	23.83	55.98	6.80	10.50	0.00	28.90	0	0.00	Modéré	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1542	124	15	2	23.90	22.50	23.20	65.75	3.40	4.90	0.00	32.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1543	277	15	2	26.40	9.50	17.95	50.20	3.40	6.40	0.00	35.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1544	102	15	2	37.40	37.40	37.40	44.80	1.70	14.30	0.00	37.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1545	38	15	2	28.50	28.50	28.50	45.90	1.70	33.00	0.00	39.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1546	18	15	2	17.10	17.10	17.10	46.50	1.70	3.40	0.00	40.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1547	118	15	2	30.00	30.00	30.00	77.20	1.70	21.10	0.00	42.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1548	266	15	2	31.30	25.20	28.25	40.30	3.40	5.60	0.00	45.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1549	240	15	2	34.30	26.30	30.30	48.85	3.40	18.30	0.00	49.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1550	168	15	2	33.10	33.10	33.10	42.70	1.70	7.10	0.00	51.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1551	165	15	2	17.50	17.50	17.50	50.20	1.70	4.00	0.00	52.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1552	62	15	2	29.20	13.50	19.37	68.23	5.10	9.00	0.00	57.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1553	285	15	2	22.90	22.90	22.90	79.50	1.70	3.90	0.00	56.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1554	125	15	2	27.10	11.10	19.10	50.05	3.40	1.70	0.00	59.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1555	243	15	2	26.20	26.20	26.20	51.10	1.70	13.40	0.00	59.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1556	202	15	2	22.50	22.50	22.50	74.50	1.70	9.30	0.00	52.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1557	200	15	2	30.30	5.20	20.40	49.57	5.10	17.80	0.00	56.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1558	275	15	2	14.60	8.50	11.55	56.45	3.40	10.40	0.00	57.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1559	155	15	2	15.40	15.40	15.40	45.20	1.70	8.00	0.00	47.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1560	268	15	2	31.10	26.40	28.75	60.25	3.40	5.50	0.00	47.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1561	136	15	2	10.70	10.70	10.70	57.60	1.70	1.80	0.00	44.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1562	11	15	2	9.20	9.20	9.20	47.30	1.70	9.60	0.00	44.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1563	1	15	2	32.40	24.70	28.55	63.53	6.80	24.60	0.00	51.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1564	325	15	2	32.40	32.40	32.40	20.60	1.70	8.00	0.00	52.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1565	241	15	2	33.40	15.50	28.13	60.28	6.80	19.10	0.00	59.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1566	167	15	2	30.40	18.80	24.60	41.05	3.40	1.00	0.00	61.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1567	166	15	2	27.90	27.90	27.90	50.50	1.70	3.10	0.00	61.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1568	193	15	2	32.10	32.10	32.10	41.00	1.70	24.30	0.00	59.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1569	139	15	2	31.00	31.00	31.00	62.20	1.70	5.90	0.00	57.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1570	310	15	2	32.90	28.10	30.50	48.50	3.40	38.30	0.00	57.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1571	312	15	2	35.40	35.40	35.40	48.00	1.70	0.50	0.00	54.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1572	31	15	2	34.90	24.30	30.17	58.63	5.10	21.60	0.00	59.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1573	145	15	2	10.50	10.50	10.50	39.90	1.70	45.40	0.00	61.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1574	301	15	2	27.20	14.30	20.75	42.80	3.40	16.20	0.00	62.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1575	142	15	2	36.40	22.10	29.25	64.40	3.40	49.10	0.00	62.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1576	122	15	2	28.60	28.60	28.60	57.90	1.70	0.30	0.00	62.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1577	135	15	2	31.10	31.10	31.10	65.80	1.70	4.40	0.00	64.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1578	252	15	2	20.90	20.90	20.90	60.00	1.70	9.80	0.00	64.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1579	24	15	2	25.10	25.10	25.10	31.80	1.70	15.30	0.00	61.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1580	103	15	2	15.20	15.20	15.20	63.60	1.70	18.80	0.00	59.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1581	86	15	2	29.40	21.90	26.17	33.73	5.10	16.40	0.00	62.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1582	258	15	2	36.10	36.10	36.10	29.20	1.70	1.20	0.00	61.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1583	149	15	2	25.90	24.40	25.15	63.40	3.40	6.60	0.00	61.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1584	249	15	2	23.30	23.30	23.30	69.80	1.70	5.40	0.00	56.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1585	262	15	2	9.90	9.90	9.90	27.10	1.70	1.00	0.00	56.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1586	57	15	2	26.00	13.50	19.75	57.65	3.40	4.50	0.00	49.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1587	37	15	2	29.00	29.00	29.00	70.30	1.70	17.70	0.00	49.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1588	138	15	2	30.50	13.40	21.95	31.20	3.40	4.30	0.00	51.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1589	137	15	2	32.20	10.70	23.53	51.80	5.10	31.40	0.00	54.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1590	46	15	2	26.30	22.90	24.60	39.50	3.40	18.70	0.00	52.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1591	281	15	2	31.40	28.10	29.75	41.50	3.40	12.00	0.00	51.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1592	92	15	2	9.10	9.10	9.10	33.20	1.70	3.80	0.00	44.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1593	234	15	2	31.40	14.00	22.90	51.33	5.10	20.70	0.00	49.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1594	303	15	2	25.80	25.80	25.80	41.00	1.70	37.50	0.00	47.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1595	319	15	2	27.20	19.20	23.20	61.20	3.40	6.00	0.00	49.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1596	43	15	2	17.40	17.40	17.40	50.30	1.70	29.00	0.00	49.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1597	306	15	2	26.80	26.80	26.80	7.80	1.70	12.20	0.00	49.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1598	232	15	2	26.70	26.70	26.70	74.30	1.70	17.30	0.00	45.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1599	119	15	2	23.90	4.00	12.97	53.80	5.10	12.60	0.00	45.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1600	101	15	2	25.50	10.70	19.13	41.80	5.10	18.70	0.00	49.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1601	56	15	2	26.30	26.30	26.30	23.30	1.70	7.80	0.00	49.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1602	297	15	2	9.30	9.30	9.30	64.90	1.70	2.80	0.00	47.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1603	90	15	2	35.30	35.30	35.30	20.60	1.70	1.60	0.00	47.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1604	52	15	2	12.00	10.70	11.35	63.30	3.40	12.50	0.00	42.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1605	308	15	2	26.50	15.00	20.75	49.95	3.40	3.60	0.00	45.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1606	245	15	2	36.00	36.00	36.00	42.40	1.70	22.00	0.00	47.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1607	126	15	2	22.50	22.50	22.50	44.10	1.70	7.00	0.00	45.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1608	73	15	2	18.70	17.40	18.05	48.90	3.40	10.70	0.00	45.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1609	204	15	2	19.50	19.50	19.50	40.40	1.70	6.20	0.00	45.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1610	53	15	2	27.70	27.70	27.70	35.70	1.70	2.80	0.00	42.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1611	3	15	2	35.00	21.20	26.23	56.50	5.10	12.50	0.00	47.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1612	300	15	2	32.00	19.00	25.50	53.40	3.40	3.70	0.00	49.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1613	208	15	2	28.80	28.70	28.75	58.15	3.40	6.60	0.00	49.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1614	87	15	2	23.70	23.70	23.70	68.40	1.70	2.80	0.00	49.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1615	28	15	2	37.40	23.50	29.77	63.40	5.10	15.60	0.00	54.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1616	212	15	2	34.40	27.80	31.10	53.05	3.40	24.80	0.00	56.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1617	8	15	2	25.60	25.60	25.60	69.00	1.70	5.40	0.00	57.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1618	239	15	2	22.20	22.20	22.20	57.60	1.70	23.60	0.00	57.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1619	290	15	2	34.40	34.40	34.40	52.90	1.70	2.30	0.00	59.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1620	75	15	2	11.20	11.20	11.20	31.20	1.70	3.80	0.00	61.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1621	131	15	2	25.00	25.00	25.00	57.20	1.70	10.20	0.00	57.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1622	71	15	2	21.20	21.20	21.20	62.10	1.70	22.40	0.00	54.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1623	19	15	2	10.10	10.10	10.10	45.20	1.70	19.60	0.00	56.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1624	2	15	2	31.10	31.10	31.10	60.30	1.70	5.10	0.00	56.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1625	287	15	2	7.30	7.30	7.30	26.60	1.70	19.00	0.00	54.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1626	190	15	2	32.00	24.50	28.25	57.80	3.40	18.60	0.00	57.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1627	104	15	2	14.60	14.00	14.30	45.85	3.40	26.60	0.00	57.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1628	34	15	2	21.70	13.50	17.60	53.15	3.40	11.40	0.00	57.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1629	108	15	2	33.50	6.30	20.90	46.83	5.10	14.50	0.00	61.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1630	251	15	2	9.60	9.60	9.60	66.10	1.70	7.80	0.00	57.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1631	64	15	2	23.70	9.20	16.45	65.20	3.40	16.60	0.00	61.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1632	229	15	2	30.30	30.30	30.30	36.90	1.70	0.40	0.00	59.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1633	39	15	2	21.80	21.80	21.80	52.10	1.70	17.20	0.00	56.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1634	291	15	2	39.00	39.00	39.00	47.90	1.70	4.00	0.00	51.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1635	195	15	2	30.70	30.70	30.70	81.50	1.70	2.60	0.00	51.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1636	83	15	2	26.10	15.30	20.70	51.25	3.40	24.10	0.00	45.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1637	242	15	2	31.20	16.70	23.95	40.10	3.40	30.10	0.00	47.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1638	213	15	2	15.00	15.00	15.00	56.70	1.70	8.70	0.00	45.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1639	115	15	2	27.60	22.10	24.85	59.60	3.40	25.10	0.00	40.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1640	305	15	2	13.70	13.60	13.65	67.80	3.40	22.10	0.00	44.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1641	25	15	2	7.60	7.60	7.60	67.10	1.70	1.10	0.00	44.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1642	5	15	2	15.40	12.30	13.85	52.75	3.40	5.30	0.00	44.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1643	112	15	2	32.30	15.30	22.57	29.70	5.10	19.10	0.00	49.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1644	278	15	2	21.20	21.20	21.20	29.30	1.70	44.40	0.00	44.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1645	172	15	2	19.80	19.80	19.80	61.20	1.70	9.20	0.00	40.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1646	61	15	2	23.50	19.90	22.23	57.10	5.10	5.90	0.00	45.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1647	311	15	2	24.30	20.30	22.30	65.50	3.40	6.20	0.00	44.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1648	238	15	2	28.40	28.40	28.40	60.10	1.70	7.10	0.00	45.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1649	6	15	2	14.70	14.70	14.70	57.90	1.70	14.10	0.00	45.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1650	4	15	2	25.10	25.10	25.10	23.40	1.70	1.10	0.00	44.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1651	32	15	2	27.30	27.30	27.30	60.40	1.70	6.30	0.00	44.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1652	66	15	2	33.40	33.40	33.40	28.50	1.70	6.10	0.00	45.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1653	244	15	2	31.30	31.30	31.30	4.50	1.70	5.30	0.00	40.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1654	147	15	2	32.20	32.20	32.20	46.80	1.70	5.00	0.00	40.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1655	272	15	2	27.70	10.90	19.30	47.00	3.40	9.80	0.00	44.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1656	100	15	2	25.30	25.30	25.30	88.40	1.70	4.70	0.00	42.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1657	176	15	2	27.40	27.40	27.40	33.00	1.70	1.10	0.00	40.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1658	68	15	2	27.60	9.30	18.45	50.70	3.40	4.60	0.00	42.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1659	161	15	2	27.40	27.40	27.40	60.10	1.70	5.30	0.00	40.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1660	48	15	2	20.20	13.50	16.85	47.65	3.40	9.30	0.00	39.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1661	261	15	2	9.00	9.00	9.00	24.80	1.70	20.40	0.00	39.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1662	318	15	2	22.30	22.30	22.30	49.30	1.70	8.00	0.00	39.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1663	246	15	2	33.70	33.70	33.70	38.30	1.70	4.00	0.00	35.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1664	219	15	2	20.90	20.90	20.90	33.70	1.70	25.90	0.00	34.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1665	26	15	2	31.30	11.60	21.45	42.35	3.40	13.20	0.00	35.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1666	259	15	2	10.60	10.60	10.60	52.90	1.70	5.70	0.00	35.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1667	7	15	2	16.00	16.00	16.00	40.40	1.70	12.50	0.00	37.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1668	182	15	2	33.20	33.20	33.20	40.10	1.70	10.70	0.00	37.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1669	231	15	2	37.10	7.50	24.52	52.66	8.50	27.60	0.00	44.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1670	223	15	2	25.50	25.50	25.50	65.10	1.70	19.60	0.00	44.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1671	230	15	2	19.60	19.60	19.60	27.00	1.70	18.90	0.00	45.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1672	154	15	2	32.00	10.20	22.43	48.95	6.80	29.30	0.00	51.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1673	180	15	2	21.20	21.20	21.20	52.00	1.70	2.40	0.00	51.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1674	74	15	2	25.10	25.10	25.10	17.30	1.70	22.10	0.00	49.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1675	132	15	2	37.90	20.80	27.70	47.67	5.10	17.70	0.00	51.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1676	45	15	2	28.30	28.30	28.30	29.30	1.70	4.90	0.00	49.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1677	191	15	2	22.10	22.10	22.10	43.00	1.70	10.50	0.00	49.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1678	44	15	2	21.60	21.60	21.60	72.30	1.70	7.50	0.00	44.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1679	143	15	2	31.30	31.30	31.30	60.20	1.70	17.90	0.00	44.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1680	164	15	2	26.40	26.40	26.40	20.90	1.70	3.40	0.00	45.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1681	205	15	2	34.80	34.80	34.80	34.50	1.70	2.60	0.00	42.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1682	183	15	2	28.00	24.60	26.30	44.50	3.40	13.10	0.00	45.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1683	276	15	2	36.80	36.80	36.80	36.50	1.70	53.40	0.00	44.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1684	89	15	2	29.00	29.00	29.00	45.00	1.70	12.60	0.00	44.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1685	148	15	2	13.70	13.70	13.70	64.50	1.70	7.70	0.00	35.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1686	269	15	2	29.10	29.10	29.10	51.20	1.70	14.90	0.00	27.20	0	0.00	Modéré	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1687	260	15	2	35.40	26.80	31.05	37.38	6.80	28.30	0.00	32.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1688	273	15	2	25.40	8.90	17.15	55.55	3.40	8.30	0.00	30.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1689	152	15	2	32.20	10.80	21.50	31.75	3.40	5.60	0.00	32.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1690	17	15	2	28.30	13.30	20.80	45.40	3.40	4.10	0.00	34.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1691	30	15	2	29.30	26.90	28.10	23.35	3.40	32.90	0.00	37.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1692	47	15	2	29.50	8.30	15.78	45.63	6.80	32.50	0.00	42.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1693	162	15	2	23.40	23.40	23.40	18.40	1.70	2.50	0.00	40.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1694	294	15	2	30.20	28.40	29.30	56.00	5.10	23.50	0.00	44.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1695	105	15	2	27.30	27.30	27.30	33.70	1.70	2.40	0.00	42.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1696	284	15	2	21.30	21.30	21.30	56.30	1.70	18.70	0.00	42.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1697	109	15	2	31.30	14.40	22.85	33.05	3.40	2.90	0.00	44.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1698	316	15	2	28.90	25.10	27.00	43.50	3.40	11.80	0.00	45.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1699	286	15	2	27.70	27.70	27.70	34.70	1.70	8.60	0.00	45.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1700	236	15	2	21.80	21.80	21.80	39.80	1.70	9.00	0.00	47.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1701	140	15	2	27.10	27.10	27.10	34.80	1.70	33.90	0.00	49.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1702	274	15	2	32.30	32.30	32.30	51.70	1.70	3.60	0.00	44.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1703	224	15	2	33.80	31.70	32.75	56.80	3.40	21.70	0.00	47.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1704	248	15	2	24.60	21.80	23.20	47.75	3.40	7.90	0.00	51.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1705	146	15	2	28.90	28.90	28.90	80.00	1.70	7.00	0.00	49.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1706	117	15	2	12.40	12.40	12.40	72.80	1.70	0.70	0.00	47.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1707	207	15	2	34.20	12.20	20.60	47.58	6.80	23.90	0.00	54.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1708	72	15	2	29.40	29.40	29.40	45.00	1.70	8.90	0.00	52.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1709	179	15	2	21.70	21.70	21.70	62.20	1.70	12.40	0.00	44.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1710	320	15	2	24.60	15.90	20.90	56.47	5.10	18.80	0.00	49.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1711	264	15	2	26.20	15.00	20.60	44.45	3.40	3.60	0.00	52.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1712	97	15	2	26.40	14.50	20.70	47.40	5.10	26.10	0.00	56.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1713	203	15	2	9.50	9.50	9.50	30.80	1.70	1.20	0.00	51.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1714	201	15	2	35.80	13.70	24.75	36.05	3.40	9.90	0.00	52.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1715	221	15	2	32.70	32.70	32.70	62.20	1.70	0.90	0.00	51.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1716	67	15	2	24.00	12.00	16.50	56.63	5.10	10.80	0.00	56.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1717	120	15	2	11.10	11.10	11.10	30.50	1.70	3.30	0.00	54.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1718	324	15	2	37.40	22.50	29.95	50.30	3.40	15.50	0.00	57.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1719	29	15	2	32.30	15.30	23.80	45.30	3.40	2.60	0.00	59.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1720	158	15	2	32.50	30.00	31.25	57.00	3.40	19.70	0.00	57.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1721	20	15	2	33.30	33.30	33.30	64.50	1.70	2.50	0.00	56.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1722	123	15	2	27.30	27.30	27.30	57.90	1.70	6.40	0.00	54.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1723	78	15	2	26.60	13.00	19.80	48.10	3.40	14.80	0.00	56.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1724	15	15	2	28.00	28.00	28.00	61.55	3.40	29.40	0.00	57.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1725	198	15	2	36.30	28.00	31.33	51.40	5.10	19.20	0.00	56.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1726	237	15	2	26.40	26.40	26.40	57.80	1.70	2.70	0.00	56.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1727	77	15	2	28.20	28.20	28.20	71.40	1.70	13.20	0.00	57.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1728	247	15	2	13.10	13.10	13.10	59.90	1.70	7.30	0.00	57.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1729	107	15	2	33.00	26.10	29.55	44.60	3.40	6.30	0.00	47.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1730	141	15	2	11.20	11.20	11.20	51.10	1.70	8.60	0.00	49.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1731	288	15	2	31.70	31.70	31.70	43.60	1.70	13.20	0.00	49.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1732	128	15	2	29.70	29.70	29.70	37.30	1.70	7.70	0.00	51.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1733	106	15	2	24.60	23.20	23.90	38.80	3.40	13.40	0.00	51.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1734	99	15	2	24.40	24.40	24.40	58.70	1.70	1.90	0.00	52.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1735	93	15	2	26.50	26.50	26.50	80.80	1.70	0.20	0.00	52.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1736	51	15	2	22.00	8.40	15.20	39.25	3.40	11.90	0.00	56.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1737	293	15	2	32.40	23.30	27.85	55.80	3.40	17.00	0.00	54.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1738	12	15	2	34.90	22.20	28.55	55.50	3.40	19.10	0.00	52.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1739	175	15	2	24.10	9.10	18.57	40.33	5.10	23.40	0.00	54.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1740	133	15	2	23.60	18.10	20.85	49.25	3.40	10.60	0.00	57.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1741	114	15	2	13.50	13.50	13.50	35.20	1.70	8.70	0.00	59.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1742	265	15	2	26.00	26.00	26.00	40.80	1.70	1.60	0.00	57.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1743	82	15	2	32.30	20.70	26.50	35.10	3.40	39.10	0.00	59.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1744	113	15	2	33.70	33.70	33.70	49.60	1.70	3.50	0.00	59.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1745	27	15	2	38.30	24.10	31.20	61.90	3.40	12.40	0.00	59.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1746	181	15	2	28.00	9.00	20.60	47.87	5.10	31.50	0.00	61.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1747	10	15	2	28.50	28.50	28.50	55.00	1.70	5.00	0.00	57.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1748	255	15	2	27.90	27.90	27.90	57.30	1.70	0.90	0.00	56.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1749	222	15	2	33.60	33.60	33.60	38.60	1.70	1.50	0.00	56.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1750	178	15	2	29.10	29.10	29.10	66.20	1.70	1.70	0.00	52.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1751	16	15	2	23.00	23.00	23.00	28.70	1.70	5.60	0.00	52.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1752	289	14	2	30.00	30.00	30.00	33.00	0.00	0.20	0.00	0.00	1	14.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1753	110	14	2	33.40	33.40	33.40	38.00	0.00	5.70	0.00	0.00	2	21.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1754	163	14	2	8.60	8.60	8.60	58.90	0.00	1.30	0.00	0.00	3	6.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1755	33	14	2	30.70	30.70	30.70	38.70	0.00	1.50	0.00	0.00	4	19.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1756	256	14	2	32.80	32.80	32.80	30.50	0.00	7.90	0.00	0.00	5	28.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1757	127	14	2	26.70	26.70	26.70	36.30	0.00	24.80	0.00	0.00	6	28.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1758	65	14	2	13.70	13.70	13.70	34.40	0.00	5.50	0.00	0.00	7	20.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1759	22	14	2	30.20	28.30	29.25	36.55	0.00	12.70	0.00	0.00	8	31.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1760	267	14	2	34.20	28.70	31.45	65.15	0.00	25.00	0.00	0.00	9	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1761	124	14	2	34.90	25.80	30.35	54.15	0.00	31.60	0.00	0.00	10	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1762	102	14	2	36.20	31.90	34.43	40.28	0.00	9.30	0.00	0.00	11	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1763	118	14	2	27.00	27.00	27.00	53.10	0.00	14.40	0.00	0.00	12	31.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1764	266	14	2	32.60	22.90	28.67	44.77	0.00	30.00	0.00	0.00	13	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1765	240	14	2	28.30	10.50	17.10	46.60	0.00	12.40	0.00	0.00	14	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1766	165	14	2	31.50	31.50	31.50	70.20	0.00	2.60	0.00	0.00	15	35.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1767	125	14	2	25.70	7.80	16.75	57.25	0.00	20.20	0.00	0.00	16	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1768	202	14	2	32.30	30.40	31.35	44.20	0.00	2.40	0.00	0.00	17	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1769	200	14	2	9.70	9.70	9.70	57.80	0.00	5.40	0.00	0.00	18	34.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1770	76	14	2	26.10	26.10	26.10	42.90	0.00	2.10	0.00	0.00	19	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1771	275	14	2	6.30	6.30	6.30	39.20	0.00	6.80	0.00	0.00	20	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1772	134	14	2	10.90	10.90	10.90	69.10	0.00	6.30	0.00	0.00	21	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1773	155	14	2	31.10	31.10	31.10	51.00	0.00	32.80	0.00	0.00	22	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1774	268	14	2	31.50	25.80	28.73	58.73	0.00	24.20	0.00	0.00	23	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1775	80	14	2	26.20	26.20	26.20	48.90	0.00	2.50	0.00	0.00	24	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1776	11	14	2	15.50	15.50	15.50	36.10	0.00	7.90	0.00	0.00	25	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1777	1	14	2	2.90	2.90	2.90	38.90	0.00	6.90	0.00	0.00	26	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1778	241	14	2	23.90	18.00	21.37	57.37	0.00	10.60	0.00	0.00	27	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1779	167	14	2	24.70	23.90	24.30	35.50	0.00	7.40	0.00	0.00	28	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1780	193	14	2	26.60	26.60	26.60	54.70	0.00	2.00	0.00	0.00	29	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1781	139	14	2	34.40	10.50	20.35	61.45	0.00	41.40	0.00	0.00	30	63.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1782	31	14	2	22.70	22.70	22.70	39.60	0.00	7.30	0.00	0.00	31	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1783	145	14	2	34.30	25.50	29.90	64.50	0.00	24.30	0.00	0.00	32	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1784	301	14	2	23.40	23.40	23.40	94.30	0.00	1.90	0.00	0.00	33	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1785	142	14	2	23.60	23.60	23.60	39.80	0.00	5.70	0.00	0.00	34	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1786	135	14	2	27.20	27.20	27.20	33.00	0.00	23.10	0.00	0.00	35	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1787	24	14	2	22.80	22.80	22.80	58.70	0.00	5.10	0.00	0.00	36	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1788	103	14	2	22.60	22.60	22.60	49.40	0.00	8.90	0.00	0.00	37	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1789	192	14	2	27.90	9.90	18.90	40.30	0.00	14.10	0.00	0.00	38	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1790	258	14	2	14.20	14.20	14.20	63.90	0.00	12.30	0.00	0.00	39	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1791	171	14	2	15.60	15.60	15.60	44.40	0.00	13.60	0.00	0.00	40	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1792	149	14	2	26.40	23.50	24.95	46.10	0.00	21.80	0.00	0.00	41	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1793	37	14	2	34.90	34.90	34.90	58.00	0.00	2.20	0.00	0.00	42	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1794	151	14	2	26.70	26.70	26.70	25.00	0.00	2.00	0.00	0.00	43	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1795	257	14	2	22.70	8.90	15.80	40.25	0.00	22.60	0.00	0.00	44	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1796	46	14	2	33.50	24.10	28.80	57.70	0.00	5.20	0.00	0.00	45	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1797	92	14	2	16.70	16.70	16.70	31.00	0.00	6.60	0.00	0.00	46	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1798	79	14	2	25.80	10.40	18.10	66.70	0.00	4.60	0.00	0.00	47	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1799	303	14	2	23.40	20.60	22.00	61.85	0.00	14.00	0.00	0.00	48	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1800	319	14	2	10.60	10.60	10.60	73.10	0.00	0.70	0.00	0.00	49	35.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1801	43	14	2	26.80	26.80	26.80	40.80	0.00	0.70	0.00	0.00	50	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1802	69	14	2	29.20	10.70	22.87	38.23	0.00	5.60	0.00	0.00	51	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1803	306	14	2	32.60	11.10	23.77	39.97	0.00	34.60	0.00	0.00	52	62.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1804	121	14	2	20.50	20.50	20.50	40.70	0.00	1.60	0.00	0.00	53	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1805	254	14	2	30.20	13.40	21.80	51.55	0.00	11.30	0.00	0.00	54	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1806	232	14	2	30.30	30.30	30.30	30.50	0.00	1.40	0.00	0.00	55	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1807	40	14	2	27.80	27.80	27.80	39.70	0.00	16.90	0.00	0.00	56	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1808	54	14	2	24.30	24.30	24.30	59.80	0.00	2.80	0.00	0.00	57	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1809	101	14	2	27.00	27.00	27.00	49.00	0.00	6.10	0.00	0.00	58	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1810	322	14	2	31.40	16.30	23.85	53.05	0.00	31.20	0.00	0.00	59	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1811	56	14	2	28.20	25.40	26.80	30.75	0.00	24.90	0.00	0.00	60	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1812	90	14	2	16.20	9.00	12.60	43.20	0.00	8.80	0.00	0.00	61	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1813	194	14	2	34.40	27.80	31.13	29.53	0.00	21.70	0.00	0.00	62	62.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1814	150	14	2	24.50	23.50	24.00	62.55	0.00	15.20	0.00	0.00	63	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1815	308	14	2	24.00	23.10	23.55	36.90	0.00	7.40	0.00	0.00	64	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1816	204	14	2	25.00	25.00	25.00	55.70	0.00	34.50	0.00	0.00	65	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1817	53	14	2	32.40	32.40	32.40	60.40	0.00	7.90	0.00	0.00	66	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1818	208	14	2	34.60	34.60	34.60	42.60	0.00	23.30	0.00	0.00	67	60.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1819	87	14	2	30.10	9.40	20.37	48.87	0.00	27.00	0.00	0.00	68	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1820	212	14	2	29.10	29.10	29.10	57.90	0.00	10.80	0.00	0.00	69	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1821	49	14	2	24.80	16.20	20.50	43.60	0.00	22.50	0.00	0.00	70	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1822	290	14	2	26.90	26.90	26.90	50.30	0.00	9.60	0.00	0.00	71	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1823	75	14	2	23.00	23.00	23.00	36.00	0.00	3.80	0.00	0.00	72	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1824	131	14	2	32.00	6.70	21.00	41.30	0.00	21.60	0.00	0.00	73	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1825	71	14	2	24.60	24.60	24.60	67.10	0.00	20.80	0.00	0.00	74	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1826	19	14	2	23.30	11.40	17.35	55.25	0.00	6.40	0.00	0.00	75	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1827	287	14	2	28.60	27.50	28.05	58.05	0.00	23.10	0.00	0.00	76	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1828	190	14	2	24.20	24.20	24.20	48.10	0.00	2.10	0.00	0.00	77	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1829	227	14	2	24.90	11.40	18.15	51.90	0.00	6.30	0.00	0.00	78	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1830	104	14	2	12.20	12.20	12.20	59.60	0.00	16.50	0.00	0.00	79	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1831	34	14	2	30.00	16.00	23.00	61.60	0.00	19.80	0.00	0.00	80	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1832	108	14	2	10.00	10.00	10.00	22.30	0.00	3.00	0.00	0.00	81	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1833	251	14	2	28.50	28.50	28.50	49.10	0.00	4.30	0.00	0.00	82	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1834	64	14	2	28.10	28.10	28.10	29.50	0.00	5.50	0.00	0.00	83	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1835	229	14	2	14.10	14.10	14.10	50.80	0.00	6.10	0.00	0.00	84	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1836	39	14	2	33.30	12.10	25.00	42.73	0.00	17.20	0.00	0.00	85	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1837	271	14	2	23.00	10.50	16.75	37.35	0.00	9.70	0.00	0.00	86	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1838	291	14	2	13.60	13.60	13.60	26.30	0.00	18.60	0.00	0.00	87	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1839	59	14	2	26.80	10.30	18.55	59.00	0.00	4.60	0.00	0.00	88	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1840	242	14	2	29.00	23.90	27.13	49.93	0.00	3.00	0.00	0.00	89	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1841	213	14	2	10.90	10.90	10.90	72.10	0.00	2.40	0.00	0.00	90	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1842	96	14	2	10.30	10.30	10.30	35.10	0.00	2.60	0.00	0.00	91	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1843	84	14	2	25.70	14.40	20.57	38.63	0.00	4.50	0.00	0.00	92	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1844	160	14	2	22.60	22.60	22.60	62.50	0.00	50.40	0.00	0.00	93	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1845	305	14	2	25.50	22.70	24.10	44.90	0.00	7.30	0.00	0.00	94	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1846	5	14	2	25.80	24.90	25.35	47.50	0.00	5.00	0.00	0.00	95	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1847	278	14	2	32.80	12.20	22.50	58.05	0.00	8.60	0.00	0.00	96	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1848	172	14	2	25.20	25.20	25.20	36.70	0.00	0.50	0.00	0.00	97	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1849	61	14	2	34.60	34.60	34.60	65.20	0.00	3.90	0.00	0.00	98	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1850	304	14	2	23.20	11.90	17.55	45.90	0.00	17.40	0.00	0.00	99	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1851	311	14	2	28.70	26.50	27.60	56.50	0.00	6.70	0.00	0.00	100	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1852	6	14	2	26.70	26.70	26.70	59.20	0.00	0.00	0.00	0.00	101	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1853	235	14	2	32.30	32.30	32.30	33.80	0.00	9.90	0.00	0.00	102	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1854	302	14	2	32.20	32.20	32.20	47.90	0.00	4.50	0.00	0.00	103	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1855	4	14	2	25.10	25.10	25.10	50.60	0.00	44.70	0.00	0.00	104	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1856	32	14	2	14.30	13.90	14.10	37.50	0.00	32.20	0.00	0.00	105	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1857	66	14	2	28.90	28.80	28.85	45.90	0.00	8.30	0.00	0.00	106	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1858	283	14	2	24.90	24.90	24.90	57.20	0.00	16.00	0.00	0.00	107	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1859	270	14	2	23.00	23.00	23.00	48.90	0.00	7.20	0.00	0.00	108	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1860	147	14	2	28.90	10.90	17.67	46.17	0.00	12.50	0.00	0.00	109	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1861	14	14	2	16.60	16.60	16.60	43.20	0.00	2.80	0.00	0.00	110	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1862	272	14	2	12.80	12.80	12.80	69.10	0.00	8.70	0.00	0.00	111	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1863	282	14	2	28.90	23.70	25.83	50.03	0.00	13.50	0.00	0.00	112	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1864	317	14	2	25.80	22.60	24.20	32.00	0.00	4.40	0.00	0.00	113	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1865	100	14	2	27.40	27.40	27.40	59.10	0.00	10.30	0.00	0.00	114	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1866	176	14	2	28.40	28.40	28.40	40.80	0.00	14.00	0.00	0.00	115	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1867	161	14	2	10.50	6.90	8.70	68.95	0.00	20.70	0.00	0.00	116	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1868	48	14	2	31.70	31.70	31.70	25.30	0.00	3.00	0.00	0.00	117	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1869	170	14	2	33.90	10.10	22.38	54.18	0.00	22.00	0.00	0.00	118	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1870	261	14	2	29.90	23.20	26.55	46.30	0.00	28.00	0.00	0.00	119	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1871	318	14	2	29.70	29.70	29.70	37.90	0.00	7.70	0.00	0.00	120	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1872	228	14	2	28.60	28.60	28.60	68.00	0.00	2.30	0.00	0.00	121	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1873	26	14	2	25.50	25.50	25.50	62.20	0.00	7.20	0.00	0.00	122	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1874	259	14	2	30.20	18.10	24.93	57.93	0.00	23.70	0.00	0.00	123	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1875	7	14	2	24.40	24.40	24.40	14.70	0.00	12.90	0.00	0.00	124	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1876	182	14	2	25.40	11.40	19.57	46.83	0.00	8.90	0.00	0.00	125	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1877	231	14	2	28.90	28.90	28.90	78.30	0.00	15.20	0.00	0.00	126	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1878	226	14	2	24.40	24.40	24.40	32.20	0.00	16.20	0.00	0.00	127	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1879	70	14	2	14.00	14.00	14.00	21.30	0.00	12.80	0.00	0.00	128	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1880	230	14	2	29.90	12.60	21.25	57.95	0.00	4.00	0.00	0.00	129	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1881	180	14	2	11.80	7.10	9.45	66.35	0.00	27.40	0.00	0.00	130	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1882	225	14	2	24.00	24.00	24.00	54.50	0.00	30.50	0.00	0.00	131	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1883	211	14	2	36.00	25.40	30.70	43.90	0.00	8.10	0.00	0.00	132	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1884	116	14	2	24.40	24.40	24.40	54.30	0.00	0.00	0.00	0.00	133	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1885	169	14	2	17.10	17.10	17.10	38.30	0.00	25.90	0.00	0.00	134	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1886	132	14	2	23.30	7.40	15.35	53.85	0.00	6.80	0.00	0.00	135	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1887	217	14	2	24.70	12.00	18.35	48.90	0.00	35.10	0.00	0.00	136	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1888	185	14	2	23.60	20.20	21.90	36.55	0.00	19.80	0.00	0.00	137	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1889	143	14	2	28.10	28.10	28.10	53.40	0.00	4.50	0.00	0.00	138	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1890	164	14	2	22.70	22.70	22.70	40.90	0.00	1.60	0.00	0.00	139	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1891	183	14	2	26.10	23.20	24.57	51.90	0.00	12.50	0.00	0.00	140	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1892	313	14	2	29.00	23.70	26.35	41.25	0.00	7.10	0.00	0.00	141	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1893	197	14	2	29.90	29.90	29.90	65.90	0.00	7.30	0.00	0.00	142	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1894	253	14	2	12.50	12.50	12.50	38.40	0.00	0.20	0.00	0.00	143	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1895	269	14	2	12.70	12.70	12.70	58.00	0.00	7.00	0.00	0.00	144	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1896	321	14	2	34.80	27.00	30.90	46.40	0.00	12.00	0.00	0.00	145	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1897	260	14	2	31.50	14.10	22.80	63.05	0.00	19.20	0.00	0.00	146	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1898	220	14	2	16.50	14.90	15.70	56.30	0.00	4.40	0.00	0.00	147	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1899	273	14	2	35.50	27.40	31.45	39.05	0.00	45.00	0.00	0.00	148	70.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1900	17	14	2	27.40	13.00	20.20	61.50	0.00	21.00	0.00	0.00	149	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1901	296	14	2	11.70	8.40	10.05	53.50	0.00	9.40	0.00	0.00	150	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1902	294	14	2	9.70	9.70	9.70	39.40	0.00	8.30	0.00	0.00	151	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1903	55	14	2	21.10	12.70	16.90	49.15	0.00	13.50	0.00	0.00	152	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1904	284	14	2	31.50	31.50	31.50	45.90	0.00	12.70	0.00	0.00	153	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1905	41	14	2	27.00	20.20	23.60	41.85	0.00	16.60	0.00	0.00	154	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1906	109	14	2	33.30	27.90	30.60	62.80	0.00	7.20	0.00	0.00	155	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1907	88	14	2	30.20	30.20	30.20	39.70	0.00	16.80	0.00	0.00	156	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1908	111	14	2	24.40	22.20	23.30	62.30	0.00	37.60	0.00	0.00	157	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1909	316	14	2	25.70	25.70	25.70	73.30	0.00	5.00	0.00	0.00	158	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1910	250	14	2	34.90	28.30	31.60	22.35	0.00	2.00	0.00	0.00	159	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1911	286	14	2	22.10	22.10	22.10	39.70	0.00	16.00	0.00	0.00	160	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1912	236	14	2	24.10	12.10	18.10	54.10	0.00	1.20	0.00	0.00	161	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1913	140	14	2	31.40	24.30	27.85	52.50	0.00	28.00	0.00	0.00	162	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1914	274	14	2	25.00	13.00	19.00	65.40	0.00	13.40	0.00	0.00	163	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1915	224	14	2	28.40	24.70	26.90	48.67	0.00	40.50	0.00	0.00	164	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1916	248	14	2	34.40	31.40	32.90	57.65	0.00	12.20	0.00	0.00	165	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1917	146	14	2	20.00	20.00	20.00	44.10	0.00	4.30	0.00	0.00	166	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1918	117	14	2	27.90	22.50	25.20	40.95	0.00	50.50	0.00	0.00	167	63.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1919	207	14	2	33.60	26.60	30.10	49.80	0.00	13.60	0.00	0.00	168	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1920	233	14	2	33.30	27.50	30.40	52.40	0.00	10.00	0.00	0.00	169	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1921	186	14	2	27.80	27.80	27.80	37.40	0.00	49.30	0.00	0.00	170	63.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1922	179	14	2	24.90	10.60	20.55	56.90	0.00	14.20	0.00	0.00	171	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1923	320	14	2	16.20	16.20	16.20	46.10	0.00	23.50	0.00	0.00	172	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1924	173	14	2	30.00	30.00	30.00	41.40	0.00	0.10	0.00	0.00	173	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1925	307	14	2	23.60	21.30	22.45	40.25	0.00	10.00	0.00	0.00	174	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1926	201	14	2	32.90	12.40	22.10	38.33	0.00	15.40	0.00	0.00	175	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1927	221	14	2	29.50	10.50	21.07	43.70	0.00	3.90	0.00	0.00	176	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1928	67	14	2	34.90	34.90	34.90	41.30	0.00	31.50	0.00	0.00	177	64.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1929	324	14	2	36.90	24.50	30.70	36.00	0.00	12.10	0.00	0.00	178	60.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1930	29	14	2	31.90	31.90	31.90	49.00	0.00	13.90	0.00	0.00	179	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1931	144	14	2	30.70	12.60	21.65	54.15	0.00	18.70	0.00	0.00	180	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1932	95	14	2	11.00	11.00	11.00	55.60	0.00	3.60	0.00	0.00	181	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1933	158	14	2	23.30	6.80	15.05	35.75	0.00	4.30	0.00	0.00	182	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1934	20	14	2	25.50	11.80	18.65	50.65	0.00	9.40	0.00	0.00	183	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1935	123	14	2	35.70	19.90	30.43	52.37	0.00	6.50	0.00	0.00	184	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1936	78	14	2	37.30	37.30	37.30	76.40	0.00	3.50	0.00	0.00	185	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1937	15	14	2	35.30	23.10	27.93	70.33	0.00	22.20	0.00	0.00	186	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1938	198	14	2	31.40	12.20	21.80	63.25	0.00	9.20	0.00	0.00	187	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1939	94	14	2	27.00	24.20	25.60	49.25	0.00	10.00	0.00	0.00	188	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1940	237	14	2	25.00	22.10	23.27	41.57	0.00	14.00	0.00	0.00	189	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1941	42	14	2	27.50	27.50	27.50	47.00	0.00	9.50	0.00	0.00	190	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1942	128	14	2	29.50	29.50	29.50	39.30	0.00	15.20	0.00	0.00	191	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1943	106	14	2	28.00	28.00	28.00	59.60	0.00	33.50	0.00	0.00	192	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1944	99	14	2	18.20	18.20	18.20	51.20	0.00	44.90	0.00	0.00	193	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1945	51	14	2	28.00	10.10	19.05	55.65	0.00	6.30	0.00	0.00	194	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1946	293	14	2	15.50	14.70	15.10	48.00	0.00	16.10	0.00	0.00	195	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1947	114	14	2	34.80	26.40	30.60	39.95	0.00	10.60	0.00	0.00	196	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1948	265	14	2	22.30	22.30	22.30	33.60	0.00	27.50	0.00	0.00	197	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1949	82	14	2	25.90	20.90	23.40	40.50	0.00	6.70	0.00	0.00	198	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1950	27	14	2	21.40	10.10	15.75	52.35	0.00	2.10	0.00	0.00	199	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1951	181	14	2	27.20	27.20	27.20	41.20	0.00	11.50	0.00	0.00	200	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1952	60	14	2	11.90	11.90	11.90	39.30	0.00	5.40	0.00	0.00	201	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1953	10	14	2	27.10	27.10	27.10	59.30	0.00	14.50	0.00	0.00	202	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1954	214	14	2	12.80	12.80	12.80	52.10	0.00	7.00	0.00	0.00	203	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1955	36	14	2	23.50	23.50	23.50	67.40	0.00	6.00	0.00	0.00	204	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1956	129	14	2	28.80	28.80	28.80	23.20	0.00	6.30	0.00	0.00	205	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1957	292	14	2	24.00	21.00	23.18	55.98	0.00	6.30	0.00	0.00	206	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1958	58	14	2	11.60	11.60	11.60	31.80	0.00	8.00	0.00	0.00	207	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1959	178	14	2	24.10	24.10	24.10	49.50	0.00	1.40	0.00	0.00	208	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1960	16	14	2	35.20	17.30	26.43	43.10	0.00	37.10	0.00	0.00	209	66.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1961	184	14	2	32.10	32.10	32.10	41.40	0.00	47.50	0.00	0.00	210	67.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1962	289	10	2	9.50	9.50	9.50	32.20	0.00	11.10	0.00	0.00	1	12.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1963	110	10	2	35.20	20.90	28.05	66.80	0.00	27.80	0.00	0.00	2	27.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1964	130	10	2	21.70	21.70	21.70	57.30	0.00	4.50	0.00	0.00	3	8.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1965	163	10	2	26.70	26.70	26.70	34.30	0.00	5.70	0.00	0.00	4	17.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1966	33	10	2	35.60	35.60	35.60	36.10	0.00	0.10	0.00	0.00	5	27.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1967	218	10	2	36.10	20.80	28.45	40.45	0.00	2.00	0.00	0.00	6	29.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1968	256	10	2	34.30	34.30	34.30	40.20	0.00	8.70	0.00	0.00	7	31.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1969	127	10	2	38.20	5.50	21.85	57.65	0.00	18.50	0.00	0.00	8	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1970	65	10	2	25.20	5.50	15.35	58.10	0.00	5.50	0.00	0.00	9	19.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1971	174	10	2	34.00	19.70	26.85	45.75	0.00	8.50	0.00	0.00	10	35.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1972	277	10	2	29.60	27.90	28.75	47.65	0.00	3.70	0.00	0.00	11	29.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1973	102	10	2	29.30	7.50	18.40	49.05	0.00	45.20	0.00	0.00	12	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1974	38	10	2	31.30	11.70	21.70	44.20	0.00	12.50	0.00	0.00	13	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1975	189	10	2	16.20	16.20	16.20	75.20	0.00	10.00	0.00	0.00	14	29.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1976	35	10	2	28.70	1.00	14.85	50.40	0.00	1.90	0.00	0.00	15	34.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1977	18	10	2	26.10	19.20	22.65	42.65	0.00	3.90	0.00	0.00	16	35.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1978	118	10	2	33.00	33.00	33.00	31.60	0.00	20.20	0.00	0.00	17	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1979	266	10	2	38.00	38.00	38.00	35.60	0.00	7.50	0.00	0.00	18	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1980	240	10	2	33.80	22.20	28.13	70.43	0.00	27.40	0.00	0.00	19	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1981	91	10	2	39.20	20.20	28.50	62.43	0.00	7.10	0.00	0.00	20	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1982	165	10	2	16.30	11.30	13.80	53.40	0.00	17.30	0.00	0.00	21	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1983	62	10	2	36.10	24.40	30.25	60.10	0.00	16.00	0.00	0.00	22	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1984	125	10	2	40.50	3.00	21.75	32.20	0.00	26.60	0.00	0.00	23	70.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1985	243	10	2	23.60	23.60	23.60	13.10	0.00	6.50	0.00	0.00	24	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1986	98	10	2	35.30	10.70	23.00	52.60	0.00	4.40	0.00	0.00	25	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1987	63	10	2	27.70	27.70	27.70	61.10	0.00	20.20	0.00	0.00	26	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1988	200	10	2	25.30	25.30	25.30	73.00	0.00	8.80	0.00	0.00	27	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1989	275	10	2	27.10	23.40	25.25	49.05	0.00	8.60	0.00	0.00	28	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1990	134	10	2	8.40	8.40	8.40	54.90	0.00	11.80	0.00	0.00	29	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1991	155	10	2	29.70	25.00	27.43	42.53	0.00	45.10	0.00	0.00	30	63.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1992	268	10	2	33.70	33.70	33.70	43.40	0.00	3.80	0.00	0.00	31	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1993	80	10	2	11.60	11.60	11.60	60.90	0.00	0.40	0.00	0.00	32	35.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1994	11	10	2	38.50	38.50	38.50	38.40	0.00	32.20	0.00	0.00	33	69.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1995	1	10	2	36.20	35.90	36.05	55.95	0.00	2.70	0.00	0.00	34	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1996	325	10	2	36.80	36.80	36.80	30.60	0.00	6.00	0.00	0.00	35	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1997	241	10	2	33.50	32.80	33.15	55.40	0.00	27.30	0.00	0.00	36	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1998	166	10	2	28.70	28.70	28.70	53.10	0.00	17.90	0.00	0.00	37	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
1999	193	10	2	33.70	33.70	33.70	37.40	0.00	8.00	0.00	0.00	38	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2000	215	10	2	26.80	26.40	26.60	56.10	0.00	15.00	0.00	0.00	39	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2001	139	10	2	23.50	23.50	23.50	54.90	0.00	4.70	0.00	0.00	40	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2002	210	10	2	7.60	7.60	7.60	40.60	0.00	50.30	0.00	0.00	41	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2003	310	10	2	24.70	24.70	24.70	26.80	0.00	3.40	0.00	0.00	42	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2004	31	10	2	40.10	40.10	40.10	65.60	0.00	3.00	0.00	0.00	43	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2005	301	10	2	30.90	27.00	28.95	59.55	0.00	17.30	0.00	0.00	44	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2006	142	10	2	30.10	26.20	28.15	59.05	0.00	18.60	0.00	0.00	45	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2007	216	10	2	39.00	24.00	34.08	50.18	0.00	20.90	0.00	0.00	46	62.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2008	135	10	2	32.70	27.70	30.20	43.20	0.00	10.90	0.00	0.00	47	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2009	252	10	2	4.60	4.60	4.60	37.30	0.00	9.80	0.00	0.00	48	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2010	24	10	2	25.60	9.80	17.70	60.60	0.00	11.80	0.00	0.00	49	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2011	103	10	2	26.50	9.30	20.60	57.80	0.00	8.70	0.00	0.00	50	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2012	86	10	2	21.80	11.00	16.40	67.40	0.00	6.50	0.00	0.00	51	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2013	258	10	2	5.80	5.80	5.80	45.50	0.00	5.30	0.00	0.00	52	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2014	149	10	2	36.30	17.50	28.77	49.67	0.00	35.60	0.00	0.00	53	65.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2015	249	10	2	29.20	29.20	29.20	46.50	0.00	9.90	0.00	0.00	54	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2016	299	10	2	33.10	23.00	27.93	48.87	0.00	15.50	0.00	0.00	55	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2017	37	10	2	24.60	24.60	24.60	72.90	0.00	1.70	0.00	0.00	56	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2018	153	10	2	20.20	16.10	18.15	63.15	0.00	11.30	0.00	0.00	57	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2019	138	10	2	19.50	19.50	19.50	71.10	0.00	7.80	0.00	0.00	58	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2020	151	10	2	21.90	21.90	21.90	68.70	0.00	4.90	0.00	0.00	59	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2021	46	10	2	34.60	34.60	34.60	48.00	0.00	4.30	0.00	0.00	60	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2022	92	10	2	10.40	10.40	10.40	37.50	0.00	1.90	0.00	0.00	61	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2023	234	10	2	26.90	8.30	17.60	61.65	0.00	6.30	0.00	0.00	62	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2024	79	10	2	38.70	27.40	33.05	41.30	0.00	13.80	0.00	0.00	63	61.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2025	303	10	2	42.00	42.00	42.00	54.30	0.00	0.20	0.00	0.00	64	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2026	319	10	2	8.50	8.50	8.50	14.20	0.00	2.30	0.00	0.00	65	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2027	43	10	2	33.00	25.30	29.15	39.10	0.00	15.40	0.00	0.00	66	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2028	69	10	2	7.60	3.70	5.53	41.53	0.00	23.80	0.00	0.00	67	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2029	306	10	2	24.50	24.50	24.50	75.10	0.00	3.70	0.00	0.00	68	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2030	121	10	2	32.70	4.80	23.10	53.60	0.00	15.70	0.00	0.00	69	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2031	254	10	2	21.20	5.40	13.30	65.00	0.00	48.80	0.00	0.00	70	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2032	232	10	2	5.50	5.50	5.50	67.40	0.00	2.40	0.00	0.00	71	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2033	54	10	2	6.90	6.90	6.90	50.30	0.00	0.40	0.00	0.00	72	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2034	101	10	2	29.00	24.80	26.90	46.85	0.00	8.70	0.00	0.00	73	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2035	56	10	2	35.50	11.40	22.08	42.43	0.00	23.80	0.00	0.00	74	61.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2036	297	10	2	36.40	3.80	23.75	60.35	0.00	21.10	0.00	0.00	75	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2037	150	10	2	35.30	25.50	30.40	68.05	0.00	26.10	0.00	0.00	76	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2038	52	10	2	30.30	30.30	30.30	61.20	0.00	2.70	0.00	0.00	77	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2039	308	10	2	33.60	28.20	30.90	48.50	0.00	3.60	0.00	0.00	78	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2040	245	10	2	8.40	8.40	8.40	45.40	0.00	25.00	0.00	0.00	79	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2041	126	10	2	37.40	32.90	35.15	48.30	0.00	19.90	0.00	0.00	80	60.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2042	73	10	2	25.10	6.80	15.95	55.95	0.00	21.60	0.00	0.00	81	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2043	3	10	2	17.30	17.30	17.30	60.80	0.00	3.90	0.00	0.00	82	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2044	208	10	2	27.60	27.60	27.60	60.70	0.00	22.80	0.00	0.00	83	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2045	87	10	2	37.80	37.80	37.80	60.20	0.00	6.30	0.00	0.00	84	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2046	28	10	2	31.10	25.90	28.50	46.50	0.00	28.00	0.00	0.00	85	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2047	8	10	2	21.10	21.10	21.10	36.20	0.00	3.00	0.00	0.00	86	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2048	75	10	2	26.10	26.10	26.10	86.80	0.00	2.90	0.00	0.00	87	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2049	131	10	2	31.20	31.20	31.20	39.50	0.00	11.70	0.00	0.00	88	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2050	2	10	2	33.20	4.30	22.17	63.67	0.00	12.60	0.00	0.00	89	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2051	263	10	2	23.00	10.90	16.95	36.90	0.00	6.00	0.00	0.00	90	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2052	190	10	2	30.90	12.10	21.63	43.63	0.00	33.90	0.00	0.00	91	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2053	227	10	2	27.20	27.20	27.20	49.20	0.00	11.10	0.00	0.00	92	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2054	104	10	2	30.00	30.00	30.00	31.80	0.00	3.80	0.00	0.00	93	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2055	34	10	2	25.80	25.80	25.80	46.30	0.00	24.90	0.00	0.00	94	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2056	314	10	2	24.90	7.80	16.35	61.30	0.00	26.80	0.00	0.00	95	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2057	229	10	2	35.60	27.80	31.70	50.15	0.00	16.90	0.00	0.00	96	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2058	59	10	2	33.60	33.60	33.60	96.90	0.00	7.20	0.00	0.00	97	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2059	83	10	2	25.60	25.60	25.60	48.60	0.00	24.20	0.00	0.00	98	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2060	81	10	2	20.50	20.50	20.50	84.70	0.00	11.10	0.00	0.00	99	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2061	213	10	2	25.50	25.30	25.40	70.50	0.00	10.00	0.00	0.00	100	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2062	96	10	2	28.80	6.20	17.50	53.90	0.00	12.80	0.00	0.00	101	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2063	84	10	2	29.80	29.80	29.80	28.50	0.00	8.30	0.00	0.00	102	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2064	159	10	2	9.70	9.70	9.70	47.90	0.00	8.00	0.00	0.00	103	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2065	160	10	2	7.90	7.90	7.90	45.80	0.00	17.00	0.00	0.00	104	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2066	115	10	2	23.90	23.90	23.90	54.00	0.00	1.20	0.00	0.00	105	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2067	305	10	2	7.70	7.70	7.70	74.80	0.00	24.80	0.00	0.00	106	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2068	25	10	2	34.70	18.60	26.03	40.50	0.00	7.60	0.00	0.00	107	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2069	5	10	2	32.60	24.70	28.65	49.20	0.00	17.30	0.00	0.00	108	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2070	112	10	2	8.50	8.50	8.50	27.00	0.00	5.40	0.00	0.00	109	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2071	13	10	2	24.60	24.60	24.60	49.20	0.00	1.90	0.00	0.00	110	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2072	278	10	2	24.80	24.80	24.80	31.50	0.00	6.90	0.00	0.00	111	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2073	238	10	2	24.80	24.10	24.45	42.50	0.00	3.50	0.00	0.00	112	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2074	6	10	2	32.50	28.20	30.35	55.90	0.00	17.00	0.00	0.00	113	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2075	302	10	2	8.40	8.40	8.40	49.40	0.00	35.50	0.00	0.00	114	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2076	4	10	2	26.40	26.40	26.40	34.20	0.00	3.50	0.00	0.00	115	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2077	66	10	2	4.60	4.60	4.60	50.80	0.00	2.90	0.00	0.00	116	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2078	206	10	2	25.50	25.50	25.50	66.30	0.00	4.70	0.00	0.00	117	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2079	283	10	2	38.70	38.70	38.70	40.80	0.00	5.50	0.00	0.00	118	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2080	244	10	2	36.60	27.70	32.60	49.77	0.00	16.70	0.00	0.00	119	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2081	147	10	2	33.00	9.80	21.78	46.65	0.00	22.10	0.00	0.00	120	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2082	272	10	2	34.60	34.60	34.60	43.10	0.00	20.30	0.00	0.00	121	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2083	161	10	2	22.80	22.80	22.80	46.10	0.00	14.90	0.00	0.00	122	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2084	48	10	2	38.80	29.30	34.05	49.75	0.00	9.20	0.00	0.00	123	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2085	170	10	2	21.80	21.80	21.80	48.10	0.00	1.30	0.00	0.00	124	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2086	261	10	2	26.60	23.90	25.25	43.30	0.00	6.30	0.00	0.00	125	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2087	219	10	2	31.60	11.60	23.98	52.45	0.00	15.80	0.00	0.00	126	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2088	26	10	2	21.30	20.20	20.75	53.65	0.00	17.20	0.00	0.00	127	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2089	259	10	2	25.10	10.60	17.85	42.50	0.00	23.00	0.00	0.00	128	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2090	231	10	2	20.60	4.90	12.75	44.85	0.00	8.40	0.00	0.00	129	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2091	70	10	2	23.30	3.90	13.60	62.55	0.00	3.00	0.00	0.00	130	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2092	180	10	2	29.60	29.60	29.60	60.60	0.00	6.10	0.00	0.00	131	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2093	225	10	2	5.20	5.20	5.20	69.50	0.00	17.00	0.00	0.00	132	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2094	211	10	2	7.30	7.30	7.30	71.50	0.00	7.80	0.00	0.00	133	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2095	74	10	2	33.20	33.10	33.15	42.60	0.00	3.50	0.00	0.00	134	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2096	132	10	2	36.90	5.90	23.84	59.52	0.00	47.90	0.00	0.00	135	69.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2097	45	10	2	27.30	27.30	27.30	37.20	0.00	2.70	0.00	0.00	136	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2098	185	10	2	36.10	36.10	36.10	51.00	0.00	4.10	0.00	0.00	137	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2099	315	10	2	5.40	5.40	5.40	67.70	0.00	8.80	0.00	0.00	138	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2100	44	10	2	34.60	31.60	33.10	47.00	0.00	24.30	0.00	0.00	139	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2101	143	10	2	9.40	9.40	9.40	51.30	0.00	1.40	0.00	0.00	140	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2102	164	10	2	24.80	24.80	24.80	48.70	0.00	4.80	0.00	0.00	141	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2103	205	10	2	28.90	28.90	28.90	48.10	0.00	1.70	0.00	0.00	142	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2104	183	10	2	36.40	3.70	24.70	33.33	0.00	38.80	0.00	0.00	143	70.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2105	276	10	2	36.40	7.80	22.10	36.85	0.00	17.70	0.00	0.00	144	61.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2106	148	10	2	26.20	1.00	13.60	63.20	0.00	6.30	0.00	0.00	145	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2107	156	10	2	26.60	26.60	26.60	63.60	0.00	6.00	0.00	0.00	146	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2108	269	10	2	39.00	5.30	23.91	49.67	0.00	24.80	0.00	0.00	147	64.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2109	321	10	2	35.60	35.60	35.60	50.00	0.00	2.60	0.00	0.00	148	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2110	188	10	2	25.30	8.50	16.90	49.40	0.00	43.10	0.00	0.00	149	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2111	260	10	2	26.60	26.40	26.50	52.85	0.00	1.10	0.00	0.00	150	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2112	280	10	2	23.50	12.30	17.90	53.85	0.00	23.40	0.00	0.00	151	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2113	220	10	2	30.60	9.70	20.15	49.60	0.00	12.90	0.00	0.00	152	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2114	273	10	2	24.20	24.20	24.20	55.30	0.00	4.10	0.00	0.00	153	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2115	296	10	2	38.80	22.70	28.53	54.23	0.00	9.70	0.00	0.00	154	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2116	30	10	2	35.70	7.60	21.65	36.05	0.00	5.70	0.00	0.00	155	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2117	177	10	2	27.30	25.20	26.25	48.70	0.00	9.20	0.00	0.00	156	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2118	196	10	2	34.10	21.40	28.10	48.43	0.00	22.30	0.00	0.00	157	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2119	162	10	2	37.70	37.70	37.70	81.50	0.00	40.00	0.00	0.00	158	66.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2120	294	10	2	10.00	10.00	10.00	44.50	0.00	6.80	0.00	0.00	159	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2121	105	10	2	29.90	7.10	19.50	59.90	0.00	30.50	0.00	0.00	160	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2122	55	10	2	25.40	25.40	25.40	65.80	0.00	21.00	0.00	0.00	161	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2123	41	10	2	29.70	29.70	29.70	41.70	0.00	14.40	0.00	0.00	162	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2124	109	10	2	8.90	8.90	8.90	55.50	0.00	2.40	0.00	0.00	163	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2125	88	10	2	10.40	10.40	10.40	50.20	0.00	17.60	0.00	0.00	164	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2126	111	10	2	37.50	20.90	29.20	51.50	0.00	4.60	0.00	0.00	165	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2127	316	10	2	33.30	28.20	30.75	42.85	0.00	23.60	0.00	0.00	166	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2128	250	10	2	30.50	30.50	30.50	60.50	0.00	8.90	0.00	0.00	167	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2129	236	10	2	17.90	17.90	17.90	34.20	0.00	3.00	0.00	0.00	168	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2130	140	10	2	26.30	26.30	26.30	36.90	0.00	12.00	0.00	0.00	169	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2131	207	10	2	27.60	23.20	25.40	51.55	0.00	6.50	0.00	0.00	170	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2132	233	10	2	8.50	6.30	7.40	51.20	0.00	1.30	0.00	0.00	171	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2133	72	10	2	24.10	8.10	16.10	46.60	0.00	16.10	0.00	0.00	172	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2134	186	10	2	26.00	26.00	26.00	35.80	0.00	3.90	0.00	0.00	173	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2135	179	10	2	21.70	21.70	21.70	49.40	0.00	2.20	0.00	0.00	174	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2136	320	10	2	27.20	27.20	27.20	57.80	0.00	7.80	0.00	0.00	175	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2137	264	10	2	24.80	24.80	24.80	20.20	0.00	15.80	0.00	0.00	176	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2138	173	10	2	35.20	27.80	31.50	37.20	0.00	15.70	0.00	0.00	177	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2139	203	10	2	25.10	25.10	25.10	33.50	0.00	18.40	0.00	0.00	178	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2140	9	10	2	27.70	27.40	27.55	51.25	0.00	10.40	0.00	0.00	179	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2141	221	10	2	31.40	24.50	27.95	58.35	0.00	8.10	0.00	0.00	180	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2142	279	10	2	34.10	34.10	34.10	77.10	0.00	4.20	0.00	0.00	181	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2143	67	10	2	34.60	34.60	34.60	38.70	0.00	8.20	0.00	0.00	182	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2144	120	10	2	21.00	21.00	21.00	74.70	0.00	1.70	0.00	0.00	183	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2145	324	10	2	9.30	9.30	9.30	37.70	0.00	6.50	0.00	0.00	184	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2146	29	10	2	38.60	38.60	38.60	34.00	0.00	6.20	0.00	0.00	185	60.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2147	144	10	2	6.30	6.30	6.30	67.30	0.00	10.60	0.00	0.00	186	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2148	95	10	2	25.40	25.40	25.40	49.50	0.00	0.00	0.00	0.00	187	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2149	158	10	2	30.40	30.40	30.40	40.10	0.00	4.90	0.00	0.00	188	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2150	20	10	2	20.80	20.80	20.80	36.40	0.00	42.50	0.00	0.00	189	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2151	15	10	2	27.40	27.30	27.35	46.35	0.00	20.90	0.00	0.00	190	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2152	94	10	2	21.80	20.10	20.95	54.85	0.00	10.60	0.00	0.00	191	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2153	77	10	2	34.20	12.00	25.93	51.60	0.00	10.80	0.00	0.00	192	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2154	247	10	2	23.40	23.40	23.40	48.20	0.00	14.20	0.00	0.00	193	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2155	23	10	2	12.20	12.20	12.20	46.60	0.00	0.60	0.00	0.00	194	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2156	42	10	2	27.40	27.40	27.40	51.90	0.00	7.70	0.00	0.00	195	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2157	107	10	2	35.50	35.50	35.50	44.40	0.00	8.80	0.00	0.00	196	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2158	141	10	2	40.00	5.00	22.50	32.95	0.00	3.40	0.00	0.00	197	60.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2159	199	10	2	23.30	23.30	23.30	58.40	0.00	10.30	0.00	0.00	198	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2160	288	10	2	9.40	4.70	7.05	48.80	0.00	12.70	0.00	0.00	199	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2161	128	10	2	31.30	8.40	19.85	64.35	0.00	7.00	0.00	0.00	200	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2162	106	10	2	10.40	7.10	8.75	38.30	0.00	2.90	0.00	0.00	201	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2163	99	10	2	29.30	29.30	29.30	70.60	0.00	5.80	0.00	0.00	202	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2164	93	10	2	32.40	9.50	20.95	35.95	0.00	9.30	0.00	0.00	203	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2165	209	10	2	34.40	23.70	29.05	37.05	0.00	59.60	0.00	0.00	204	71.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2166	12	10	2	24.50	24.50	24.50	34.70	0.00	1.70	0.00	0.00	205	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2167	114	10	2	30.70	7.40	20.40	38.00	0.00	38.40	0.00	0.00	206	62.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2168	27	10	2	39.10	39.10	39.10	46.50	0.00	2.90	0.00	0.00	207	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2169	181	10	2	22.70	7.00	14.85	72.30	0.00	12.90	0.00	0.00	208	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2170	60	10	2	38.80	21.00	29.90	50.50	0.00	14.80	0.00	0.00	209	60.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2171	214	10	2	38.80	22.90	30.47	39.73	0.00	12.50	0.00	0.00	210	61.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2172	255	10	2	5.40	5.40	5.40	56.70	0.00	1.10	0.00	0.00	211	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2173	222	10	2	5.70	5.70	5.70	39.70	0.00	8.30	0.00	0.00	212	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2174	36	10	2	25.20	25.20	25.20	21.50	0.00	3.00	0.00	0.00	213	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2175	129	10	2	28.40	4.60	16.50	22.90	0.00	13.40	0.00	0.00	214	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2176	292	10	2	11.20	7.00	9.10	28.05	0.00	9.80	0.00	0.00	215	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2177	178	10	2	23.60	10.40	17.00	37.35	0.00	22.30	0.00	0.00	216	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2178	16	10	2	29.50	22.40	25.95	50.40	0.00	6.90	0.00	0.00	217	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2179	184	10	2	26.10	26.10	26.10	52.00	0.00	13.30	0.00	0.00	218	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2180	289	9	2	29.60	4.50	17.05	65.70	3.80	4.70	0.00	3.80	0	4.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2181	110	9	2	25.60	25.60	25.60	35.60	1.90	11.40	0.00	5.70	0	5.00	Élevé	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2182	163	9	2	9.80	9.80	9.80	55.30	1.90	2.30	0.00	7.60	0	0.00	Élevé	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2183	218	9	2	26.00	26.00	26.00	47.10	1.90	25.30	0.00	9.50	0	5.00	Élevé	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2184	127	9	2	35.00	35.00	35.00	34.20	1.90	1.10	0.00	11.40	0	7.00	Élevé	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2185	65	9	2	32.70	32.70	32.70	58.40	1.90	4.00	0.00	13.30	0	0.00	Élevé	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2186	22	9	2	24.90	24.90	24.90	65.00	1.90	6.90	0.00	15.20	0	0.00	Modéré	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2187	267	9	2	24.30	24.30	24.30	81.30	1.90	2.10	0.00	17.10	0	0.00	Modéré	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2188	124	9	2	38.60	1.80	20.20	68.10	3.80	28.60	0.00	20.90	0	7.00	Modéré	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2189	277	9	2	39.30	25.50	34.10	64.57	5.70	23.20	0.00	26.60	0	0.00	Modéré	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2190	102	9	2	19.60	4.60	12.10	43.20	3.80	18.60	0.00	30.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2191	189	9	2	33.40	33.40	33.40	42.80	1.90	6.40	0.00	32.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2192	18	9	2	7.30	7.30	7.30	66.90	1.90	2.40	0.00	34.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2193	118	9	2	35.10	27.70	31.40	59.25	3.80	15.50	0.00	38.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2194	266	9	2	34.40	34.40	34.40	28.10	1.90	8.10	0.00	39.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2195	240	9	2	34.30	11.80	24.15	43.23	7.60	23.70	0.00	47.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2196	91	9	2	9.40	9.40	9.40	54.10	1.90	21.20	0.00	49.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2197	168	9	2	28.60	28.60	28.60	58.90	1.90	13.20	0.00	51.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2198	165	9	2	26.20	26.20	26.20	10.50	1.90	0.10	0.00	53.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2199	62	9	2	32.10	19.90	26.00	52.30	3.80	20.40	0.00	57.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2200	285	9	2	27.00	27.00	27.00	40.80	1.90	14.80	0.00	53.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2201	243	9	2	22.80	9.40	16.10	50.80	3.80	15.60	0.00	55.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2202	63	9	2	27.50	27.50	27.50	53.60	1.90	17.20	0.00	55.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2203	202	9	2	12.30	12.30	12.30	41.40	1.90	4.30	0.00	57.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2204	200	9	2	36.30	16.80	26.55	36.45	3.80	8.20	0.00	58.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2205	76	9	2	26.20	6.30	16.25	45.00	3.80	30.10	0.00	60.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2206	275	9	2	36.70	36.70	36.70	75.00	1.90	4.30	0.00	60.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2207	155	9	2	9.70	9.70	9.70	60.90	1.90	18.00	0.00	60.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2208	80	9	2	36.70	26.60	32.93	33.87	5.70	8.60	0.00	57.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2209	136	9	2	11.60	11.60	11.60	33.90	1.90	4.50	0.00	55.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2210	11	9	2	28.40	24.40	26.40	43.35	3.80	12.90	0.00	58.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2211	1	9	2	24.50	7.70	16.10	39.95	3.80	14.60	0.00	60.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2212	325	9	2	23.60	23.60	23.60	59.30	1.90	0.90	0.00	62.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2213	193	9	2	36.40	25.90	30.47	45.93	5.70	14.70	0.00	60.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2214	215	9	2	24.60	24.60	24.60	44.80	1.90	6.20	0.00	55.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2215	139	9	2	37.80	35.40	36.60	44.80	3.80	10.70	0.00	57.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2216	210	9	2	26.60	26.60	26.60	66.80	1.90	12.40	0.00	57.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2217	310	9	2	27.30	27.30	27.30	26.10	1.90	19.30	0.00	57.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2218	31	9	2	27.30	26.60	26.95	33.25	3.80	4.40	0.00	57.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2219	301	9	2	24.10	24.10	24.10	70.60	1.90	0.70	0.00	57.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2220	216	9	2	42.70	24.20	33.45	50.95	3.80	8.80	0.00	57.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2221	122	9	2	22.50	22.50	22.50	51.60	1.90	20.30	0.00	58.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2222	135	9	2	27.10	24.10	25.60	42.55	3.80	7.40	0.00	60.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2223	252	9	2	23.80	23.80	23.80	64.80	1.90	20.40	0.00	60.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2224	103	9	2	29.60	24.50	27.05	58.45	3.80	4.30	0.00	55.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2225	86	9	2	28.30	26.30	27.30	45.50	3.80	16.30	0.00	57.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2226	192	9	2	8.90	8.90	8.90	48.80	1.90	24.60	0.00	58.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2227	171	9	2	30.00	6.30	15.70	39.60	5.70	2.60	0.00	57.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2228	249	9	2	25.90	25.90	25.90	10.30	1.90	9.00	0.00	51.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2229	299	9	2	3.90	3.90	3.90	31.30	1.90	10.70	0.00	51.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2230	57	9	2	34.70	34.70	34.70	69.00	1.90	3.90	0.00	53.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2231	138	9	2	30.20	20.90	25.73	63.63	5.70	32.30	0.00	51.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2232	151	9	2	20.50	20.50	20.50	40.60	1.90	1.10	0.00	47.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2233	257	9	2	28.50	25.60	27.05	52.45	3.80	34.30	0.00	49.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2234	46	9	2	33.00	28.60	30.80	61.20	3.80	5.60	0.00	53.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2235	92	9	2	23.30	23.30	23.30	37.30	1.90	8.40	0.00	49.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2236	79	9	2	26.40	26.40	26.40	52.70	1.90	3.40	0.00	45.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2237	43	9	2	30.40	28.40	29.40	46.45	3.80	36.30	0.00	43.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2238	69	9	2	40.50	7.70	29.27	30.00	5.70	8.10	0.00	49.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2239	121	9	2	31.50	25.40	28.45	47.10	3.80	10.50	0.00	49.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2240	254	9	2	39.70	23.80	31.75	67.45	3.80	5.70	0.00	49.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2241	119	9	2	32.10	32.10	32.10	82.20	1.90	0.10	0.00	43.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2242	101	9	2	38.50	34.60	36.55	63.20	3.80	6.70	0.00	45.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2243	322	9	2	8.20	8.20	8.20	20.00	1.90	30.30	0.00	47.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2244	56	9	2	10.20	10.20	10.20	38.80	1.90	9.20	0.00	47.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2245	297	9	2	35.30	8.90	22.10	40.85	3.80	11.20	0.00	49.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2246	150	9	2	27.50	13.00	20.25	39.85	3.80	3.40	0.00	47.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2247	308	9	2	33.20	22.70	27.95	44.25	3.80	9.00	0.00	49.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2248	245	9	2	35.00	35.00	35.00	66.40	1.90	6.70	0.00	47.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2249	204	9	2	28.40	24.90	26.65	74.25	3.80	20.10	0.00	45.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2250	53	9	2	40.70	5.40	23.77	62.63	5.70	14.30	0.00	51.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2251	3	9	2	28.40	28.40	28.40	61.20	1.90	0.80	0.00	51.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2252	208	9	2	21.70	9.90	15.80	71.10	3.80	3.50	0.00	55.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2253	28	9	2	13.00	13.00	13.00	29.30	1.90	27.80	0.00	47.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2254	212	9	2	14.60	14.60	14.60	41.30	1.90	4.60	0.00	49.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2255	8	9	2	26.50	12.20	21.70	33.03	5.70	13.80	0.00	51.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2256	49	9	2	24.00	7.70	15.85	44.05	3.80	25.60	0.00	51.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2257	239	9	2	32.60	7.80	20.20	58.10	3.80	4.40	0.00	55.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2258	290	9	2	25.30	25.30	25.30	44.80	1.90	1.60	0.00	57.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2259	131	9	2	24.20	22.60	23.40	48.20	3.80	24.50	0.00	58.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2260	19	9	2	38.60	5.00	18.70	60.83	5.70	24.10	0.00	58.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2261	2	9	2	28.70	27.70	28.20	47.10	3.80	31.40	0.00	60.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2262	263	9	2	28.80	28.80	28.80	46.70	1.90	14.10	0.00	58.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2263	190	9	2	25.50	24.80	25.15	58.45	3.80	9.90	0.00	62.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2264	108	9	2	36.80	23.90	30.35	54.40	3.80	14.00	0.00	57.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2265	314	9	2	23.70	23.70	23.70	83.90	1.90	14.30	0.00	58.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2266	251	9	2	33.50	23.60	28.55	38.55	3.80	5.10	0.00	62.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2267	64	9	2	24.20	24.20	24.20	60.80	1.90	26.10	0.00	64.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2268	229	9	2	25.50	25.50	25.50	34.70	3.80	30.40	0.00	58.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2269	39	9	2	35.80	10.70	23.25	65.55	3.80	6.60	0.00	60.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2270	271	9	2	13.40	6.00	9.70	58.60	3.80	34.80	0.00	64.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2271	195	9	2	25.60	25.60	25.60	41.10	1.90	6.90	0.00	62.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2272	59	9	2	37.00	37.00	37.00	47.20	1.90	2.30	0.00	62.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2273	295	9	2	10.90	10.90	10.90	7.40	1.90	8.90	0.00	57.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2274	242	9	2	38.20	38.20	38.20	40.10	1.90	9.70	0.00	55.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2275	213	9	2	35.70	35.70	35.70	45.60	1.90	12.10	0.00	51.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2276	96	9	2	23.90	23.90	23.90	48.90	1.90	28.40	0.00	53.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2277	159	9	2	23.60	6.00	14.80	44.25	3.80	24.60	0.00	53.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2278	305	9	2	40.20	20.80	28.23	43.27	5.70	11.00	0.00	47.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2279	25	9	2	21.60	20.80	21.20	46.20	3.80	4.70	0.00	51.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2280	5	9	2	28.00	9.50	18.75	48.00	3.80	49.20	0.00	51.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2281	278	9	2	37.40	34.10	35.75	55.20	3.80	3.40	0.00	55.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2282	172	9	2	27.00	25.20	26.10	68.35	3.80	47.60	0.00	55.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2283	61	9	2	38.50	32.10	35.30	24.90	3.80	13.20	0.00	57.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2284	304	9	2	34.60	26.60	31.37	43.57	5.70	8.90	0.00	58.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2285	311	9	2	36.40	33.80	35.10	53.65	3.80	6.60	0.00	60.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2286	238	9	2	22.50	5.90	14.20	48.65	3.80	20.20	0.00	64.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2287	235	9	2	26.10	10.60	18.35	36.90	3.80	6.80	0.00	60.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2288	302	9	2	38.70	11.80	25.25	71.25	3.80	7.70	0.00	60.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2289	4	9	2	28.00	28.00	28.00	38.30	1.90	13.50	0.00	62.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2290	32	9	2	8.10	8.10	8.10	54.00	1.90	9.70	0.00	62.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2291	66	9	2	26.50	22.90	24.70	57.80	3.80	7.60	0.00	64.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2292	206	9	2	37.90	37.90	37.90	37.60	1.90	37.00	0.00	66.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2293	272	9	2	33.30	33.30	33.30	67.20	1.90	9.00	0.00	60.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2294	282	9	2	30.40	29.60	30.00	49.20	3.80	7.00	0.00	60.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2295	317	9	2	23.00	21.00	22.00	54.85	3.80	26.20	0.00	64.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2296	68	9	2	23.70	7.00	15.35	65.80	3.80	6.00	0.00	58.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2297	161	9	2	24.70	24.70	24.70	57.80	1.90	0.00	0.00	57.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2298	170	9	2	24.50	24.50	24.50	33.30	1.90	4.70	0.00	58.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2299	261	9	2	23.40	23.40	23.40	58.80	1.90	2.20	0.00	57.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2300	318	9	2	12.80	12.80	12.80	23.80	1.90	1.30	0.00	55.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2301	246	9	2	26.20	26.20	26.20	52.50	1.90	0.40	0.00	53.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2302	26	9	2	35.90	35.90	35.90	62.50	1.90	0.20	0.00	41.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2303	259	9	2	21.10	21.10	21.10	60.20	1.90	29.10	0.00	39.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2304	7	9	2	0.50	0.50	0.50	51.50	1.90	8.50	0.00	38.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2305	231	9	2	11.80	8.40	10.10	52.80	3.80	8.60	0.00	38.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2306	223	9	2	12.10	12.10	12.10	40.80	1.90	17.00	0.00	36.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2307	226	9	2	33.40	33.40	33.40	22.20	1.90	3.60	0.00	36.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2308	154	9	2	35.60	28.30	31.95	38.40	3.80	13.30	0.00	39.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2309	180	9	2	22.90	20.10	21.50	38.95	3.80	17.20	0.00	43.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2310	225	9	2	20.60	20.60	20.60	54.50	1.90	1.50	0.00	45.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2311	211	9	2	12.30	12.30	12.30	48.70	1.90	20.20	0.00	45.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2312	74	9	2	22.60	22.60	22.60	50.30	1.90	1.30	0.00	43.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2313	116	9	2	28.20	22.40	25.67	44.00	5.70	30.70	0.00	45.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2314	169	9	2	25.90	25.90	25.90	57.50	1.90	18.00	0.00	47.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2315	132	9	2	24.90	24.90	24.90	43.60	1.90	1.30	0.00	49.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2316	191	9	2	32.40	22.90	27.67	49.10	5.70	20.60	0.00	49.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2317	217	9	2	27.60	13.30	20.45	32.10	3.80	11.10	0.00	53.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2318	185	9	2	22.20	9.90	16.05	43.60	3.80	11.80	0.00	55.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2319	44	9	2	27.80	23.30	25.55	58.20	3.80	5.80	0.00	55.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2320	143	9	2	7.80	7.80	7.80	68.40	1.90	45.50	0.00	55.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2321	164	9	2	36.70	22.40	29.97	46.23	5.70	7.80	0.00	60.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2322	205	9	2	27.10	24.90	26.00	34.40	3.80	3.30	0.00	62.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2323	276	9	2	16.50	6.80	11.65	40.60	3.80	13.80	0.00	62.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2324	89	9	2	39.10	23.50	31.30	59.05	3.80	54.10	0.00	66.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2325	85	9	2	25.20	5.10	15.15	49.30	3.80	7.60	0.00	66.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2326	148	9	2	35.10	29.10	32.10	62.95	3.80	5.70	0.00	68.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2327	313	9	2	37.00	37.00	37.00	35.40	1.90	15.10	0.00	68.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2328	197	9	2	26.10	26.10	26.10	44.10	1.90	1.90	0.00	70.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2329	253	9	2	32.20	28.40	30.30	63.75	3.80	31.70	0.00	74.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2330	269	9	2	26.60	26.60	26.60	52.90	1.90	9.20	0.00	68.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2331	321	9	2	34.30	33.40	33.85	44.55	3.80	2.30	0.00	70.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2332	188	9	2	37.70	24.30	32.07	41.57	5.70	21.90	0.00	74.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2333	260	9	2	26.10	26.10	26.10	16.40	1.90	6.00	0.00	74.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2334	280	9	2	9.90	9.90	9.90	60.20	1.90	1.30	0.00	70.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2335	220	9	2	29.10	8.20	20.87	57.50	5.70	27.60	0.00	74.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2336	273	9	2	34.60	34.60	34.60	81.90	1.90	2.70	0.00	74.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2337	152	9	2	28.50	1.40	13.23	63.07	5.70	15.10	0.00	79.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2338	17	9	2	33.40	33.40	33.40	41.60	1.90	8.70	0.00	72.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2339	296	9	2	31.60	31.60	31.60	44.60	1.90	9.00	0.00	70.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2340	30	9	2	34.20	21.80	26.83	34.97	5.70	15.00	0.00	76.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2341	47	9	2	25.10	7.90	18.57	59.03	5.70	14.50	0.00	77.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2342	177	9	2	32.00	10.40	21.20	40.45	3.80	7.70	0.00	79.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2343	196	9	2	24.10	23.50	23.83	57.57	5.70	14.90	0.00	79.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2344	162	9	2	27.70	27.70	27.70	66.50	1.90	1.50	0.00	81.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2345	105	9	2	33.60	33.60	33.60	45.50	1.90	3.50	0.00	79.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2346	55	9	2	36.00	36.00	36.00	53.30	1.90	2.30	0.00	81.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2347	284	9	2	1.20	1.20	1.20	1.80	1.90	9.40	0.00	79.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2348	41	9	2	22.30	22.30	22.30	70.10	1.90	18.20	0.00	77.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2349	88	9	2	19.20	5.60	10.57	40.23	5.70	38.90	0.00	76.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2350	298	9	2	11.60	11.60	11.60	22.90	1.90	9.70	0.00	76.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2351	111	9	2	23.10	10.60	16.85	33.30	3.80	4.50	0.00	77.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2352	316	9	2	23.50	23.50	23.50	81.30	1.90	1.50	0.00	76.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2353	236	9	2	24.60	24.60	24.60	69.00	1.90	10.80	0.00	72.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2354	140	9	2	37.00	8.80	18.60	51.07	5.70	4.30	0.00	72.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2355	224	9	2	8.90	8.90	8.90	52.10	1.90	0.00	0.00	70.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2356	248	9	2	13.30	13.30	13.30	23.70	1.90	20.30	0.00	66.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2357	146	9	2	29.60	7.80	18.70	57.55	3.80	5.50	0.00	68.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2358	207	9	2	38.70	38.70	38.70	28.20	1.90	0.60	0.00	64.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2359	233	9	2	31.70	31.70	31.70	22.60	1.90	8.40	0.00	64.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2360	186	9	2	19.30	19.30	19.30	63.30	1.90	20.60	0.00	58.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2361	179	9	2	29.40	25.90	27.60	53.07	5.70	20.20	0.00	58.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2362	320	9	2	25.20	11.50	18.35	63.25	3.80	13.40	0.00	58.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2363	97	9	2	28.30	28.30	28.30	20.40	1.90	6.00	0.00	53.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2364	307	9	2	26.70	26.70	26.70	65.50	1.90	47.70	0.00	53.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2365	201	9	2	28.80	26.60	27.70	51.05	3.80	10.30	0.00	51.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2366	221	9	2	33.60	22.30	27.95	40.15	3.80	10.40	0.00	49.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2367	67	9	2	36.20	36.20	36.20	49.30	1.90	56.20	0.00	45.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2368	120	9	2	35.30	35.30	35.30	61.30	1.90	12.90	0.00	45.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2369	324	9	2	9.90	9.90	9.90	55.90	1.90	46.30	0.00	47.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2370	29	9	2	11.80	11.80	11.80	59.30	1.90	0.20	0.00	49.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2371	144	9	2	21.10	21.10	21.10	49.30	1.90	2.70	0.00	49.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2372	158	9	2	29.10	29.10	29.10	70.80	1.90	13.50	0.00	45.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2373	20	9	2	9.00	9.00	9.00	35.60	1.90	8.50	0.00	45.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2374	123	9	2	36.80	35.10	35.95	43.65	3.80	33.20	0.00	47.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2375	78	9	2	24.10	24.10	24.10	49.50	1.90	12.10	0.00	45.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2376	94	9	2	32.90	10.60	21.75	46.65	3.80	52.30	0.00	45.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2377	77	9	2	38.10	38.10	38.10	40.70	1.90	7.70	0.00	45.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2378	247	9	2	21.50	9.50	15.50	52.25	3.80	3.50	0.00	43.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2379	107	9	2	25.40	8.30	19.23	28.97	5.70	17.50	0.00	43.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2380	199	9	2	23.20	23.20	23.20	57.80	1.90	9.10	0.00	43.70	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2381	288	9	2	28.80	5.90	17.35	38.00	3.80	4.00	0.00	47.50	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2382	128	9	2	20.20	20.20	20.20	45.60	1.90	15.10	0.00	49.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2383	99	9	2	31.60	20.50	26.05	59.55	3.80	26.90	0.00	49.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2384	93	9	2	29.60	3.00	20.17	52.93	5.70	6.70	0.00	51.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2385	51	9	2	8.20	5.60	6.90	57.80	3.80	17.50	0.00	55.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2386	293	9	2	30.90	30.90	30.90	32.80	1.90	10.80	0.00	55.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2387	133	9	2	26.10	26.10	26.10	73.90	1.90	0.10	0.00	49.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2388	114	9	2	10.40	9.60	10.00	62.25	3.80	7.70	0.00	53.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2389	265	9	2	11.00	11.00	11.00	33.00	1.90	5.90	0.00	53.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2390	113	9	2	33.70	33.70	33.70	34.80	1.90	2.90	0.00	49.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2391	27	9	2	6.40	6.40	6.40	44.70	1.90	3.50	0.00	49.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2392	10	9	2	34.90	7.30	21.10	53.40	3.80	16.00	0.00	49.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2393	214	9	2	9.60	9.60	9.60	56.10	1.90	6.30	0.00	51.30	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2394	255	9	2	27.80	21.10	24.45	69.05	3.80	25.10	0.00	53.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2395	222	9	2	37.20	9.80	23.50	36.30	3.80	13.20	0.00	53.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2396	36	9	2	26.70	26.70	26.70	71.00	1.90	10.40	0.00	55.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2397	129	9	2	37.40	7.20	22.30	55.90	3.80	13.90	0.00	58.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2398	292	9	2	20.70	20.70	20.70	52.10	1.90	3.00	0.00	55.10	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2399	58	9	2	41.40	9.90	25.65	51.85	3.80	22.80	0.00	58.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2400	178	9	2	24.60	20.00	22.30	65.65	3.80	5.70	0.00	60.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2401	16	9	2	28.40	28.40	28.40	49.40	1.90	0.70	0.00	58.90	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2402	110	3	2	30.10	22.60	26.35	47.65	0.00	5.50	0.00	0.00	1	13.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2403	33	3	2	7.30	7.30	7.30	63.40	0.00	15.30	0.00	0.00	2	10.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2404	218	3	2	8.60	6.40	7.50	33.15	0.00	24.40	0.00	0.00	3	21.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2405	127	3	2	41.80	22.60	32.20	41.75	0.00	9.30	0.00	0.00	4	35.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2406	65	3	2	8.20	8.20	8.20	39.40	0.00	10.40	0.00	0.00	5	18.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2407	174	3	2	38.20	38.20	38.20	44.60	0.00	11.40	0.00	0.00	6	34.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2408	124	3	2	25.90	25.90	25.90	49.30	0.00	9.40	0.00	0.00	7	19.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2409	277	3	2	28.40	28.40	28.40	40.10	0.00	5.40	0.00	0.00	8	25.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2410	102	3	2	21.40	6.00	13.70	41.85	0.00	10.90	0.00	0.00	9	24.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2411	38	3	2	4.20	4.20	4.20	69.70	0.00	4.50	0.00	0.00	10	19.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2412	189	3	2	15.10	15.10	15.10	53.90	0.00	1.00	0.00	0.00	11	21.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2413	157	3	2	29.00	17.70	23.35	64.50	0.00	5.00	0.00	0.00	12	28.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2414	35	3	2	35.30	32.30	33.80	53.00	0.00	14.90	0.00	0.00	13	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2415	18	3	2	28.90	28.90	28.90	72.90	0.00	13.00	0.00	0.00	14	34.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2416	118	3	2	28.30	28.30	28.30	29.00	0.00	2.80	0.00	0.00	15	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2417	266	3	2	26.10	22.50	24.30	42.15	0.00	2.20	0.00	0.00	16	34.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2418	240	3	2	22.60	7.80	15.20	58.45	0.00	12.40	0.00	0.00	17	35.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2419	91	3	2	6.50	6.50	6.50	62.10	0.00	4.70	0.00	0.00	18	33.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2420	168	3	2	22.70	22.70	22.70	48.80	0.00	19.70	0.00	0.00	19	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2421	165	3	2	35.10	24.30	29.40	52.98	0.00	6.20	0.00	0.00	20	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2422	62	3	2	32.40	32.40	32.40	55.10	0.00	2.40	0.00	0.00	21	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2423	285	3	2	10.10	10.10	10.10	52.70	0.00	14.40	0.00	0.00	22	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2424	125	3	2	37.80	29.10	33.93	56.80	0.00	21.00	0.00	0.00	23	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2425	63	3	2	22.90	15.70	19.30	40.20	0.00	37.50	0.00	0.00	24	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2426	202	3	2	33.60	18.90	24.60	61.97	0.00	21.40	0.00	0.00	25	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2427	275	3	2	19.70	19.70	19.70	66.30	0.00	16.90	0.00	0.00	26	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2428	134	3	2	40.30	24.40	32.35	55.60	0.00	12.00	0.00	0.00	27	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2429	268	3	2	37.70	34.70	36.20	66.65	0.00	19.20	0.00	0.00	28	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2430	80	3	2	30.50	30.50	30.50	63.00	0.00	1.20	0.00	0.00	29	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2431	136	3	2	9.80	9.80	9.80	81.30	0.00	14.70	0.00	0.00	30	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2432	11	3	2	29.40	8.30	21.87	41.50	0.00	5.30	0.00	0.00	31	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2433	325	3	2	8.00	8.00	8.00	36.00	0.00	13.50	0.00	0.00	32	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2434	241	3	2	11.50	11.50	11.50	54.60	0.00	2.10	0.00	0.00	33	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2435	167	3	2	27.10	24.20	25.65	44.10	0.00	19.20	0.00	0.00	34	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2436	215	3	2	23.70	11.70	17.70	49.80	0.00	1.40	0.00	0.00	35	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2437	139	3	2	27.50	7.60	19.80	47.50	0.00	12.30	0.00	0.00	36	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2438	310	3	2	25.80	25.80	25.80	59.10	0.00	45.00	0.00	0.00	37	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2439	31	3	2	39.70	4.70	22.10	56.85	0.00	43.10	0.00	0.00	38	71.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2440	145	3	2	7.00	7.00	7.00	52.90	0.00	3.20	0.00	0.00	39	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2441	301	3	2	11.80	11.80	11.80	55.40	0.00	2.90	0.00	0.00	40	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2442	142	3	2	26.90	3.70	15.30	37.90	0.00	17.10	0.00	0.00	41	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2443	216	3	2	6.30	6.30	6.30	61.90	0.00	0.10	0.00	0.00	42	35.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2444	122	3	2	28.00	28.00	28.00	45.30	0.00	5.20	0.00	0.00	43	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2445	252	3	2	23.00	23.00	23.00	68.30	0.00	1.30	0.00	0.00	44	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2446	24	3	2	29.10	28.30	28.70	34.95	0.00	3.10	0.00	0.00	45	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2447	103	3	2	24.90	24.90	24.90	39.60	0.00	9.30	0.00	0.00	46	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2448	171	3	2	23.60	23.20	23.40	48.00	0.00	7.40	0.00	0.00	47	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2449	149	3	2	25.40	25.40	25.40	37.00	0.00	2.10	0.00	0.00	48	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2450	249	3	2	29.30	25.20	27.25	67.00	0.00	19.10	0.00	0.00	49	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2451	262	3	2	36.30	27.70	33.23	76.17	0.00	12.20	0.00	0.00	50	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2452	299	3	2	24.10	24.10	24.10	21.80	0.00	3.50	0.00	0.00	51	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2453	57	3	2	-2.00	-2.00	-2.00	75.70	0.00	6.60	0.00	0.00	52	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2454	37	3	2	30.60	22.70	26.07	44.73	0.00	21.80	0.00	0.00	53	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2455	153	3	2	37.30	7.80	27.10	48.90	0.00	15.90	0.00	0.00	54	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2456	138	3	2	25.90	25.90	25.90	50.40	0.00	8.20	0.00	0.00	55	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2457	137	3	2	29.10	29.10	29.10	36.30	0.00	2.50	0.00	0.00	56	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2458	151	3	2	10.40	10.40	10.40	45.10	0.00	0.30	0.00	0.00	57	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2459	257	3	2	25.70	19.70	23.50	49.43	0.00	3.60	0.00	0.00	58	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2460	46	3	2	10.00	10.00	10.00	36.70	0.00	7.00	0.00	0.00	59	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2461	281	3	2	9.90	9.90	9.90	49.60	0.00	11.10	0.00	0.00	60	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2462	92	3	2	27.00	27.00	27.00	58.90	0.00	19.60	0.00	0.00	61	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2463	303	3	2	5.50	4.00	4.80	50.13	0.00	1.30	0.00	0.00	62	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2464	319	3	2	23.20	5.40	14.30	51.35	0.00	16.70	0.00	0.00	63	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2465	43	3	2	25.10	25.10	25.10	30.70	0.00	8.00	0.00	0.00	64	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2466	69	3	2	8.40	6.90	7.65	44.70	0.00	27.60	0.00	0.00	65	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2467	232	3	2	26.50	26.50	26.50	28.60	0.00	1.00	0.00	0.00	66	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2468	54	3	2	33.50	33.50	33.50	51.30	0.00	13.60	0.00	0.00	67	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2469	119	3	2	24.20	8.60	16.40	50.40	0.00	8.70	0.00	0.00	68	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2470	101	3	2	24.50	24.50	24.50	23.20	0.00	2.80	0.00	0.00	69	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2471	322	3	2	26.50	26.50	26.50	31.00	0.00	0.50	0.00	0.00	70	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2472	56	3	2	31.80	24.20	28.00	71.10	0.00	6.00	0.00	0.00	71	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2473	297	3	2	27.90	27.90	27.90	58.00	0.00	5.20	0.00	0.00	72	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2474	90	3	2	37.30	37.30	37.30	40.20	0.00	29.70	0.00	0.00	73	66.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2475	194	3	2	37.40	37.40	37.40	45.20	0.00	1.90	0.00	0.00	74	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2476	150	3	2	33.70	11.00	25.00	44.87	0.00	24.60	0.00	0.00	75	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2477	52	3	2	24.40	24.40	24.40	45.40	0.00	2.00	0.00	0.00	76	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2478	308	3	2	9.20	4.30	6.75	39.60	0.00	36.10	0.00	0.00	77	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2479	245	3	2	24.80	24.80	24.80	39.00	0.00	1.90	0.00	0.00	78	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2480	126	3	2	20.60	20.00	20.30	42.70	0.00	4.70	0.00	0.00	79	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2481	73	3	2	34.60	34.60	34.60	46.10	0.00	5.10	0.00	0.00	80	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2482	309	3	2	24.60	12.30	18.45	40.35	0.00	16.20	0.00	0.00	81	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2483	53	3	2	31.20	24.40	27.80	38.20	0.00	22.40	0.00	0.00	82	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2484	87	3	2	36.00	11.20	23.60	50.35	0.00	15.20	0.00	0.00	83	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2485	28	3	2	26.60	6.80	16.70	44.35	0.00	1.00	0.00	0.00	84	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2486	49	3	2	24.20	24.20	24.20	35.10	0.00	7.00	0.00	0.00	85	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2487	239	3	2	32.30	32.30	32.30	50.00	0.00	2.60	0.00	0.00	86	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2488	290	3	2	2.40	2.40	2.40	42.20	0.00	0.40	0.00	0.00	87	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2489	75	3	2	25.10	25.10	25.10	39.10	0.00	2.50	0.00	0.00	88	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2490	131	3	2	12.80	5.10	8.95	64.15	0.00	1.10	0.00	0.00	89	35.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2491	71	3	2	32.70	24.70	28.70	52.20	0.00	16.60	0.00	0.00	90	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2492	19	3	2	27.10	27.10	27.10	64.60	0.00	8.20	0.00	0.00	91	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2493	2	3	2	30.10	26.20	28.63	42.43	0.00	25.90	0.00	0.00	92	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2494	287	3	2	26.60	26.60	26.60	56.10	0.00	17.80	0.00	0.00	93	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2495	190	3	2	31.60	21.40	26.50	34.05	0.00	37.90	0.00	0.00	94	64.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2496	227	3	2	28.10	10.60	19.35	46.50	0.00	9.80	0.00	0.00	95	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2497	104	3	2	30.10	30.10	30.10	39.90	0.00	1.20	0.00	0.00	96	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2498	34	3	2	34.90	9.50	23.73	44.50	0.00	23.50	0.00	0.00	97	60.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2499	108	3	2	33.40	21.30	27.35	36.10	0.00	38.50	0.00	0.00	98	66.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2500	229	3	2	33.10	22.80	29.53	57.10	0.00	21.20	0.00	0.00	99	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2501	271	3	2	31.70	31.70	31.70	56.50	0.00	5.60	0.00	0.00	100	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2502	291	3	2	23.20	23.20	23.20	37.20	0.00	1.00	0.00	0.00	101	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2503	195	3	2	34.50	34.50	34.50	50.70	0.00	10.50	0.00	0.00	102	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2504	83	3	2	24.10	24.10	24.10	46.10	0.00	18.70	0.00	0.00	103	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2505	242	3	2	29.70	23.30	26.50	44.50	0.00	11.50	0.00	0.00	104	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2506	213	3	2	25.20	25.20	25.20	28.00	0.00	0.90	0.00	0.00	105	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2507	96	3	2	32.00	24.10	27.00	55.10	0.00	20.70	0.00	0.00	106	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2508	84	3	2	6.50	6.50	6.50	48.70	0.00	2.10	0.00	0.00	107	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2509	159	3	2	31.40	18.00	24.70	57.95	0.00	46.00	0.00	0.00	108	62.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2510	305	3	2	27.70	27.70	27.70	70.20	0.00	1.60	0.00	0.00	109	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2511	25	3	2	9.50	5.60	7.55	42.80	0.00	41.30	0.00	0.00	110	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2512	5	3	2	23.50	23.50	23.50	53.60	0.00	1.00	0.00	0.00	111	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2513	112	3	2	26.30	4.30	18.95	41.33	0.00	10.80	0.00	0.00	112	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2514	304	3	2	6.50	6.50	6.50	40.90	0.00	3.00	0.00	0.00	113	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2515	6	3	2	19.70	19.70	19.70	44.60	0.00	2.30	0.00	0.00	114	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2516	235	3	2	38.20	10.30	22.73	37.63	0.00	16.40	0.00	0.00	115	62.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2517	4	3	2	34.80	31.20	33.10	51.70	0.00	26.50	0.00	0.00	116	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2518	32	3	2	5.80	5.80	5.80	54.20	0.00	4.20	0.00	0.00	117	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2519	283	3	2	39.80	26.10	33.33	38.20	0.00	29.90	0.00	0.00	118	70.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2520	270	3	2	22.20	22.20	22.20	62.30	0.00	0.40	0.00	0.00	119	35.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2521	244	3	2	23.70	23.70	23.70	54.00	0.00	3.80	0.00	0.00	120	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2522	147	3	2	23.60	6.10	14.85	35.75	0.00	13.20	0.00	0.00	121	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2523	14	3	2	29.60	25.10	26.70	44.47	0.00	14.40	0.00	0.00	122	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2524	317	3	2	39.30	39.30	39.30	56.80	0.00	2.10	0.00	0.00	123	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2525	176	3	2	35.00	22.10	28.55	40.45	0.00	18.80	0.00	0.00	124	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2526	68	3	2	31.00	31.00	31.00	42.50	0.00	9.60	0.00	0.00	125	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2527	161	3	2	23.20	23.20	23.20	51.90	0.00	8.00	0.00	0.00	126	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2528	48	3	2	10.90	10.90	10.90	42.10	0.00	3.90	0.00	0.00	127	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2529	170	3	2	35.00	35.00	35.00	49.10	0.00	1.20	0.00	0.00	128	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2530	261	3	2	5.30	5.30	5.30	26.00	0.00	21.00	0.00	0.00	129	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2531	318	3	2	4.70	4.70	4.70	59.90	0.00	26.20	0.00	0.00	130	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2532	246	3	2	23.60	23.30	23.45	55.45	0.00	25.20	0.00	0.00	131	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2533	228	3	2	34.50	3.50	22.63	43.73	0.00	13.80	0.00	0.00	132	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2534	219	3	2	31.30	31.30	31.30	33.90	0.00	3.00	0.00	0.00	133	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2535	26	3	2	28.40	28.40	28.40	73.50	0.00	0.20	0.00	0.00	134	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2536	7	3	2	41.00	2.80	21.90	28.45	0.00	12.40	0.00	0.00	135	66.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2537	182	3	2	28.30	28.30	28.30	55.00	0.00	1.50	0.00	0.00	136	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2538	231	3	2	26.90	20.30	23.60	65.00	0.00	16.00	0.00	0.00	137	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2539	223	3	2	36.80	3.20	24.77	52.37	0.00	20.70	0.00	0.00	138	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2540	226	3	2	30.60	30.60	30.60	22.90	0.00	27.30	0.00	0.00	139	61.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2541	70	3	2	21.50	21.50	21.50	50.80	0.00	29.30	0.00	0.00	140	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2542	230	3	2	9.40	9.40	9.40	37.20	0.00	4.30	0.00	0.00	141	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2543	154	3	2	24.20	24.20	24.20	80.20	0.00	33.50	0.00	0.00	142	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2544	180	3	2	31.90	31.90	31.90	58.60	0.00	9.50	0.00	0.00	143	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2545	225	3	2	23.30	4.00	13.65	49.90	0.00	4.50	0.00	0.00	144	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2546	74	3	2	25.90	25.90	25.90	51.70	0.00	0.30	0.00	0.00	145	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2547	169	3	2	26.10	26.10	26.10	67.20	0.00	22.60	0.00	0.00	146	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2548	132	3	2	34.20	34.20	34.20	58.20	0.00	6.50	0.00	0.00	147	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2549	45	3	2	28.40	28.40	28.40	44.50	0.00	19.10	0.00	0.00	148	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2550	217	3	2	24.00	24.00	24.00	53.90	0.00	29.40	0.00	0.00	149	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2551	185	3	2	22.00	18.10	20.05	51.85	0.00	3.50	0.00	0.00	150	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2552	50	3	2	25.10	2.70	17.17	37.17	0.00	11.80	0.00	0.00	151	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2553	183	3	2	28.90	28.90	28.90	50.30	0.00	1.70	0.00	0.00	152	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2554	276	3	2	36.40	28.60	32.50	42.50	0.00	3.10	0.00	0.00	153	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2555	85	3	2	27.10	27.10	27.10	54.70	0.00	4.60	0.00	0.00	154	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2556	148	3	2	39.60	13.20	22.70	51.03	0.00	10.50	0.00	0.00	155	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2557	313	3	2	40.80	7.30	24.05	70.15	0.00	11.40	0.00	0.00	156	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2558	197	3	2	25.70	25.70	25.70	52.30	0.00	4.20	0.00	0.00	157	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2559	253	3	2	33.40	10.30	21.85	39.50	0.00	14.10	0.00	0.00	158	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2560	156	3	2	36.50	36.50	36.50	21.60	0.00	5.30	0.00	0.00	159	60.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2561	269	3	2	31.80	31.80	31.80	48.50	0.00	13.10	0.00	0.00	160	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2562	321	3	2	23.90	20.60	22.25	42.30	0.00	9.50	0.00	0.00	161	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2563	188	3	2	39.30	22.30	31.13	52.37	0.00	26.50	0.00	0.00	162	64.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2564	260	3	2	25.20	25.20	25.20	47.40	0.00	22.10	0.00	0.00	163	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2565	273	3	2	30.20	30.20	30.20	74.70	0.00	2.80	0.00	0.00	164	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2566	152	3	2	40.00	35.70	37.85	53.10	0.00	58.70	0.00	0.00	165	75.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2567	47	3	2	29.60	25.90	27.75	56.20	0.00	17.20	0.00	0.00	166	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2568	177	3	2	16.10	16.10	16.10	65.20	0.00	1.20	0.00	0.00	167	35.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2569	196	3	2	36.70	24.90	30.80	44.65	0.00	11.60	0.00	0.00	168	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2570	162	3	2	24.60	24.60	24.60	56.30	0.00	20.50	0.00	0.00	169	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2571	294	3	2	38.40	23.80	31.10	47.20	0.00	48.10	0.00	0.00	170	73.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2572	105	3	2	26.90	8.40	17.65	43.85	0.00	12.00	0.00	0.00	171	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2573	284	3	2	33.00	4.10	18.55	47.70	0.00	6.90	0.00	0.00	172	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2574	88	3	2	26.10	26.10	26.10	64.30	0.00	19.60	0.00	0.00	173	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2575	111	3	2	30.50	30.50	30.50	8.30	0.00	3.90	0.00	0.00	174	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2576	250	3	2	36.00	5.10	20.55	61.50	0.00	1.70	0.00	0.00	175	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2577	236	3	2	27.20	22.00	24.60	49.55	0.00	6.80	0.00	0.00	176	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2578	140	3	2	33.90	25.30	29.60	52.05	0.00	13.00	0.00	0.00	177	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2579	274	3	2	25.00	5.00	17.43	41.37	0.00	5.90	0.00	0.00	178	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2580	248	3	2	24.30	24.30	24.30	35.00	0.00	1.80	0.00	0.00	179	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2581	146	3	2	38.80	38.80	38.80	67.90	0.00	8.30	0.00	0.00	180	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2582	207	3	2	12.00	12.00	12.00	40.30	0.00	2.70	0.00	0.00	181	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2583	72	3	2	22.80	22.80	22.80	18.10	0.00	26.60	0.00	0.00	182	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2584	186	3	2	34.70	34.70	34.70	44.40	0.00	5.00	0.00	0.00	183	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2585	179	3	2	35.00	35.00	35.00	71.00	0.00	5.30	0.00	0.00	184	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2586	320	3	2	24.90	24.90	24.90	63.10	0.00	4.00	0.00	0.00	185	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2587	173	3	2	26.40	7.90	17.15	35.45	0.00	2.50	0.00	0.00	186	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2588	307	3	2	43.00	43.00	43.00	59.80	0.00	1.90	0.00	0.00	187	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2589	203	3	2	36.80	24.90	30.85	38.60	0.00	6.70	0.00	0.00	188	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2590	201	3	2	27.20	27.20	27.20	41.70	0.00	6.30	0.00	0.00	189	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2591	221	3	2	25.40	25.40	25.40	42.60	0.00	2.70	0.00	0.00	190	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2592	279	3	2	6.20	6.20	6.20	28.90	0.00	19.10	0.00	0.00	191	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2593	67	3	2	30.50	30.50	30.50	37.10	0.00	19.80	0.00	0.00	192	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2594	324	3	2	27.00	27.00	27.00	74.70	0.00	0.10	0.00	0.00	193	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2595	29	3	2	8.60	8.60	8.60	43.50	0.00	30.60	0.00	0.00	194	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2596	144	3	2	37.90	8.20	19.65	47.68	0.00	32.20	0.00	0.00	195	66.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2597	95	3	2	3.30	3.30	3.30	60.10	0.00	11.60	0.00	0.00	196	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2598	158	3	2	9.00	9.00	9.00	51.00	0.00	49.60	0.00	0.00	197	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2599	20	3	2	35.00	9.30	22.15	30.45	0.00	17.80	0.00	0.00	198	61.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2600	123	3	2	33.70	33.70	33.70	60.20	0.00	0.90	0.00	0.00	199	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2601	94	3	2	26.40	11.80	19.10	55.05	0.00	24.90	0.00	0.00	200	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2602	237	3	2	33.20	29.20	31.20	40.55	0.00	12.70	0.00	0.00	201	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2603	77	3	2	24.70	23.50	24.10	45.05	0.00	4.50	0.00	0.00	202	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2604	23	3	2	27.20	27.20	27.20	66.60	0.00	0.90	0.00	0.00	203	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2605	42	3	2	25.80	8.40	17.10	42.15	0.00	6.10	0.00	0.00	204	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2606	288	3	2	23.40	11.60	18.27	53.80	0.00	3.20	0.00	0.00	205	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2607	106	3	2	4.30	4.30	4.30	63.80	0.00	0.40	0.00	0.00	206	35.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2608	99	3	2	8.40	8.40	8.40	23.80	0.00	27.90	0.00	0.00	207	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2609	93	3	2	25.50	10.10	17.80	23.25	0.00	26.50	0.00	0.00	208	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2610	293	3	2	31.40	9.90	20.65	61.30	0.00	1.30	0.00	0.00	209	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2611	12	3	2	25.40	21.80	23.60	34.90	0.00	22.20	0.00	0.00	210	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2612	175	3	2	26.70	10.30	18.50	62.10	0.00	10.60	0.00	0.00	211	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2613	133	3	2	36.70	36.70	36.70	21.60	0.00	4.20	0.00	0.00	212	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2614	114	3	2	38.60	29.20	33.90	36.10	0.00	1.20	0.00	0.00	213	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2615	265	3	2	37.50	25.20	33.33	54.33	0.00	15.20	0.00	0.00	214	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2616	82	3	2	33.20	7.60	22.67	43.90	0.00	20.60	0.00	0.00	215	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2617	27	3	2	9.60	9.60	9.60	51.90	0.00	11.90	0.00	0.00	216	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2618	222	3	2	11.70	11.70	11.70	48.00	0.00	2.80	0.00	0.00	217	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2619	36	3	2	20.20	20.20	20.20	39.70	0.00	3.40	0.00	0.00	218	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2620	129	3	2	25.80	25.80	25.80	57.70	0.00	21.20	0.00	0.00	219	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2621	292	3	2	33.00	33.00	33.00	47.70	0.00	7.00	0.00	0.00	220	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2622	58	3	2	12.60	12.60	12.60	68.40	0.00	16.90	0.00	0.00	221	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2623	110	1	2	25.20	24.70	24.95	35.55	7.20	12.70	0.00	7.20	0	4.00	Élevé	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2624	163	1	2	13.90	13.90	13.90	47.50	3.60	26.70	0.00	10.80	0	3.00	Élevé	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2625	218	1	2	28.10	24.30	26.20	41.70	7.20	7.60	0.00	18.00	0	0.00	Modéré	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2626	65	1	2	26.40	26.00	26.20	62.55	7.20	19.30	0.00	25.20	0	0.00	Modéré	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2627	22	1	2	31.50	28.80	30.15	52.75	7.20	60.80	0.00	32.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2628	174	1	2	14.00	14.00	14.00	47.70	3.60	1.40	0.00	36.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2629	267	1	2	13.10	13.10	13.10	60.60	3.60	5.50	0.00	39.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2630	124	1	2	33.20	26.40	29.80	68.95	7.20	8.90	0.00	46.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2631	277	1	2	11.10	11.10	11.10	57.80	3.60	16.70	0.00	50.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2632	102	1	2	26.00	8.00	17.00	45.05	7.20	52.30	0.00	57.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2633	38	1	2	29.40	23.50	26.45	44.20	7.20	11.40	0.00	64.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2634	35	1	2	32.10	31.70	31.90	60.75	7.20	24.10	0.00	72.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2635	18	1	2	27.80	23.70	25.13	47.73	10.80	19.90	0.00	82.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2636	118	1	2	29.80	29.80	29.80	47.90	3.60	10.50	0.00	86.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2637	266	1	2	10.80	8.70	9.75	57.35	7.20	10.30	0.00	93.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2638	240	1	2	25.00	25.00	25.00	54.20	3.60	26.40	0.00	97.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2639	168	1	2	34.60	34.60	34.60	66.20	3.60	14.40	0.00	100.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2640	165	1	2	24.90	24.90	24.90	27.10	3.60	9.80	0.00	104.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2641	62	1	2	39.40	39.40	39.40	55.40	3.60	2.50	0.00	108.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2642	285	1	2	33.00	33.00	33.00	61.60	3.60	17.70	0.00	104.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2643	63	1	2	31.90	22.50	27.20	31.10	7.20	21.60	0.00	100.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2644	202	1	2	28.50	24.30	26.40	41.85	7.20	35.20	0.00	108.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2645	200	1	2	25.10	25.10	25.10	25.60	3.60	4.00	0.00	111.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2646	275	1	2	33.00	33.00	33.00	39.50	3.60	16.70	0.00	100.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2647	134	1	2	33.60	20.80	27.20	66.20	7.20	8.40	0.00	104.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2648	155	1	2	24.50	13.30	20.63	42.27	10.80	11.60	0.00	111.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2649	80	1	2	25.40	13.10	19.25	68.60	7.20	9.30	0.00	108.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2650	136	1	2	24.70	24.70	24.70	42.10	3.60	40.60	0.00	104.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2651	11	1	2	27.80	10.40	20.50	52.83	10.80	19.20	0.00	108.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2652	1	1	2	28.20	28.20	28.20	43.70	3.60	1.80	0.00	111.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2653	241	1	2	27.10	23.80	25.45	49.55	7.20	12.90	0.00	111.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2654	167	1	2	24.80	24.80	24.80	67.60	3.60	2.90	0.00	104.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2655	166	1	2	28.80	6.90	15.23	49.33	10.80	34.90	0.00	111.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2656	193	1	2	14.10	11.70	12.90	63.00	7.20	17.70	0.00	111.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2657	139	1	2	32.40	23.60	28.00	58.90	7.20	2.00	0.00	115.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2658	301	1	2	25.30	25.30	25.30	35.40	3.60	7.60	0.00	104.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2659	142	1	2	30.10	9.20	19.65	56.00	7.20	5.10	0.00	111.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2660	122	1	2	38.90	23.00	29.42	54.02	18.00	43.30	0.00	129.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2661	252	1	2	17.90	16.30	17.10	48.60	7.20	8.80	0.00	122.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2662	24	1	2	34.00	34.00	34.00	56.00	3.60	0.40	0.00	122.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2663	21	1	2	28.60	21.90	24.63	38.70	10.80	16.30	0.00	133.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2664	192	1	2	24.50	13.50	19.00	58.35	7.20	17.70	0.00	118.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2665	171	1	2	21.10	21.10	21.10	47.90	3.60	4.70	0.00	111.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2666	249	1	2	23.90	18.50	21.20	53.90	7.20	10.60	0.00	104.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2667	299	1	2	28.80	28.80	28.80	25.80	3.60	22.90	0.00	100.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2668	37	1	2	23.80	11.40	17.60	51.55	7.20	20.80	0.00	93.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2669	153	1	2	22.30	9.00	15.65	42.90	7.20	19.60	0.00	93.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2670	138	1	2	15.60	15.60	15.60	33.90	3.60	28.20	0.00	97.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2671	137	1	2	31.80	31.80	31.80	64.30	3.60	14.30	0.00	93.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2672	151	1	2	31.90	24.10	28.00	73.95	7.20	10.30	0.00	100.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2673	257	1	2	29.40	29.40	29.40	36.30	3.60	26.70	0.00	104.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2674	281	1	2	29.80	29.80	29.80	58.60	3.60	24.10	0.00	108.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2675	92	1	2	35.70	35.70	35.70	62.30	3.60	1.60	0.00	100.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2676	234	1	2	29.80	29.80	29.80	37.80	3.60	3.00	0.00	104.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2677	79	1	2	27.50	23.20	25.35	38.55	7.20	5.30	0.00	93.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2678	303	1	2	12.80	12.80	12.80	49.10	3.60	5.10	0.00	97.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2679	69	1	2	23.70	23.70	23.70	59.60	3.60	18.40	0.00	79.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2680	306	1	2	10.70	10.70	10.70	43.00	3.60	9.80	0.00	82.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2681	254	1	2	22.50	22.50	22.50	53.20	3.60	16.20	0.00	86.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2682	232	1	2	28.00	28.00	28.00	39.20	3.60	19.20	0.00	82.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2683	54	1	2	31.90	31.90	31.90	46.00	3.60	14.90	0.00	82.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2684	119	1	2	24.80	24.80	24.80	45.50	3.60	18.10	0.00	86.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2685	101	1	2	31.90	10.40	23.04	49.08	18.00	16.20	0.00	97.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2686	56	1	2	23.50	23.50	23.50	57.30	3.60	3.70	0.00	97.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2687	297	1	2	31.10	31.10	31.10	28.40	3.60	6.10	0.00	100.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2688	90	1	2	16.20	16.20	16.20	54.50	3.60	10.00	0.00	97.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2689	194	1	2	27.00	22.80	24.90	38.90	7.20	9.10	0.00	97.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2690	150	1	2	9.40	9.40	9.40	43.30	3.60	6.70	0.00	97.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2691	52	1	2	29.30	29.30	29.30	62.00	3.60	7.00	0.00	97.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2692	308	1	2	10.10	10.10	10.10	31.10	3.60	12.60	0.00	93.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2693	245	1	2	23.50	14.90	19.13	49.43	14.40	49.60	0.00	104.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2694	126	1	2	26.60	22.70	24.65	57.40	7.20	3.30	0.00	111.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2695	204	1	2	31.10	31.10	31.10	42.60	3.60	8.70	0.00	108.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2696	53	1	2	28.30	8.40	20.03	40.10	10.80	14.40	0.00	115.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2697	3	1	2	15.00	12.40	13.70	47.65	7.20	5.20	0.00	115.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2698	300	1	2	30.10	30.10	30.10	30.10	3.60	3.80	0.00	115.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2699	87	1	2	27.70	22.00	24.85	72.95	7.20	14.70	0.00	122.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2700	28	1	2	17.70	17.70	17.70	36.40	3.60	2.00	0.00	122.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2701	212	1	2	34.30	13.10	20.27	43.73	10.80	33.30	0.00	129.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2702	8	1	2	24.70	24.60	24.65	47.35	7.20	17.30	0.00	136.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2703	239	1	2	9.70	9.70	9.70	58.70	3.60	10.50	0.00	133.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2704	290	1	2	24.60	15.50	20.05	59.15	7.20	22.20	0.00	140.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2705	75	1	2	22.40	22.40	22.40	46.50	3.60	7.80	0.00	140.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2706	131	1	2	37.70	37.70	37.70	66.70	3.60	1.40	0.00	140.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2707	71	1	2	28.30	9.30	18.80	52.65	7.20	33.80	0.00	129.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2708	19	1	2	25.60	25.60	25.60	51.90	3.60	4.90	0.00	133.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2709	190	1	2	28.20	27.50	27.85	51.75	7.20	23.00	0.00	122.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2710	227	1	2	31.10	31.10	31.10	60.40	3.60	12.40	0.00	122.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2711	104	1	2	26.50	26.50	26.50	70.40	3.60	8.40	0.00	122.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2712	108	1	2	34.40	34.40	34.40	60.40	3.60	19.40	0.00	108.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2713	251	1	2	8.00	8.00	8.00	56.60	3.60	1.90	0.00	104.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2714	64	1	2	23.50	16.20	19.85	62.95	7.20	7.00	0.00	111.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2715	229	1	2	10.20	10.20	10.20	49.60	3.60	17.30	0.00	100.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2716	39	1	2	29.90	29.90	29.90	61.90	3.60	29.90	0.00	97.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2717	271	1	2	28.10	27.00	27.60	52.33	10.80	17.10	0.00	104.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2718	195	1	2	15.00	15.00	15.00	56.10	3.60	9.70	0.00	100.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2719	59	1	2	31.20	31.20	31.20	54.30	3.60	25.20	0.00	100.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2720	295	1	2	27.30	27.30	27.30	49.20	3.60	8.60	0.00	86.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2721	96	1	2	32.20	32.20	32.20	38.10	3.60	9.60	0.00	75.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2722	84	1	2	26.10	11.20	18.65	37.15	7.20	14.00	0.00	79.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2723	159	1	2	28.30	28.30	28.30	65.80	3.60	5.50	0.00	75.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2724	5	1	2	10.60	10.60	10.60	49.50	3.60	18.70	0.00	68.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2725	112	1	2	31.80	31.80	31.80	46.90	3.60	15.40	0.00	68.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2726	13	1	2	32.00	19.40	25.70	48.85	7.20	19.40	0.00	72.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2727	278	1	2	36.60	36.60	36.60	64.40	3.60	33.10	0.00	75.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2728	172	1	2	31.90	29.80	30.85	51.10	7.20	31.50	0.00	79.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2729	61	1	2	28.20	28.20	28.20	54.50	3.60	0.60	0.00	82.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2730	304	1	2	24.00	24.00	24.00	51.40	3.60	0.40	0.00	82.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2731	311	1	2	5.40	5.40	5.40	53.90	3.60	1.10	0.00	79.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2732	6	1	2	26.20	26.20	26.20	58.00	3.60	36.50	0.00	79.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2733	235	1	2	28.50	28.50	28.50	72.80	3.60	4.70	0.00	79.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2734	32	1	2	20.00	7.70	14.67	41.30	10.80	21.20	0.00	75.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2735	66	1	2	33.60	8.90	21.25	48.35	7.20	14.50	0.00	79.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2736	206	1	2	32.90	13.00	22.95	74.80	7.20	11.10	0.00	86.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2737	283	1	2	14.70	14.70	14.70	50.70	3.60	8.30	0.00	86.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2738	270	1	2	33.90	16.80	26.47	49.30	10.80	28.20	0.00	97.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2739	244	1	2	24.00	8.30	15.50	55.17	10.80	7.80	0.00	108.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2740	147	1	2	28.40	21.80	25.10	52.75	7.20	11.70	0.00	115.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2741	272	1	2	31.30	23.70	27.50	78.80	7.20	2.70	0.00	111.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2742	282	1	2	33.70	33.70	33.70	43.60	3.60	4.60	0.00	111.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2743	100	1	2	17.40	17.40	17.40	50.60	3.60	3.90	0.00	115.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2744	176	1	2	33.40	14.90	24.15	42.15	7.20	26.80	0.00	122.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2745	68	1	2	10.70	10.70	10.70	25.60	3.60	2.10	0.00	126.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2746	161	1	2	24.50	24.30	24.40	69.90	7.20	7.00	0.00	129.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2747	48	1	2	25.70	16.50	21.10	55.80	7.20	10.00	0.00	133.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2748	170	1	2	30.90	30.90	30.90	49.40	3.60	9.10	0.00	129.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2749	261	1	2	31.30	30.80	31.05	46.70	7.20	6.70	0.00	133.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2750	318	1	2	36.00	36.00	36.00	31.00	3.60	1.40	0.00	129.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2751	228	1	2	27.90	27.90	27.90	55.30	3.60	16.00	0.00	126.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2752	26	1	2	27.70	26.10	26.90	47.60	7.20	25.20	0.00	129.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2753	259	1	2	16.00	16.00	16.00	59.70	3.60	2.60	0.00	126.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2754	182	1	2	27.00	27.00	27.00	11.60	3.60	8.90	0.00	129.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2755	231	1	2	33.00	33.00	33.00	74.20	3.60	13.10	0.00	122.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2756	223	1	2	32.10	29.60	30.85	33.15	7.20	13.30	0.00	122.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2757	226	1	2	22.50	9.60	16.05	63.10	7.20	1.90	0.00	122.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2758	70	1	2	34.50	34.50	34.50	62.70	3.60	2.20	0.00	122.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2759	230	1	2	13.70	9.90	11.80	63.15	7.20	16.90	0.00	118.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2760	154	1	2	32.70	32.70	32.70	87.10	3.60	11.80	0.00	111.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2761	74	1	2	11.90	11.90	11.90	29.70	3.60	0.10	0.00	97.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2762	116	1	2	31.10	28.30	29.70	51.10	7.20	12.40	0.00	104.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2763	45	1	2	14.50	8.20	11.35	50.90	7.20	2.30	0.00	97.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2764	191	1	2	26.00	26.00	26.00	38.30	3.60	26.80	0.00	93.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2765	217	1	2	27.60	9.10	18.35	62.50	7.20	3.10	0.00	93.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2766	44	1	2	31.00	10.80	20.90	69.95	7.20	29.70	0.00	86.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2767	143	1	2	11.50	11.50	11.50	76.20	3.60	9.20	0.00	90.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2768	164	1	2	23.60	12.10	17.85	47.10	7.20	13.90	0.00	93.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2769	205	1	2	25.30	16.40	22.23	40.97	10.80	8.30	0.00	97.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2770	183	1	2	24.40	24.30	24.35	54.85	7.20	29.30	0.00	104.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2771	89	1	2	28.80	27.90	28.35	58.65	7.20	19.10	0.00	104.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2772	85	1	2	23.50	12.70	16.63	70.00	10.80	33.50	0.00	111.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2773	148	1	2	24.60	24.60	24.60	37.90	3.60	1.20	0.00	108.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2774	197	1	2	24.40	15.60	19.60	56.63	10.80	25.10	0.00	108.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2775	253	1	2	10.60	10.60	10.60	50.40	3.60	7.70	0.00	104.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2776	156	1	2	22.30	22.30	22.30	71.00	3.60	7.20	0.00	104.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2777	188	1	2	21.40	21.40	21.40	64.10	3.60	5.30	0.00	108.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2778	260	1	2	13.90	13.90	13.90	64.00	3.60	9.10	0.00	108.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2779	280	1	2	23.60	23.60	23.60	64.40	3.60	7.60	0.00	104.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2780	220	1	2	32.10	24.30	28.20	63.75	7.20	9.10	0.00	111.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2781	152	1	2	28.10	14.10	21.10	55.95	7.20	19.00	0.00	111.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2782	187	1	2	34.70	23.30	27.20	57.83	10.80	24.40	0.00	118.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2783	17	1	2	26.10	25.80	25.95	52.85	7.20	6.40	0.00	118.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2784	296	1	2	32.20	32.20	32.20	36.20	3.60	0.10	0.00	122.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2785	30	1	2	30.40	30.40	30.40	65.50	3.60	9.10	0.00	126.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2786	47	1	2	32.60	29.40	31.00	54.40	7.20	3.00	0.00	126.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2787	177	1	2	25.80	25.80	25.80	87.90	3.60	1.40	0.00	126.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2788	196	1	2	31.80	31.80	31.80	32.40	3.60	9.80	0.00	122.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2789	162	1	2	33.90	25.00	29.45	44.85	7.20	37.80	0.00	129.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2790	294	1	2	10.30	10.30	10.30	66.80	3.60	3.20	0.00	122.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2791	105	1	2	9.40	9.40	9.40	52.50	3.60	2.00	0.00	118.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2792	55	1	2	13.70	13.70	13.70	43.70	3.60	14.20	0.00	122.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2793	284	1	2	19.40	19.40	19.40	44.40	3.60	33.90	0.00	126.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2794	109	1	2	38.50	24.60	28.50	37.83	14.40	29.40	0.00	122.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2795	316	1	2	33.70	33.70	33.70	37.00	3.60	4.50	0.00	108.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2796	250	1	2	26.80	26.80	26.80	50.30	3.60	2.00	0.00	108.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2797	286	1	2	15.40	15.40	15.40	35.30	3.60	4.70	0.00	111.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2798	236	1	2	31.90	31.90	31.90	25.80	3.60	10.00	0.00	115.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2799	140	1	2	29.40	26.10	27.75	54.95	7.20	9.70	0.00	118.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2800	274	1	2	27.90	22.70	25.30	52.75	7.20	10.60	0.00	122.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2801	146	1	2	26.20	23.80	25.00	55.20	7.20	12.60	0.00	118.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2802	117	1	2	30.10	24.00	27.05	50.65	7.20	10.30	0.00	118.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2803	233	1	2	34.30	34.30	34.30	45.50	3.60	17.90	0.00	104.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2804	72	1	2	26.30	26.30	26.30	32.80	3.60	10.10	0.00	104.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2805	186	1	2	24.30	24.30	24.30	72.10	3.60	8.10	0.00	104.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2806	179	1	2	32.60	25.50	28.30	51.90	10.80	4.70	0.00	108.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2807	264	1	2	25.50	24.50	25.00	47.70	7.20	6.40	0.00	108.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2808	97	1	2	25.70	22.30	24.00	47.20	7.20	15.50	0.00	108.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2809	173	1	2	28.50	22.90	25.70	50.60	7.20	28.70	0.00	111.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2810	307	1	2	26.50	26.50	26.50	50.70	3.60	5.70	0.00	111.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2811	203	1	2	36.10	36.10	36.10	26.50	3.60	21.50	0.00	111.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2812	201	1	2	10.30	8.30	9.30	44.95	7.20	41.10	0.00	115.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2813	279	1	2	27.80	27.80	27.80	60.50	3.60	6.30	0.00	104.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2814	324	1	2	29.90	10.70	23.23	51.67	10.80	13.20	0.00	108.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2815	144	1	2	20.70	20.70	20.70	60.40	3.60	0.40	0.00	104.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2816	158	1	2	29.10	22.50	25.80	63.65	7.20	29.60	0.00	97.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2817	20	1	2	29.00	29.00	29.00	27.70	3.60	7.50	0.00	100.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2818	123	1	2	30.00	30.00	30.00	43.90	3.60	16.70	0.00	104.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2819	15	1	2	27.10	19.40	23.25	53.60	7.20	11.70	0.00	97.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2820	198	1	2	34.20	34.20	34.20	40.80	3.60	1.40	0.00	100.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2821	247	1	2	33.20	25.50	29.35	59.70	7.20	10.20	0.00	86.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2822	23	1	2	24.00	24.00	24.00	53.90	3.60	4.60	0.00	90.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2823	42	1	2	28.60	16.30	23.63	54.25	14.40	17.80	0.00	97.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2824	107	1	2	22.60	20.00	21.30	60.40	7.20	30.80	0.00	97.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2825	141	1	2	28.60	23.60	26.10	31.70	7.20	11.10	0.00	97.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2826	288	1	2	25.90	23.20	24.55	59.00	7.20	13.90	0.00	97.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2827	128	1	2	26.80	26.80	26.80	73.80	3.60	9.20	0.00	100.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2828	106	1	2	31.10	15.80	23.45	58.00	7.20	2.40	0.00	100.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2829	99	1	2	34.60	22.10	28.35	61.85	7.20	9.50	0.00	108.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2830	93	1	2	13.80	13.80	13.80	65.40	3.60	27.90	0.00	111.60	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2831	51	1	2	33.00	22.60	27.80	50.85	7.20	5.60	0.00	115.20	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2832	293	1	2	31.20	31.20	31.20	81.00	3.60	30.90	0.00	118.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2833	209	1	2	28.90	11.10	20.00	36.00	7.20	10.60	0.00	126.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2834	12	1	2	22.70	22.70	22.70	35.00	3.60	6.10	0.00	118.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2835	114	1	2	24.60	24.60	24.60	41.40	3.60	0.70	0.00	118.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2836	265	1	2	30.40	21.20	26.37	43.77	10.80	7.00	0.00	122.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2837	113	1	2	26.70	26.70	26.70	44.20	3.60	6.60	0.00	118.80	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2838	27	1	2	22.10	17.90	20.00	40.20	7.20	6.70	0.00	126.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2839	181	1	2	31.80	31.80	31.80	45.10	3.60	6.10	0.00	122.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2840	60	1	2	32.00	30.20	31.10	53.35	7.20	18.30	0.00	126.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2841	222	1	2	25.90	25.90	25.90	60.60	3.60	2.60	0.00	122.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2842	36	1	2	24.70	24.70	24.70	48.80	3.60	21.80	0.00	122.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2843	292	1	2	24.70	24.70	24.70	38.20	3.60	3.70	0.00	104.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2844	58	1	2	34.50	24.60	29.55	54.20	7.20	1.80	0.00	104.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2845	178	1	2	37.90	37.90	37.90	36.00	3.60	13.70	0.00	108.00	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2846	16	1	2	13.00	13.00	13.00	41.70	3.60	8.50	0.00	104.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2847	184	1	2	28.30	28.30	28.30	45.00	3.60	12.00	0.00	104.40	0	0.00	Normal	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2848	289	8	2	30.00	13.40	21.70	54.55	0.00	45.90	0.00	0.00	1	27.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2849	130	8	2	22.10	22.10	22.10	16.10	0.00	4.90	0.00	0.00	2	15.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2850	163	8	2	33.60	7.70	23.33	46.17	0.00	54.10	0.00	0.00	3	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2851	33	8	2	30.00	16.10	23.05	54.90	0.00	6.10	0.00	0.00	4	17.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2852	218	8	2	31.10	31.10	31.10	49.90	0.00	0.80	0.00	0.00	5	19.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2853	256	8	2	25.70	11.10	18.40	56.30	0.00	6.40	0.00	0.00	6	15.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2854	22	8	2	25.70	25.70	25.70	38.60	0.00	16.00	0.00	0.00	7	24.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2855	174	8	2	24.00	24.00	24.00	45.30	0.00	4.10	0.00	0.00	8	19.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2856	267	8	2	22.30	22.30	22.30	59.60	0.00	14.00	0.00	0.00	9	21.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2857	124	8	2	26.80	26.80	26.80	21.40	0.00	9.40	0.00	0.00	10	32.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2858	102	8	2	25.10	7.70	16.40	52.25	0.00	16.80	0.00	0.00	11	28.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2859	189	8	2	28.70	28.70	28.70	54.80	0.00	2.90	0.00	0.00	12	28.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2860	157	8	2	23.70	23.70	23.70	56.30	0.00	8.40	0.00	0.00	13	27.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2861	18	8	2	35.30	35.30	35.30	57.70	0.00	19.30	0.00	0.00	14	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2862	266	8	2	25.40	13.10	19.25	36.20	0.00	5.50	0.00	0.00	15	34.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2863	240	8	2	35.50	35.50	35.50	56.90	0.00	2.40	0.00	0.00	16	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2864	91	8	2	28.20	21.50	24.85	39.80	0.00	8.30	0.00	0.00	17	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2865	168	8	2	26.60	26.60	26.60	40.80	0.00	2.40	0.00	0.00	18	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2866	165	8	2	25.70	25.70	25.70	63.80	0.00	0.60	0.00	0.00	19	34.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2867	62	8	2	30.60	16.50	23.55	55.55	0.00	21.30	0.00	0.00	20	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2868	285	8	2	33.90	13.90	23.90	52.50	0.00	14.20	0.00	0.00	21	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2869	125	8	2	25.70	25.70	25.70	53.60	0.00	7.20	0.00	0.00	22	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2870	243	8	2	31.30	29.20	30.25	41.95	0.00	10.90	0.00	0.00	23	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2871	98	8	2	33.20	28.60	30.90	37.65	0.00	5.00	0.00	0.00	24	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2872	63	8	2	5.60	5.60	5.60	30.20	0.00	27.00	0.00	0.00	25	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2873	202	8	2	11.80	11.80	11.80	35.20	0.00	51.30	0.00	0.00	26	61.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2874	200	8	2	21.50	21.50	21.50	44.60	0.00	21.80	0.00	0.00	27	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2875	76	8	2	30.70	30.70	30.70	47.60	0.00	15.70	0.00	0.00	28	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2876	275	8	2	32.60	32.60	32.60	8.50	0.00	4.70	0.00	0.00	29	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2877	134	8	2	29.20	19.80	24.50	65.25	0.00	11.70	0.00	0.00	30	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2878	80	8	2	26.50	26.50	26.50	56.80	0.00	14.20	0.00	0.00	31	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2879	136	8	2	10.80	10.80	10.80	27.10	0.00	29.50	0.00	0.00	32	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2880	1	8	2	25.80	25.80	25.80	29.90	0.00	27.20	0.00	0.00	33	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2881	166	8	2	22.20	22.20	22.20	56.90	0.00	14.10	0.00	0.00	34	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2882	193	8	2	14.20	14.20	14.20	74.70	0.00	33.10	0.00	0.00	35	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2883	215	8	2	34.50	32.90	33.70	45.20	0.00	5.10	0.00	0.00	36	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2884	139	8	2	14.30	14.30	14.30	40.20	0.00	1.10	0.00	0.00	37	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2885	31	8	2	12.60	12.60	12.60	62.40	0.00	8.10	0.00	0.00	38	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2886	145	8	2	19.00	19.00	19.00	37.40	0.00	4.40	0.00	0.00	39	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2887	301	8	2	24.20	24.20	24.20	39.70	0.00	4.90	0.00	0.00	40	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2888	142	8	2	34.80	24.40	29.60	31.20	0.00	20.10	0.00	0.00	41	61.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2889	216	8	2	11.80	11.80	11.80	32.30	0.00	3.00	0.00	0.00	42	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2890	122	8	2	27.90	27.90	27.90	65.50	0.00	5.70	0.00	0.00	43	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2891	135	8	2	29.60	14.80	22.20	56.90	0.00	12.40	0.00	0.00	44	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2892	21	8	2	29.90	21.40	25.65	28.05	0.00	4.30	0.00	0.00	45	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2893	103	8	2	22.90	22.90	22.90	87.40	0.00	14.30	0.00	0.00	46	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2894	192	8	2	22.30	22.30	22.30	49.10	0.00	4.20	0.00	0.00	47	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2895	149	8	2	24.40	22.90	23.65	41.70	0.00	9.60	0.00	0.00	48	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2896	249	8	2	22.70	8.70	15.70	53.95	0.00	9.20	0.00	0.00	49	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2897	262	8	2	24.30	24.30	24.30	51.60	0.00	39.10	0.00	0.00	50	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2898	299	8	2	23.50	23.50	23.50	28.60	0.00	24.10	0.00	0.00	51	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2899	57	8	2	27.80	27.80	27.80	35.10	0.00	6.60	0.00	0.00	52	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2900	37	8	2	34.90	27.80	31.35	44.70	0.00	20.40	0.00	0.00	53	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2901	153	8	2	37.40	22.50	29.95	43.05	0.00	7.50	0.00	0.00	54	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2902	137	8	2	21.30	18.40	19.85	55.40	0.00	43.40	0.00	0.00	55	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2903	151	8	2	33.80	8.90	21.35	35.70	0.00	9.90	0.00	0.00	56	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2904	257	8	2	29.70	14.10	21.90	23.55	0.00	19.00	0.00	0.00	57	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2905	46	8	2	29.20	22.60	25.90	37.90	0.00	16.20	0.00	0.00	58	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2906	281	8	2	25.80	25.80	25.80	53.20	0.00	2.90	0.00	0.00	59	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2907	92	8	2	24.00	24.00	24.00	52.70	0.00	0.30	0.00	0.00	60	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2908	234	8	2	36.20	31.90	34.05	50.35	0.00	31.90	0.00	0.00	61	63.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2909	79	8	2	27.70	13.30	20.87	50.40	0.00	27.20	0.00	0.00	62	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2910	319	8	2	23.40	23.40	23.40	67.20	0.00	3.10	0.00	0.00	63	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2911	69	8	2	31.00	20.50	25.75	45.85	0.00	18.10	0.00	0.00	64	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2912	121	8	2	30.90	30.90	30.90	35.50	0.00	3.40	0.00	0.00	65	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2913	254	8	2	28.20	7.40	14.97	43.33	0.00	13.00	0.00	0.00	66	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2914	119	8	2	32.40	10.40	22.00	38.10	0.00	11.20	0.00	0.00	67	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2915	322	8	2	30.90	24.20	27.55	51.10	0.00	6.30	0.00	0.00	68	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2916	297	8	2	25.90	20.20	23.40	43.13	0.00	7.70	0.00	0.00	69	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2917	90	8	2	24.80	10.60	17.70	40.05	0.00	8.00	0.00	0.00	70	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2918	194	8	2	27.40	27.40	27.40	82.40	0.00	5.00	0.00	0.00	71	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2919	150	8	2	34.10	34.10	34.10	29.30	0.00	0.30	0.00	0.00	72	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2920	52	8	2	26.30	22.50	24.60	46.27	0.00	12.10	0.00	0.00	73	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2921	245	8	2	18.30	18.30	18.30	43.70	0.00	0.60	0.00	0.00	74	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2922	126	8	2	21.60	21.60	21.60	40.30	0.00	2.60	0.00	0.00	75	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2923	73	8	2	27.20	27.20	27.20	54.90	0.00	6.60	0.00	0.00	76	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2924	309	8	2	8.40	8.40	8.40	57.70	0.00	4.50	0.00	0.00	77	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2925	204	8	2	26.00	26.00	26.00	38.50	0.00	0.90	0.00	0.00	78	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2926	3	8	2	24.40	24.40	24.40	57.40	0.00	1.50	0.00	0.00	79	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2927	300	8	2	28.40	11.40	21.73	53.40	0.00	14.90	0.00	0.00	80	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2928	28	8	2	21.40	14.80	18.10	58.60	0.00	19.70	0.00	0.00	81	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2929	49	8	2	25.70	23.00	24.35	37.25	0.00	8.90	0.00	0.00	82	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2930	239	8	2	36.20	36.20	36.20	53.40	0.00	2.60	0.00	0.00	83	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2931	290	8	2	14.10	14.10	14.10	61.00	0.00	11.60	0.00	0.00	84	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2932	75	8	2	23.20	23.20	23.20	40.40	0.00	12.00	0.00	0.00	85	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2933	71	8	2	32.60	21.40	29.35	44.68	0.00	23.00	0.00	0.00	86	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2934	2	8	2	27.70	27.70	27.70	62.70	0.00	6.40	0.00	0.00	87	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2935	263	8	2	21.60	21.60	21.60	64.60	0.00	8.40	0.00	0.00	88	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2936	190	8	2	32.30	24.50	28.40	37.20	0.00	30.90	0.00	0.00	89	61.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2937	227	8	2	24.80	20.10	22.45	65.80	0.00	26.80	0.00	0.00	90	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2938	104	8	2	28.60	28.60	28.60	35.80	0.00	0.10	0.00	0.00	91	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2939	108	8	2	21.50	21.50	21.50	38.80	0.00	27.30	0.00	0.00	92	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2940	314	8	2	11.40	11.40	11.40	64.80	0.00	1.20	0.00	0.00	93	35.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2941	251	8	2	26.00	26.00	26.00	20.80	0.00	7.90	0.00	0.00	94	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2942	64	8	2	34.00	34.00	34.00	58.70	0.00	8.20	0.00	0.00	95	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2943	229	8	2	28.70	8.70	18.70	47.05	0.00	4.90	0.00	0.00	96	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2944	271	8	2	24.70	12.60	16.73	43.80	0.00	17.60	0.00	0.00	97	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2945	291	8	2	30.50	13.50	24.43	35.43	0.00	18.40	0.00	0.00	98	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2946	195	8	2	29.20	10.00	21.17	36.97	0.00	11.90	0.00	0.00	99	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2947	59	8	2	33.70	26.30	30.00	48.30	0.00	8.00	0.00	0.00	100	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2948	81	8	2	28.80	12.70	20.75	36.65	0.00	11.20	0.00	0.00	101	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2949	213	8	2	32.10	32.10	32.10	37.70	0.00	21.50	0.00	0.00	102	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2950	84	8	2	31.40	31.40	31.40	41.80	0.00	37.70	0.00	0.00	103	62.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2951	160	8	2	31.50	31.50	31.50	60.10	0.00	23.20	0.00	0.00	104	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2952	305	8	2	32.90	26.90	29.90	48.90	0.00	13.50	0.00	0.00	105	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2953	25	8	2	28.80	28.80	28.80	61.70	0.00	3.30	0.00	0.00	106	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2954	5	8	2	22.50	13.90	18.20	41.20	0.00	10.10	0.00	0.00	107	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2955	13	8	2	34.70	34.70	34.70	48.20	0.00	4.70	0.00	0.00	108	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2956	278	8	2	22.10	11.00	16.55	57.45	0.00	13.00	0.00	0.00	109	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2957	61	8	2	29.50	20.50	25.00	58.85	0.00	6.30	0.00	0.00	110	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2958	311	8	2	27.60	22.30	24.27	49.30	0.00	16.40	0.00	0.00	111	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2959	235	8	2	27.20	15.60	21.40	50.45	0.00	26.80	0.00	0.00	112	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2960	302	8	2	30.80	12.00	21.40	34.20	0.00	17.90	0.00	0.00	113	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2961	4	8	2	14.20	14.20	14.20	38.20	0.00	0.20	0.00	0.00	114	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2962	66	8	2	36.90	8.80	23.53	43.33	0.00	16.30	0.00	0.00	115	60.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2963	206	8	2	31.50	12.20	21.85	52.20	0.00	10.70	0.00	0.00	116	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2964	283	8	2	38.70	28.50	33.60	58.40	0.00	9.30	0.00	0.00	117	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2965	244	8	2	34.10	25.80	28.70	48.50	0.00	10.20	0.00	0.00	118	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2966	14	8	2	40.20	40.20	40.20	24.50	0.00	0.40	0.00	0.00	119	61.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2967	282	8	2	23.30	9.40	16.35	58.55	0.00	2.60	0.00	0.00	120	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2968	176	8	2	28.40	28.40	28.40	26.30	0.00	2.30	0.00	0.00	121	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2969	48	8	2	9.20	9.20	9.20	60.00	0.00	11.10	0.00	0.00	122	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2970	170	8	2	28.80	23.90	26.35	68.00	0.00	41.00	0.00	0.00	123	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2971	246	8	2	9.80	9.70	9.75	54.25	0.00	17.90	0.00	0.00	124	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2972	219	8	2	35.50	11.10	23.30	64.30	0.00	25.40	0.00	0.00	125	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2973	26	8	2	30.00	17.10	24.95	49.60	0.00	17.30	0.00	0.00	126	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2974	259	8	2	20.30	20.30	20.30	65.70	0.00	18.00	0.00	0.00	127	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2975	7	8	2	14.00	14.00	14.00	80.20	0.00	23.40	0.00	0.00	128	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2976	231	8	2	29.20	9.70	17.43	45.97	0.00	4.00	0.00	0.00	129	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2977	70	8	2	31.80	31.80	31.80	54.30	0.00	14.70	0.00	0.00	130	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2978	154	8	2	18.20	18.20	18.20	41.30	0.00	7.30	0.00	0.00	131	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2979	225	8	2	20.90	20.90	20.90	59.30	0.00	1.30	0.00	0.00	132	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2980	211	8	2	25.00	11.70	18.35	60.70	0.00	24.00	0.00	0.00	133	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2981	74	8	2	29.80	6.00	17.90	57.30	0.00	42.00	0.00	0.00	134	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2982	169	8	2	32.00	23.10	26.63	50.23	0.00	10.50	0.00	0.00	135	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2983	132	8	2	30.40	26.90	28.93	62.73	0.00	9.30	0.00	0.00	136	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2984	45	8	2	12.00	12.00	12.00	69.80	0.00	7.20	0.00	0.00	137	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2985	191	8	2	13.50	13.50	13.50	77.60	0.00	2.20	0.00	0.00	138	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2986	44	8	2	16.70	16.70	16.70	26.10	0.00	11.50	0.00	0.00	139	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2987	143	8	2	14.90	14.90	14.90	63.50	0.00	21.10	0.00	0.00	140	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2988	50	8	2	33.90	23.30	28.60	52.00	0.00	11.60	0.00	0.00	141	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2989	205	8	2	27.60	27.60	27.60	51.40	0.00	8.80	0.00	0.00	142	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2990	183	8	2	25.00	25.00	25.00	30.30	0.00	25.20	0.00	0.00	143	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2991	276	8	2	29.60	25.00	27.30	40.05	0.00	2.70	0.00	0.00	144	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2992	89	8	2	14.90	14.90	14.90	34.70	0.00	24.20	0.00	0.00	145	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2993	85	8	2	22.50	22.50	22.50	92.30	0.00	4.10	0.00	0.00	146	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2994	313	8	2	28.00	27.60	27.80	48.15	0.00	50.60	0.00	0.00	147	61.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2995	197	8	2	11.70	11.70	11.70	70.80	0.00	14.80	0.00	0.00	148	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2996	253	8	2	30.70	12.40	24.40	51.75	0.00	26.00	0.00	0.00	149	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2997	269	8	2	29.20	28.70	28.95	37.50	0.00	8.90	0.00	0.00	150	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2998	188	8	2	36.40	30.90	33.65	47.60	0.00	1.50	0.00	0.00	151	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
2999	260	8	2	36.00	22.40	27.57	47.37	0.00	26.00	0.00	0.00	152	61.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3000	280	8	2	27.10	24.20	25.47	55.90	0.00	20.40	0.00	0.00	153	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3001	273	8	2	28.10	9.90	17.60	63.80	0.00	22.10	0.00	0.00	154	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3002	187	8	2	23.90	23.90	23.90	32.00	0.00	0.50	0.00	0.00	155	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3003	17	8	2	15.20	15.20	15.20	62.90	0.00	0.70	0.00	0.00	156	35.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3004	296	8	2	33.10	33.10	33.10	61.60	0.00	6.50	0.00	0.00	157	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3005	177	8	2	34.60	24.70	30.47	46.80	0.00	2.80	0.00	0.00	158	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3006	196	8	2	16.00	16.00	16.00	68.80	0.00	14.20	0.00	0.00	159	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3007	294	8	2	24.90	24.90	24.90	32.60	0.00	1.30	0.00	0.00	160	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3008	105	8	2	26.80	26.80	26.80	59.80	0.00	6.30	0.00	0.00	161	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3009	284	8	2	16.20	16.20	16.20	38.00	0.00	29.10	0.00	0.00	162	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3010	41	8	2	27.60	9.10	18.35	63.35	0.00	7.40	0.00	0.00	163	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3011	109	8	2	30.80	17.30	24.60	31.80	0.00	13.30	0.00	0.00	164	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3012	88	8	2	33.00	10.40	21.70	37.15	0.00	12.30	0.00	0.00	165	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3013	298	8	2	31.50	7.30	19.40	42.90	0.00	14.00	0.00	0.00	166	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3014	111	8	2	23.20	23.20	23.20	61.30	0.00	11.10	0.00	0.00	167	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3015	316	8	2	28.70	18.50	23.60	41.10	0.00	5.70	0.00	0.00	168	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3016	250	8	2	20.90	20.90	20.90	42.90	0.00	9.20	0.00	0.00	169	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3017	286	8	2	37.70	37.70	37.70	53.30	0.00	0.80	0.00	0.00	170	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3018	236	8	2	21.30	21.30	21.30	30.80	0.00	8.70	0.00	0.00	171	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3019	140	8	2	22.60	22.60	22.60	32.70	0.00	15.60	0.00	0.00	172	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3020	224	8	2	22.60	22.60	22.60	16.20	0.00	5.40	0.00	0.00	173	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3021	248	8	2	29.30	14.10	24.03	45.10	0.00	22.40	0.00	0.00	174	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3022	146	8	2	32.50	32.50	32.50	23.50	0.00	11.00	0.00	0.00	175	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3023	117	8	2	23.20	11.20	19.07	54.67	0.00	10.00	0.00	0.00	176	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3024	207	8	2	32.90	32.90	32.90	19.10	0.00	7.10	0.00	0.00	177	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3025	186	8	2	16.50	8.30	12.40	38.65	0.00	24.70	0.00	0.00	178	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3026	179	8	2	27.30	27.30	27.30	47.20	0.00	2.90	0.00	0.00	179	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3027	320	8	2	33.80	21.00	27.93	57.53	0.00	8.20	0.00	0.00	180	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3028	264	8	2	28.00	28.00	28.00	75.60	0.00	4.60	0.00	0.00	181	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3029	97	8	2	35.30	34.20	34.75	56.55	0.00	10.40	0.00	0.00	182	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3030	173	8	2	5.70	5.70	5.70	39.40	0.00	8.10	0.00	0.00	183	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3031	307	8	2	14.10	14.10	14.10	37.70	0.00	14.10	0.00	0.00	184	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3032	203	8	2	31.40	29.30	30.35	41.10	0.00	11.70	0.00	0.00	185	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3033	201	8	2	8.00	8.00	8.00	62.50	0.00	5.50	0.00	0.00	186	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3034	9	8	2	28.30	13.90	21.10	43.50	0.00	22.50	0.00	0.00	187	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3035	67	8	2	33.50	26.00	29.75	59.70	0.00	19.10	0.00	0.00	188	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3036	324	8	2	24.50	22.70	23.60	58.15	0.00	7.00	0.00	0.00	189	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3037	29	8	2	32.60	12.30	23.57	46.10	0.00	21.00	0.00	0.00	190	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3038	144	8	2	14.10	13.60	13.85	51.40	0.00	9.70	0.00	0.00	191	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3039	158	8	2	24.70	24.70	24.70	56.40	0.00	15.00	0.00	0.00	192	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3040	15	8	2	31.30	28.30	30.27	54.43	0.00	25.50	0.00	0.00	193	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3041	94	8	2	25.40	25.40	25.40	70.00	0.00	3.30	0.00	0.00	194	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3042	237	8	2	28.40	23.20	25.80	55.70	0.00	11.20	0.00	0.00	195	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3043	77	8	2	26.40	22.10	24.17	47.87	0.00	20.30	0.00	0.00	196	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3044	23	8	2	31.00	31.00	31.00	54.80	0.00	2.20	0.00	0.00	197	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3045	107	8	2	28.50	28.50	28.50	61.80	0.00	6.70	0.00	0.00	198	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3046	141	8	2	29.40	29.40	29.40	45.20	0.00	1.00	0.00	0.00	199	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3047	199	8	2	35.40	26.60	31.00	35.30	0.00	9.80	0.00	0.00	200	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3048	288	8	2	30.30	10.40	20.35	45.80	0.00	15.90	0.00	0.00	201	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3049	128	8	2	25.40	25.40	25.40	40.70	0.00	3.40	0.00	0.00	202	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3050	106	8	2	36.30	30.20	33.25	65.55	0.00	13.70	0.00	0.00	203	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3051	51	8	2	24.20	24.20	24.20	43.30	0.00	27.90	0.00	0.00	204	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3052	293	8	2	6.80	6.80	6.80	57.70	0.00	16.30	0.00	0.00	205	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3053	175	8	2	36.00	31.50	33.75	49.85	0.00	13.70	0.00	0.00	206	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3054	133	8	2	26.40	13.90	20.15	40.95	0.00	17.70	0.00	0.00	207	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3055	265	8	2	33.10	10.70	21.90	50.00	0.00	24.20	0.00	0.00	208	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3056	82	8	2	22.80	22.80	22.80	47.80	0.00	19.30	0.00	0.00	209	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3057	27	8	2	32.70	14.10	23.40	23.80	0.00	17.10	0.00	0.00	210	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3058	181	8	2	32.20	25.10	28.65	55.00	0.00	22.10	0.00	0.00	211	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3059	60	8	2	26.10	24.00	25.05	50.40	0.00	23.20	0.00	0.00	212	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3060	10	8	2	24.60	24.60	24.60	31.00	0.00	1.90	0.00	0.00	213	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3061	222	8	2	26.50	26.50	26.50	25.90	0.00	14.00	0.00	0.00	214	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3062	129	8	2	38.40	19.60	29.00	46.40	0.00	6.00	0.00	0.00	215	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3063	292	8	2	22.10	15.90	19.00	58.80	0.00	10.50	0.00	0.00	216	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3064	58	8	2	26.50	26.50	26.50	36.70	0.00	12.50	0.00	0.00	217	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3065	178	8	2	28.00	16.00	21.17	51.27	0.00	16.30	0.00	0.00	218	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3066	16	8	2	26.40	26.40	26.40	48.10	0.00	11.10	0.00	0.00	219	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3067	184	8	2	23.20	23.20	23.20	56.00	0.00	8.70	0.00	0.00	220	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3068	289	5	2	31.80	31.80	31.80	54.00	0.00	6.20	0.00	0.00	1	14.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3069	163	5	2	36.20	22.20	29.20	45.75	0.00	1.90	0.00	0.00	2	21.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3070	33	5	2	33.80	33.80	33.80	78.50	0.00	15.50	0.00	0.00	3	22.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3071	256	5	2	32.90	8.40	19.60	53.60	0.00	26.80	0.00	0.00	4	29.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3072	65	5	2	15.40	15.40	15.40	64.20	0.00	12.20	0.00	0.00	5	14.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3073	22	5	2	25.10	9.60	17.35	41.55	0.00	25.80	0.00	0.00	6	25.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3074	174	5	2	34.50	8.60	23.47	35.87	0.00	7.90	0.00	0.00	7	32.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3075	267	5	2	20.30	20.30	20.30	53.30	0.00	20.00	0.00	0.00	8	24.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3076	124	5	2	28.50	28.50	28.50	58.60	0.00	16.00	0.00	0.00	9	27.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3077	102	5	2	30.30	30.30	30.30	30.00	0.00	4.60	0.00	0.00	10	32.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3078	189	5	2	25.00	25.00	25.00	54.40	0.00	1.60	0.00	0.00	11	21.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3079	157	5	2	19.80	19.80	19.80	39.40	0.00	5.60	0.00	0.00	12	28.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3080	18	5	2	24.00	11.30	20.30	59.93	0.00	20.60	0.00	0.00	13	31.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3081	118	5	2	27.50	27.50	27.50	50.50	0.00	11.50	0.00	0.00	14	34.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3082	240	5	2	35.80	35.80	35.80	64.90	0.00	2.80	0.00	0.00	15	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3083	91	5	2	29.40	12.20	20.80	31.35	0.00	9.40	0.00	0.00	16	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3084	168	5	2	27.50	23.90	25.70	73.35	0.00	17.50	0.00	0.00	17	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3085	165	5	2	27.80	12.50	20.15	44.20	0.00	1.60	0.00	0.00	18	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3086	62	5	2	34.60	26.20	30.40	37.80	0.00	19.40	0.00	0.00	19	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3087	125	5	2	33.40	6.80	19.43	49.18	0.00	22.00	0.00	0.00	20	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3088	243	5	2	33.40	21.60	27.60	68.20	0.00	49.40	0.00	0.00	21	65.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3089	63	5	2	9.70	7.90	8.80	47.15	0.00	13.50	0.00	0.00	22	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3090	200	5	2	29.20	27.20	28.20	52.60	0.00	23.70	0.00	0.00	23	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3091	76	5	2	24.90	24.90	24.90	27.00	0.00	7.10	0.00	0.00	24	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3092	275	5	2	37.80	37.80	37.80	29.40	0.00	12.20	0.00	0.00	25	62.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3093	155	5	2	28.50	25.70	27.10	48.95	0.00	6.20	0.00	0.00	26	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3094	268	5	2	38.10	28.80	33.57	51.80	0.00	29.10	0.00	0.00	27	64.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3095	80	5	2	27.50	17.50	22.50	52.15	0.00	20.00	0.00	0.00	28	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3096	136	5	2	25.90	25.90	25.90	44.60	0.00	18.60	0.00	0.00	29	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3097	1	5	2	24.80	24.80	24.80	54.20	0.00	20.30	0.00	0.00	30	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3098	325	5	2	34.30	34.30	34.30	43.20	0.00	6.50	0.00	0.00	31	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3099	241	5	2	25.30	25.30	25.30	65.50	0.00	9.50	0.00	0.00	32	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3100	166	5	2	24.60	11.90	17.37	56.73	0.00	32.10	0.00	0.00	33	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3101	139	5	2	26.20	14.10	20.15	23.20	0.00	2.70	0.00	0.00	34	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3102	210	5	2	23.40	23.40	23.40	50.30	0.00	4.60	0.00	0.00	35	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3103	310	5	2	11.50	11.50	11.50	51.20	0.00	7.60	0.00	0.00	36	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3104	312	5	2	24.60	11.10	19.47	64.67	0.00	25.20	0.00	0.00	37	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3105	142	5	2	11.60	11.60	11.60	34.20	0.00	0.40	0.00	0.00	38	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3106	216	5	2	26.60	26.60	26.60	44.50	0.00	0.50	0.00	0.00	39	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3107	122	5	2	10.30	10.30	10.30	40.90	0.00	3.60	0.00	0.00	40	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3108	135	5	2	28.20	27.90	28.05	42.20	0.00	1.70	0.00	0.00	41	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3109	24	5	2	24.00	24.00	24.00	51.00	0.00	5.80	0.00	0.00	42	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3110	103	5	2	28.80	28.80	28.80	60.30	0.00	16.00	0.00	0.00	43	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3111	86	5	2	30.70	30.70	30.70	42.30	0.00	0.30	0.00	0.00	44	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3112	192	5	2	13.70	13.70	13.70	31.50	0.00	14.10	0.00	0.00	45	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3113	171	5	2	30.10	13.70	21.90	44.60	0.00	12.20	0.00	0.00	46	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3114	149	5	2	8.70	8.70	8.70	54.40	0.00	9.90	0.00	0.00	47	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3115	249	5	2	24.90	24.90	24.90	55.60	0.00	9.90	0.00	0.00	48	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3116	262	5	2	11.10	11.10	11.10	32.90	0.00	2.60	0.00	0.00	49	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3117	299	5	2	25.90	25.80	25.85	47.85	0.00	4.20	0.00	0.00	50	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3118	37	5	2	23.40	22.50	22.95	38.80	0.00	11.00	0.00	0.00	51	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3119	153	5	2	9.30	9.30	9.30	57.90	0.00	5.00	0.00	0.00	52	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3120	138	5	2	30.90	25.70	28.30	47.15	0.00	28.60	0.00	0.00	53	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3121	257	5	2	25.80	25.80	25.80	39.60	0.00	2.70	0.00	0.00	54	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3122	46	5	2	24.10	24.10	24.10	12.50	0.00	8.10	0.00	0.00	55	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3123	281	5	2	24.90	24.90	24.90	43.50	0.00	13.10	0.00	0.00	56	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3124	234	5	2	13.50	13.50	13.50	52.90	0.00	15.90	0.00	0.00	57	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3125	79	5	2	33.70	24.20	28.95	50.75	0.00	11.70	0.00	0.00	58	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3126	303	5	2	18.20	18.20	18.20	22.80	0.00	2.70	0.00	0.00	59	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3127	43	5	2	24.00	24.00	24.00	47.20	0.00	3.30	0.00	0.00	60	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3128	306	5	2	33.20	29.20	31.20	64.85	0.00	7.30	0.00	0.00	61	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3129	254	5	2	33.50	33.50	33.50	44.50	0.00	11.80	0.00	0.00	62	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3130	54	5	2	24.40	24.40	24.40	29.10	0.00	1.00	0.00	0.00	63	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3131	119	5	2	30.10	25.50	27.80	62.15	0.00	31.50	0.00	0.00	64	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3132	101	5	2	35.40	35.40	35.40	46.20	0.00	0.90	0.00	0.00	65	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3133	297	5	2	27.80	27.80	27.80	59.20	0.00	8.50	0.00	0.00	66	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3134	90	5	2	34.90	34.90	34.90	31.90	0.00	16.70	0.00	0.00	67	60.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3135	194	5	2	9.40	9.40	9.40	38.20	0.00	2.40	0.00	0.00	68	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3136	150	5	2	13.50	13.50	13.50	35.80	0.00	0.20	0.00	0.00	69	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3137	245	5	2	31.10	29.20	30.15	58.45	0.00	18.70	0.00	0.00	70	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3138	126	5	2	33.00	10.40	21.70	55.90	0.00	9.70	0.00	0.00	71	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3139	309	5	2	33.40	33.40	33.40	26.70	0.00	1.40	0.00	0.00	72	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3140	53	5	2	32.30	12.30	22.30	57.85	0.00	3.10	0.00	0.00	73	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3141	3	5	2	20.30	20.30	20.30	59.60	0.00	10.20	0.00	0.00	74	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3142	300	5	2	28.50	13.20	20.85	45.10	0.00	20.50	0.00	0.00	75	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3143	208	5	2	27.20	17.10	22.15	51.90	0.00	18.90	0.00	0.00	76	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3144	28	5	2	27.30	6.90	20.13	50.00	0.00	20.40	0.00	0.00	77	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3145	212	5	2	32.80	20.40	27.53	41.33	0.00	8.00	0.00	0.00	78	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3146	239	5	2	8.20	8.20	8.20	65.90	0.00	3.80	0.00	0.00	79	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3147	290	5	2	26.00	18.60	23.33	58.67	0.00	36.70	0.00	0.00	80	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3148	75	5	2	28.50	28.50	28.50	50.30	0.00	17.70	0.00	0.00	81	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3149	19	5	2	32.80	9.80	17.97	54.30	0.00	34.60	0.00	0.00	82	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3150	2	5	2	32.80	25.10	28.95	44.35	0.00	17.20	0.00	0.00	83	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3151	263	5	2	31.80	31.00	31.40	53.00	0.00	35.90	0.00	0.00	84	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3152	287	5	2	26.10	20.00	23.05	62.70	0.00	14.30	0.00	0.00	85	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3153	190	5	2	27.10	19.50	23.30	36.90	0.00	19.60	0.00	0.00	86	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3154	104	5	2	36.40	28.90	32.10	54.20	0.00	20.70	0.00	0.00	87	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3155	314	5	2	31.00	31.00	31.00	71.10	0.00	13.60	0.00	0.00	88	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3156	251	5	2	30.80	30.80	30.80	14.90	0.00	7.90	0.00	0.00	89	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3157	64	5	2	13.80	13.80	13.80	45.60	0.00	5.50	0.00	0.00	90	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3158	229	5	2	36.40	36.40	36.40	37.10	0.00	19.60	0.00	0.00	91	62.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3159	39	5	2	24.10	14.70	19.40	51.45	0.00	37.20	0.00	0.00	92	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3160	195	5	2	32.40	31.40	31.90	50.65	0.00	4.20	0.00	0.00	93	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3161	59	5	2	21.90	8.20	15.05	23.60	0.00	4.60	0.00	0.00	94	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3162	83	5	2	26.00	13.30	18.07	54.00	0.00	25.20	0.00	0.00	95	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3163	295	5	2	31.90	31.10	31.50	51.55	0.00	14.30	0.00	0.00	96	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3164	242	5	2	24.80	17.00	21.63	41.17	0.00	20.40	0.00	0.00	97	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3165	213	5	2	20.90	20.90	20.90	49.40	0.00	8.00	0.00	0.00	98	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3166	159	5	2	29.40	7.60	21.08	40.10	0.00	11.70	0.00	0.00	99	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3167	160	5	2	36.80	36.80	36.80	69.80	0.00	22.40	0.00	0.00	100	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3168	115	5	2	9.00	9.00	9.00	52.90	0.00	0.00	0.00	0.00	101	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3169	305	5	2	32.30	31.50	31.90	42.90	0.00	14.80	0.00	0.00	102	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3170	5	5	2	33.50	27.40	30.45	50.50	0.00	2.60	0.00	0.00	103	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3171	112	5	2	24.90	24.90	24.90	41.20	0.00	18.20	0.00	0.00	104	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3172	13	5	2	11.90	11.90	11.90	34.80	0.00	1.50	0.00	0.00	105	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3173	278	5	2	30.50	26.00	28.25	39.65	0.00	2.60	0.00	0.00	106	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3174	172	5	2	34.70	34.70	34.70	72.60	0.00	2.80	0.00	0.00	107	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3175	61	5	2	29.90	29.90	29.90	39.80	0.00	21.00	0.00	0.00	108	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3176	311	5	2	8.80	8.80	8.80	60.40	0.00	20.60	0.00	0.00	109	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3177	6	5	2	23.20	23.20	23.20	65.60	0.00	7.30	0.00	0.00	110	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3178	235	5	2	9.60	9.60	9.60	41.80	0.00	5.90	0.00	0.00	111	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3179	32	5	2	29.40	17.00	22.90	65.50	0.00	10.90	0.00	0.00	112	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3180	66	5	2	18.60	18.60	18.60	50.20	0.00	0.20	0.00	0.00	113	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3181	206	5	2	30.40	30.40	30.40	60.60	0.00	4.90	0.00	0.00	114	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3182	283	5	2	11.70	11.70	11.70	0.00	0.00	19.80	0.00	0.00	115	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3183	270	5	2	23.90	23.90	23.90	54.30	0.00	4.00	0.00	0.00	116	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3184	244	5	2	27.40	27.40	27.40	37.70	0.00	15.20	0.00	0.00	117	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3185	14	5	2	33.10	10.90	22.00	45.95	0.00	25.70	0.00	0.00	118	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3186	272	5	2	14.90	14.90	14.90	57.10	0.00	25.30	0.00	0.00	119	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3187	317	5	2	21.00	21.00	21.00	44.60	0.00	12.70	0.00	0.00	120	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3188	100	5	2	9.50	9.50	9.50	55.30	0.00	15.20	0.00	0.00	121	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3189	176	5	2	26.10	26.10	26.10	31.80	0.00	10.30	0.00	0.00	122	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3190	48	5	2	5.50	5.50	5.50	32.20	0.00	30.00	0.00	0.00	123	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3191	170	5	2	13.00	10.50	11.75	39.90	0.00	3.10	0.00	0.00	124	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3192	261	5	2	27.70	27.70	27.70	48.60	0.00	0.60	0.00	0.00	125	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3193	318	5	2	5.90	5.90	5.90	52.50	0.00	4.10	0.00	0.00	126	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3194	246	5	2	24.10	20.90	22.50	60.90	0.00	2.70	0.00	0.00	127	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3195	259	5	2	35.20	35.20	35.20	39.90	0.00	7.30	0.00	0.00	128	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3196	7	5	2	29.60	29.60	29.60	46.20	0.00	5.30	0.00	0.00	129	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3197	182	5	2	25.60	12.40	17.20	50.60	0.00	5.60	0.00	0.00	130	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3198	231	5	2	26.80	24.30	25.55	57.65	0.00	14.20	0.00	0.00	131	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3199	223	5	2	31.10	30.90	31.00	49.75	0.00	0.70	0.00	0.00	132	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3200	230	5	2	30.90	10.50	20.97	49.27	0.00	8.80	0.00	0.00	133	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3201	154	5	2	26.40	26.40	26.40	63.60	0.00	54.10	0.00	0.00	134	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3202	225	5	2	29.10	29.10	29.10	65.20	0.00	3.30	0.00	0.00	135	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3203	74	5	2	23.30	23.30	23.30	67.20	0.00	12.10	0.00	0.00	136	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3204	116	5	2	33.80	13.00	20.27	58.83	0.00	23.90	0.00	0.00	137	55.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3205	169	5	2	3.50	3.50	3.50	67.30	0.00	6.50	0.00	0.00	138	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3206	132	5	2	27.10	20.20	23.65	44.75	0.00	11.10	0.00	0.00	139	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3207	45	5	2	22.00	22.00	22.00	21.40	0.00	39.60	0.00	0.00	140	60.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3208	191	5	2	23.20	22.40	22.80	39.90	0.00	13.60	0.00	0.00	141	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3209	217	5	2	31.80	31.80	31.80	52.60	0.00	3.40	0.00	0.00	142	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3210	44	5	2	30.60	30.60	30.60	60.40	0.00	3.30	0.00	0.00	143	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3211	183	5	2	9.50	9.50	9.50	51.50	0.00	41.40	0.00	0.00	144	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3212	276	5	2	21.40	21.40	21.40	47.90	0.00	4.70	0.00	0.00	145	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3213	89	5	2	22.60	15.30	18.95	57.80	0.00	9.50	0.00	0.00	146	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3214	85	5	2	37.20	22.70	29.95	44.40	0.00	24.50	0.00	0.00	147	63.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3215	148	5	2	26.20	26.20	26.20	36.20	0.00	1.00	0.00	0.00	148	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3216	197	5	2	30.00	20.90	26.67	55.83	0.00	31.10	0.00	0.00	149	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3217	253	5	2	27.90	13.50	20.70	53.00	0.00	3.60	0.00	0.00	150	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3218	156	5	2	23.90	23.70	23.80	51.85	0.00	4.00	0.00	0.00	151	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3219	188	5	2	33.60	9.90	22.17	44.53	0.00	11.80	0.00	0.00	152	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3220	260	5	2	25.80	23.70	24.75	61.60	0.00	26.10	0.00	0.00	153	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3221	280	5	2	28.50	28.50	28.50	64.10	0.00	27.40	0.00	0.00	154	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3222	152	5	2	24.20	21.60	22.90	73.25	0.00	14.80	0.00	0.00	155	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3223	296	5	2	28.30	13.00	22.77	46.60	0.00	12.30	0.00	0.00	156	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3224	30	5	2	9.90	9.90	9.90	59.00	0.00	31.50	0.00	0.00	157	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3225	47	5	2	23.40	23.40	23.40	65.70	0.00	17.70	0.00	0.00	158	42.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3226	177	5	2	10.10	10.10	10.10	26.10	0.00	35.80	0.00	0.00	159	57.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3227	196	5	2	25.10	25.10	25.10	71.60	0.00	4.10	0.00	0.00	160	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3228	294	5	2	31.80	26.00	28.90	51.90	0.00	17.50	0.00	0.00	161	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3229	105	5	2	10.70	10.70	10.70	14.20	0.00	14.50	0.00	0.00	162	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3230	55	5	2	24.80	24.80	24.80	51.40	0.00	10.30	0.00	0.00	163	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3231	109	5	2	27.50	13.70	21.10	43.57	0.00	19.70	0.00	0.00	164	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3232	88	5	2	25.40	6.70	18.50	49.87	0.00	29.90	0.00	0.00	165	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3233	111	5	2	31.10	25.50	28.30	70.20	0.00	8.90	0.00	0.00	166	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3234	316	5	2	26.10	26.10	26.10	40.00	0.00	7.10	0.00	0.00	167	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3235	250	5	2	33.50	22.40	26.17	41.80	0.00	12.10	0.00	0.00	168	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3236	286	5	2	26.20	26.20	26.20	51.20	0.00	23.70	0.00	0.00	169	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3237	236	5	2	32.00	12.40	22.20	62.20	0.00	24.90	0.00	0.00	170	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3238	140	5	2	25.50	25.50	25.50	59.30	0.00	2.30	0.00	0.00	171	37.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3239	224	5	2	24.60	24.60	24.60	34.80	0.00	11.90	0.00	0.00	172	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3240	146	5	2	29.50	27.40	28.45	53.75	0.00	5.50	0.00	0.00	173	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3241	117	5	2	19.50	11.90	14.67	36.70	0.00	6.80	0.00	0.00	174	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3242	207	5	2	30.60	30.60	30.60	47.60	0.00	1.70	0.00	0.00	175	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3243	233	5	2	27.40	9.20	20.43	59.33	0.00	8.60	0.00	0.00	176	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3244	72	5	2	32.60	27.40	30.10	43.87	0.00	8.50	0.00	0.00	177	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3245	186	5	2	36.80	36.80	36.80	57.60	0.00	0.90	0.00	0.00	178	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3246	179	5	2	32.30	32.30	32.30	53.80	0.00	9.70	0.00	0.00	179	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3247	320	5	2	31.70	26.90	29.30	54.45	0.00	18.60	0.00	0.00	180	52.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3248	97	5	2	23.00	23.00	23.00	49.20	0.00	3.20	0.00	0.00	181	39.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3249	173	5	2	20.10	20.10	20.10	62.30	0.00	30.70	0.00	0.00	182	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3250	307	5	2	29.40	26.20	27.57	36.00	0.00	11.30	0.00	0.00	183	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3251	201	5	2	23.80	23.20	23.50	57.55	0.00	11.70	0.00	0.00	184	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3252	279	5	2	32.60	26.50	29.55	48.05	0.00	10.00	0.00	0.00	185	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3253	120	5	2	28.20	14.20	21.20	33.35	0.00	5.30	0.00	0.00	186	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3254	29	5	2	28.40	28.40	28.40	25.90	0.00	7.30	0.00	0.00	187	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3255	144	5	2	18.50	18.50	18.50	25.80	0.00	1.00	0.00	0.00	188	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3256	95	5	2	29.80	27.70	28.75	42.05	0.00	3.00	0.00	0.00	189	46.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3257	158	5	2	31.90	9.30	20.60	37.95	0.00	1.10	0.00	0.00	190	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3258	20	5	2	20.00	20.00	20.00	37.00	0.00	2.20	0.00	0.00	191	41.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3259	78	5	2	35.20	14.20	24.48	45.30	0.00	14.60	0.00	0.00	192	56.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3260	15	5	2	28.30	28.30	28.30	34.30	0.00	4.40	0.00	0.00	193	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3261	237	5	2	34.00	34.00	34.00	54.30	0.00	3.90	0.00	0.00	194	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3262	77	5	2	32.20	32.20	32.20	69.00	0.00	13.00	0.00	0.00	195	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3263	247	5	2	17.80	17.80	17.80	43.30	0.00	26.20	0.00	0.00	196	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3264	42	5	2	29.90	11.80	20.85	57.75	0.00	20.80	0.00	0.00	197	50.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3265	199	5	2	32.60	25.50	29.07	57.83	0.00	22.90	0.00	0.00	198	54.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3266	288	5	2	12.20	12.20	12.20	38.40	0.00	8.60	0.00	0.00	199	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3267	128	5	2	32.20	8.90	16.73	49.90	0.00	31.40	0.00	0.00	200	58.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3268	106	5	2	24.60	24.60	24.60	35.40	0.00	15.90	0.00	0.00	201	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3269	99	5	2	26.50	19.40	23.80	43.70	0.00	20.80	0.00	0.00	202	49.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3270	93	5	2	34.10	14.60	24.35	51.55	0.00	8.00	0.00	0.00	203	51.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3271	293	5	2	20.80	20.80	20.80	84.20	0.00	22.00	0.00	0.00	204	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3272	209	5	2	30.10	30.10	30.10	75.20	0.00	14.60	0.00	0.00	205	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3273	175	5	2	22.90	22.90	22.90	38.50	0.00	0.70	0.00	0.00	206	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3274	133	5	2	10.80	10.80	10.80	43.60	0.00	2.70	0.00	0.00	207	40.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3275	82	5	2	30.70	21.70	26.20	45.30	0.00	5.40	0.00	0.00	208	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3276	113	5	2	32.60	11.00	19.57	46.57	0.00	30.70	0.00	0.00	209	59.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3277	10	5	2	10.60	10.60	10.60	52.90	0.00	2.50	0.00	0.00	210	38.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3278	214	5	2	28.00	28.00	28.00	39.80	0.00	4.60	0.00	0.00	211	45.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3279	255	5	2	31.90	13.30	22.60	26.65	0.00	5.70	0.00	0.00	212	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3280	222	5	2	32.40	13.90	24.63	51.70	0.00	17.40	0.00	0.00	213	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3281	36	5	2	21.80	21.80	21.80	50.40	0.00	18.00	0.00	0.00	214	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3282	129	5	2	30.80	24.20	27.50	55.55	0.00	10.60	0.00	0.00	215	47.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3283	292	5	2	29.10	23.50	26.30	47.80	0.00	13.70	0.00	0.00	216	48.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3284	58	5	2	28.50	27.70	28.10	46.55	0.00	3.70	0.00	0.00	217	44.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3285	178	5	2	14.10	14.10	14.10	61.40	0.00	3.00	0.00	0.00	218	36.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3286	16	5	2	28.00	14.90	21.45	24.05	0.00	15.60	0.00	0.00	219	53.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
3287	184	5	2	23.40	23.40	23.40	34.40	0.00	4.90	0.00	0.00	220	43.00	Critique	Excellente	ETL_TALEND	2026-02-16 20:13:38.836204+00	2026-02-16 20:13:38.836204+00
\.


--
-- Name: dim_alerte_id_alerte_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.dim_alerte_id_alerte_seq', 2, true);


--
-- Name: dim_station_id_station_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.dim_station_id_station_seq', 15, true);


--
-- Name: dim_temps_id_temps_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.dim_temps_id_temps_seq', 325, true);


--
-- Name: fait_releves_climatiques_id_releve_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.fait_releves_climatiques_id_releve_seq', 3287, true);


--
-- Name: dim_alerte dim_alerte_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dim_alerte
    ADD CONSTRAINT dim_alerte_pkey PRIMARY KEY (id_alerte);


--
-- Name: dim_station dim_station_code_station_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dim_station
    ADD CONSTRAINT dim_station_code_station_key UNIQUE (code_station);


--
-- Name: dim_station dim_station_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dim_station
    ADD CONSTRAINT dim_station_pkey PRIMARY KEY (id_station);


--
-- Name: dim_temps dim_temps_date_complete_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dim_temps
    ADD CONSTRAINT dim_temps_date_complete_key UNIQUE (date_complete);


--
-- Name: dim_temps dim_temps_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dim_temps
    ADD CONSTRAINT dim_temps_pkey PRIMARY KEY (id_temps);


--
-- Name: fait_releves_climatiques fait_releves_climatiques_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fait_releves_climatiques
    ADD CONSTRAINT fait_releves_climatiques_pkey PRIMARY KEY (id_releve);


--
-- Name: dim_alerte uq_dim_alerte; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dim_alerte
    ADD CONSTRAINT uq_dim_alerte UNIQUE (type_precip, severity_index, niveau_urgence);


--
-- Name: fait_releves_climatiques uq_fact_grain; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fait_releves_climatiques
    ADD CONSTRAINT uq_fact_grain UNIQUE (id_temps, id_station);


--
-- Name: idx_alerte_severity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_alerte_severity ON public.dim_alerte USING btree (severity_index);


--
-- Name: idx_fact_alerte; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fact_alerte ON public.fait_releves_climatiques USING btree (id_alerte);


--
-- Name: idx_fact_station; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fact_station ON public.fait_releves_climatiques USING btree (id_station);


--
-- Name: idx_fact_temps; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fact_temps ON public.fait_releves_climatiques USING btree (id_temps);


--
-- Name: idx_mv_dashboard; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_mv_dashboard ON public.mv_dashboard_kpis USING btree (date_complete, nom_station);


--
-- Name: idx_station_zone_geo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_station_zone_geo ON public.dim_station USING btree (zone_geo);


--
-- Name: idx_temps_annee_mois; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_temps_annee_mois ON public.dim_temps USING btree (annee, mois);


--
-- Name: fait_releves_climatiques fait_releves_climatiques_id_alerte_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fait_releves_climatiques
    ADD CONSTRAINT fait_releves_climatiques_id_alerte_fkey FOREIGN KEY (id_alerte) REFERENCES public.dim_alerte(id_alerte);


--
-- Name: fait_releves_climatiques fait_releves_climatiques_id_station_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fait_releves_climatiques
    ADD CONSTRAINT fait_releves_climatiques_id_station_fkey FOREIGN KEY (id_station) REFERENCES public.dim_station(id_station);


--
-- Name: fait_releves_climatiques fait_releves_climatiques_id_temps_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fait_releves_climatiques
    ADD CONSTRAINT fait_releves_climatiques_id_temps_fkey FOREIGN KEY (id_temps) REFERENCES public.dim_temps(id_temps);


--
-- Name: mv_dashboard_kpis; Type: MATERIALIZED VIEW DATA; Schema: public; Owner: -
--

REFRESH MATERIALIZED VIEW public.mv_dashboard_kpis;


--
-- PostgreSQL database dump complete
--

