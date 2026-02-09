-- ESQUEMA EXEMPLO
SELECT * FROM pessoas
LIMIT 10;
SELECT * FROM instituicoes
LIMIT 10;
SELECT * FROM areas
LIMIT 10;
SELECT * FROM formacoes
LIMIT 10;
SELECT * FROM formacoes_areas
LIMIT 10;

SELECT nome_area, COUNT(*)
FROM areas a
JOIN formacoes_areas fa ON a.id = fa.area_id
WHERE tipo = 'area'
GROUP BY nome_area
ORDER BY COUNT(*);

SELECT * FROM areas
WHERE tipo = 'grande_area'

-- ID ESPECIFICO
SELECT 
    fa.id AS id_formacao_area,
    f.id AS id_formacao,
    f.tipo_formacao,
    a.id AS id_area,
    a.nome_area,
    a.tipo AS tipo_area
FROM pessoas p
JOIN formacoes f ON p.id = f.pessoa_id
JOIN formacoes_areas fa ON f.id = fa.formacao_id
JOIN areas a ON fa.area_id = a.id
WHERE p.numero_identificador = 0001185178581199;

SELECT COUNT(*) FROM pessoas

-- UF INSTITUIÇAO NULA 
SELECT
  COUNT(*) FILTER (WHERE i.pais_instituicao = 'Brasil' AND i.uf_instituicao IS NULL) AS qtd_null_uf,
  COUNT(*) FILTER (WHERE i.pais_instituicao = 'Brasil') AS total_bra,
  ROUND(
    (COUNT(*) FILTER (WHERE i.pais_instituicao = 'Brasil' AND i.uf_instituicao IS NULL)::numeric
     / NULLIF(COUNT(*) FILTER (WHERE i.pais_instituicao = 'Brasil'), 0)
    ) * 100, 2
  ) AS pct_null_uf
FROM formacoes f
JOIN instituicoes i ON f.instituicao_id = i.id;

SELECT *
FROM instituicoes
WHERE sigla_instituicao LIKE '%USP%';

SELECT * 
FROM pessoas
WHERE uf_nascimento IS NOT NULL AND pais_nascimento != 'Brasil';


SELECT DISTINCT RANK() OVER (ORDER BY sigla_instituicao) AS rank_sigla, sigla_instituicao, uf_instituicao, pais_instituicao
FROM instituicoes
ORDER BY sigla_instituicao;

SELECT i.id, sigla_instituicao, uf_instituicao, pais_instituicao, COUNT(f.id) AS qtd_formacoes
FROM instituicoes i
JOIN formacoes f ON i.id = f.instituicao_id
GROUP BY i.id, sigla_instituicao, uf_instituicao, pais_instituicao
ORDER BY qtd_formacoes DESC;

SELECT * 
FROM formacoes f
JOIN instituicoes i ON f.instituicao_id = i.id
WHERE sigla_instituicao = 'UC'
ORDER BY f.id;

SELECT 
    sigla_instituicao,
    COUNT(DISTINCT uf_instituicao) AS qtd_ufs
FROM instituicoes
WHERE uf_instituicao IS NOT NULL
GROUP BY sigla_instituicao
HAVING COUNT(DISTINCT uf_instituicao) > 1
ORDER BY qtd_ufs DESC, sigla_instituicao;

SELECT *
FROM instituicoes
WHERE sigla_instituicao ILIKE '%PUC%'
AND pais_instituicao = 'Brasil'
ORDER BY uf_instituicao;

SELECT DISTINCT ON (uf_instituicao)
    sigla_instituicao,
    uf_instituicao,
    regiao_instituicao,
    pais_instituicao,
    COUNT(f.id) AS qtd_formacoes
FROM
    instituicoes i
JOIN
    formacoes f ON i.id = f.instituicao_id
GROUP BY
    sigla_instituicao, uf_instituicao,regiao_instituicao, pais_instituicao
ORDER BY
    uf_instituicao, qtd_formacoes DESC;

SELECT DISTINCT pais_nascimento FROM pessoas ORDER BY pais_nascimento;
SELECT DISTINCT pais_instituicao FROM instituicoes ORDER BY pais_instituicao;

SELECT DISTINCT uf_instituicao FROM instituicoes ORDER BY uf_instituicao;

SELECT * FROM instituicoes
WHERE uf_instituicao IS NOT NULL AND pais_instituicao != 'Brasil'
ORDER BY uf_instituicao;

SELECT * FROM pessoas
WHERE uf_nascimento IS NOT NULL AND pais_nascimento != 'Brasil'
ORDER BY uf_nascimento;

-- UFS QUE SE REPETEM NO BRASIL, COM PELO MENOS UMA NULA
SELECT 
    i.id,
    i.sigla_instituicao,
    i.uf_instituicao,
    i.regiao_instituicao,
    i.pais_instituicao,
    c.qtd_ocorrencias
FROM instituicoes i
JOIN (
    SELECT 
        sigla_instituicao,
        COUNT(*) AS qtd_ocorrencias
    FROM instituicoes
    GROUP BY sigla_instituicao
    HAVING COUNT(*) > 1
) c ON i.sigla_instituicao = c.sigla_instituicao
WHERE i.sigla_instituicao IN (
    SELECT sigla_instituicao
    FROM instituicoes
    WHERE pais_instituicao = 'Brasil' AND uf_instituicao IS NULL
)
ORDER BY c.qtd_ocorrencias DESC, i.sigla_instituicao;

SELECT 
    i.sigla_instituicao,
    COUNT(*) AS total_repeticoes,
    COUNT(CASE WHEN i.pais_instituicao = 'Brasil' THEN 1 END) AS qtd_no_brasil,
    COUNT(CASE WHEN i.pais_instituicao = 'Brasil' AND i.uf_instituicao IS NULL THEN 1 END) AS qtd_uf_nula_brasil,
    COUNT(CASE WHEN i.pais_instituicao = 'Brasil' AND i.uf_instituicao IS NOT NULL THEN 1 END) AS qtd_uf_nao_nula_brasil
FROM instituicoes i
JOIN (
    SELECT 
        sigla_instituicao,
        COUNT(*) AS qtd_ocorrencias
    FROM instituicoes
    GROUP BY sigla_instituicao
    HAVING COUNT(*) > 1
) c ON i.sigla_instituicao = c.sigla_instituicao
GROUP BY i.sigla_instituicao
ORDER BY total_repeticoes DESC;


