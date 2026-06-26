ThisBuild / scalaVersion := "2.13.18"

lazy val sparkVersion = "4.1.2"

lazy val root = (project in file("."))
  .settings(
    name := "de-mastery",
    libraryDependencies ++= Seq(
      "org.apache.spark" %% "spark-core" % sparkVersion,
      "org.apache.spark" %% "spark-sql" % sparkVersion,
    )
  )
