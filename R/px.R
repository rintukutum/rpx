setOldClass(c("xml_document", "xml_node"))

.PXDataset <- setClass("PXDataset",
                       slots = list(
                           ## attributes
                           id = "character",
                           formatVersion = "character",
                           ## Nodes
                           Data = "xml_document"))

setMethod("show", "PXDataset",
          function(object) {
              cat("Object of class \"", class(object), "\"\n", sep = "")
              fls <- pxfiles(object)
              fls <- paste0("'", fls, "'")
              n <- length(fls)
              cat(" Id:", object@id, "with ")
              cat(n, "files\n")
              cat(" ")
              if (n < 3) {
                  cat(paste(fls, collapse = ", "), "\n")
              } else {
                  cat("[1]", paste(fls[1], collapse = ", "))
                  cat(" ... ")
                  cat("[", n, "] ", paste(fls[n], collapse = ", "),
                      "\n", sep = "")
                  cat(" Use 'pxfiles(.)' to see all files.\n")
              }
          })

## ##' Returns the node names of the underliyng XML content of an
## ##' \code{PXDataset} object, available in the \code{Data} slot. This
## ##' function is meant to be used if additional parsing of the XML
## ##' structure is needed.
## ##'
## ##' @title Return the nodes of a \code{PXDataset}
## ##' @param pxdata An instance of class \code{PXDataset}.
## ##' @param name The name of a node.
## ##' @param all Should node from all levels be returned. Default is
## ##' \code{FALSE}.
## ##' @return A \code{character} with XML node names.
## ##' @author Laurent Gatto
## pxnodes <- function(pxdata, name, all = FALSE) {
##     stopifnot(inherits(pxdata, "PXDataset"))
##     stop("Not available for new version")
##     if (all) {
##         ans <- names(unlist(pxdata@Data))
##         ans <- ans[grep("children", ans)]
##         ans <- gsub("\\.", "/", ans)
##         ans <- gsub("children", "", ans)
##         return(ans)
##     }
##     if (missing(name)) ans <- names(names(pxdata@Data))        
##     else ans <- names(xmlChildren(pxdata@Data[[name]]))
##     ans
## }


pxid <- function(object) object@id


pxurl <- function(object) {
    stopifnot(inherits(object, "PXDataset"))
    p <- "//cvParam[@accession = 'PRIDE:0000411']"
    url <- xml_attr(xml_find_all(object@Data, p), "value")
    names(url) <- NULL
    url
}


pxtax <- function(object) {
    p <- "//cvParam[@accession = 'MS:1001469']"
    tax <- xml_attr(xml_find_all(object@Data, p), "value")
    names(tax) <- NULL
    tax
}


pxref <- function(object) {
    p <- "//cvParam[@accession = 'PRIDE:0000400']"
    q <- "//cvParam[@accession = 'PRIDE:0000432']"    
    ref <- xml_attr(xml_find_all(object@Data, p), "value")
    pendingref <- xml_attr(xml_find_all(object@Data, q), "value")
    c(ref, pendingref)
}


pxfiles <- function(object) {
    stopifnot(inherits(object, "PXDataset"))
    ftpdir <- paste0(pxurl(object), "/")
    ans <- strsplit(getURL(ftpdir, dirlistonly = TRUE), "\n")[[1]]
    if (Sys.info()['sysname'] == "Windows")
        ans <- sub("\r$", "", ans)
    ans
}


pxget <- function(object, list, force = FALSE, destdir = getwd(), ...) {
    fls <- pxfiles(object)
    url <- pxurl(object)
    if (missing(list)) 
        list <- menu(fls, FALSE, paste0("Files for ", object@id))
    if (length(list) == 1 && list == "all") {
        toget <- fls
    } else {
        if (is.character(list)) {
            toget <- fls[fls %in% list]
        } else toget <- fls[list]
    }
    if (length(toget) < 1)
        stop("No files to download.")
    urls <- gsub(" ", "\ ", paste0(url, "/", toget))
    toget <- file.path(destdir, toget)
    message("Downloading ", length(urls), " file",
            ifelse(length(urls) > 1, "s", ""))
    for (i in 1:length(urls)) {
        if (file.exists(toget[i]) && !force)
            message(toget[i], " already present.")
        else download.file(urls[i], toget[i], ...)
    }
    invisible(toget)
}

## ns10 <- "https://raw.githubusercontent.com/proteomexchange/proteomecentral/master/lib/schemas/proteomeXchange-1.0.xsd"
## ns11 <- "https://raw.githubusercontent.com/proteomexchange/proteomecentral/master/lib/schemas/proteomeXchange-1.1.0.xsd"
## ns12 <- "https://raw.githubusercontent.com/proteomexchange/proteomecentral/master/lib/schemas/proteomeXchange-1.2.0.xsd"
## ns13 <- "https://raw.githubusercontent.com/proteomexchange/proteomecentral/master/lib/schemas/proteomeXchange-1.3.0.xsd"

## constructor
PXDataset <- function(id) {
    url <- paste0(
        "http://proteomecentral.proteomexchange.org/cgi/GetDataset?ID=",
        id, "&outputMode=XML&test=no")
    x <- readLines(url)
    if (length(grep("ERROR", x)) > 0) {
        x <- x[grep("message=", x)]
        x <- sub("message=", "", x)
        stop(x)
    }       
    x <- x[x != ""]   
    v <- sub("\".+$", "",  sub("^.+formatVersion=\"", "", x[2]))
    x <- read_xml(url)
    .formatVersion <- xml_attr(x, "formatVersion")
    .id <- xml_attr(x, "id")
    if (length(.id) != 1)
        stop("Got ", length(.id), " identifiers: ",
             paste(.id, collapse = ", "), ".")
    if (id != .id)
        warning("Identifier '", id, "' not found. Retrieved '",
                .id, "' instead.")
    if (v != .formatVersion)
        warning("Format version does not match. Got '",
                .formatVersion, "' instead of '", v, "'.")
    .PXDataset(id = .id,
               formatVersion = .formatVersion,
               Data = x)
}
