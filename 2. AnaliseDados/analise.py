from pyspark.sql.window import Window
from pyspark.sql import functions as F

top_cod_df = (
    bronze_df
    .groupBy("cod_cliente").count()
    .orderBy(F.col("count").desc())
    .limit(5)
)

window_spec = Window.partitionBy("cod_cliente").orderBy(F.col("dt_atualizacao").desc())

deduplicated_df = (
    bronze_df.withColumn(
        "num_telefone_cliente",
        F.when(
            F.col("num_telefone_cliente").rlike(r"^\(\d{2}\)\d{5}-\d{4}$"),
            F.col("num_telefone_cliente")
        ).otherwise(None)
    )
    .withColumn("row_number", F.row_number().over(window_spec))
    .filter(F.col("row_number") == 1)
    .drop("row_number")
)

result_df = (
    top_cod_df
    .join(deduplicated_df.select("cod_cliente", "nm_cliente"), on="cod_cliente", how="inner")
    .select("cod_cliente", "count", "nm_cliente")
)

result_df.show()
# cod_cliente	count	nm_cliente
# 396	        5	    SARAH ALLEN
# 479	        5	    JASMINE BAUTISTA
# 855	        4	    DAVID PETERS
# 878	        5	    JENNIFER JARVIS
# 925	        3	    CHRISTIAN GATES

from pyspark.sql import functions as F

deduplicated_df = deduplicated_df.withColumn(
    "idade_cliente",
    (F.months_between(F.current_date(), F.col("dt_nascimento_cliente")) / 12).cast("int")
)

result_df = deduplicated_df.agg(
    F.avg("idade_cliente").alias("media_idade_cliente")
)

result_df.show()
# media_idade_cliente
# 50.70780856423174 -> 51 anos
