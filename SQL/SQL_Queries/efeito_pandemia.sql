SELECT
  ano_conclusao AS ano,
  COUNT(*) AS qtd_formacoes
FROM formacoes
WHERE ano_conclusao > 2009 AND ano_conclusao < 2024
GROUP BY ano_conclusao
ORDER BY ano_conclusao;

WITH yearly AS (
  SELECT ano_conclusao AS ano, COUNT(*)::bigint AS qtd
  FROM formacoes
  WHERE ano_conclusao > 2009 AND ano_conclusao < 2024
  GROUP BY ano_conclusao
)
SELECT
  y.ano,
  y.qtd,
  LAG(y.qtd) OVER (ORDER BY y.ano) AS qtd_ano_anterior,
  CASE WHEN LAG(y.qtd) OVER (ORDER BY y.ano) IS NULL THEN NULL
       WHEN LAG(y.qtd) OVER (ORDER BY y.ano) = 0 THEN NULL
       ELSE ROUND(100.0 * (y.qtd - LAG(y.qtd) OVER (ORDER BY y.ano)) / LAG(y.qtd) OVER (ORDER BY y.ano), 2)
  END AS pct_change
FROM yearly y
ORDER BY y.ano;

WITH grupos AS (
  SELECT
    CASE
      WHEN ano_conclusao BETWEEN 2015 AND 2019 THEN 'pre_pandemia'
      WHEN ano_conclusao BETWEEN 2020 AND 2021 THEN 'pandemia'
      WHEN ano_conclusao >= 2022 THEN 'pos_pandemia'
      ELSE 'outros'
    END AS periodo
  FROM formacoes
  WHERE ano_conclusao IS NOT NULL
)
SELECT periodo, COUNT(*) AS total_formacoes, ROUND(COUNT(*)::numeric / NULLIF(COUNT(DISTINCT CASE WHEN periodo='pre_pandemia' THEN ano_conclusao END),0),2) AS media_anual
FROM (
  SELECT f.*, 
    CASE
      WHEN f.ano_conclusao BETWEEN 2015 AND 2019 THEN 'pre_pandemia'
      WHEN f.ano_conclusao BETWEEN 2020 AND 2021 THEN 'pandemia'
      WHEN f.ano_conclusao >= 2022 THEN 'pos_pandemia'
      ELSE 'outros'
    END AS periodo
  FROM formacoes f
  WHERE f.ano_conclusao IS NOT NULL
) t
GROUP BY periodo;

SELECT
  ano_conclusao AS ano,
  tipo_formacao,
  COUNT(*) AS qtd
FROM formacoes
WHERE ano_conclusao > 2009 AND ano_conclusao < 2024
GROUP BY ano_conclusao, tipo_formacao
ORDER BY ano_conclusao, tipo_formacao;

SELECT
  f.ano_conclusao AS ano,
  a.nome_area,
  COUNT(*) AS qtd
FROM formacoes f
JOIN formacoes_areas fa ON fa.formacao_id = f.id
JOIN areas a ON a.id = fa.area_id
WHERE f.ano_conclusao > 2009 AND f.ano_conclusao < 2024
GROUP BY f.ano_conclusao, a.nome_area
ORDER BY f.ano_conclusao, qtd DESC;

WITH counts AS (
  SELECT
    a.id AS area_id,
    a.nome_area,
    SUM(CASE WHEN f.ano_conclusao BETWEEN 2015 AND 2019 THEN 1 ELSE 0 END) AS pre_total,
    SUM(CASE WHEN f.ano_conclusao BETWEEN 2020 AND 2021 THEN 1 ELSE 0 END) AS pand_total
  FROM formacoes f
  JOIN formacoes_areas fa ON fa.formacao_id = f.id
  JOIN areas a ON a.id = fa.area_id
  GROUP BY a.id, a.nome_area
)
SELECT
  area_id, nome_area, pre_total, pand_total,
  CASE WHEN pre_total = 0 THEN NULL ELSE ROUND(100.0 * (pand_total - pre_total) / pre_total,2) END AS pct_change
FROM counts
ORDER BY pct_change
LIMIT 10; -- mais negativos => maiores quedas

SELECT
  f.ano_conclusao AS ano,
  i.uf_instituicao,
  COUNT(*) AS qtd
FROM formacoes f
LEFT JOIN instituicoes i ON i.id = f.instituicao_id
WHERE f.ano_conclusao > 2009 AND f.ano_conclusao < 2024
GROUP BY f.ano_conclusao, i.uf_instituicao
ORDER BY f.ano_conclusao, i.uf_instituicao;

SELECT
  f.ano_conclusao AS ano,
  p.genero,
  COUNT(*) AS qtd
FROM formacoes f
JOIN pessoas p ON p.id = f.pessoa_id
WHERE f.ano_conclusao > 2009 AND f.ano_conclusao < 2024
GROUP BY f.ano_conclusao, p.genero
ORDER BY f.ano_conclusao, p.genero;

SELECT
  f.ano_conclusao AS ano,
  f.flag_bolsa,
  COUNT(*) AS qtd
FROM formacoes f
WHERE f.ano_conclusao > 2009 AND f.ano_conclusao < 2024
GROUP BY f.ano_conclusao, f.flag_bolsa
ORDER BY f.ano_conclusao, f.flag_bolsa;

SELECT
  ano_inicio AS ano,
  COUNT(*) AS qtd_inicios
FROM formacoes
WHERE ano_inicio > 2009 AND ano_inicio < 2024
GROUP BY ano_inicio
ORDER BY ano_inicio;

WITH yearly AS (
  SELECT ano_conclusao AS ano, COUNT(*)::numeric AS qtd
  FROM formacoes
  WHERE ano_conclusao > 2009 AND ano_conclusao < 2024
  GROUP BY ano_conclusao
)
SELECT
  ano,
  qtd,
  ROUND(AVG(qtd) OVER (ORDER BY ano ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),2) AS media_movel_3anos
FROM yearly
ORDER BY ano;