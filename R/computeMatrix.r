#' Read density per region
#'
#' Write matrix containing read density per region from bigwig files
#' IF ERROR, CHECK WHAT I WAS DOING LIBRARY(TOOLS) FOR
#' @param filenames Character - List of BAM files
#' @param deeptoolsPath String - Path to deeptools directory
#' @param genomeSizeFile String - Filename (with path) to text file containing genome size information
#' @param bwDest String - Directory where bigwig files should be written
#' @param outSuffix String - will be appended to original filename (and ".bedgraph" is replaced by ".bigwig")
#' @details Take a list of bigwigs and use the deeptools computeMatrix function to get a matrix file for each,
#' which can then be used by plotHeatmap to create an eps.
#' IMPROVE: You have to be in the directory with the input files right now.  At least if you're giving it a
#' matDest and maybe if you're not, I dunno.
#' Make it so you can do reference-point instead of scale-regions.
#' Could be two different functions if the options are really different.  a and b have different defaults.
#' Don't bother making it possible to group bigwigs.  They're still separate plots, just in the same output file.
#' Have it write the deeptools command to the top of the err file.
#' Time:
#' ~14m for a 90MB bigwig, to 5MB matrix.
#' Example at the command line (if you want to play with the parameters while looking at just one file, this might be easiest):
#' computeMatrix scale-regions -S samplename.bw -R All_mm10_wholeGenes.bed -b 1000 -a 1000 --skipZeros -o samplename_regions.mat.gz -p 2
#' @examples
#' computeMatrix("samplename.bigwig", regionsFiles=c("All_mm10_wholeGenes.bed", "Shuffled_RORht_mm10.bed"), outSuffix="genebody")
#' @author Emma Myers
#' @export

computeMatrix = function(bigwigs, regionsFiles, deeptoolsPath="", matDest="./", outSuffix="", textMatrix=FALSE, startLabel=NULL, endLabel=NULL,
                         skipZeros=FALSE, missingDataAsZero=FALSE, maxThreshold=NULL, minThreshold=NULL,
                         upstream=0, downstream=0, regionBodyLength=1000, binSize=10,
                         nProcessors=1) {

    # Check arguments
    if (! deeptoolsPath == "") {deeptoolsPath = dir_check(deeptoolsPath)}
    matDest = dir_check(matDest)
    if ( ! all(file.exists(regionsFiles)) ) { stop("One or more of the specified regions files do not exist.") }

    # For each bigwig
    for (b in bigwigs) {

        writeLines("\n")

        # Make sure file exists, but let's not be picky about the extension as bigwigs might not have .bigwig
        if ( ! file_checks(b, verbose=TRUE) ) { next }

        writeLines(paste("Processing file:", b))

        # Define arguments to the computeMatrix command
        fOut = paste(matDest, sub(file_ext(b), paste(outSuffix, "mat.gz", sep=""), b), sep="")
        arguments = c("scale-regions", "-S", b, "-R", paste(regionsFiles, collapse=" "),
                      "-b", upstream, "-a", downstream,
                      "--regionBodyLength", regionBodyLength, "--binSize", binSize,
                      "-o", fOut, "-p", nProcessors)
        if (skipZeros) { arguments = c(arguments, "--skipZeros") }
        if (missingDataAsZero) { arguments = c(arguments, "--missingDataAsZero") }
        if ( !is.null(maxThreshold) ) { arguments = c(arguments, "--maxThreshold", maxThreshold) }
        if ( !is.null(minThreshold) ) { arguments = c(arguments, "--minThreshold", minThreshold) }
        if (textMatrix) { arguments = c(arguments, "--outFileNameMatrix", sub(".gz", ".txt", fOut)) }
        if ( !is.null(startLabel) ) { arguments = c(arguments, "--startLabel", paste("'", startLabel, "'", sep="")) }
        if ( !is.null(endLabel) ) { arguments = c(arguments, "--endLabel", paste("'", endLabel, "'", sep="")) }

        writeLines( paste(arguments, collapse=" ") )

        #################
        # Get output file
        #################
        errFile = sub(".gz", ".err.txt", fOut)
        if ( file_checks(fOut, shouldExist=FALSE, verbose=TRUE) ) {
            writeLines(paste("Creating file ", fOut, "...", sep=""), sep="")
            tStart = proc.time()[3]
            system2(paste(deeptoolsPath, "computeMatrix", sep=""), args = arguments, stdout = fOut, stderr = errFile)
            tElapsed = proc.time()[3] - tStart
            writeLines(paste("done (", round(tElapsed/60, digits=2), "m).", sep=""))
            writeLines(paste("Done with file.  See", errFile, "for messages displayed by computeMatrix."))
        }

    }

}
