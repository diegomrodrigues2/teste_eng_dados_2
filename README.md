# Teste Prático para Engenharia de Dados

## Introdução

O teste é destinado a avaliar as habilidades práticas como Engenheir@ de dados

**Itens do teste:**
1. ETL
2. Análise dos dados
3. Desenho de Arquitetura para ingestão de dados batch
4. Implementação de um Data quality
5. Desenvolvimento de testes unitários
6. Infra as Code (IaC)

## Fork
Realize um fork do repositorio e após a conclusão submeta um pull request. Através do PR que as respostas serão revisadas.

## Sugestão de estrutura dos arquivos de resposta
```bash
├── 1.ETL/
│   └── script.py
├── 2.AnaliseDados/
│   └── analise.txt
├── 3.DesenhodeArquitetura/
│   ├── desenho.jpg
│   └── explicacao.txt
├── 4.DataQuality/
│   └── script_data_quality.py
├── 5.TesteUnitario/
│   ├── unit_test.py
│   └── resultados.txt
└── 6.InfraAsCode/
    └── script.tf
 ```

## Docker
Disponibilizamos também um docker compose para criação de um ambiente spark para desenvolvimento na própria maquina, a utilização não é obrigatória.

## Desafios

### 1. ETL

#### Descrição

Utilize o arquivo `clientes_sinteticos.csv`.

Deverá ser gerado um único script que irá escrever em 2 buckets da AWS, um deles Bronze e o outro Silver.

Ambos os arquivos escritos no bucket Bronze e Silver devem estar acessíveis atraves do Glue Data Catalog, o schema de cata tabela pode ser definido por você mas considere que ambas as tabelas já foram criadas(nao a necessidade de criacao). A partição física devera ser a data de processamento e o nome da particao será **anomesdia**, lembre que além da partição física será necessario criar a partição lógica na tabela.

Passos:
- Especifique um schema para o dataset.
- Trate os nomes dos clientes para que fique todos com letra maiuscula
- Renomeie a coluna telefone_cliente para num_telefone_cliente
- Realize a escrita do dado no bucket s3://bucket-bronze/tabela_cliente_landing
- Deduplique o dataset mantendo sempre somente a ultima data de atualizacao do cadastro de cada cliente 
- Trate a coluna de telefone de modo a permitir somente valores que sigam o padrao (NN)NNNNN-NNNN os demais devem ficar nulos
- Realize a escrita do dado no bucket s3://bucket-silver/tb_cliente
---

### 2. Análise dos dados

Utilize o arquivo `clientes_sinteticos.csv`.
#### Descrição

- Identifique os 5 clientes que mais sofreram atualizações na base.
- Calcule a média de idade dos clientes.
---

### 3. Desenho de Arquitetura

#### Descrição

Proponha uma arquitetura na AWS para coletar dados de cadastros de clientes em um banco MySQL. Esses dados devem ser persistidos em um datalake que usa a arquitetura medalhão:

- Desenhe um sistema para coletar dados do banco MySQL realizando CDC.
- O processamento e escrita deve ser projetado para os 3 niveis do lake (bronze, silver e gold)
- Além do armazenamento do dado será necessaria uma governança de acesso a nível de usuário
---

### 4. Data Quality

#### Descrição

A qualidade dos dados é fundamental para garantir que as análises e os insights derivados sejam confiáveis. 

- Considere que voce está implementando o processo de Qualidade dos dados na camada Silver do lake na tabela de clientes que você ja preparou anteriormente.
- Crie um script de modo a validar as dimensões de qualidade que você julgue necessario para esse dataset.
---

### 5. Teste Unitário

#### Descrição

Os testes unitários são fundamentais para garantir a robustez e confiabilidade do código, permitindo identificar e corrigir bugs e erros antes que eles atinjam o ambiente de produção. Para este desafio:

- Escolha uma das funções ou classes que você implementou nas etapas anteriores deste teste.
- Escreva testes unitários para esta função ou classe. Os testes devem cobrir:
  - Casos padrão ou "happy path".
  - Casos de borda ou extremos.
  - Situações de erro ou exceção.
- Utilize uma biblioteca de testes de sua escolha (como `pytest`, `unittest`, etc.).
---

### 6. Infra as Code
#### Descrição
- Desenvolva um script Terraform que crie um Glue Job. Abaixo alguns parametros que o serviço deve ter.
- Parametros
  - Script : script desenvolvido na etapa 2
  - Versão: 5
  - Workers: 10
  - Tipo de Máquina: G1x
  - Tag: 
     - Nome: projeto  
     - Valor: teste_eng_dados



# O que é esperado do candidato

Caro candidato, o teste prático proposto visa avaliar suas habilidades, competências e abordagem como Engenheiro de Dados. Aqui está o que esperamos de você:

## 1. Atenção aos Detalhes

Verifique cuidadosamente cada etapa do teste, garantindo que nenhum detalhe foi perdido. Em Engenharia de Dados, muitas vezes os detalhes são cruciais para o sucesso de um projeto.

## 2. Qualidade do Código

Esperamos que o código que você produza seja claro, legível e bem organizado. Isso inclui:
- Uso adequado de funções, classes e módulos.
- Comentários relevantes.
- Nomes significativos para variáveis e funções.
- Performance utilizando o Framework Spark

## 3. Eficiência

Mais do que apenas escrever um código funcional, é importante demonstrar preocupação com a eficiência. Leve em consideração a performance da sua solução, especialmente em cenários que envolvem grandes volumes de dados.


## 4. Familiaridade com Ferramentas e Tecnologias

Este desafio também tem o objetivo de verificar seu domínio sobre tecnologias como Apache Spark e AWS. Aproveite a oportunidade para mostrar como utiliza essas ferramentas na prática, de forma estratégica e eficaz.


## 5. Arquitetura de Solução

Na parte de Arquitetura, queremos entender como você projeta sistemas que sejam robustos e preparados para escalar. Avaliaremos sua atenção a pontos como resiliência, custo-benefício, manutenção e crescimento da solução.


## 6. Capacidade de Trabalhar de Forma Independente

Você pode e deve consultar fontes externas, mas queremos ver como você se organiza, toma decisões e resolve problemas com os recursos disponíveis, demonstrando autonomia.


## 7. Comunicação

Além da parte técnica, valorizamos sua habilidade de explicar suas decisões. Ao final do teste, será importante justificar suas escolhas e descrever seu raciocínio de forma clara e objetiva.
O propósito do teste vai além de respostas certas ou erradas. Queremos entender como você pensa, resolve problemas e se envolve com a área de Engenharia de Dados. Estamos empolgados para conhecer o seu trabalho!

---

Boa sorte!
