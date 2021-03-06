#' Expression heatmaps
#'
#' Create gene-by-sample heatmap of expression values
#' Needs plotly
#' @param exprDataFrame Data frame - Gene x sample expression values (counts, tpm, whatever)
#' @param genes Character - Gene symbols that appear as row names in exprDataFrame
#' @param L2 Logical - Whether to take log2 of values.  Pseudocount of 1 is added.
#' @param scaleGenes Logical - Whether to scale values within-gene
#' @param scaleByGroup Vector? - Indexes (in exprDataFrame) of samples whose mean profile will be subtracted from each value
#' @param yticklabSize Numeric - Font size for gene symbols
#' @param yticklabColor Character vector
#' @param figHeightPerGene Numeric -
#' @param figWidth Numeric -
#' @param colorsPlot Color ramp -
#' @param ncolors Numeric -
#' @param plotTitle String -
#' @param minVal Numeric -
#' @param maxVal Numeric -
#' @param fileOut String - If given, save png to with this filename
#' @return Plotly object
#' @details Given a gene-by-sample dataframe with expression values, and (optionally) a list of the genes and
#' samples you want included, make an expression heatmap using plotly.  Note that, probably because I'm not set
#' up to do the paying thing, some stuff doesn't get incorporated into the output png.
#' Log2:  If TRUE, a pseudocount of 1 is added to all values.  This means that genes with an original count of 0 get
#' a log2(count) of 0 rather than an infinite value, and there are no negative values because there are no genes with
#' count < 1.
#' Within-gene scaling:  If TRUE, the default scaling is to scale each gene's alues so they fall within 0 and 1.
#' If TRUE and you also give this function a scaleByGroup value (a set of column indexes in exprDataFrame), within-gene
#' scaling will instead be done by taking the gene's mean value for that group of samples and subtracting that from its
#' value for all samples.  Make scaleByGroup be the indexes of control samples to convey a sense of effect size.
#' @examples
#' exprData = read.table("Rorb_p2_TPM.csv", header=TRUE, row.names=1, sep=",")
#' colnames(exprDataFrame) = gsub("BF_RORb", "", colnames(exprDataFrame))
#' geneList = c("Rorb", "Plxnd1", "Has2", "Sparcl1", "Pde1a", "Has3")
#' sampleList = c("HTp2_1", "HTp2_2", "KOp2_1", "KOp2_2")
#' exprHeatmap(exprData, genes=geneList, samples=sampleList, fileOut="expr.png")
#' @author Emma Myers
#' @export

exprHeatmap = function(exprDataFrame, genes=NULL, samples=NULL, L2=FALSE, scaleGenes=FALSE, scaleByGroup=NULL,
                yticklabSize=8, yticklabColor=NULL, figHeightPerGene=20, figWidth = 300, colorsPlot = colorRamp(c("yellow", "red")), ncolors=5,
                plotTitle="Expression heatmap", minVal=NULL, maxVal=NULL, fileOut=NULL) {

    ### Check inputs ######################################################

    # If genes and samples unspecified, use them all
    if (is.null(genes)) { genes = rownames(exprDataFrame) }
    if (is.null(samples)) { samples = colnames(exprDataFrame) }

    # Check for missing genes and samples
    msgGeneIdx = which( !is.element(genes, rownames(exprDataFrame)) )
    msgSampleIdx = which( !is.element(samples, colnames(exprDataFrame)) )
    if ( any(c(msgGeneIdx, msgSampleIdx)) ) {
        writeLines("Missing genes:")
        writeLines(genes[msgGeneIdx])
        writeLines("Missing samples:")
        writeLines(samples[msgSampleIdx])
        stop("At least one gene or sample requested is not in exprDataFrame (see above).")
    }


    ### Get submatrix #######################################################
    exprSubset = exprDataFrame[genes, samples] # hang onto these values
    exprForPlot = exprSubset # we're gonna transform these for the plot

    ### Do some transformations ##############################################
    # Take log2 if requested
    if ( L2 ) {
        exprTemp = exprForPlot
        exprForPlot = log2(exprForPlot + 1)
    }
    if ( scaleGenes ) {
        # If we're scaling the genes but weren't given control samples, scale to 0-to-1 range
        if (is.null(scaleByGroup) ) {
            normFun = function(v) {vnorm = (v-min(v)) / (max(v)-min(v)); return(vnorm)}
            exprForPlot = t(apply(exprForPlot, 1, normFun))
        } else {
            exprForPlot = exprForPlot - rowMeans(exprForPlot[,scaleByGroup])
        }
    } else { if (!is.null(scaleByGroup)) {stop("You gave me a group of samples to scale by, but scaleGenes=FALSE.  You want to scale within-gene or not?")} }

    # Vertically flip for heatmap
    exprForPlot = apply(exprForPlot, 2, rev)

    ### Dimensions and colorscale stuff ######################################
    figHeightThis = figHeightPerGene*dim(exprForPlot)[1]
    # Min value for getting the color scale should be slightly smaller than actual min in data
    if ( is.null(minVal) ) {
        if (min(exprForPlot) >= 0) { minFactor = 0.95 } else {minFactor = 1.05}
        minVal = min(exprForPlot) * minFactor
    }
    # and vice versa
    if ( is.null(maxVal) ) {
        if (max(exprForPlot) >= 0) { maxFactor = 1.05 } else {maxFactor = 0.95}
        maxVal = max(exprForPlot) * maxFactor
    }


    ### Making the plot #######################################################
    # Make plotly object
    exprPlotlyObj = plotly::plot_ly(z = exprForPlot, x = colnames(exprForPlot), y = rownames(exprForPlot),
                    type="heatmap", colors = colorsPlot,
                    zmin = minVal, zmax = maxVal,
                    height=figHeightThis, width = figWidth)

    # Set some layout stuff
    exprPlotlyObj = plotly::layout(exprPlotlyObj,
                           yaxis = list(ticklen = 0, tickfont = list(size = yticklabSize, tickvals = 1:dim(exprForPlot)[2], color = yticklabColor)),
                           xaxis = list(ticklen = 0),
                           title = plotTitle)


    # Save if given fileOut name
    if ( !is.null(fileOut) ) {
        fileOutFull = fileOut
        if ( !(substr(fileOutFull, nchar(fileOutFull)-3, nchar(fileOutFull)) == ".png") ) { fileOutFull = paste(fileOutFull, ".png", sep="") }
        if ( !is.null(fileOut) ) {
            if ( file_checks(fileOutFull, shouldExist=FALSE, verbose=TRUE) ) {
                writeLines(paste("Saving image to", fileOutFull))
                plotly::plotly_IMAGE(exprPlotlyObj, format="png", out_file=fileOutFull)
            }
        }
    }

    return(exprPlotlyObj)

}
