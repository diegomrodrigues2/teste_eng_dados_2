import sys
from datetime import datetime, date
import json
from pyspark.sql import SparkSession
from pyspark.sql.window import Window
from pyspark.sql import functions as F
from pyspark.sql.types import StringType, IntegerType, DateType, DoubleType
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job


def carregar_dados(spark, caminho_tabela_silver):
    """
    Carrega os dados da camada Silver.
    
    Esta função lê os arquivos parquet da camada Silver e retorna o DataFrame correspondente
    junto com a contagem de registros. Útil para iniciar as validações de qualidade de dados.
    
    Args:
        spark: Sessão Spark ativa
        caminho_tabela_silver: Caminho para a tabela na camada Silver
        
    Returns:
        DataFrame com os dados carregados e a contagem de registros
    """
    print(f"Carregando dados de: {caminho_tabela_silver}")
    try:
        df = spark.read.parquet(caminho_tabela_silver)
        contagem_registros = df.count()
        print(f"Carregados {contagem_registros} registros com sucesso")
        return df, contagem_registros
    except Exception as e:
        print(f"Falha ao carregar dados: {str(e)}")
        return None, 0


def adicionar_resultado_validacao(resultados_dq, dimensao, validacao, status, mensagem, contagem_falhas=0, limite=0):
    """
    Adiciona um resultado de validação ao relatório de qualidade de dados.
    
    Esta função mantém o registro de todas as validações realizadas, incluindo 
    a dimensão avaliada, o status (passou/aviso/falhou) e detalhes sobre a validação.
    
    Args:
        resultados_dq: Dicionário com os resultados de qualidade
        dimensao: Dimensão de qualidade sendo avaliada (completude, unicidade, etc.)
        validacao: Nome da validação específica
        status: Status da validação (passou, aviso, falhou)
        mensagem: Descrição detalhada do resultado
        contagem_falhas: Número de registros que falharam na validação
        limite: Limite aceitável para considerar a validação como bem-sucedida
    """
    resultados_dq["validations"].append({
        "dimension": dimensao,
        "validation": validacao,
        "status": status,
        "message": mensagem,
        "failed_count": contagem_falhas,
        "threshold": limite,
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    })


def validar_completude(df, resultados_dq):
    """
    Valida a completude dos campos obrigatórios na tabela de clientes.
    
    Esta função verifica se os campos obrigatórios estão preenchidos (não nulos),
    calculando a porcentagem de valores ausentes e comparando com um limite predefinido.
    A verificação de completude é crucial para garantir que todos os dados essenciais
    do cliente estejam disponíveis para processamento posterior.
    
    Args:
        df: DataFrame com os dados a serem validados
        resultados_dq: Dicionário para armazenar os resultados das validações
    """
    print("Validando completude dos dados...")
    
    # Define campos obrigatórios
    campos_obrigatorios = [
        "cod_cliente", 
        "nm_cliente", 
        "nm_pais_cliente", 
        "dt_nascimento_cliente", 
        "dt_atualizacao",
        "tp_pessoa"
    ]
    
    # Verifica cada campo obrigatório
    for campo in campos_obrigatorios:
        contagem_nulos = df.filter(F.col(campo).isNull()).count()
        porcentagem_nulos = (contagem_nulos / resultados_dq["record_count"]) * 100 if resultados_dq["record_count"] > 0 else 0
        
        # Define limite e determina status
        limite = 1.0  # 1% de limite para valores ausentes
        if porcentagem_nulos == 0:
            status = "passou"
            mensagem = f"Campo '{campo}' não possui valores ausentes"
        elif porcentagem_nulos <= limite:
            status = "aviso"
            mensagem = f"Campo '{campo}' possui {porcentagem_nulos:.2f}% de valores ausentes (limite: {limite}%)"
        else:
            status = "falhou"
            mensagem = f"Campo '{campo}' possui {porcentagem_nulos:.2f}% de valores ausentes, excedendo o limite de {limite}%"
        
        adicionar_resultado_validacao(
            resultados_dq,
            dimensao="completude",
            validacao=f"campo_obrigatorio_{campo}",
            status=status,
            mensagem=mensagem,
            contagem_falhas=contagem_nulos,
            limite=limite
        )


