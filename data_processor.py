import pandas as pd
from pathlib import Path
import unicodedata
import re

class LattesDataProcessor:
    """Processa e enriquece dados dos currículos Lattes"""
    
    def __init__(self, input_file, grupos_file, output_dir):
        self.input_file = Path(input_file)
        self.grupos_file = Path(grupos_file)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        
        # Inicializar estruturas
        self.name_to_gender = {}
        self.nomes_principais = set()
        
        # Carregar base de nomes
        print("="*60)
        print("Carregando base de grupos de nomes...")
        print("="*60)
        self.grupos_df = self._load_grupos()
        
        # Estatísticas de classificação
        self.stats = {
            'nomes_nao_classificados': set()
        }
        
        # Mapeamentos de UF para Região
        self.uf_to_region = {
            # Norte
            'AC': 'Norte', 'AP': 'Norte', 'AM': 'Norte', 'PA': 'Norte',
            'RO': 'Norte', 'RR': 'Norte', 'TO': 'Norte',
            # Nordeste
            'AL': 'Nordeste', 'BA': 'Nordeste', 'CE': 'Nordeste', 'MA': 'Nordeste',
            'PB': 'Nordeste', 'PE': 'Nordeste', 'PI': 'Nordeste', 'RN': 'Nordeste', 'SE': 'Nordeste',
            # Centro-Oeste
            'DF': 'Centro-Oeste', 'GO': 'Centro-Oeste', 'MT': 'Centro-Oeste', 'MS': 'Centro-Oeste',
            # Sudeste
            'ES': 'Sudeste', 'MG': 'Sudeste', 'RJ': 'Sudeste', 'SP': 'Sudeste',
            # Sul
            'PR': 'Sul', 'RS': 'Sul', 'SC': 'Sul'
        }
    
    def _normalize_text(self, text):
        if pd.isna(text):
            return ''
        s = str(text).strip().upper()
        # decompor e remover marcas combinantes (acentos)
        s = unicodedata.normalize('NFD', s)
        s = ''.join(ch for ch in s if not unicodedata.combining(ch))
        # opcional: remover caracteres que não sejam letras ou espaço
        # s = re.sub(r'[^A-Z\s]', '', s)
        return s
    
    def _load_grupos(self):
        """Carrega e processa o arquivo grupos.csv"""
        try:
            # Tentar diferentes encodings
            df = None
            last_error = None
            for encoding in ['utf-8', 'latin-1', 'iso-8859-1', 'cp1252']:
                try:
                    df = pd.read_csv(self.grupos_file, encoding=encoding)
                    print(f"✓ Arquivo carregado com encoding {encoding}")
                    print(f"  Colunas: {df.columns.tolist()}")
                    print(f"  Total de grupos: {len(df):,}")
                    break
                except Exception as e:
                    last_error = e
                    continue
            
            if df is None:
                raise Exception(f"Não foi possível ler o arquivo. Último erro: {last_error}")
            
            # Verificar colunas
            required_cols = ['name', 'classification', 'names']
            missing = [col for col in required_cols if col not in df.columns]
            if missing:
                raise Exception(f"Colunas faltando: {missing}")
            
            print("\nCriando índice de nomes...")
            
            # Indexar nomes principais
            for idx, row in df.iterrows():
                nome_principal = self._normalize_text(row['name'])
                classification = str(row['classification']).strip().upper()
                
                if nome_principal:
                    self.name_to_gender[nome_principal] = classification
                    self.nomes_principais.add(nome_principal)
                
                if (idx + 1) % 5000 == 0:
                    print(f"  Processados {idx + 1:,}/{len(df):,} grupos...")
            
            print(f"✓ {len(self.nomes_principais):,} nomes principais indexados")
            
            # Indexar variações
            print("\nIndexando variações de nomes...")
            variacoes_count = 0
            for idx, row in df.iterrows():
                classification = str(row['classification']).strip().upper()
                
                if pd.notna(row['names']):
                    names_list = str(row['names']).split('|')
                    
                    for variacao in names_list:
                        variacao_clean = self._normalize_text(variacao)
                        
                        if variacao_clean and variacao_clean not in self.nomes_principais:
                            if variacao_clean not in self.name_to_gender:
                                self.name_to_gender[variacao_clean] = classification
                                variacoes_count += 1
                
                if (idx + 1) % 5000 == 0:
                    print(f"  Processados {idx + 1:,}/{len(df):,} grupos...")
            
            print(f"✓ {variacoes_count:,} variações adicionais indexadas")
            print(f"✓ Total no cache: {len(self.name_to_gender):,} nomes únicos")
            print("="*60)
            
            return df
            
        except Exception as e:
            print(f"\n⚠ ERRO: {e}")
            import traceback
            traceback.print_exc()
            print("⚠ Continuando sem base de nomes")
            return None
    
    def predict_gender(self, nome_completo):
        """Prediz o gênero baseado no primeiro nome"""
        if pd.isna(nome_completo) or not self.name_to_gender:
            return None
        
        nome_normalizado = self._normalize_text(str(nome_completo))
        partes = nome_normalizado.split()
        
        if not partes:
            return None
        
        primeiro_nome = partes[0]
        
        if primeiro_nome in self.name_to_gender:
            classificacao = self.name_to_gender[primeiro_nome]
            return classificacao
        
        if primeiro_nome.endswith('A'):
            return 'F'
        elif primeiro_nome.endswith(('O', 'OS', 'EUS', 'EU', 'OR')):
            return 'M'
        elif primeiro_nome.endswith(('NE', 'TE', 'CE', 'SE')):
            return 'F'
        
        self.stats['nomes_nao_classificados'].add(primeiro_nome)
        return None
    
    def get_region_from_uf(self, uf):
        """Retorna a região a partir da UF"""
        if pd.isna(uf):
            return None
        uf = str(uf).strip().upper()
        return self.uf_to_region.get(uf, None)
    
    def process_grande_area(self, curso_grande_area, grande_area_formacao):
        """Define grande_area_definitivo seguindo as regras"""
        if pd.isna(curso_grande_area) or str(curso_grande_area).strip() == '':
            if pd.notna(grande_area_formacao) and str(grande_area_formacao).strip() != '':
                return str(grande_area_formacao)
            return None
        
        if str(curso_grande_area).strip().upper() == 'OUTROS':
            if pd.notna(grande_area_formacao) and str(grande_area_formacao).strip() != '':
                areas = [a.strip() for a in str(grande_area_formacao).split(';')]
                areas_filtradas = [a for a in areas if a.upper() != 'OUTROS']
                
                if areas_filtradas:
                    return '; '.join(areas_filtradas)
                return str(grande_area_formacao)
            return curso_grande_area
        
        return curso_grande_area
    
    def process_area(self, curso_area, area_formacao):
        """Define area_definitivo seguindo as regras"""
        areas_genericas = ['MULTIDISCIPLINAR', 'ADMINISTRAÇÃO HOSPITALAR']
        
        if pd.isna(curso_area) or str(curso_area).strip() == '':
            if pd.notna(area_formacao) and str(area_formacao).strip() != '':
                return str(area_formacao)
            return None
        
        curso_area_upper = str(curso_area).strip().upper()
        if any(generica in curso_area_upper for generica in areas_genericas):
            if pd.notna(area_formacao) and str(area_formacao).strip() != '':
                areas = [a.strip() for a in str(area_formacao).split(';')]
                areas_filtradas = [
                    a for a in areas 
                    if not any(gen in a.upper() for gen in areas_genericas)
                ]
                
                if areas_filtradas:
                    return '; '.join(areas_filtradas)
                return str(area_formacao)
            return curso_area
        
        return curso_area
    
    def process_flag_bolsa(self, df):
        """Converte a coluna 'flag_bolsa' para booleano."""
        df['flag_bolsa'] = (df['flag_bolsa'] == 'SIM')
        return df

    def process_status_curso(self, df):
        """Converte a coluna 'status_curso' para booleano (concluido ou nao)."""
        df['curso_concluido'] = (df['status_curso'] == 'CONCLUIDO')
        df = df.drop(columns=['status_curso'])
        return df

    def _create_capital_column(self, df):
        """Cria uma coluna booleana para identificar se a cidade de nascimento é capital."""
        capitais = {
            'AC': 'RIO BRANCO', 'AL': 'MACEIO', 'AP': 'MACAPA', 'AM': 'MANAUS',
            'BA': 'SALVADOR', 'CE': 'FORTALEZA', 'DF': 'BRASILIA', 'ES': 'VITORIA',
            'GO': 'GOIANIA', 'MA': 'SAO LUIS', 'MT': 'CUIABA', 'MS': 'CAMPO GRANDE',
            'MG': 'BELO HORIZONTE', 'PA': 'BELEM', 'PB': 'JOAO PESSOA', 'PR': 'CURITIBA',
            'PE': 'RECIFE', 'PI': 'TERESINA', 'RJ': 'RIO DE JANEIRO', 'RN': 'NATAL',
            'RS': 'PORTO ALEGRE', 'RO': 'PORTO VELHO', 'RR': 'BOA VISTA',
            'SC': 'FLORIANOPOLIS', 'SP': 'SAO PAULO', 'SE': 'ARACAJU', 'TO': 'PALMAS'
        }

        def is_capital(row):
            uf = row['uf_nascimento']
            cidade = row['cidade_nascimento']
            
            if pd.isna(uf) or pd.isna(cidade):
                return False
            
            # Normaliza os textos para comparação
            uf_norm = self._normalize_text(uf)
            cidade_norm = self._normalize_text(cidade)
            
            capital_do_uf = capitais.get(uf_norm)
            
            return cidade_norm == capital_do_uf

        df['capital_nascimento'] = df.apply(is_capital, axis=1)
        return df

    def _convert_data_types(self, df):
        """Converte os tipos de dados das colunas para os formatos corretos."""
        # Converter data_atualizacao para date
        df['data_atualizacao'] = pd.to_datetime(df['data_atualizacao'], format='%d%m%Y', errors='coerce').dt.date
        # Converter anos para inteiros, tratando erros
        df['ano_inicio'] = pd.to_numeric(df['ano_inicio'], errors='coerce').astype('Int64')
        df['ano_conclusao'] = pd.to_numeric(df['ano_conclusao'], errors='coerce').astype('Int64')
        return df
    
    def _limpar_sigla_instituicao(self, df):
        def limpar_texto(sigla):
            if not isinstance(sigla, str):
                return sigla
            sigla = unicodedata.normalize('NFKD', sigla)
            sigla = ''.join(c for c in sigla if not unicodedata.combining(c))
            sigla = sigla.upper()
            sigla = sigla.replace('Ç', 'C')
            sigla = sigla.replace('%20', '')
            sigla = re.sub(r'[^A-Z0-9]', '', sigla)
            return sigla.strip()

        # Aplica a limpeza à coluna existente
        if 'sigla_instituicao' in df.columns:
            df['sigla_instituicao'] = df['sigla_instituicao'].apply(limpar_texto)
        return df
    
    def corrigir_area(self, df):
        substituicoes = {
            "Ling&uuml;&iacute;stica": "Linguística",
            "Engenharia El&eacute;trica": "Engenharia Elétrica",
            "Servi&ccedil;o Social": "Serviço Social",
            "Medicina Veterin&aacute;ria": "Medicina Veterinária",
            "Administra&ccedil;&atilde;o": "Administração",
            "Educa&ccedil;&atilde;o": "Educação",
            "Gen&eacute;tica": "Genética",
            "Bot&acirc;nica": "Botânica",
            "Ci&ecirc;ncia e Tecnologia de Alimentos": "Ciência e Tecnologia de Alimentos",
            "Ci&ecirc;ncia Pol&iacute": "Ciência Política",
            "Qu&iacute;mica": "Química",
            "Agronomía": "Agronomia",
            "Energia": "Engenharia de Energia",
            "Lingüística, Letras e Artes": "Linguística",
            "Lingüística": "Linguística",
            "Ci&ecirc;ncia Pol&iacute;tica": "Ciência Política"
        }
        df["area"] = df["area"].replace(substituicoes)
        return df
    
    def limpar_campos_exterior(self, df):
        # Campos da instituição
        df.loc[df["pais_instituicao"] != "Brasil", ["uf_instituicao", "regiao_instituicao"]] = ''
        # Campos de nascimento
        df.loc[df["pais_nascimento"] != "Brasil", ["uf_nascimento", "regiao_nascimento"]] = ''
        return df

    def select_and_order_columns(self, df):
        """Seleciona e ordena as colunas finais do DataFrame."""
        final_columns = [
            'numero_identificador', 'genero', 'data_atualizacao', 'uf_nascimento', 'capital_nascimento',
            'regiao_nascimento', 'pais_nascimento', 'tipo_formacao', 'curso_concluido',
            'ano_inicio', 'ano_conclusao', 'grande_area', 'area', 'flag_bolsa',
            'sigla_instituicao', 'uf_instituicao', 'regiao_instituicao', 'pais_instituicao'
        ]
        
        # Garante que apenas colunas existentes sejam selecionadas para evitar erros
        existing_columns = [col for col in final_columns if col in df.columns]
                
        return df[existing_columns]
    
    def process_data(self):
        """Processa o arquivo de dados"""
        print("\nCarregando dados de currículos...")
        
        if self.input_file.suffix == '.parquet':
            df = pd.read_parquet(self.input_file)
        elif self.input_file.suffix == '.csv':
            df = pd.read_csv(self.input_file, encoding='utf-8-sig')
        else:
            raise ValueError("Use .parquet ou .csv")
        
        print(f"✓ Carregados {len(df):,} registros")
        
        # Resetar estatísticas
        self.stats = {
            'nomes_nao_classificados': set()
        }
        
        print("\n1. Adicionando regiões...")
        df['regiao_nascimento'] = df['uf_nascimento'].apply(self.get_region_from_uf)
        df['regiao_instituicao'] = df['uf_instituicao'].apply(self.get_region_from_uf)
        
        print("2. Processando grande_area_definitivo...")
        df['grande_area'] = df.apply(
            lambda row: self.process_grande_area(
                row.get('curso_grande_area'),
                row.get('grande_area_formacao')
            ),
            axis=1
        )
        
        print("3. Processando area_definitivo...")
        df['area'] = df.apply(
            lambda row: self.process_area(
                row.get('curso_area'),
                row.get('area_formacao')
            ),
            axis=1
        )
        
        print("4. Predizendo gênero...")
        df['genero'] = df['nome_completo'].apply(self.predict_gender)

        # Salvar nomes não classificados
        if self.stats['nomes_nao_classificados']:
            nomes_file = self.output_dir / "nomes_nao_classificados.txt"
            with open(nomes_file, 'w', encoding='utf-8') as f:
                for nome in sorted(self.stats['nomes_nao_classificados']):
                    f.write(f"{nome}\n")
        
        # Transformar colunas para booleano
        print("5. Convertendo 'flag_bolsa' para booleano...")
        df = self.process_flag_bolsa(df)
        print("6. Convertendo 'status_curso' para booleano...")
        df = self.process_status_curso(df)

        # Converter tipos de dados
        print("7. Convertendo tipos de dados...")
        df = self._convert_data_types(df)

        # Adiciona a coluna de capital
        print("8. Verificando se a cidade de nascimento é capital...")
        df = self._create_capital_column(df)

        # Deixar dados mais bonitos
        print("9. Limpando siglas de instituições...")
        df = self._limpar_sigla_instituicao(df)

        print("10. Corrigindo nomes de áreas...")
        df = self.corrigir_area(df)

        print("11. Limpando uf do exterior...")
        df = self.limpar_campos_exterior(df)

        # Selecionar e ordenar colunas
        print("12. Selecionando e ordenando colunas finais...")
        df_final = self.select_and_order_columns(df)
        
        # Estatísticas
        print("\n" + "="*60)
        print("ESTATÍSTICAS")
        print("="*60)
        print(f"Total de registros: {len(df):,}")
        
        print(f"\nRegiões de nascimento:")
        print(df['regiao_nascimento'].value_counts().to_string())
        
        print(f"\nRegiões de instituição:")
        print(df['regiao_instituicao'].value_counts().to_string())

        print(f"\nDistribuição de gênero:")
        print(df['genero'].value_counts().to_string())
        print(f"Gênero indeterminado: {df['genero'].isna().sum():,} ({df['genero'].isna().sum()/len(df)*100:.1f}%)")
        print(f"Nomes únicos não classificados: {len(self.stats['nomes_nao_classificados']):,}")
        
        print(f"\nDistribuição de bolsas:")
        print(df['flag_bolsa'].value_counts().to_string())

        print("\nEstatísticas de Nascimento em Capital:")
        print(df['capital_nascimento'].value_counts().to_string())
        print(f"Percentual de nascidos em capital: {df['capital_nascimento'].mean()*100:.2f}%")

        # Salvar
        output_parquet = self.output_dir / "curriculos_processados.parquet"
        output_csv = self.output_dir / "curriculos_processados.csv"
        
        print(f"\nSalvando arquivos...")
        df_final.to_parquet(output_parquet, index=False)
        df_final.to_csv(output_csv, index=False, encoding='utf-8-sig')
        
        print(f"✓ Parquet: {output_parquet}")
        print(f"✓ CSV: {output_csv}")
        print("="*60)
        
        return df_final


if __name__ == "__main__":
    processor = LattesDataProcessor(
        input_file="output_lattes/curriculos_data.parquet",
        grupos_file="grupos.csv",
        output_dir="output_lattes"
    )
    
    df = processor.process_data()