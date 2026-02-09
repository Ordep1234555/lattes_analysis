BEGIN;

CREATE TEMP TABLE instituicoes_to_merge (
    master_id INT,
    duplicate_id INT
);

WITH master_list (sigla, uf) AS (
    VALUES
        ('USP', 'SP'), ('UFRJ', 'RJ'), ('UNICAMP', 'SP'), ('UFRGS', 'RS'), 
        ('UFMG', 'MG'), ('UNB', 'DF'), ('PUCSP', 'SP'), ('UFPR', 'PR'), 
        ('UFBA', 'BA'), ('UFPB', 'PB'), ('UERJ', 'RJ'), ('UFRN', 'RN'), 
        ('UNIFESP', 'SP'), ('UFPA', 'PA'), ('UFSCAR', 'SP'), ('UFV', 'MG'), 
        ('UFSM', 'RS'), ('PUCRIO', 'RJ'), ('PUCRS', 'RS'), ('UFU', 'MG'), 
        ('UFES', 'ES'), ('UEL', 'PR'), ('UFLA', 'MG'), ('UFPEL', 'RS'), 
        ('UFJF', 'MG'), ('UFRRJ', 'RJ'), ('UFMT', 'MT'), ('UNISINOS', 'RS'), 
        ('FIOCRUZ', 'RJ'), ('UFAM', 'AM'), ('UFCG', 'PB'), ('UFRPE', 'PE'), 
        ('UECE', 'CE'), ('UFMS', 'MS'), ('UFPI', 'PI'), ('UFAL', 'AL'), 
        ('PUCMINAS', 'MG'), ('UTFPR', 'PR'), ('PUCPR', 'PR'), ('UDESC', 'SC'), 
        ('MACKENZIE', 'SP'), ('UNIOESTE', 'PR'), ('UFMA', 'MA'), ('UFAC', 'AC'), 
        ('UNIFAP', 'AP'), ('PUCRJ', 'RJ'), ('PUCGO', 'GO'), ('PUCMG','MG')
)

-- 1) Universidades em master_list
INSERT INTO instituicoes_to_merge (master_id, duplicate_id)
SELECT
    master.id AS master_id,
    duplicata.id AS duplicate_id
FROM
    master_list ml
JOIN
    instituicoes master ON ml.sigla = master.sigla_instituicao 
                        AND ml.uf = master.uf_instituicao
JOIN
    instituicoes duplicata ON duplicata.sigla_instituicao LIKE '%' || master.sigla_instituicao || '%'
WHERE
    duplicata.id <> master.id;

-- 2.1) Caso especial UNESP
INSERT INTO instituicoes_to_merge (master_id, duplicate_id)
SELECT
    master.id AS master_id,
    duplicata.id AS duplicate_id
FROM
    instituicoes master
JOIN
    instituicoes duplicata ON duplicata.sigla_instituicao LIKE '%UNESP%'
                          AND duplicata.sigla_instituicao NOT LIKE '%UNESPAR%' 
WHERE
    master.sigla_instituicao = 'UNESP'
    AND master.uf_instituicao = 'SP'
    AND duplicata.id <> master.id;

-- 2.2) Caso especial UFSC
INSERT INTO instituicoes_to_merge (master_id, duplicate_id)
SELECT
    master.id AS master_id,
    duplicata.id AS duplicate_id
FROM
    instituicoes master
JOIN
    instituicoes duplicata ON duplicata.sigla_instituicao LIKE '%UFSC%'
                          AND duplicata.sigla_instituicao NOT LIKE '%UFSCAR%' 
WHERE
    master.sigla_instituicao = 'UFSC'
    AND master.uf_instituicao = 'SC'
    AND duplicata.id <> master.id;

-- 2.3) Caso especial UFPE
INSERT INTO instituicoes_to_merge (master_id, duplicate_id)
SELECT
    master.id AS master_id,
    duplicata.id AS duplicate_id
FROM
    instituicoes master
JOIN
    instituicoes duplicata ON duplicata.sigla_instituicao LIKE '%UFPE%'
                          AND duplicata.sigla_instituicao NOT LIKE '%UFPEL%' 
WHERE
    master.sigla_instituicao = 'UFPE'
    AND master.uf_instituicao = 'PE'
    AND duplicata.id <> master.id;

-- 2.4) Caso especial UFC
INSERT INTO instituicoes_to_merge (master_id, duplicate_id)
SELECT
    master.id AS master_id,
    duplicata.id AS duplicate_id
FROM
    instituicoes master
JOIN
    instituicoes duplicata ON duplicata.sigla_instituicao LIKE '%UFC%'
                          AND duplicata.sigla_instituicao NOT LIKE '%UFCG%' 
                          AND duplicata.sigla_instituicao NOT LIKE '%UFCS%' 
WHERE
    master.sigla_instituicao = 'UFC'
    AND master.uf_instituicao = 'CE'
    AND duplicata.id <> master.id;

-- 2.5) Caso especial UFF
INSERT INTO instituicoes_to_merge (master_id, duplicate_id)
SELECT
    master.id AS master_id,
    duplicata.id AS duplicate_id
FROM
    instituicoes master
JOIN
    instituicoes duplicata ON duplicata.sigla_instituicao LIKE '%UFF%'
                          AND duplicata.sigla_instituicao NOT LIKE '%UFFS%' 