def validar_unicidade(df, resultados_dq):
    """
    Valida a unicidade dos registros de clientes.
    
    Esta função verifica se existem registros duplicados de clientes com base no código
    do cliente, o que não deveria ocorrer na camada Silver. A unicidade é essencial para
    garantir que cada cliente seja representado apenas uma vez no conjunto de dados,
    evitando inconsistências nas análises e processamentos posteriores.
    
    Args:
        df: DataFrame com os dados a serem validados
        resultados_dq: Dicionário para armazenar os resultados das validações
    """
    print("Validando unicidade dos registros...")
    
    # Verifica duplicidades no código de cliente (não devem existir na camada Silver)
    especificacao_janela = Window.partitionBy("cod_cliente")
    df_com_contagem = df.withColumn("contagem_registros", F.count("*").over(especificacao_janela))
    registros_duplicados = df_com_contagem.filter(F.col("contagem_registros") > 1)
    contagem_duplicados = registros_duplicados.count()
    
    if contagem_duplicados == 0:
        status = "passou"
        mensagem = "Nenhum registro de cliente duplicado encontrado"
    else:
        status = "falhou"
        mensagem = f"Encontrados {contagem_duplicados} registros de clientes duplicados"
        
        # Registra os duplicados para investigação
        if contagem_duplicados > 0:
            print("IDs de clientes duplicados encontrados:")
            registros_duplicados.select("cod_cliente", "contagem_registros") \
                .distinct() \
                .orderBy(F.col("contagem_registros").desc()) \
                .show(10, truncate=False)
    
    adicionar_resultado_validacao(
        resultados_dq,
        dimensao="unicidade",
        validacao="id_cliente_unico",
        status=status,
        mensagem=mensagem,
        contagem_falhas=contagem_duplicados,
        limite=0
    )


def validar_validade(df, resultados_dq):
    """
    Valida os formatos e padrões dos dados na tabela de clientes.
    
    Esta função verifica se os dados estão em formatos válidos e dentro de padrões esperados.
    Inclui validações para:
    - Formato de números de telefone (deve seguir o padrão (NN)NNNNN-NNNN)
    - Datas de nascimento (devem estar no passado e não muito antigas)
    - Datas de atualização (não devem estar no futuro)
    - Tipo de pessoa (deve ser PF ou PJ)
    
    Estas validações são essenciais para garantir a integridade semântica dos dados.
    
    Args:
        df: DataFrame com os dados a serem validados
        resultados_dq: Dicionário para armazenar os resultados das validações
    """
    print("Validando formato e validade dos dados...")
    
    # Valida formato de número de telefone
    if "num_telefone_cliente" in df.columns:
        # Formato de telefone deve ser nulo ou corresponder ao padrão (NN)NNNNN-NNNN
        telefones_nao_nulos = df.filter(F.col("num_telefone_cliente").isNotNull())
        contagem_nao_nulos = telefones_nao_nulos.count()
        
        if contagem_nao_nulos > 0:
            contagem_telefones_invalidos = telefones_nao_nulos.filter(
                ~F.col("num_telefone_cliente").rlike(r"^\(\d{2}\)\d{5}-\d{4}$")
            ).count()
            
            porcentagem_invalidos = (contagem_telefones_invalidos / contagem_nao_nulos) * 100
            
            if porcentagem_invalidos == 0:
                status = "passou"
                mensagem = "Todos os números de telefone não nulos correspondem ao formato exigido"
            else:
                status = "falhou"
                mensagem = f"{porcentagem_invalidos:.2f}% dos números de telefone não nulos têm formato inválido"
            
            adicionar_resultado_validacao(
                resultados_dq,
                dimensao="validade",
                validacao="formato_telefone",
                status=status,
                mensagem=mensagem,
                contagem_falhas=contagem_telefones_invalidos,
                limite=0
            )
    
    # Valida formatos de data (data de nascimento e data de atualização)
    colunas_data = ["dt_nascimento_cliente", "dt_atualizacao"]
    
    for coluna_data in colunas_data:
        # Verifica se datas de nascimento estão no passado e datas de atualização não estão no futuro
        eh_data_nascimento = coluna_data == "dt_nascimento_cliente"
        
        if eh_data_nascimento:
            # Datas de nascimento devem estar no passado e não muito antigas (ex.: não mais de 120 anos)
            contagem_futuro = df.filter(F.col(coluna_data) > F.current_date()).count()
            contagem_muito_antigo = df.filter(
                F.months_between(F.current_date(), F.col(coluna_data)) > 120 * 12
            ).count()
            contagem_invalidos = contagem_futuro + contagem_muito_antigo
            
            if contagem_invalidos == 0:
                status = "passou"
                mensagem = "Todas as datas de nascimento são válidas (no passado e não muito antigas)"
            else:
                status = "aviso"
                mensagem = f"Encontradas {contagem_futuro} datas de nascimento no futuro e {contagem_muito_antigo} datas muito antigas"
        else:
            # Datas de atualização não devem estar no futuro
            contagem_futuro = df.filter(F.col(coluna_data) > F.current_date()).count()
            contagem_invalidos = contagem_futuro
            
            if contagem_invalidos == 0:
                status = "passou"
                mensagem = "Todas as datas de atualização são válidas (não estão no futuro)"
            else:
                status = "aviso"
                mensagem = f"Encontradas {contagem_futuro} datas de atualização no futuro"
        
        adicionar_resultado_validacao(
            resultados_dq,
            dimensao="validade",
            validacao=f"formato_data_{coluna_data}",
            status=status,
            mensagem=mensagem,
            contagem_falhas=contagem_invalidos,
            limite=0
        )
    
    # Valida tipo de cliente (tp_pessoa)
    tipos_validos = ["PF", "PJ"]
    contagem_tipos_invalidos = df.filter(~F.col("tp_pessoa").isin(tipos_validos)).count()
    
    if contagem_tipos_invalidos == 0:
        status = "passou"
        mensagem = "Todos os tipos de cliente são válidos (PF ou PJ)"
    else:
        status = "falhou"
        mensagem = f"Encontrados {contagem_tipos_invalidos} registros com tipos de cliente inválidos"
    
    adicionar_resultado_validacao(
        resultados_dq,
        dimensao="validade",
        validacao="tipo_cliente",
        status=status,
        mensagem=mensagem,
        contagem_falhas=contagem_tipos_invalidos,
        limite=0
    )


