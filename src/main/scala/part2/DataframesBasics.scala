package part2

import org.apache.spark.sql.{Row, SparkSession}
import org.apache.spark.sql.types.{DoubleType, IntegerType, LongType, StringType, StructField, StructType}

object DataframesBasics extends App {

  val spark = SparkSession.builder()
    .appName("DataframesBasics")
    .config("spark.master", "local[*]")
    .getOrCreate()

  val firstDF = spark.read
    .format("json")
    .option("inferSchema", "true")
    .load("src/main/resources/data/cars.json")

  firstDF.show()
  firstDF.printSchema()

  firstDF.take(10).foreach(println)

  val longType = LongType

  val carSchema = StructType(
    Array(
      StructField("Name", StringType),
      StructField("Miles_per_Gallon", IntegerType),
      StructField("Cylinders", IntegerType),
      StructField("Displacement", IntegerType),
      StructField("Weight_in_lbs", IntegerType),
      StructField("Acceleration", DoubleType),
      StructField("Year", StringType),
      StructField("Origin", StringType),
    )
  )

  val carsDFSchema = firstDF.schema

  var carsDFWithSchema = spark.read
    .format("json")
    .schema(carSchema)
    .load("src/main/resources/data/cars.json")

  val myRow = Row(
    "Tesla", 21, 6, 160, 110, 30.4, "2013", "USA"
  )

  val cars = Seq(
    ("Tesla", 21, 6, 160, 110, 30.4, "2013", "USA"),
    ("BMW", 32, 4, 135, 185, 12.08, "2011", "Germany"),
    ("Honda", 29, 6, 225, 140, 13.0, "2012", "Japan"),
  )

  val manualCarsDF = spark.createDataFrame(cars)

  import spark.implicits._

  val manualCarsDFWithImplicits = cars.toDF("Name", "Miles_per_Gallon", "Cylinders", "Displacement", "Weight_in_lbs", "Acceleration", "Year", "Origin")

  manualCarsDF.printSchema()
  manualCarsDFWithImplicits.printSchema()

  val manualPhonesSchema = StructType(
    Array(
      StructField("Make", StringType),
      StructField("Model", StringType),
      StructField("Dimension", StringType),
      StructField("Megapixels", StringType),
    )
  )

  val manualPhones = Seq(
    ("Samsung", "Galaxy S10", "5.5 inches", "128 MP"),
    ("Apple", "iPhone 12 Pro Max", "6.1 inches", "128 MP"),
    ("Huawei", "P30 Pro", "5.9 inches", "128 MP"),
  )

  val manualPhonesDF = manualPhones.toDF("Make", "Model", "Dimension", "Megapixels")
  manualPhonesDF.show()

  val moviesDF = spark.read
    .format("json")
    .load("src/main/resources/data/movies.json")
  moviesDF.printSchema()
  println(moviesDF.count())
}
