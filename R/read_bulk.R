#' Read and combine multiple data files
#'
#' Read and combine multiple data files. The files will be merged into one
#' \link{data.frame}.
#'
#' \code{read_bulk} provides a wrapper around a specific data import function
#' (\link[utils:read.table]{read.csv} by default) to load the individual data files. After
#' loading, the different data files are merged using \link[plyr]{rbind.fill}.
#' This function can deal with varying column names across files, and still
#' places data into the appropriate columns. If a column is not present in a
#' specific file, it will be filled with \code{NA}.
#'
#' @param directory a character string. Name of the folder where the raw data
#'   are stored. If it does not contain an absolute path, the file name is
#'   relative to the current working directory. Defaults to current working
#'   directory.
#' @param subdirectories logical indicating whether the directory contains
#'   subdirectories. If \code{FALSE} (the default), it is assumed that all raw
#'   data files are directly included in the directory. If \code{TRUE}, it is
#'   assumed that the raw data files are stored in folders within the directory.
#'   Alternatively, a vector of folder names that contain the raw data.
#' @param name_contains an optional character string. If specified, only files
#'   whose name contains this string will be merged.
#' @param name_filter an optional regular expression. If specified, only files
#'   whose name matches this regular expression will be merged.
#' @param extension an optional character string. If specified, only files
#'   ending with the specified extension will be merged.
#' @param data A \code{data.frame} to which the new data will be added. This is
#'   optional, and an empty \code{data.frame} is used if none is provided.
#' @param verbose logical indicating whether function should report its
#'   progress.
#' @param fun the function used for reading the individual files. By default,
#'   this is \link[utils:read.table]{read.csv}. Can be any data import function as long as it
#'   takes the file name as first argument.
#' @param ... additional arguments passed on to \code{fun}.
#'
#'
#' @return A \link{data.frame} containing the merged data.
#'
#'   One column in the data.frame (\code{File}) contains the name of the raw
#'   data file. If the \code{subdirectories} option is set, an additional column
#'   (\code{Subdirectory}) with the name of the subdirectory is added.
#'
#' @seealso \link{read.table} for reading individual data files.
#'
#'   \link[plyr]{rbind.fill} is responsible for merging files.
#'
#'   \link{write.table} for data export.
#'
#' @examples
#' \dontrun{
#' # Merge all files in the main folder "raw_data"
#' # (which is in the current working directory)
#' raw_data <- read_bulk(directory = "raw_data")
#'
#' # Merge files with file extension ".csv"
#' raw_data <- read_bulk(directory = "raw_data",
#'   extension = ".csv")
#'
#' # Merge all files stored in separate folders
#' # within the folder "raw_data"
#' raw_data <- read_bulk(directory = "raw_data",
#'   subdirectories = TRUE)
#'
#' # Merge all raw data stored in the folders "Session1"
#' # and "Session2" within the folder "raw_data"
#' raw_data <- read_bulk(directory = "raw_data",
#'   subdirectories = c("Session1","Session2"))
#'
#' # Merge tab separated data files and prevent
#' # character vectors from being converted to factors
#' raw_data <- read_bulk(directory = "raw_data",
#'   fun=read.delim,stringsAsFactors=FALSE)
#'}
#' @export
read_bulk <- function(directory=".",
  subdirectories=FALSE,
  name_contains=NULL,
  name_filter=NULL,
  extension=NULL,
  data=NULL,
  verbose=TRUE,
  fun=utils::read.csv,
  ...) {

  # Change warning options so that instant warning message is returned
  # (not summarized at the end)
  current_setting_warning <- options()$warn
  options(warn=1)


  # Set subdirectory variables according to the selected option
  if (is.logical(subdirectories)) {
    check_subdirectories <- subdirectories
    if (check_subdirectories){
      subdirectories <- dir(directory)
    } else {
      subdirectories <- c("")
    }

  } else if (is.character(subdirectories)) {
    check_subdirectories <- TRUE

  } else {
    stop(
      "subdirectories argument should ",
      "either be boolean or vector of character values"
    )
  }

  # Read in data

  all_data_list <- lapply(subdirectories, function(subdirectory){

    if (check_subdirectories & verbose) {
      message(paste("Start merging subdirectory:", subdirectory))
    }

    # Get files in directory
    files <- dir(paste(directory, subdirectory, sep="/"))

    # In case a file name filter was specified, filter files
    if(is.null(name_contains)==FALSE){
      files <- grep(name_contains, files, fixed=TRUE, value=TRUE)
    }
    if(is.null(name_filter)==FALSE){
      files <- grep(name_filter, files, fixed=FALSE, value=TRUE)
    }

    # In case a file extension was specified, filter files
    if(is.null(extension)==FALSE){
      files <- grep(paste0(extension, "$"), files, value=TRUE)
    }

    subdirectory_data_list <- lapply(files, function(file){

      if (verbose){
        message(paste("Reading", file))
      }

      # Load individual file
      single_data <- fun(
        paste(directory, subdirectory, file, sep="/"),
        ...
      )

      # Issue warning if read in data file has 0 rows
      if (nrow(single_data)==0) {
        warning("File ",file, " has 0 rows after reading it in.")

      # Add metadata otherwise
      } else {

        if(check_subdirectories) {
          single_data$Subdirectory <- subdirectory
        }
        single_data$File <- file
      }

      return(single_data)

    })

    # Bind data together for subdirectory
    return(plyr::rbind.fill(subdirectory_data_list))

  })


  # Bind all data together into global data.frame
  all_data <- plyr::rbind.fill(all_data_list)

  # Perform incremental merging, if previous data were provided
  if (is.null(data) == FALSE) {
    all_data <- plyr::rbind.fill(data, all_data)
  }

  # Reset warning option
  options(warn=current_setting_warning)

  results <- data.frame(all_data)
  if (nrow(results) == 0) {
    warning(
      "Final data.frame has 0 rows. ",
      "Please check that directory was specified correctly."
    )
  }

  # Return data
  return(results)
}
