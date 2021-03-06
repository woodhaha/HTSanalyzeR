
##initialization method
setMethod(
		"initialize",
		"NWA",
		function(.Object, pvalues, phenotypes = NULL, interactome = NULL) {
			##check input arguments
			paraCheck(name = "pvalues", para = pvalues)
			if(!is.null(phenotypes))
				paraCheck(name = "phenotypes", para = phenotypes)
			if(!is.null(interactome)) 
				paraCheck(name = "interactome", para = interactome)
			.Object@pvalues <- pvalues
			.Object@phenotypes <- phenotypes
			.Object@interactome <- interactome
			
			##set up summary framework
			sum.info.input <- matrix(, 2, 5)
			colnames(sum.info.input) <- c("input", "valid", 
				"duplicate removed", "converted to entrez", "in interactome")
			rownames(sum.info.input) <- c("p-values", "phenotypes")
			
			sum.info.db <- matrix(, 1, 5)
			colnames(sum.info.db) <- c("name", "species", "genetic", 
				"node No", "edge No")
			rownames(sum.info.db) <- "Interaction dataset"
			
			sum.info.para <- matrix(, 1, 1)
			colnames(sum.info.para) <- "FDR"
			rownames(sum.info.para) <- "Parameter"
			
			sum.info.results <- matrix(, 1, 2)
			colnames(sum.info.results) <- c("node No", "edge No")
			rownames(sum.info.results) <- "Subnetwork"
			
			.Object@summary <- list(input = sum.info.input, 
				db = sum.info.db, para = sum.info.para, 
				results = sum.info.results)
			##initialization of summary
			.Object@summary$input["p-values", "input"] <- length(pvalues)
			.Object@summary$input["phenotypes", "input"] <- length(phenotypes)

			.Object@summary$db[1, "name"] <- "Unknown"
			if(!is.null(interactome)) {
				.Object@summary$db[1, "node No"] <- numNodes(interactome)
				.Object@summary$db[1, "edge No"] <- numEdges(interactome)
			}
			
			.Object@preprocessed <- FALSE
			
			.Object
		}
)
##pre-processing
setMethod(
		"preprocess",
		"NWA",
		function(object, species = "Dm", duplicateRemoverMethod = "max", 
			initialIDs = "FlybaseCG", keepMultipleMappings = TRUE, 
			verbose = TRUE) {
			##check input arguments
			paraCheck(name = "species", para = species)
			##Check that the method argument is correctly specified
			paraCheck(name = "duplicateRemoverMethod", para = duplicateRemoverMethod)
			paraCheck(name = "initialIDs", para = initialIDs)
			paraCheck(name = "keepMultipleMappings", para = keepMultipleMappings)
			paraCheck(name = "verbose", para = verbose)
			
			cat("-Preprocessing for input p-values and phenotypes ...\n")
			pvalues <- object@pvalues
			phenotypes <- object@phenotypes
			##1.remove NA
			if(verbose) 
				cat("--Removing invalid p-values and phenotypes ...\n")
			pvalues <- pvalues[which(!is.na(pvalues) 
				& names(pvalues) != "" & !is.na(names(pvalues)))]
			##valid p-values 
			object@summary$input[1, "valid"] <- length(pvalues)				
			if(length(pvalues) == 0)
				stop("Input 'pvalues' contains no useful data!\n")
			if(!is.null(phenotypes)) {
				phenotypes <- phenotypes[which((!is.na(phenotypes)) & 
					(names(phenotypes) != "" & !is.na(names(phenotypes))))]
				##valid phenotypes
				object@summary$input[2,"valid"] <- length(phenotypes)				
				if(length(phenotypes) == 0)
					stop("Input 'phenotypes' contains no useful data!\n")
			}
			##2.duplicate remover
			if(verbose) cat("--Removing duplicated genes ...\n")
			pvalues <- duplicateRemover(geneList = pvalues, 
				method = duplicateRemoverMethod)
			##p-values after removing duplicates 
			object@summary$input[1, "duplicate removed"] <- length(pvalues)	
	
			if(!is.null(phenotypes)) {
				phenotypes <- duplicateRemover(geneList = phenotypes, 
					method = duplicateRemoverMethod)
				##phenotypes after removing duplicates 
				object@summary$input[2, "duplicate removed"] <- length(phenotypes)	
			}
			##3.convert annotations in pvalues
			if(initialIDs != "Entrez.gene") {
				if(verbose) cat("--Converting annotations ...\n")
				pvalues <- annotationConvertor(
					geneList = pvalues,
					species = species,
					initialIDs = initialIDs,
					finalIDs = "Entrez.gene",
					keepMultipleMappings = keepMultipleMappings,
					verbose = verbose
				)
				if(!is.null(phenotypes)) {
					phenotypes <- annotationConvertor(
						geneList = phenotypes,
						species = species,
						initialIDs = initialIDs,
						finalIDs = "Entrez.gene",
						keepMultipleMappings = keepMultipleMappings,
						verbose = verbose
					)
				}
			}
			##p-values after annotation conversion
			object@summary$input[1, "converted to entrez"] <- length(pvalues)	
			##phenotypes after annotation conversion
			if(!is.null(phenotypes))
				object@summary$input[2,"converted to entrez"] <- length(phenotypes)	
			##5.update genelist and hits, and return object
			object@pvalues <- pvalues
			object@phenotypes <- phenotypes
			object@preprocessed <- TRUE
			
			cat("-Preprocessing complete!\n\n")
			object
		}
)
##build interactome
setMethod(
		"interactome",
		"NWA",
		function(object, interactionMatrix = NULL, species, 
			link = "http://thebiogrid.org/downloads/archives/Release%20Archive/BIOGRID-3.1.71/BIOGRID-ORGANISM-3.1.71.tab2.zip",
			reportDir = "HTSanalyzerReport", genetic = FALSE, verbose = TRUE) {
			##check arguments
			cat("-Creating interactome ...\n")
			if(missing(species) && is.null(interactionMatrix))
				stop("You should either input 'interactionMatrix' or ",
					"specifiy 'species' to download biogrid dataset!\n")
			if(!missing(species)) {
				paraCheck(name = "species", para = species)
				object@summary$db[, "species"] <- species
			}
			paraCheck(name = "genetic", para = genetic)
			paraCheck(name = "verbose", para = verbose)
			paraCheck(name = "reportDir", para = reportDir)
			
			object@summary$db[, "genetic"] <- genetic
			
			##4.make interactome
			##download the data from the BioGRID, if no data matrix is 
			##specified by the argument 'interactionMatrix'	
			if(is.null(interactionMatrix)) {
				paraCheck(name = "link", para = link)
				##create folders for biogrid date downloading
				biogridDataDir = file.path(reportDir, "Data")
				if(!file.exists(reportDir)) 
					dir.create(reportDir)
				InteractionsData <- biogridDataDownload(link = link,
					species = species, dataDirectory = biogridDataDir, 
					verbose = verbose)
				object@summary$db[1, "name"] <- "Biogrid"
			} else {
				paraCheck(name = "interactionMatrix", para = interactionMatrix)
				InteractionsData <- interactionMatrix
				object@summary$db[1, "name"] <- "User-input"
			}
			##If it is specified that genetic interactions should be 
			##discarded, remove those rows			
			if(!genetic) 
				InteractionsData <- InteractionsData[
					which(InteractionsData[, "InteractionType"] != "genetic"), ]
			##Make a graphNEL object from the data 	
			object@interactome <- makeNetwork(
				source = InteractionsData[, "InteractorA"], 
				target = InteractionsData[, "InteractorB"], 
				edgemode = "undirected")
			##update graph info in summary
			object@summary$db[, "node No"] <- numNodes(object@interactome)
			object@summary$db[, "edge No"] <- numEdges(object@interactome)

			cat("-Interactome created! \n\n")
			object
		}
)

