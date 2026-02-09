import xml.etree.ElementTree as ET
import zipfile
import os
import json
import time
from pathlib import Path
from datetime import datetime
import pandas as pd

class LattesProcessor:
    def __init__(self, base_path, output_dir="output"):
        self.base_path = Path(base_path)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        
        # Arquivos de checkpoint e log
        self.checkpoint_file = self.output_dir / "checkpoint.json"
        self.progress_file = self.output_dir / "progress.json"
        self.error_log = self.output_dir / "errors.log"
        self.data_file = self.output_dir / "curriculos_data.jsonl"
        
        # Carregar checkpoint se existir
        self.checkpoint = self.load_checkpoint()
        
    def load_checkpoint(self):
        """Carrega o último checkpoint para retomar processamento"""
        if self.checkpoint_file.exists():
            with open(self.checkpoint_file, 'r') as f:
                return json.load(f)
        return {"last_folder": -1, "last_file": "", "processed_count": 0}
    
    def save_checkpoint(self, folder, file, count):
        """Salva checkpoint atual"""
        checkpoint = {
            "last_folder": folder,
            "last_file": file,
            "processed_count": count,
            "timestamp": datetime.now().isoformat()
        }
        with open(self.checkpoint_file, 'w') as f:
            json.dump(checkpoint, f)
    
    def log_error(self, error_msg):
        """Registra erros em arquivo de log"""
        with open(self.error_log, 'a', encoding='utf-8') as f:
            f.write(f"[{datetime.now().isoformat()}] {error_msg}\n")
    
    def extract_xml_from_zip(self, zip_path):
        """Extrai XML de um arquivo ZIP"""
        try:
            with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                xml_files = [f for f in zip_ref.namelist() if f.endswith('.xml')]
                if xml_files:
                    return zip_ref.read(xml_files[0])
        except Exception as e:
            self.log_error(f"Erro ao extrair {zip_path}: {str(e)}")
        return None
    
    def parse_curriculo(self, xml_content, filename=None):
        """Extrai informações de um currículo XML
        
        Args:
            xml_content: Conteúdo XML do currículo
            filename: Nome do arquivo (usado se NUMERO-IDENTIFICADOR não existir)
        """
        try:
            root = ET.fromstring(xml_content)
            
            # Pegar NUMERO-IDENTIFICADOR do root ou do nome do arquivo
            numero_id = root.get('NUMERO-IDENTIFICADOR')
            if not numero_id and filename:
                # Remove extensão .zip do filename
                numero_id = filename.replace('.zip', '')
            
            # Pegar DATA-ATUALIZACAO do root também
            data_atualizacao = root.get('DATA-ATUALIZACAO')
            
            data = {
                "numero_identificador": numero_id,
                "dados_gerais": {},
                "formacoes": [],
                "instituicoes": {},
                "cursos": {}
            }
            
            # DADOS GERAIS
            dados_gerais = root.find('.//DADOS-GERAIS')
            if dados_gerais is not None:
                data["dados_gerais"] = {
                    "nome_completo": dados_gerais.get('NOME-COMPLETO'),
                    "pais_nascimento": dados_gerais.get('PAIS-DE-NASCIMENTO'),
                    "uf_nascimento": dados_gerais.get('UF-NASCIMENTO'),
                    "cidade_nascimento": dados_gerais.get('CIDADE-NASCIMENTO')
                }
            
            # Adicionar data de atualização do root
            if data_atualizacao:
                data["dados_gerais"]["data_atualizacao"] = data_atualizacao
            
            # FORMAÇÕES (Mestrado, Doutorado)
            formacao_paths = [
                './/FORMACAO-ACADEMICA-TITULACAO/MESTRADO',
                './/FORMACAO-ACADEMICA-TITULACAO/MESTRADO-PROFISSIONALIZANTE',
                './/FORMACAO-ACADEMICA-TITULACAO/DOUTORADO'
            ]
            
            codigos_instituicao = set()
            codigos_curso = set()
            
            for path in formacao_paths:
                for formacao in root.findall(path):
                    tipo = path.split('/')[-1]
                    
                    formacao_data = {
                        "tipo": tipo,
                        "codigo_instituicao": formacao.get('CODIGO-INSTITUICAO'),
                        "codigo_curso": formacao.get('CODIGO-CURSO'),
                        "codigo_area_curso": formacao.get('CODIGO-AREA-CURSO'),
                        "status": formacao.get('STATUS-DO-CURSO'),
                        "ano_inicio": formacao.get('ANO-DE-INICIO'),
                        "ano_conclusao": formacao.get('ANO-DE-CONCLUSAO'),
                        "flag_bolsa": formacao.get('FLAG-BOLSA'),
                        "areas_conhecimento": []
                    }
                    
                    # Adicionar códigos aos sets para buscar depois
                    if formacao_data["codigo_instituicao"]:
                        codigos_instituicao.add(formacao_data["codigo_instituicao"])
                    if formacao_data["codigo_curso"]:
                        codigos_curso.add(formacao_data["codigo_curso"])
                    
                    # AREAS-DO-CONHECIMENTO dentro da formação
                    # Pode ter AREA-DO-CONHECIMENTO-1, AREA-DO-CONHECIMENTO-2, etc
                    areas_conhecimento = formacao.find('.//AREAS-DO-CONHECIMENTO')
                    if areas_conhecimento is not None:
                        # Buscar todas as áreas (AREA-DO-CONHECIMENTO, AREA-DO-CONHECIMENTO-1, etc)
                        for child in areas_conhecimento:
                            if 'AREA-DO-CONHECIMENTO' in child.tag:
                                formacao_data["areas_conhecimento"].append({
                                    "nome_grande_area": child.get('NOME-GRANDE-AREA-DO-CONHECIMENTO'),
                                    "nome_area": child.get('NOME-DA-AREA-DO-CONHECIMENTO')
                                })
                    
                    data["formacoes"].append(formacao_data)
            
            # INFORMAÇÕES ADICIONAIS - INSTITUIÇÕES
            for inst in root.findall('.//DADOS-COMPLEMENTARES/INFORMACOES-ADICIONAIS-INSTITUICOES/INFORMACAO-ADICIONAL-INSTITUICAO'):
                codigo = inst.get('CODIGO-INSTITUICAO')
                if codigo in codigos_instituicao:
                    data["instituicoes"][codigo] = {
                        "sigla_instituicao": inst.get('SIGLA-INSTITUICAO'),
                        "sigla_uf": inst.get('SIGLA-UF-INSTITUICAO'),
                        "nome_pais": inst.get('NOME-PAIS-INSTITUICAO')
                    }
            
            # INFORMAÇÕES ADICIONAIS - CURSOS
            for curso in root.findall('.//DADOS-COMPLEMENTARES/INFORMACOES-ADICIONAIS-CURSOS/INFORMACAO-ADICIONAL-CURSO'):
                codigo = curso.get('CODIGO-CURSO')
                if codigo in codigos_curso:
                    data["cursos"][codigo] = {
                        "nome_grande_area": curso.get('NOME-GRANDE-AREA-DO-CONHECIMENTO'),
                        "nome_area": curso.get('NOME-DA-AREA-DO-CONHECIMENTO')
                    }
            
            return data
            
        except Exception as e:
            self.log_error(f"Erro ao parsear XML: {str(e)}")
            return None
    
    def process_all(self, max_folders=None):
        """Processa todos os currículos
        
        Args:
            max_folders: Número máximo de pastas a processar (None = todas)
                        Ex: max_folders=3 processa apenas pastas 00, 01, 02
        """
        start_time = time.time()
        processed_count = self.checkpoint["processed_count"]
        error_count = 0
        
        # Define quantas pastas processar
        total_folders = max_folders if max_folders is not None else 100
        
        print(f"Iniciando processamento...")
        print(f"Processando {total_folders} pasta(s)")
        print(f"Retomando do folder {self.checkpoint['last_folder'] + 1}")
        
        # Processar pastas de 00 a 99 (ou até max_folders)
        for folder_num in range(total_folders):
            # Pular pastas já processadas
            if folder_num <= self.checkpoint["last_folder"]:
                continue
                
            folder_name = f"{folder_num:02d}"
            folder_path = self.base_path / folder_name
            
            if not folder_path.exists():
                print(f"Pasta {folder_name} não encontrada, pulando...")
                continue
            
            print(f"\nProcessando pasta {folder_name}...")
            
            # Listar todos os arquivos ZIP
            zip_files = sorted(folder_path.glob("*.zip"))
            
            if not zip_files:
                print(f"Nenhum arquivo ZIP encontrado em {folder_name}")
                continue
            
            print(f"Encontrados {len(zip_files)} arquivos ZIP")
            
            for i, zip_file in enumerate(zip_files):
                # Pular arquivos já processados na última pasta
                if folder_num == self.checkpoint["last_folder"] + 1:
                    if zip_file.name <= self.checkpoint["last_file"]:
                        continue
                
                try:
                    # Extrair XML
                    xml_content = self.extract_xml_from_zip(zip_file)
                    if xml_content is None:
                        error_count += 1
                        continue
                    
                    # Parsear currículo (passando o nome do arquivo)
                    data = self.parse_curriculo(xml_content, zip_file.name)
                    if data is None:
                        error_count += 1
                        continue
                    
                    # Salvar em arquivo JSONL (uma linha por currículo)
                    with open(self.data_file, 'a', encoding='utf-8') as f:
                        f.write(json.dumps(data, ensure_ascii=False) + '\n')
                    
                    processed_count += 1
                    
                    # Atualizar checkpoint a cada 100 currículos
                    if processed_count % 100 == 0:
                        self.save_checkpoint(folder_num, zip_file.name, processed_count)
                        elapsed = time.time() - start_time
                        rate = processed_count / elapsed
                        
                        # Calcular tempo restante baseado nos arquivos desta pasta
                        files_remaining_in_folder = len(zip_files) - (i + 1)
                        remaining_seconds = files_remaining_in_folder / rate if rate > 0 else 0

                        # Converter tempo restante em minutos e segundos
                        mins, secs = divmod(int(remaining_seconds), 60)
                        
                        print(f"Processados: {processed_count:,} | "
                              f"Erros: {error_count:,} | "
                              f"Taxa: {rate:.1f}/s | "
                              f"Restam nesta pasta: {files_remaining_in_folder:,} | "
                              f"Tempo estimado:  {mins} min {secs:02d} s")
                
                except Exception as e:
                    self.log_error(f"Erro ao processar {zip_file}: {str(e)}")
                    error_count += 1
            
            # Checkpoint ao final de cada pasta
            self.save_checkpoint(folder_num, "", processed_count)
        
        # Estatísticas finais
        total_time = time.time() - start_time
        print(f"\n{'='*60}")
        print(f"PROCESSAMENTO CONCLUÍDO!")
        print(f"Total processado: {processed_count:,}")
        print(f"Total de erros: {error_count:,}")
        print(f"Tempo total: {total_time/3600:.2f} horas")
        print(f"Taxa média: {processed_count/total_time:.1f} currículos/segundo")
        print(f"{'='*60}")
        
        # Salvar estatísticas
        stats = {
            "processed_count": processed_count,
            "error_count": error_count,
            "total_time_hours": total_time/3600,
            "rate_per_second": processed_count/total_time,
            "completion_date": datetime.now().isoformat()
        }
        with open(self.output_dir / "statistics.json", 'w') as f:
            json.dump(stats, f, indent=2)
    
    def convert_to_dataframe(self):
        """Converte JSONL para DataFrame para análise"""
        
        # Verificar se o arquivo existe
        if not self.data_file.exists():
            print("Nenhum dado foi processado ainda.")
            print("Verifique se o caminho está correto e se existem arquivos ZIP nas pastas.")
            return None
            
        print("Convertendo dados para DataFrame...")
        
        records = []
        with open(self.data_file, 'r', encoding='utf-8') as f:
            for line in f:
                data = json.loads(line)
                
                # Dados base
                base = {
                    "numero_identificador": data["numero_identificador"],
                    "nome_completo": data["dados_gerais"].get("nome_completo"),
                    "pais_nascimento": data["dados_gerais"].get("pais_nascimento"),
                    "uf_nascimento": data["dados_gerais"].get("uf_nascimento"),
                    "cidade_nascimento": data["dados_gerais"].get("cidade_nascimento"),
                    "data_atualizacao": data["dados_gerais"].get("data_atualizacao")
                }
                
                # Uma linha por formação
                for formacao in data["formacoes"]:
                    record = base.copy()
                    
                    # Dados da formação
                    record["tipo_formacao"] = formacao.get("tipo")
                    record["codigo_instituicao"] = formacao.get("codigo_instituicao")
                    record["codigo_curso"] = formacao.get("codigo_curso")
                    record["codigo_area_curso"] = formacao.get("codigo_area_curso")
                    record["status_curso"] = formacao.get("status")
                    record["ano_inicio"] = formacao.get("ano_inicio")
                    record["ano_conclusao"] = formacao.get("ano_conclusao")
                    record["flag_bolsa"] = formacao.get("flag_bolsa")
                    
                    # Adicionar info de instituição
                    codigo_inst = formacao.get("codigo_instituicao")
                    if codigo_inst and codigo_inst in data["instituicoes"]:
                        record["sigla_instituicao"] = data["instituicoes"][codigo_inst].get("sigla_instituicao")
                        record["uf_instituicao"] = data["instituicoes"][codigo_inst].get("sigla_uf")
                        record["pais_instituicao"] = data["instituicoes"][codigo_inst].get("nome_pais")
                    else:
                        record["sigla_instituicao"] = None
                        record["uf_instituicao"] = None
                        record["pais_instituicao"] = None
                    
                    # Adicionar info de curso
                    codigo_curso = formacao.get("codigo_curso")
                    if codigo_curso and codigo_curso in data["cursos"]:
                        record["curso_grande_area"] = data["cursos"][codigo_curso].get("nome_grande_area")
                        record["curso_area"] = data["cursos"][codigo_curso].get("nome_area")
                    else:
                        record["curso_grande_area"] = None
                        record["curso_area"] = None
                    
                    # Áreas do conhecimento da formação (separadas e únicas)
                    areas_conhecimento = formacao.get("areas_conhecimento", [])
                    if areas_conhecimento:
                        # Extrair grandes áreas únicas
                        grandes_areas = list(set([
                            area.get('nome_grande_area', '') 
                            for area in areas_conhecimento 
                            if area.get('nome_grande_area')
                        ]))
                        
                        # Extrair áreas únicas
                        areas = list(set([
                            area.get('nome_area', '') 
                            for area in areas_conhecimento 
                            if area.get('nome_area')
                        ]))
                        
                        record["grande_area_formacao"] = "; ".join(sorted(grandes_areas)) if grandes_areas else None
                        record["area_formacao"] = "; ".join(sorted(areas)) if areas else None
                    else:
                        record["grande_area_formacao"] = None
                        record["area_formacao"] = None
                    
                    records.append(record)
        
        df = pd.DataFrame(records)
        df.to_parquet(self.output_dir / "curriculos_data.parquet", index=False)
        df.to_csv(self.output_dir / "curriculos_data.csv", index=False, encoding='utf-8-sig')
        
        print(f"DataFrame salvo com {len(df):,} registros")
        return df


if __name__ == "__main__":
    # Configurar processador
    base_path = r"D:\Dowloads\mestres-e-doutores-completo"
    
    print(f"Verificando caminho base: {base_path}")
    print(f"Caminho existe? {Path(base_path).exists()}")
    
    # Listar pastas disponíveis
    if Path(base_path).exists():
        pastas = sorted([p.name for p in Path(base_path).iterdir() if p.is_dir()])
        print(f"Pastas encontradas: {pastas[:10]}...")  # Mostra as 10 primeiras
    
    processor = LattesProcessor(
        base_path=base_path,
        output_dir="output_lattes"
    )
    
    # TESTE: Processar apenas as 3 primeiras pastas (00, 01, 02)
    # Para processar tudo, use: processor.process_all(max_folders=1)
    processor.process_all()  # ← MUDE AQUI para testar
    
    # Converter para formato de análise
    df = processor.convert_to_dataframe()
    
    if df is not None:
        print("\nPrimeiras linhas do DataFrame:")
        print(df.head())
        print(f"\nTotal de registros: {len(df)}")