def validar_precisao(df, resultados_dq):
    """
    Valida a precisão e razoabilidade dos valores de dados na tabela de clientes.
    
    Esta função verifica se os valores estão dentro de faixas razoáveis e precisas:
    - Valores de renda (devem estar dentro de limites razoáveis min/max)
    - Valores de idade (calculados a partir da data de nascimento, devem ser razoáveis)
    
    Estas validações são importantes para identificar valores anômalos ou potencialmente
    incorretos que poderiam afetar análises e decisões de negócio.
    
    Args:
        df: DataFrame com os dados a serem validados
        resultados_dq: Dicionário para armazenar os resultados das validações
    """
    print("Validando precisão e razoabilidade dos dados...")
    
    # Verifica valores razoáveis de renda (vl_renda)
    if "vl_renda" in df.columns:
        # Define limites mínimo e máximo razoáveis para renda
        renda_minima = 1.0  # Renda mínima razoável
        renda_maxima = 1000000.0  # Renda máxima razoável
        
        contagem_muito_baixo = df.filter(
            (F.col("vl_renda") < renda_minima) & 
            F.col("vl_renda").isNotNull()
        ).count()
        
        contagem_muito_alto = df.filter(
            F.col("vl_renda") > renda_maxima
        ).count()
        
        contagem_outliers = contagem_muito_baixo + contagem_muito_alto
        porcentagem_outliers = (contagem_outliers / resultados_dq["record_count"]) * 100 if resultados_dq["record_count"] > 0 else 0
        
        # Define limite para porcentagem de outliers
        limite = 10.0  # 10% limite para outliers
        
        if porcentagem_outliers <= limite:
            status = "passou" if porcentagem_outliers == 0 else "aviso"
            mensagem = f"{porcentagem_outliers:.2f}% dos valores de renda são outliers ({contagem_muito_baixo} muito baixos, {contagem_muito_alto} muito altos)"
        else:
            status = "falhou"
            mensagem = f"{porcentagem_outliers:.2f}% dos valores de renda são outliers, excedendo o limite de {limite}%"
        
        adicionar_resultado_validacao(
            resultados_dq,
            dimensao="precisao",
            validacao="faixa_valores_renda",
            status=status,
            mensagem=mensagem,
            contagem_falhas=contagem_outliers,
            limite=limite
        )
    
    # Verifica valores razoáveis de idade (calculados a partir de dt_nascimento_cliente)
    idade_minima = 15  # Idade mínima razoável
    idade_maxima = 120  # Idade máxima razoável
    
    df_com_idade = df.withColumn(
        "idade_cliente",
        (F.months_between(F.current_date(), F.col("dt_nascimento_cliente")) / 12).cast("int")
    )
    
    contagem_muito_jovem = df_com_idade.filter(
        (F.col("idade_cliente") < idade_minima) & 
        F.col("idade_cliente").isNotNull()
    ).count()
    
    contagem_muito_velho = df_com_idade.filter(
        (F.col("idade_cliente") > idade_maxima) & 
        F.col("idade_cliente").isNotNull()
    ).count()
    
    contagem_outliers = contagem_muito_jovem + contagem_muito_velho
    porcentagem_outliers = (contagem_outliers / resultados_dq["record_count"]) * 100 if resultados_dq["record_count"] > 0 else 0
    
    # Define limite para porcentagem de outliers de idade
    limite = 5.0  # 5% limite para outliers de idade
    
    if porcentagem_outliers <= limite:
        status = "passou" if porcentagem_outliers == 0 else "aviso"
        mensagem = f"{porcentagem_outliers:.2f}% dos valores de idade são outliers ({contagem_muito_jovem} muito jovens, {contagem_muito_velho} muito velhos)"
    else:
        status = "falhou"
        mensagem = f"{porcentagem_outliers:.2f}% dos valores de idade são outliers, excedendo o limite de {limite}%"
    
    adicionar_resultado_validacao(
        resultados_dq,
        dimensao="precisao",
        validacao="faixa_valores_idade",
        status=status,
        mensagem=mensagem,
        contagem_falhas=contagem_outliers,
        limite=limite
    )


