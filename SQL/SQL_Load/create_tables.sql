DROP TABLE IF EXISTS formacoes_areas CASCADE;
DROP TABLE IF EXISTS formacoes CASCADE;
DROP TABLE IF EXISTS areas CASCADE;
DROP TABLE IF EXISTS instituicoes CASCADE;
DROP TABLE IF EXISTS pessoas CASCADE;

-- Tabela principal de pessoas
CREATE TABLE pessoas (
    id SERIAL PRIMARY KEY,
    numero_identificador BIGINT UNIQUE,
    genero VARCHAR(1),
    data_atualizacao DATE,
    capital_nascimento BOOLEAN,
    uf_nascimento VARCHAR(2),
    regiao_nascimento VARCHAR(20),
    pais_nascimento VARCHAR(50)
);

-- Tabela de instituições (para normalizar)
CREATE TABLE instituicoes (
    id SERIAL PRIMARY KEY,
    sigla_instituicao VARCHAR(50),
    uf_instituicao VARCHAR(2),
    regiao_instituicao VARCHAR(20),
    pais_instituicao VARCHAR(50),
    UNIQUE(sigla_instituicao, uf_instituicao, pais_instituicao)
);

-- Tabela de áreas (para normalizar áreas múltiplas)
CREATE TABLE areas (
    id SERIAL PRIMARY KEY,
    nome_area VARCHAR(255) NOT NULL,
    tipo VARCHAR(20) CHECK (tipo IN ('grande_area', 'area')),
    UNIQUE(nome_area, tipo)
);

-- Tabela principal de formações
CREATE TABLE formacoes (
    id SERIAL PRIMARY KEY,
    pessoa_id INTEGER REFERENCES pessoas(id),
    instituicao_id INTEGER REFERENCES instituicoes(id),
    tipo_formacao VARCHAR(30),
    curso_concluido BOOLEAN,
    ano_inicio INTEGER,
    ano_conclusao INTEGER,
    flag_bolsa BOOLEAN
);

-- Tabela de relacionamento formações-áreas (para múltiplas áreas)
CREATE TABLE formacoes_areas (
    id SERIAL PRIMARY KEY,
    formacao_id INTEGER REFERENCES formacoes(id),
    area_id INTEGER REFERENCES areas(id),
    UNIQUE(formacao_id, area_id) -- Evita duplicatas
);

-- Índices para otimizar JOINS
CREATE INDEX idx_formacoes_pessoa_id ON formacoes(pessoa_id);
CREATE INDEX idx_formacoes_instituicao_id ON formacoes(instituicao_id);
CREATE INDEX idx_formacoes_areas_formacao_id ON formacoes_areas(formacao_id);
CREATE INDEX idx_formacoes_areas_area_id ON formacoes_areas(area_id);
CREATE INDEX idx_pessoas_nascimento ON pessoas(uf_nascimento, regiao_nascimento, pais_nascimento);
CREATE INDEX idx_instituicoes_local ON instituicoes(uf_instituicao, regiao_instituicao, pais_instituicao);