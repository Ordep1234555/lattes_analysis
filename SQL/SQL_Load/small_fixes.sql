BEGIN;

UPDATE formacoes
SET tipo_formacao = CASE 
    WHEN tipo_formacao = 'DOUTORADO' THEN 'Doutorado'
    WHEN tipo_formacao = 'MESTRADO' THEN 'Mestrado'
    WHEN tipo_formacao = 'MESTRADO-PROFISSIONALIZANTE' THEN 'Mestrado Profissionalizante'
    ELSE tipo_formacao
END;

UPDATE instituicoes
SET uf_instituicao = NULL
WHERE uf_instituicao = 'ZZ';

UPDATE areas
SET nome_area = v.nome_area_novo
FROM (
    VALUES
    ('CIENCIAS_AGRARIAS', 'Ciências Agrárias'),
    ('CIENCIAS_BIOLOGICAS', 'Ciências Biológicas'),
    ('CIENCIAS_DA_SAUDE', 'Ciências da Saúde'),
    ('CIENCIAS_EXATAS_E_DA_TERRA', 'Ciências Exatas e da Terra'),
    ('CIENCIAS_HUMANAS', 'Ciências Humanas'),
    ('CIENCIAS_SOCIAIS_APLICADAS', 'Ciências Sociais Aplicadas'),
    ('ENGENHARIAS', 'Engenharias'),
    ('LINGUISTICA_LETRAS_E_ARTES', 'Linguística, Letras e Artes'),
    ('OUTROS', 'Outros')
) AS v(nome_area_antigo, nome_area_novo)
WHERE areas.nome_area = v.nome_area_antigo;

CREATE TEMP TABLE instituicoes_to_merge AS
WITH targets AS (
  SELECT sigla_instituicao
  FROM instituicoes
  WHERE pais_instituicao = 'Brasil'
  GROUP BY sigla_instituicao
  HAVING COUNT(*) > 1
     AND COUNT(DISTINCT uf_instituicao) = 1
     AND COUNT(*) FILTER (WHERE uf_instituicao IS NULL) > 0
),
candidates AS (
  SELECT i.*
  FROM instituicoes i
  JOIN targets t USING (sigla_instituicao)
  WHERE i.pais_instituicao = 'Brasil'
),
mapping AS (
  SELECT
    sigla_instituicao,
    MIN(id) FILTER (WHERE uf_instituicao IS NOT NULL) AS keep_id,
    array_agg(id) FILTER (WHERE uf_instituicao IS NULL) AS remove_ids
  FROM candidates
  GROUP BY sigla_instituicao
)
SELECT m.sigla_instituicao, m.keep_id, unnest(m.remove_ids) AS remove_id
FROM mapping m;

UPDATE formacoes f
SET instituicao_id = e.keep_id
FROM instituicoes_to_merge e
WHERE f.instituicao_id = e.remove_id;

DELETE FROM instituicoes ins
USING instituicoes_to_merge e
WHERE ins.id = e.remove_id;

DROP TABLE IF EXISTS instituicoes_to_merge;

COMMIT;