def calcular_pontuacao_qualidade(resultados_dq):
    """
    Calcula uma pontuação geral de qualidade de dados com base nos resultados das validações.
    
    Esta função analisa todos os resultados de validação e calcula uma pontuação ponderada:
    - passou = 1.0 ponto
    - aviso = 0.5 ponto
    - falhou = 0.0 ponto
    
    A pontuação final é a média ponderada convertida em porcentagem, permitindo
    classificar a qualidade geral dos dados como "passou", "aviso" ou "falhou".
    
    Args:
        resultados_dq: Dicionário com os resultados das validações
    """
    validacoes = resultados_dq["validations"]
    
    # Conta resultados de validação por status
    passou = sum(1 for v in validacoes if v.get("status") == "passou")
    avisos = sum(1 for v in validacoes if v.get("status") == "aviso")
    falhou = sum(1 for v in validacoes if v.get("status") == "falhou")
    
    # Exclui status "info" do cálculo
    total_validacoes = sum(1 for v in validacoes if v.get("status") in ["passou", "aviso", "falhou"])
    
    if total_validacoes > 0:
        # Calcula pontuação ponderada (passou=1.0, aviso=0.5, falhou=0.0)
        pontuacao = ((passou * 1.0) + (avisos * 0.5)) / total_validacoes * 100
        status = "passou" if pontuacao >= 90 else "aviso" if pontuacao >= 70 else "falhou"
    else:
        pontuacao = 0
        status = "falhou"
    
    resultados_dq["quality_score"] = {
        "score": round(pontuacao, 2),
        "status": status,
        "passed": passou,
        "warnings": avisos,
        "failed": falhou,
        "total_validations": total_validacoes
    }
    
    print(f"Pontuação de Qualidade de Dados: {pontuacao:.2f}% ({status})")
    print(f"Passou: {passou}, Avisos: {avisos}, Falhou: {falhou}, Total: {total_validacoes}")


def salvar_resultados(spark, resultados_dq, caminho_saida_relatorio):
    """
    Salva os resultados de qualidade de dados no caminho de saída especificado.
    
    Esta função converte os resultados para formato JSON e os salva como arquivo texto,
    permitindo que sejam facilmente consultados e analisados posteriormente.
    
    Args:
        spark: Sessão Spark ativa
        resultados_dq: Dicionário com os resultados de qualidade de dados
        caminho_saida_relatorio: Caminho onde o relatório será salvo
    """
    try:
        # Converte os resultados para uma string
        resultados_json = json.dumps(resultados_dq, indent=2)
        
        # Salva como arquivo JSON usando Spark
        resultados_df = spark.createDataFrame([(resultados_json,)], ["results"])
        resultados_df.coalesce(1).write.mode("overwrite").text(caminho_saida_relatorio)
        
        print(f"Resultados de qualidade de dados salvos em: {caminho_saida_relatorio}")
    except Exception as e:
        print(f"Falha ao salvar resultados: {str(e)}")


