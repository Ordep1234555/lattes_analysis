-- Script para carregar dados do CSV após o container estar pronto
-- Este arquivo deve ser rodado DEPOIS que o banco foi inicializado

-- Criar a tabela temporária
CREATE TEMP TABLE temp_curriculos (
    numero_identificador BIGINT,
    genero VARCHAR(1),
    data_atualizacao TEXT,
    uf_nascimento VARCHAR(2),
    capital_nascimento BOOLEAN,
    regiao_nascimento VARCHAR(20),
    pais_nascimento VARCHAR(50),
    tipo_formacao VARCHAR(30),
    curso_concluido BOOLEAN,
    ano_inicio TEXT,
    ano_conclusao TEXT,
    grande_area VARCHAR(255),
    area VARCHAR(255),
    flag_bolsa BOOLEAN,
    sigla_instituicao VARCHAR(50),
    uf_instituicao VARCHAR(2),
    regiao_instituicao VARCHAR(20),
    pais_instituicao VARCHAR(50)
);

-- Carregar CSV (arquivo montado em /tmp/output_lattes via docker-compose)
-- Usa COPY (server-side): o arquivo deve estar acessível ao servidor Postgres
COPY temp_curriculos FROM '/tmp/output_lattes/curriculos_processados.csv' WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',');

-- Popular tabelas das trelações com dados do CSV
INSERT INTO pessoas (numero_identificador, genero, data_atualizacao, capital_nascimento, uf_nascimento, regiao_nascimento, pais_nascimento)
SELECT DISTINCT ON (numero_identificador)
    numero_identificador,
    genero,
    NULLIF(data_atualizacao, '')::DATE,
    capital_nascimento,
    uf_nascimento,
    regiao_nascimento,
    pais_nascimento
FROM temp_curriculos
ORDER BY numero_identificador, data_atualizacao DESC;

INSERT INTO instituicoes (sigla_instituicao, uf_instituicao, regiao_instituicao, pais_instituicao)
SELECT DISTINCT
    sigla_instituicao,
    uf_instituicao,
    regiao_instituicao,
    pais_instituicao
FROM temp_curriculos
WHERE sigla_instituicao IS NOT NULL AND sigla_instituicao <> ''
ON CONFLICT (sigla_instituicao, uf_instituicao, pais_instituicao) DO NOTHING;

INSERT INTO areas (nome_area, tipo)
SELECT DISTINCT TRIM(unnest_grande_area), 'grande_area'
FROM temp_curriculos
CROSS JOIN LATERAL regexp_split_to_table(grande_area, ';\s*') AS unnest_grande_area
WHERE unnest_grande_area <> ''
ON CONFLICT (nome_area, tipo) DO NOTHING;

INSERT INTO areas (nome_area, tipo)
SELECT DISTINCT TRIM(unnest_area), 'area'
FROM temp_curriculos
CROSS JOIN LATERAL regexp_split_to_table(area, ';\s*') AS unnest_area
WHERE unnest_area <> ''
ON CONFLICT (nome_area, tipo) DO NOTHING;

INSERT INTO formacoes (pessoa_id, instituicao_id, tipo_formacao, curso_concluido, ano_inicio, ano_conclusao, flag_bolsa)
SELECT
    p.id,
    i.id,
    t.tipo_formacao,
    t.curso_concluido,
    NULLIF(t.ano_inicio, '')::INTEGER,
    NULLIF(t.ano_conclusao, '')::INTEGER,
    t.flag_bolsa
FROM temp_curriculos t
JOIN pessoas p ON t.numero_identificador = p.numero_identificador
LEFT JOIN instituicoes i ON t.sigla_instituicao = i.sigla_instituicao 
                         AND COALESCE(t.uf_instituicao, '') = COALESCE(i.uf_instituicao, '')
                         AND COALESCE(t.pais_instituicao, '') = COALESCE(i.pais_instituicao, '');

WITH formacao_map AS (
    SELECT
        f.id as formacao_id,
        p.numero_identificador,
        f.tipo_formacao,
        f.ano_inicio
    FROM formacoes f
    JOIN pessoas p ON f.pessoa_id = p.id
)
INSERT INTO formacoes_areas (formacao_id, area_id)
SELECT DISTINCT
    fm.formacao_id,
    a.id as area_id
FROM temp_curriculos t
CROSS JOIN LATERAL (
    SELECT TRIM(area_nome) as nome FROM regexp_split_to_table(t.grande_area, ';\s*') area_nome
    UNION
    SELECT TRIM(area_nome) as nome FROM regexp_split_to_table(t.area, ';\s*') area_nome
) AS areas_desaninhadas
JOIN formacao_map fm ON t.numero_identificador = fm.numero_identificador AND t.tipo_formacao = fm.tipo_formacao AND NULLIF(t.ano_inicio, '')::INTEGER = fm.ano_inicio
JOIN areas a ON a.nome_area = areas_desaninhadas.nome
WHERE areas_desaninhadas.nome <> '';

DROP TABLE temp_curriculos;

-- Mensagem de sucesso
SELECT 'Dados carregados com sucesso!' AS status;
