`%notin%` <- `%!in%` <- Negate(`%in%`)

# quiet
#' Function to suppress output if desired, especially useful for ASReml output
#'
#' @param x A function call with output to be suppressed.
#'
#' @returns The invisible output of the function called.
#'
#' @keywords internal
#'
quiet <- function(x) {
    sink(tempfile())
    on.exit(sink())
    invisible(force(x))
}


######################################################
# Start up function
# this function is executed once the package is loaded
######################################################

#' @importFrom utils available.packages packageVersion compareVersion
#' @importFrom rlang is_interactive is_installed
.onAttach <- function(library, pkg)
{
    local_version <- utils::packageVersion('biometryassist')

    if(rlang::is_interactive() && !isFALSE(rlang::peek_option("biometryassist.check"))) {
        output <- paste(paste0("    ", paste0(rep("~", times = 69), collapse = "")),
                        paste("    |  ", pkg, " version ", local_version, "                                     |",sep=""),
                        "    |  Authors: Sharon Nielsen, Sam Rogers, Annie Conway                |",
                        "    |  Developed at the University of Adelaide with funding provided    |",
                        "    |  by the Australian Grains Research and Development Corporation.   |",
                        "    |  Package website: https://biometryhub.github.io/biometryassist    |",
                        "    |                                                                   |",
                        "    |  If you have used this package in your work, please cite it.      |",
                        "    |  Type 'citation('biometryassist')' for the citation details.      |",
                        paste0("    ", paste0(rep("~", times = 69), collapse = ""), "\n"), sep = "\n")

        if(.check_package_available("crayon")) {
            packageStartupMessage(crayon::green(output), appendLF=TRUE)
        }
        else {
            packageStartupMessage(output, appendLF=TRUE)
        }

        # check which version is more recent
        cran_version <- tryCatch(
            {
                packages <- utils::available.packages()
                ver <- packages["biometryassist","Version"]
            },
            error=function(cond) {
                NA
            }
        )

        if(.compare_version(cran_version, as.character(local_version)) == 1) { # current version on CRAN newer than installed
            warning("    biometryassist version ", cran_version, " is now available.\n",
                    "    Please update biometryassist by running\n",
                    "    install.packages('biometryassist')", call. = FALSE)
        }
    }
    invisible()
}

#' Function to compare package version for mocking
#'
#' @param a,b Character strings representing package version numbers.
#'
#' @returns Numeric. `0` if the numbers are equal, `-1` if `b` is later and `1` if `a` is later
#' @keywords internal
.compare_version <- function(a, b) {
    return(utils::compareVersion(as.character(a), as.character(b)))
}

#' Check Package Availability
#'
#' Internal function to check if a package is available for loading.
#' This wrapper around \code{.check_package_available} makes testing easier
#' by allowing the dependency check to be mocked.
#'
#' @param pkg Character string specifying the package name to check
#' @return Logical value: \code{TRUE} if the package is available,
#'   \code{FALSE} otherwise
#' @keywords internal
.check_package_available <- function(pkg) {
    return(requireNamespace(pkg, quietly = TRUE))
}

#' Handle deprecated parameters
#'
#' Simple internal function to warn about deprecated parameters
#'
#' @param old_param Name of the deprecated parameter
#' @param new_param Name of the replacement parameter or NULL if parameter is being removed
#' @param custom_msg Optional custom message to append to the warning
#' @param call_env Environment where to check for the deprecated parameter
#'
#' @return Nothing, called for side effects (warnings)
#'
#' @keywords internal
handle_deprecated_param <- function(old_param, new_param = NULL, custom_msg = NULL, call_env = parent.frame()) {
    # Check if the old parameter was provided
    if(!eval(substitute(missing(PARAM), list(PARAM = as.name(old_param))), envir = call_env)) {
        # Different message depending on whether parameter is replaced or removed
        msg <- sprintf("Argument `%s` has been deprecated and will be removed in a future version.", old_param)
        if(!is.null(new_param)) {
            warning(msg, sprintf(" Please use `%s` instead.", new_param), call. = FALSE)
        } else {
            if(!is.null(custom_msg)) {
                msg <- paste(msg, custom_msg)
            }
            warning(msg, call. = FALSE)
        }
    }
}


#' Determine if a Colour is Light
#'
#' Internal helper function to determine whether a colour is light or dark
#' for appropriate font colour selection (black text on light backgrounds,
#' white text on dark backgrounds).
#'
#' @param colour A colour specification (hex code, named colour, etc.)
#' @return Logical. TRUE if the colour is light (luminance > 0.5), FALSE if dark.
#'
#' @details Uses standard luminance calculation: 0.299*R + 0.587*G + 0.114*B,
#'   normalized to 0-1 scale. Coefficients reflect human eye sensitivity to
#'   different colours (green > red > blue).
#'
#' @keywords internal
.is_light_colour <- function(colour) {
    # Convert vector of colours to RGB matrix (columns = colours)
    rgb_vals <- grDevices::col2rgb(colour)
    # Calculate luminance for each colour
    luminance <- (0.299 * rgb_vals[1, ] + 0.587 * rgb_vals[2, ] + 0.114 * rgb_vals[3, ]) / 255
    return(luminance > 0.5)
}