def executar_todas_validacoes(spark, caminho_tabela_silver, caminho_saida_relatorio=None):
    """
    Executa todas as validações de qualidade de dados na tabela de clientes.
    
    Esta função coordena a execução de todas as validações definidas:
    1. Carrega os dados da camada Silver
    2. Valida a completude dos campos obrigatórios
    3. Valida a unicidade dos registros de clientes
    4. Valida o formato e validade dos dados
    5. Valida a precisão e razoabilidade dos valores
    6. Calcula uma pontuação geral de qualidade
    7. Salva os resultados em um relatório
    
    Args:
        spark: Sessão Spark ativa
        caminho_tabela_silver: Caminho para a tabela na camada Silver
        caminho_saida_relatorio: Caminho para salvar o relatório de qualidade (opcional)
        
    Returns:
        Dicionário com os resultados completos das validações
    """
    # Inicializa dicionário de resultados
    resultados_dq = {
        "table_name": "tb_cliente",
        "layer": "silver",
        "execution_date": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "record_count": 0,
        "validations": []
    }
    
    # Carrega dados
    df, contagem_registros = carregar_dados(spark, caminho_tabela_silver)
    if df is None:
        print("Falha ao carregar dados. Não é possível prosseguir com as validações.")
        adicionar_resultado_validacao(
            resultados_dq,
            dimensao="acesso_dados",
            validacao="tabela_existe",
            status="falhou",
            mensagem="Falha ao carregar dados do caminho especificado"
        )
        return resultados_dq
    
    resultados_dq["record_count"] = contagem_registros
    
    # Executa todas as funções de validação
    validar_completude(df, resultados_dq)
    validar_unicidade(df, resultados_dq)
    validar_validade(df, resultados_dq)
    validar_precisao(df, resultados_dq)
    
    # Calcula pontuação geral de qualidade de dados
    calcular_pontuacao_qualidade(resultados_dq)
    
    # Salva os resultados se o caminho de saída for fornecido
    if caminho_saida_relatorio:
        salvar_resultados(spark, resultados_dq, caminho_saida_relatorio)
    
    return resultados_dq


def main(args):
    """
    Função principal para executar as validações de qualidade de dados.
    
    Esta função inicializa a sessão Spark, executa todas as validações
    e exibe os resultados, retornando um código de status apropriado.
    
    Args:
        args: Dicionário com as seguintes chaves:
            - silver_table_path: Caminho para a tabela na camada Silver
            - report_output_path: Caminho para salvar o relatório de qualidade
    """
    # Inicializa sessão Spark
    spark = SparkSession.builder \
        .appName("QualidadeDadosSilverCliente") \
        .getOrCreate()
    
    # Inicializa contexto Glue (para execução em Glue job)
    glue_context = GlueContext(spark.sparkContext)
    
    try:
        # Executa validações
        resultados = executar_todas_validacoes(
            spark=spark,
            caminho_tabela_silver=args["silver_table_path"],
            caminho_saida_relatorio=args.get("report_output_path")
        )
        
        # Registra a pontuação de qualidade
        pontuacao_qualidade = resultados.get("quality_score", {})
        pontuacao = pontuacao_qualidade.get("score", 0)
        status = pontuacao_qualidade.get("status", "desconhecido")
        
        print(f"Validação de Qualidade de Dados Concluída. Pontuação Geral: {pontuacao}% ({status})")
        
        # Retorna sucesso ou falha com base no status
        if status == "falhou":
            print("Validação de Qualidade de Dados FALHOU. Veja o relatório para detalhes.")
            sys.exit(1)
        elif status == "aviso":
            print("Validação de Qualidade de Dados concluída com AVISOS. Veja o relatório para detalhes.")
        else:
            print("Validação de Qualidade de Dados PASSOU com sucesso.")
        
    except Exception as e:
        print(f"Erro durante a validação de qualidade de dados: {str(e)}")
        sys.exit(1)
    finally:
        spark.stop()


if __name__ == "__main__":
    # For AWS Glue job execution
    if '--JOB_NAME' in sys.argv:
        # This is running as a Glue job
        # Parse required arguments
        required_args = ['JOB_NAME', 'silver_table_path']
        args = getResolvedOptions(sys.argv, required_args)
        
        # Parse optional arguments
        optional_args = ['report_output_path']
        try:
            optional_resolved = getResolvedOptions(sys.argv, optional_args)
            args.update(optional_resolved)
        except Exception:
            pass
        
        # Initialize Glue job
        glue_context = GlueContext(SparkSession.builder.getOrCreate().sparkContext)
        job = Job(glue_context)
        job.init(args['JOB_NAME'], args)
        
        main(args)
        
        job.commit()
        
    else:
        if len(sys.argv) < 2:
            print("Uso: data_quality_silver_cliente.py <caminho_tabela_silver> [caminho_saida_relatorio]")
            sys.exit(1)
        
        caminho_tabela_silver = sys.argv[1]
        caminho_saida_relatorio = sys.argv[2] if len(sys.argv) > 2 else None
        
        args = {
            "silver_table_path": caminho_tabela_silver,
            "report_output_path": caminho_saida_relatorio
        }
        
        main(args) 