-- SE FOR LIKE PUCC OU PUCA && pais_instituicao = 'Brasil' then PUCSP
-- SE FOR LIKE '%PUC%' COM pais_instituicao = 'Brasil' DEIXAR SOMENTE UMA EM CADA UM DOS ESTADOS: SP, GO, MG, PR, RJ, RS
-- OUTROS ESTADOS DEIXAR uf_instituicao e regiao_instituicao como NULL 
-- DEIXAR SOMENTE UMA COM LIKE %PUC% POR PAIS QUE NÃO SEJA BRASIL

BEGIN;

-- ============================
-- 0) Visualizar candidatos
-- ============================
-- (a) PUCC / PUCA brasileiros
SELECT * FROM instituicoes
 WHERE pais_instituicao = 'Brasil'
   AND (sigla_instituicao LIKE '%PUCC%' OR sigla_instituicao LIKE '%PUCA%');

-- (b) Todos os "%PUC%" no Brasil
SELECT * FROM instituicoes
 WHERE pais_instituicao = 'Brasil'
   AND sigla_instituicao LIKE '%PUC%'
 ORDER BY uf_instituicao, id;

-- (c) Fora do Brasil com "%PUC%"
SELECT * FROM instituicoes
 WHERE pais_instituicao <> 'Brasil'
   AND sigla_instituicao LIKE '%PUC%'
 ORDER BY pais_instituicao, id;


-- =====================================================
-- 1) Juntar todos '%PUCC%' ou '%PUCA%' (Brasil) em PUCSP
-- =====================================================

UPDATE formacoes
SET instituicao_id = (
    SELECT id FROM instituicoes
     WHERE sigla_instituicao = 'PUCSP' AND uf_instituicao = 'SP'
     LIMIT 1
)
WHERE instituicao_id IN (
    SELECT id FROM instituicoes
     WHERE pais_instituicao = 'Brasil'
       AND (sigla_instituicao LIKE '%PUCC%' OR sigla_instituicao LIKE '%PUCA%')
);

-- (1.3) Remover os registros antigos (exceto o PUCSP)
DELETE FROM instituicoes
 WHERE pais_instituicao = 'Brasil'
   AND (sigla_instituicao LIKE '%PUCC%' OR sigla_instituicao LIKE '%PUCA%')
   AND NOT (sigla_instituicao = 'PUCSP' AND uf_instituicao = 'SP');


-- =====================================================
-- 2) Manter somente 1 registro '%PUC%' por UF para lista
--     estados = SP, GO, MG, PR, RJ, RS (somente Brasil)
-- =====================================================
-- (2.1) criar tabela temporária com mapeamento antigo -> keeper por UF

CREATE TEMP TABLE tmp_puc_keep AS
SELECT
  id AS old_id,
  FIRST_VALUE(id) OVER (PARTITION BY uf_instituicao ORDER BY id) AS keeper_id,
  uf_instituicao
FROM instituicoes
WHERE pais_instituicao = 'Brasil'
  AND sigla_instituicao LIKE '%PUC%'
  AND uf_instituicao IN ('SP','GO','MG','PR','RJ','RS');

-- Verifica quem será mantido e quem migrará
SELECT keeper_id, uf_instituicao, COUNT(*) AS count_group
FROM tmp_puc_keep
GROUP BY keeper_id, uf_instituicao
ORDER BY uf_instituicao;

-- (2.2) Atualizar formacoes para apontar para o keeper por UF
UPDATE formacoes f
SET instituicao_id = k.keeper_id
FROM tmp_puc_keep k
WHERE f.instituicao_id = k.old_id
  AND k.old_id <> k.keeper_id;

-- (2.3) Deletar registros antigos agora que os formacoes foram atualizados (exceto os keeper)
DELETE FROM instituicoes i
USING tmp_puc_keep k
WHERE i.id = k.old_id
  AND k.old_id <> k.keeper_id;

DROP TABLE IF EXISTS tmp_puc_keep CASCADE;

-- =====================================================
-- 3) Para o restante do Brasil (não nos 6 estados),
--    setar uf_instituicao e regiao_instituicao = NULL
-- =====================================================
CREATE TEMP TABLE tmp_alvo AS
SELECT id
FROM instituicoes
WHERE pais_instituicao = 'Brasil'
  AND sigla_instituicao ILIKE '%PUC%'
  AND (uf_instituicao IS NULL OR uf_instituicao NOT IN ('SP','GO','MG','PR','RJ','RS'));

