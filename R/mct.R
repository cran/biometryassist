#' Multiple Comparison Tests
#'
#' A function for comparing and ranking predicted means with Tukey's Honest Significant Difference (HSD) Test.
#'
#' @param model.obj An ASReml-R or aov model object. Will likely also work with `lme` ([nlme::lme()]), `lmerMod` ([lme4::lmer()]) models as well.
#' @param classify Name of predictor variable as string.
#' @param sig The significance level, numeric between 0 and 1. Default is 0.05.
#' @param int.type The type of confidence interval to calculate. One of `ci`, `1se` or `2se`. Default is `ci`.
#' @param trans Transformation that was applied to the response variable. One of `log`, `sqrt`, `logit` or `inverse`. Default is `NA`.
#' @param offset Numeric offset applied to response variable prior to transformation. Default is `NA`. Use 0 if no offset was applied to the transformed data. See Details for more information.
#' @param decimals Controls rounding of decimal places in output. Default is 2 decimal places.
#' @param descending Logical (default `FALSE`). Order of the output sorted by the predicted value. If `TRUE`, largest will be first, through to smallest last.
#' @param plot Automatically produce a plot of the output of the multiple comparison test? Default is `FALSE`. This is maintained for backwards compatibility, but the preferred method now is to use `autoplot(<multiple_comparisons output>)`. See [biometryassist::autoplot.mct()] for more details.
#' @param label_height Height of the text labels above the upper error bar on the plot. Default is 0.1 (10%) of the difference between upper and lower error bars above the top error bar.
#' @param rotation Rotate the text output as Treatments within the plot. Allows for easier reading of long treatment labels. Number between 0 and 360 (inclusive) - default 0
#' @param save Logical (default `FALSE`). Save the predicted values to a csv file?
#' @param savename A file name for the predicted values to be saved to. Default is `predicted_values`.
#' @param order Deprecated. Use `descending` instead.
#' @param pred Deprecated. Use `classify` instead.
#' @param pred.obj Deprecated. Predicted values are calculated within the function from version 1.0.1 onwards.
#' @param ... Other arguments passed through to `predict.asreml()`.
#'
#' @importFrom multcompView multcompLetters
#' @importFrom predictmeans predictmeans
#' @importFrom stats model.frame predict qtukey qt
#' @importFrom utils packageVersion
#' @importFrom ggplot2 ggplot aes_ aes geom_errorbar geom_text geom_point theme_bw labs theme element_text facet_wrap
#'
#' @details Some transformations require that data has a small offset applied, otherwise it will cause errors (for example taking a log of 0, or square root of negative values). In order to correctly reverse this offset, if the `trans` argument is supplied, an offset value must also be supplied. If there was no offset required for a transformation, then use a value of 0 for the `offset` argument.
#'
#' @return A list containing a data frame with predicted means, standard errors, confidence interval upper and lower bounds, and significant group allocations (named `predicted_values`), as well as a plot visually displaying the predicted values (named `predicted_plot`). If some of the predicted values are aliased, a warning is printed, and the aliased treatment levels are returned in the output (named `aliased`).
#'
#' @references Jørgensen, E. & Pedersen, A. R. How to Obtain Those Nasty Standard Errors From Transformed Data - and Why They Should Not Be Used. [https://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.47.9023&rep=rep1&type=pdf](https://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.47.9023&rep=rep1&type=pdf)
#'
#' @examples
#' # Fit aov model
#' model <- aov(Petal.Length ~ Species, data = iris)
#'
#' # Display the ANOVA table for the model
#' anova(model)
#'
#' # Determine ranking and groups according to Tukey's Test
#' pred.out <- multiple_comparisons(model, classify = "Species")
#'
#' # Display the predicted values table
#' pred.out
#'
#' # Show the predicted values plot
#' autoplot(pred.out, label_height = 0.5)
#'
#'
#'
#' \dontrun{
#' # ASReml-R Example
#' library(asreml)
#'
#' #Fit ASReml Model
#' model.asr <- asreml(yield ~ Nitrogen + Variety + Nitrogen:Variety,
#'                     random = ~ Blocks + Blocks:Wplots,
#'                     residual = ~ units,
#'                     data = asreml::oats)
#'
#' wald(model.asr) #Nitrogen main effect significant
#'
#' #Determine ranking and groups according to Tukey's Test
#' pred.out <- multiple_comparisons(model.obj = model.asr, classify = "Nitrogen",
#'                     descending = TRUE, decimals = 5)
#'
#' pred.out}
#'
#' @export
#'
multiple_comparisons <- function(model.obj,
                                 classify,
                                 sig = 0.05,
                                 int.type = "ci",
                                 trans = NA,
                                 offset = NA,
                                 decimals = 2,
                                 descending = FALSE,
                                 plot = FALSE,
                                 label_height = 0.1,
                                 rotation = 0,
                                 save = FALSE,
                                 savename = "predicted_values",
                                 order,
                                 pred.obj,
                                 pred,
                                 ...) {

    rlang::check_dots_used()

    if(!missing(pred)) {
        warning("Argument `pred` has been deprecated and will be removed in a future version. Please use `classify` instead.")
        classify <- pred
    }

    if(!missing(order)) {
        warning("Argument `order` has been deprecated and will be removed in a future version. Please use `descending` instead.")
    }

    if(sig > 0.5)  {
        warning("Significance level given by `sig` is high. Perhaps you meant ", 1-sig, "?", call. = FALSE)
    }

    if(inherits(model.obj, "asreml")){

        if(!missing(pred.obj)) {
            warning("Argument `pred.obj` has been deprecated and will be removed in a future version. Predictions are now performed internally in the function.")
        }

        pred.obj <- asreml::predict.asreml(model.obj, classify = classify, sed = TRUE, trace = FALSE, ...)
        # Check if any treatments are aliased, and remove them and print a warning
        if(anyNA(pred.obj$pvals$predicted.value)) {
            aliased <- which(is.na(pred.obj$pvals$predicted.value))
            # Get the level values of the aliased treatments
            # If only one treatment (classify does not contain :) all levels printed separated with ,
            # If multiple treatments, first need to concatenate columns, then collapse rows
            aliased_names <- pred.obj$pvals[aliased, !names(pred.obj$pvals) %in% c("predicted.value", "std.error", "status")]

            if(is.data.frame(aliased_names) & length(aliased_names)==3) {
                aliased_names <- paste(aliased_names[,1], aliased_names[,2], aliased_names[,3], sep = ":")
            }
            else if(is.data.frame(aliased_names) & length(aliased_names)==2) {
                aliased_names <- paste(aliased_names[,1], aliased_names[,2], sep = ":")
            }

            if(length(aliased_names) > 1) {
                warn_string <- paste0("Some levels of ", classify, " are aliased. They have been removed from predicted output.\n  Aliased levels are: ", paste(aliased_names, collapse = ", "), ".\n  These levels are saved in the output object.")
            }
            else {
                warn_string <- paste0("A level of ", classify, " is aliased. It has been removed from predicted output.\n  Aliased level is: ", aliased_names, ".\n  This level is saved as an attribute of the output object.")
            }

            pred.obj$pvals <- pred.obj$pvals[!is.na(pred.obj$pvals$predicted.value),]
            pred.obj$pvals <- droplevels(pred.obj$pvals)
            pred.obj$sed <- pred.obj$sed[-aliased, -aliased]
            warning(warn_string, call. = FALSE)
        }

        #For use with asreml 4+
        if(utils::packageVersion("asreml") > 4) {
            pp <- pred.obj$pvals

            # Check that the prediction object was created with the sed matrix
            if(is.null(pred.obj$sed)) {
                stop("Prediction object (pred.obj) must be created with argument sed = TRUE.")
            }

            sed <- pred.obj$sed
        }

        pp <- pp[!is.na(pp$predicted.value),]
        pp$status <- NULL

        dat.ww <- asreml::wald(model.obj, ssType = "conditional", denDF = "default", trace = FALSE)$Wald

        dendf <- data.frame(Source = row.names(dat.ww), denDF = dat.ww$denDF)

        ifelse(grepl(":", classify),
               pp$Names <- apply(pp[,unlist(strsplit(classify, ":"))], 1, paste, collapse = "_"),
               pp$Names <- pp[[classify]])

        ndf <- dendf$denDF[grepl(classify, dendf$Source) & nchar(classify) == nchar(as.character(dendf$Source))]
        crit.val <- 1/sqrt(2)* stats::qtukey((1-sig), nrow(pp), ndf)*sed

        # Grab the response from the formula to create plot Y label
        ylab <- model.obj$formulae$fixed[[2]]
    }

    else if(inherits(model.obj, c("aov", "lm", "lmerMod", "lmerModLmerTest"))) {
        # vars <- unlist(strsplit(classify, "\\:"))
        #
        # if(inherits(model.obj, c("aov", "lm"))) {
        #     mdf <- stats::model.frame(model.obj)
        #     not_factors <- intersect(vars, names(mdf)[!sapply(mdf, is.factor)])
        # }
        # else if(inherits(model.obj, c("lmerMod", "lmerModLmerTest"))) {
        #     mdf <- get(model.obj@call$data, pos = parent.frame())
        #     not_factors <- intersect(vars, names(mdf)[!sapply(mdf, is.factor)])
        # }
        #
        # if(length(not_factors) == 1) {
        #     stop(paste(not_factors, "must be a factor."), call. = F)
        # }
        # else if(length(not_factors) > 1) {
        #     stop(paste(paste(not_factors[-length(not_factors)], collapse = ", "), "and", not_factors[length(not_factors)], "must be factors"), call. = F)
        # }

        pred.out <- predictmeans::predictmeans(model.obj, classify, mplot = FALSE, ndecimal = decimals)

        pred.out$mean_table <- pred.out$mean_table[,!grepl("95", names(pred.out$mean_table))]
        sed <- pred.out$`Standard Error of Differences`[1]
        pp <- pred.out$mean_table
        names(pp)[names(pp) == "Predicted means"] <- "predicted.value"
        names(pp)[names(pp) == "Standard error"] <- "std.error"

        SED <- matrix(data = sed, nrow = nrow(pp), ncol = nrow(pp))
        diag(SED) <- NA
        ifelse(grepl(":", classify),
               pp$Names <- apply(pp[,unlist(strsplit(classify, ":"))], 1, paste, collapse = "_"),
               pp$Names <- pp[[classify]])

        ndf <- pp$Df[1]
        crit.val <- 1/sqrt(2)* stats::qtukey((1-sig), nrow(pp), ndf)*SED

        # Grab the response from the formula to create plot Y label
        if(inherits(model.obj, c("lmerMod", "lmerModLmerTest"))) {
            ylab <- model.obj@call[[2]][[2]]
        }
        else {
            ylab <- model.obj$terms[[2]]
        }
    }

    else {
        stop("Models of type ", class(model.obj), " are not supported.")
    }

    # Check that the predicted levels don't contain a dash -, if they do replace and display warning
    if(any(grepl("-", pp[,1]))) {
        levs <- grep("-", pp[,1], value = TRUE)
        if(length(levs)>1) {
            warning("The treatment levels ", paste(levs, collapse = ", "), " contained '-', which has been replaced in the final output with '_'")
        }
        else {
            warning("The treatment level ", levs, " contained '-', which has been replaced in the final output with '_'")
        }
        pp[,1] <- gsub(pattern = "-", replacement = "_", pp[,1])
        pp$Names <- gsub(pattern = "-", replacement = "_", pp$Names)
    }

    Names <-  as.character(pp$Names)

    # Determine pairs that are significantly different
    diffs <- abs(outer(pp$predicted.value, pp$predicted.value, "-")) > crit.val
    diffs <- diffs[lower.tri(diffs)]

    # Create a vector of treatment comparison names
    m <- outer(pp$Names, pp$Names, paste, sep="-")
    m <- m[lower.tri(m)]

    names(diffs) <- m

    ll <- multcompView::multcompLetters3("Names", "predicted.value", diffs, pp, reversed = !descending)

    rr <- data.frame(groups = ll$Letters)
    rr$Names <- row.names(rr)

    pp.tab <- merge(pp,rr)

    if(!is.na(trans)){

        if(is.na(offset)) {
            stop("Please supply an offset value for the transformation using the 'offset' argument. If an offset was not applied, use a value of 0 for the offset argument.")
        }

        if(trans == "sqrt"){
            pp.tab$PredictedValue <- (pp.tab$predicted.value)^2 - ifelse(!is.na(offset), offset, 0)
            pp.tab$ApproxSE <- 2*abs(pp.tab$std.error)*sqrt(pp.tab$PredictedValue)
            if(int.type == "ci"){
                pp.tab$ci <- stats::qt(p = sig, ndf, lower.tail = FALSE) * pp.tab$std.error
            }
            if(int.type == "1se"){
                pp.tab$ci <- pp.tab$std.error
            }
            if(int.type == "2se"){
                pp.tab$ci <- 2*pp.tab$std.error
            }
            pp.tab$low <- (pp.tab$predicted.value - pp.tab$ci)^2 - ifelse(!is.na(offset), offset, 0)
            pp.tab$up <- (pp.tab$predicted.value + pp.tab$ci)^2 - ifelse(!is.na(offset), offset, 0)
        }

        if(trans == "log"){
            pp.tab$PredictedValue <- exp(pp.tab$predicted.value) - ifelse(!is.na(offset), offset, 0)
            pp.tab$ApproxSE <- abs(pp.tab$std.error)*pp.tab$PredictedValue
            if(int.type == "ci"){
                pp.tab$ci <- stats::qt(p = sig, ndf, lower.tail = FALSE) * pp.tab$std.error
            }
            if(int.type == "1se"){
                pp.tab$ci <- pp.tab$std.error
            }
            if(int.type == "2se"){
                pp.tab$ci <- 2*pp.tab$std.error
            }
            pp.tab$low <- exp(pp.tab$predicted.value - pp.tab$ci) - ifelse(!is.na(offset), offset, 0)
            pp.tab$up <- exp(pp.tab$predicted.value + pp.tab$ci) - ifelse(!is.na(offset), offset, 0)
        }

        if(trans == "logit"){
            pp.tab$PredictedValue <- exp(pp.tab$predicted.value)/(1 + exp(pp.tab$predicted.value))
            pp.tab$ApproxSE <- pp.tab$PredictedValue * (1 - pp.tab$PredictedValue)* abs(pp.tab$std.error)
            if(int.type == "ci"){
                pp.tab$ci <- stats::qt(p = sig, ndf, lower.tail = FALSE) * pp.tab$std.error
            }
            if(int.type == "1se"){
                pp.tab$ci <- pp.tab$std.error
            }
            if(int.type == "2se"){
                pp.tab$ci <- 2*pp.tab$std.error
            }
            pp.tab$ll <- pp.tab$predicted.value - pp.tab$ci
            pp.tab$low <- exp(pp.tab$ll)/(1 + exp(pp.tab$ll))
            pp.tab$uu <- pp.tab$predicted.value + pp.tab$ci
            pp.tab$up <- exp(pp.tab$uu)/(1 + exp(pp.tab$uu))

            pp.tab$ll <- NULL
            pp.tab$uu <- NULL
        }

        if(trans == "inverse"){
            pp.tab$PredictedValue <- 1/pp.tab$predicted.value
            pp.tab$ApproxSE <- abs(pp.tab$std.error)*pp.tab$PredictedValue^2
            if(int.type == "ci"){
                pp.tab$ci <- stats::qt(p = sig, ndf, lower.tail = FALSE) * pp.tab$std.error
            }
            if(int.type == "1se"){
                pp.tab$ci <- pp.tab$std.error
            }
            if(int.type == "2se"){
                pp.tab$ci <- 2*pp.tab$std.error
            }
            pp.tab$low <- 1/(pp.tab$predicted.value - pp.tab$ci)
            pp.tab$up <- 1/(pp.tab$predicted.value + pp.tab$ci)
        }
    }

    else {

        if(int.type == "ci"){
            pp.tab$ci <- stats::qt(p = sig, ndf, lower.tail = FALSE) * pp.tab$std.error
        }
        if(int.type == "1se"){
            pp.tab$ci <- pp.tab$std.error
        }
        if(int.type == "2se"){
            pp.tab$ci <- 2*pp.tab$std.error
        }
        pp.tab$low <- pp.tab$predicted.value - pp.tab$ci
        pp.tab$up <- pp.tab$predicted.value + pp.tab$ci

    }

    pp.tab <- pp.tab[base::order(pp.tab$predicted.value, decreasing = descending),]

    pp.tab$Names <- NULL

    if(class(model.obj)[1] == "asreml"){
        trtindex <- grep("groups", names(pp.tab)) - 3
    }

    else {
        trtindex <- grep("groups", names(pp.tab)) - 4
    }

    trtnam <- names(pp.tab)[1:trtindex]

    i <- 1
    for(i in 1:trtindex){
        pp.tab[[trtnam[i]]] <- factor(pp.tab[[trtnam[i]]], levels = unique(pp.tab[[trtnam[i]]]))
    }

    # rounding to the correct number of decimal places
    pp.tab <- rapply(object = pp.tab, f = round, classes = "numeric", how = "replace", digits = decimals)

    if(save) {
        write.csv(pp.tab, file = paste0(savename, ".csv"), row.names = FALSE)
    }

    # If there are brackets in the label, grab the text from inside
    if(is.call(ylab)) {
        ylab <- as.character(ylab)[2]
    }
    attr(pp.tab, "ylab") <- ylab

    if(grepl(":", classify)) {
        split_classify <- unlist(strsplit(classify, ":"))
        if(length(split_classify)>2) {
            classify3 <- split_classify[3]
        }
        classify2 <- split_classify[2]
        classify <- split_classify[1]
    }

    class(pp.tab) <- c("mct", class(pp.tab))
    if(plot) {
        print(autoplot(pp.tab))
    }

    if(exists("aliased_names")) {
        attr(pp.tab, 'aliased') <- as.character(aliased_names)
    }

    return(pp.tab)
}


#' Print method for multiple_comparisons
#'
#' @param x An mct object to print to the console.
#' @inheritParams rlang::args_dots_used
#'
#' @return The original object invisibly.
#' @seealso [multiple_comparisons()]
#' @method print mct
#' @export
#' @examples
#' dat.aov <- aov(Petal.Width ~ Species, data = iris)
#' output <- multiple_comparisons(dat.aov, classify = "Species")
#' print(output)
print.mct <- function(x, ...) {
    stopifnot(inherits(x, "mct"))
    print.data.frame(x, ...)

    if(!is.null(attr(x, "aliased"))) {
        aliased <- attr(x, "aliased")
        if(length(aliased) > 1) {
            cat("\nAliased levels are:", paste(aliased[1:(length(aliased)-1)], collapse = ", "), "and", aliased[length(aliased)], "\n")
        }
        else {
            cat("\nAliased level is:", aliased, "\n")
        }
    }
    invisible(x)
}

