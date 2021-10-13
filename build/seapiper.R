## Here is a seaPiper demo. It is actually fully functional, the only
## difference to the regular seaPiper container is that we do not use the
## temporary log web server and that we use by default an example data set
## from Rseasnap
library(shiny)
library(Rseasnap)
library(bioshmods)
library(seaPiper)
library(RJSONIO)
library(curl)
library(shinyBS)
options(spinner.type=6)
options(spinner.color="#47336F")

system("./weblog.sh", wait=FALSE)

title <- Sys.getenv("TITLE")

datasets <- Sys.getenv("datasets")
if(datasets == "") {
  title <- "Example dataset"
  pips <- list(example=load_de_pipeline(system.file("extdata/example_pipeline/DE_config.yaml", package="Rseasnap")))
} else {

  if(title == "") {
    title <- "Workflow output explorer"
  }


  ## for whatever reason the JSON is broken
  datasets <- gsub("'", '"', datasets)
  datasets <- sprintf('{ "datasets": %s }', datasets)
  datasets <- fromJSON(datasets)[[1]]
  stopifnot(is.list(datasets))
  stopifnot(length(datasets) > 0)

  names(datasets) <- sapply(datasets, function(.) .[["name"]])
  for(i in datasets) {
    info("Dataset: %s", i[["name"]])
  }

  irods_path     <- Sys.getenv("IRODS_PATH")
  irods_token    <- Sys.getenv("IRODS_TOKEN")
  davrods_server <- Sys.getenv("DAVRODS_SERVER")
  stopifnot(all(c(irods_path != "", irods_token != "", davrods_server != "")))

  info("Downloading data")
  for(ds in datasets) {
    info("Downloading data set %s", ds[["name"]])
    .dsdir <- paste0("archive_", ds[["name"]])
    info(sprintf("Creating directory '%s'", .dsdir))
    dir.create(.dsdir)
    
    .url <- sprintf("https://anonymous:%s@%s%s/%s",
                    irods_token,
                    davrods_server,
                    irods_path,
                    ds[["archive"]])
    info("Downloading tar file from\n
      https://anonymous:%s@%s%s/%s",
                    "XXXXX",
                    davrods_server,
                    irods_path,
                    ds[["archive"]]
                    )
    .arch_file <- file.path(.dsdir, ds[["archive"]])
    curl_download(.url, .arch_file, quiet=TRUE)
    info("opening archive:\n      cd '%s' ; tar xzf '%s'", .dsdir, ds[["archive"]])
    system(sprintf("cd '%s' ; tar xzf '%s'", .dsdir, ds[["archive"]]))

  }

  info("Creating pipeline objects")
#Sys.sleep(1000000)

  pips <- lapply(datasets, function(.) {
                   .conf_file <- file.path(
                                           paste0("archive_", .[["name"]]),
                                           .[["config"]])
                   info(sprintf("Loading workflow config file %s", .conf_file))
                   load_de_pipeline(.conf_file)
                    })

}

message("Launching app")
app <- seapiper(pips, title=title)
runApp(app, launch.browser = FALSE, port = 8080, host = "0.0.0.0") #runs shiny app in port 8080 localhost