CREATE TEMP TABLE tmp_keeper AS
SELECT MIN(id) AS keeper_id FROM tmp_alvo;

UPDATE formacoes f
SET instituicao_id = (SELECT keeper_id FROM tmp_keeper)
WHERE (SELECT keeper_id FROM tmp_keeper) IS NOT NULL
  AND f.instituicao_id IN (SELECT id FROM tmp_alvo)
  AND f.instituicao_id <> (SELECT keeper_id FROM tmp_keeper);

DELETE FROM instituicoes i
WHERE i.id IN (SELECT id FROM tmp_alvo)
  AND (SELECT keeper_id FROM tmp_keeper) IS NOT NULL
  AND i.id <> (SELECT keeper_id FROM tmp_keeper);

UPDATE instituicoes
SET uf_instituicao = NULL,
    regiao_instituicao = NULL
WHERE id = (SELECT keeper_id FROM tmp_keeper)
  AND (SELECT keeper_id FROM tmp_keeper) IS NOT NULL;

DROP TABLE IF EXISTS tmp_alvo;
DROP TABLE IF EXISTS tmp_keeper;

-- =====================================================
-- 4) Fora do Brasil: manter somente 1 registro '%PUC%' por país
-- =====================================================
-- (4.1) mapping por país (pais <> 'Brasil')
CREATE TEMP TABLE tmp_puc_country_keep AS
SELECT
  id AS old_id,
  FIRST_VALUE(id) OVER (PARTITION BY pais_instituicao ORDER BY id) AS keeper_id,
  pais_instituicao
FROM instituicoes
WHERE pais_instituicao <> 'Brasil'
  AND sigla_instituicao LIKE '%PUC%';

-- (4.2) Verificação
SELECT pais_instituicao, keeper_id, COUNT(*) AS how_many
FROM tmp_puc_country_keep
GROUP BY pais_instituicao, keeper_id
ORDER BY pais_instituicao;

-- (4.3) Atualizar formacoes para apontar ao keeper por país
UPDATE formacoes f
SET instituicao_id = k.keeper_id
FROM tmp_puc_country_keep k
WHERE f.instituicao_id = k.old_id
  AND k.old_id <> k.keeper_id;

-- (4.4) Deletar os registros antigos (exceto keepers)
DELETE FROM instituicoes i
USING tmp_puc_country_keep k
WHERE i.id = k.old_id
  AND k.old_id <> k.keeper_id;

DROP TABLE IF EXISTS tmp_puc_country_keep CASCADE;

-- =====================================================
-- 5) Finalmente renomear todas as siglas resultantes para 'PUC'
--     (apenas registros com sigla parecida com PUC)
-- =====================================================
UPDATE instituicoes
SET sigla_instituicao = 'PUC'
WHERE sigla_instituicao LIKE '%PUC%';


-- ============================
-- 6) Verificações finais
-- ============================
-- (a) Conferir quantos por estado (para os 6 estados)
SELECT uf_instituicao, pais_instituicao, COUNT(*) AS qtd
FROM instituicoes
WHERE pais_instituicao = 'Brasil' AND sigla_instituicao = 'PUC'
GROUP BY uf_instituicao, pais_instituicao
ORDER BY uf_instituicao;

-- (b) Conferir quantos por país (fora do Brasil)
SELECT pais_instituicao, COUNT(*) AS qtd
FROM instituicoes
WHERE pais_instituicao <> 'Brasil' AND sigla_instituicao = 'PUC'
GROUP BY pais_instituicao
ORDER BY qtd DESC;

-- (c) Conferir se ainda existem registros antigos que casem com padrões anteriores
SELECT * FROM instituicoes
 WHERE (sigla_instituicao LIKE '%PUCC%' OR sigla_instituicao LIKE '%PUCA%')
    OR (sigla_instituicao LIKE '%PUC%' AND pais_instituicao = 'Brasil' AND uf_instituicao NOT IN ('SP','GO','MG','PR','RJ','RS') );



COMMIT;