-- Passo 1: Criar uma tabela temporária para carregar os dados brutos do CSV.
-- Esta tabela servirá como uma área de preparação (staging area).
CREATE TEMP TABLE temp_curriculos (
    numero_identificador BIGINT,
    genero VARCHAR(1),
    data_atualizacao TEXT, -- Carregar como texto para tratar valores vazios/inválidos
    uf_nascimento VARCHAR(2),
    capital_nascimento BOOLEAN,
    regiao_nascimento VARCHAR(20),
    pais_nascimento VARCHAR(50),
    tipo_formacao VARCHAR(30),
    curso_concluido BOOLEAN,
    ano_inicio TEXT, -- Carregar como texto para tratar valores vazios/inválidos
    ano_conclusao TEXT, -- Carregar como texto para tratar valores vazios/inválidos
    grande_area VARCHAR(255),
    area VARCHAR(255),
    flag_bolsa BOOLEAN,
    sigla_instituicao VARCHAR(50),
    uf_instituicao VARCHAR(2),
    regiao_instituicao VARCHAR(20),
    pais_instituicao VARCHAR(50)
);

-- Passo 2: Carregar os dados do CSV para a tabela temporária.
-- IMPORTANTE: O caminho para o arquivo CSV deve ser absoluto.
-- Adapte o caminho abaixo para o local correto do seu arquivo 'curriculos_processados.csv'.
COPY temp_curriculos FROM 'C:\Program Files\PostgreSQL\17\data\curriculos_processados.csv' WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',');

-- Passo 3: Popular a tabela 'pessoas' com dados únicos.
-- Usamos DISTINCT ON para garantir que cada 'numero_identificador' seja inserido apenas uma vez.
-- A cláusula ORDER BY garante a consistência ao escolher qual linha usar para os dados da pessoa.
INSERT INTO pessoas (numero_identificador, genero, data_atualizacao, capital_nascimento, uf_nascimento, regiao_nascimento, pais_nascimento)
SELECT DISTINCT ON (numero_identificador)
    numero_identificador,
    genero,
    NULLIF(data_atualizacao, '')::DATE, -- Converte para data, tratando strings vazias
    capital_nascimento,
    uf_nascimento,
    regiao_nascimento,
    pais_nascimento
FROM temp_curriculos
ORDER BY numero_identificador, data_atualizacao DESC; -- Prioriza a data de atualização mais recente

-- Passo 4: Popular a tabela 'instituicoes' com dados únicos.
-- A restrição UNIQUE na tabela 'instituicoes' (sigla_instituicao, uf_instituicao) já previne duplicatas.
-- O 'ON CONFLICT DO NOTHING' garante que, se uma instituição já existir, o comando não falhará.
INSERT INTO instituicoes (sigla_instituicao, uf_instituicao, regiao_instituicao, pais_instituicao)
SELECT DISTINCT
    sigla_instituicao,
    uf_instituicao,
    regiao_instituicao,
    pais_instituicao
FROM temp_curriculos
WHERE sigla_instituicao IS NOT NULL AND sigla_instituicao <> ''
ON CONFLICT (sigla_instituicao, uf_instituicao, pais_instituicao) DO NOTHING;

-- Passo 5: Popular a tabela 'areas' com 'grande_area' e 'area'.
-- Inserimos primeiro as 'grande_area' e depois as 'area', tratando valores nulos ou vazios.
-- A restrição UNIQUE em 'nome_area' e o 'ON CONFLICT DO NOTHING' evitam duplicatas.

-- Inserir 'grande_area'
INSERT INTO areas (nome_area, tipo)
SELECT DISTINCT TRIM(unnest_grande_area), 'grande_area'
FROM temp_curriculos
CROSS JOIN LATERAL regexp_split_to_table(grande_area, ';\s*') AS unnest_grande_area
WHERE unnest_grande_area <> ''
ON CONFLICT (nome_area, tipo) DO NOTHING;

-- Inserir 'area'
INSERT INTO areas (nome_area, tipo)
SELECT DISTINCT TRIM(unnest_area), 'area'
FROM temp_curriculos
CROSS JOIN LATERAL regexp_split_to_table(area, ';\s*') AS unnest_area
WHERE unnest_area <> ''
ON CONFLICT (nome_area, tipo) DO NOTHING;

-- Passo 6: Popular a tabela 'formacoes'.
-- Aqui, fazemos o JOIN com as tabelas já populadas ('pessoas' e 'instituicoes') para obter os IDs corretos.
-- Usamos COALESCE e NULLIF para converter os anos para INTEGER, tratando valores vazios ou não numéricos.
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

-- Passo 7: Popular a tabela de relacionamento 'formacoes_areas'.
-- Esta etapa é mais complexa, pois precisamos associar cada formação às suas respectivas áreas.
-- Usamos uma CTE (Common Table Expression) para recriar a lógica de identificação de uma formação.
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

-- Passo 8: Limpar a tabela temporária após o uso.
DROP TABLE temp_curriculos;