##analysis
setMethod(
		"analyze",
		"NWA",
		function(object, fdr = 0.001, species, verbose = TRUE) {
			##check input arguments	
			paraCheck(name = "interactome", para = object@interactome)
			paraCheck(name = "fdr", para = fdr)
			object@fdr <- fdr
			object@summary$input[1, "in interactome"] <- 
				length(intersect(names(object@pvalues), nodes(object@interactome)))
			object@summary$para[1, 1] <- fdr
			if(!is.null(object@phenotypes))
				object@summary$input[2, "in interactome"] <- 
					length(intersect(names(object@phenotypes), nodes(object@interactome)))
			if(length(object@pvalues) == 0 || 
				object@summary$input[1, "in interactome"] == 0)
				stop("pvalues vector has length 0, or has no overlap ",
					"with interactome!\n")
			##perform network analysis
			module <- networkAnalysis(
				pvalues = object@pvalues,
				graph = object@interactome,
				fdr = object@fdr,
				verbose = verbose
			)
			##update module info in summary
			object@summary$result[, "node No"] <- numNodes(module)
			object@summary$result[, "edge No"] <- numEdges(module)
			##To represent the network in a more convenient format, 
			##the symbol identifiers will be mapped and given to the 
			##user (more readable than Entrez.gene IDs)	
			if(!missing(species)) {
				paraCheck(name = "species", para = species)
				anno.db.species <- paste("org", species, "eg", "db", sep=".")
				if(!(paste("package:", anno.db.species, sep="") %in% search()))
					library(anno.db.species, character.only = TRUE)
				map <- as.list(get(paste("org", species, "egSYMBOL", sep=".")))
				labels <- map[nodes(module)]
				object@result <- list(subnw = module, labels = labels)
			} else {
				object@result <- list(subnw = module, labels = nodes(module))
			}
			object
		}
)
##show summary information on screen
setMethod(
		"show",
		"NWA",
		function(object) {
			cat("A NWA (Network Analysis) object:\n")
			summarize(object, what = c("Pval", "Phenotype", "Interactome", "Para"))
		}
)
##print summary information on screen
setMethod(
		"summarize",
		"NWA",
		function(object, what = "ALL") {
			paraCheck(name = "what.nwa", para = what)
			if(any(c("ALL", "Pval") %in% what)) {
				cat("\n")
				cat("-p-values: \n")
				print(object@summary$input[1, ], quote = FALSE)
				cat("\n")
			}
			if(any(c("ALL","Phenotype") %in% what)) {
				cat("\n")
				cat("-Phenotypes: \n")
				print(object@summary$input[1, ],quote = FALSE)
				cat("\n")
			}
			if(any(c("ALL","Interactome") %in% what)) {
				cat("\n")
				cat("-Interactome: \n")
				print(object@summary$db,quote = FALSE)
				cat("\n")
			}
			if(any(c("ALL","Para") %in% what)) {
				cat("\n")
				cat("-Parameters for analysis: \n")
				print(object@summary$para, quote = FALSE)
				cat("\n")
			}
			if(any(c("ALL","Result") %in% what)) {
				cat("\n")
				cat("-Subnetwork identified: \n")
				print(object@summary$result, quote = FALSE)
				cat("\n")
			}	
		}
)
##plot subnetwork
setMethod(
		"plotSubNet",
		"NWA",
		function(object, filepath=".", filename="test", output="png", ...) {
			if(missing(filepath) || missing(filename))
				stop("Please specify 'filepath' and 'filename' ",
					"to save network plot! \n")
			paraCheck(name = "filepath", para = filepath)
			paraCheck(name = "filename", para = filename)
			paraCheck(name = "output", para = output)
			if(output == "pdf" ) 
				pdf(file.path(filepath, filename), ...=...)
			if(output == "png" ) 
				png(file.path(filepath, filename), ...=...)
			networkPlot(nwAnalysisOutput = object@result, 
				phenotypeVector = object@phenotypes)
			dev.off()
		}
)
##view subnetwork
setMethod(
		"viewSubNet",
		"NWA",
		function(object) {
			networkPlot(nwAnalysisOutput = object@result, 
					phenotypeVector = object@phenotypes)
		}
)
##generate html report for NWA
setMethod(
		"report",
		"NWA",
		function(object, experimentName = "Unknown", species = NULL, 
			ntop = NULL, allSig = FALSE, keggGSCs = NULL, goGSCs = NULL, 
			reportDir = "HTSanalyzerReport") {
			##call writeReportHTSA
			writeReportHTSA(nwa = object, experimentName = experimentName, 
				species = species, ntop = ntop, allSig = allSig, 
				keggGSCs = keggGSCs, goGSCs = goGSCs, reportDir = reportDir)
		}
)