WHERE
    master.sigla_instituicao = 'UFF'
    AND master.uf_instituicao = 'RJ'
    AND duplicata.id <> master.id;

-- 2.6) Caso especial UFG
INSERT INTO instituicoes_to_merge (master_id, duplicate_id)
SELECT
    master.id AS master_id,
    duplicata.id AS duplicate_id
FROM
    instituicoes master
JOIN
    instituicoes duplicata ON duplicata.sigla_instituicao LIKE '%UFG%'
                          AND duplicata.sigla_instituicao NOT LIKE '%UFGD%' 
WHERE
    master.sigla_instituicao = 'UFG'
    AND master.uf_instituicao = 'GO'
    AND duplicata.id <> master.id;

-- 2.7) Caso especial UEM
INSERT INTO instituicoes_to_merge (master_id, duplicate_id)
SELECT
    master.id AS master_id,
    duplicata.id AS duplicate_id
FROM
    instituicoes master
JOIN
    instituicoes duplicata ON duplicata.sigla_instituicao LIKE '%UEM%'
                          AND duplicata.sigla_instituicao NOT LIKE '%UEMA%'
                          AND duplicata.sigla_instituicao NOT LIKE '%UEMS%'
                          AND duplicata.sigla_instituicao NOT LIKE '%UEMG%' 
WHERE
    master.sigla_instituicao = 'UEM'
    AND master.uf_instituicao = 'PR'
    AND duplicata.id <> master.id;

-- 2.8) Caso especial UFS
INSERT INTO instituicoes_to_merge (master_id, duplicate_id)
SELECT
    master.id AS master_id,
    duplicata.id AS duplicate_id
FROM
    instituicoes master
JOIN
    instituicoes duplicata ON duplicata.sigla_instituicao LIKE '%UFS%'
                          AND duplicata.sigla_instituicao NOT LIKE '%UFSC%' 
                          AND duplicata.sigla_instituicao NOT LIKE '%UFSM%'
                          AND duplicata.sigla_instituicao NOT LIKE '%UFSJ%'
                          AND duplicata.sigla_instituicao NOT LIKE '%UFSB%'
WHERE
    master.sigla_instituicao = 'UFS'
    AND master.uf_instituicao = 'SE'
    AND duplicata.id <> master.id;

-- 2.9) Caso especial UNIR
INSERT INTO instituicoes_to_merge (master_id, duplicate_id)
SELECT
    master.id AS master_id,
    duplicata.id AS duplicate_id
FROM
    instituicoes master
JOIN
    instituicoes duplicata ON duplicata.sigla_instituicao LIKE '%UNIR%'
                          AND duplicata.sigla_instituicao NOT LIKE '%UNIRIO%'
                          AND duplicata.sigla_instituicao NOT LIKE '%UNIROMA%'
WHERE
    master.sigla_instituicao = 'UNIR'
    AND master.uf_instituicao = 'RO'
    AND duplicata.id <> master.id;

-- 2.10) Caso especial UFRR
INSERT INTO instituicoes_to_merge (master_id, duplicate_id)
SELECT
    master.id AS master_id,
    duplicata.id AS duplicate_id
FROM
    instituicoes master
JOIN
    instituicoes duplicata ON duplicata.sigla_instituicao LIKE '%UFRR%'
                          AND duplicata.sigla_instituicao NOT LIKE '%UFRRJ%' 
WHERE
    master.sigla_instituicao = 'UFRR'
    AND master.uf_instituicao = 'RR'
    AND duplicata.id <> master.id;

-- 2.11) Caso especial UFT
INSERT INTO instituicoes_to_merge (master_id, duplicate_id)
SELECT
    master.id AS master_id,
    duplicata.id AS duplicate_id
FROM
    instituicoes master
JOIN
    instituicoes duplicata ON duplicata.sigla_instituicao LIKE '%UFT%'
                          AND duplicata.sigla_instituicao NOT LIKE '%UFTM%' 
WHERE
    master.sigla_instituicao = 'UFT'
    AND master.uf_instituicao = 'TO'
    AND duplicata.id <> master.id;

-- 3) FGV
WITH fgv_map AS (
    SELECT
        id,
        uf_instituicao,
        FIRST_VALUE(id) OVER(
            PARTITION BY uf_instituicao
            ORDER BY id ASC
        ) AS master_id
    FROM
        instituicoes
    WHERE
        sigla_instituicao LIKE '%FGV%'
)

INSERT INTO instituicoes_to_merge (master_id, duplicate_id)
SELECT
    master_id,
    id AS duplicate_id
FROM
    fgv_map
WHERE
    id <> master_id;

UPDATE formacoes f
SET instituicao_id = itm.master_id
FROM instituicoes_to_merge itm
WHERE f.instituicao_id = itm.duplicate_id
  AND f.instituicao_id <> itm.master_id; -- Segurança extra

DELETE FROM instituicoes i
WHERE i.id IN (SELECT DISTINCT duplicate_id FROM instituicoes_to_merge);

UPDATE instituicoes
SET sigla_instituicao = 'FGV'
WHERE sigla_instituicao LIKE '%FGV%';

DROP TABLE IF EXISTS instituicoes_to_merge;

COMMIT;