##Write html reports 
makeGSEAplots <- function(geneList, geneSet, exponent, filepath, 
	filename, output='png', ...) {
	test <- gseaScores(geneList = geneList, geneSet = geneSet,
			exponent = exponent, mode = "graph")
	filename<-sub("\\W","_", filename, perl=TRUE)
	if(output == "pdf" ) 
		pdf(file=file.path(filepath, paste("gsea_plots", filename, ".pdf", sep="")), ...=...)
	if(output == "png" ) 
		png(filename=file.path(filepath, paste("gsea_plots", filename, ".png", sep="")), ...=...)
	gseaPlots(runningScore = test[['runningScore']],
			enrichmentScore = test[['enrichmentScore']],
			positions = test[['positions']], geneList = geneList)
	dev.off()
}
makeOverlapTable <- function(geneSet, hits, mapID, filepath, filename) {
	overlap <- intersect(geneSet, hits)
	nOverlap <- length(overlap)
	overlapSymbols <- rep(0, nOverlap)
	filename<-sub("\\W","_", filename, perl=TRUE)
	if (nOverlap > 0)
		overlapSymbols <- sapply(mapID[overlap], function(x) 
			ifelse(length(x) == 1, x, 0))
	filename <- file.path(filepath, paste(filename, ".txt", sep=""))
	overlap <- cbind(EntrezGene = overlap, Symbols = overlapSymbols)
	write.table(overlap, file = filename, row.names = FALSE, quote = FALSE)
}
##generate html report for both GSCA and NWA
setClassUnion("GSCA_Or_NULL",c("GSCA","NULL"))
setClassUnion("NWA_Or_NULL",c("NWA","NULL"))
setMethod(
		"reportAll",
		c("GSCA_Or_NULL", "NWA_Or_NULL"),
		function(gsca, nwa, experimentName="Unknown", species=NULL, 
			ntop=NULL, allSig=FALSE, keggGSCs=NULL, goGSCs=NULL, 
			reportDir="HTSanalyzerReport") {
			##call writeReportHTSA
			if(missing(gsca)) gsca<-NULL
			if(missing(nwa)) nwa<-NULL
			writeReportHTSA(gsca = gsca, nwa = nwa, 
				experimentName = experimentName, species=species, 
				ntop=ntop, allSig = allSig, keggGSCs = keggGSCs, 
				goGSCs = goGSCs, reportDir = reportDir)
		}
)
writeReportHTSA <- function(gsca = NULL, nwa = NULL, experimentName = "Unknown", 
	species = NULL, ntop = NULL, allSig = FALSE, keggGSCs = NULL, 
	goGSCs = NULL, reportDir = "HTSanalyzerReport") {
	##check input arguments
	##check gsca and nwa
	Rep.gsca <- FALSE
	Rep.nwa <- FALSE
	if(is(gsca, "GSCA"))
		Rep.gsca <- TRUE
	if(is(nwa, "NWA"))
		Rep.nwa <- TRUE
	if(!Rep.gsca && !Rep.nwa)
		stop("Please input a 'GSCA' or 'NWA' object, or both of them! \n")
	##check experimentName
	paraCheck(name = "experimentName", para = experimentName)
	if(Rep.gsca) {
		##check gscs
		gscs <- names(gsca@listOfGeneSetCollections)
		if(is.null(gsca@result$HyperGeo.results))
			doGSOA<-FALSE
		else
			doGSOA<-TRUE
		if(is.null(gsca@result$GSEA.results))
			doGSEA<-FALSE
		else
			doGSEA<-TRUE
		if((!doGSOA) && (!doGSEA))			
			stop("Please do gene set overrepresentation and/or enrichment analysis first!\n")
	}
	##check species
	if(!is.null(species)) {
		paraCheck(name = "species",para = species)	
	}
	##check ntop and allSig
	if(!is.null(ntop))
		paraCheck(name = "ntop",para = ntop)
	paraCheck(name = "allSig", para = allSig)
	if((is.null(ntop) && !allSig) || (!is.null(ntop) && allSig))
		stop("Either specify 'ntop' or set 'allSig' to be TRUE!\n")
	if(Rep.gsca) {
		##check keggGSCs and goGSCs
		if(!is.null(keggGSCs)) {
			paraCheck(name = "keggGSCs", para = keggGSCs)
			if(!all(keggGSCs %in% gscs))
				stop("Wrong gene set collection names specified in 'keggGSCs'!\n")
		}
		if(!is.null(goGSCs)) {
			paraCheck(name = "goGSCs", para = goGSCs)
			if(!all(goGSCs %in% gscs))
				stop("Wrong gene set collection names specified in 'goGSCs'!\n")
		}	
	}
	##check reportDir
	paraCheck(name="reportDir",para=reportDir)
	##########################################
	##           create directories 	     #
	##########################################
	##Directories: alphabetically sorted (1 - doc; 2 - html; 3 - image)
	dirs <- file.path(reportDir, c('','doc', 'html', 'image'))
	names(dirs) <- c('root', 'doc', 'html', 'image')
	sapply(dirs, function(diri) if(!file.exists(diri)) dir.create(diri))
	##########################################
	##       	produce html templates	     #
	##########################################
	##Copy css and logos in there
	cpfile <- dir(system.file("templates", package="HTSanalyzeR"), full.names=TRUE)
	file.copy(from = cpfile, to = dirs['image'], overwrite = TRUE)
	##########################################
	##          	index page 				 #
	##########################################
	#Produce the index html page
	htmlfile <- file.path(reportDir, "index.html")
	writeHTSAHtmlHead(experimentName = experimentName, 
		htmlfile = htmlfile, rootdir = ".")
	##Produce tabs	
	writeHTSAHtmlTab(enrichmentAnalysis = gsca@result,
		tab = c("GSCA", "NWA")[c(Rep.gsca, Rep.nwa)], 
		htmlfile = htmlfile, rootdir = ".", index = FALSE)
	##Write summary info
	writeHTSAHtmlSummary(gsca = gsca, nwa = nwa, htmlfile = htmlfile)
	##Write tail of this HTML page
	writeHTSAHtmlTail(htmlfile=htmlfile)
	##########################################
	##           	GSCA pages	 		     #
	##########################################
	if(Rep.gsca) {
		numGeneSetCollections<-length(gsca@listOfGeneSetCollections)
		##Combine results from each individual gene set collection into one
		sapply(c("HyperGeo.results","GSEA.results","Sig.pvals.in.both","Sig.adj.pvals.in.both"), function(rslt) {
			if(!is.null(gsca@result[[rslt]])) {
				##large dataframe of all results
				gsca@result[[rslt]][["All.collections"]]<<-NULL
				sapply(1:numGeneSetCollections, function(i) {
							gsca@result[[rslt]][["All.collections"]]<<-
									rbind(gsca@result[[rslt]][["All.collections"]], gsca@result[[rslt]][[i]])
						}
				)
				if(nrow(gsca@result[[rslt]][["All.collections"]])>0) {
					##Results are ordered by adjusted p-values from lowest to highest
					if(rslt %in% c("HyperGeo.results","GSEA.results"))
						gsca@result[[rslt]][["All.collections"]]<<-
								gsca@result[[rslt]][["All.collections"]][order(gsca@result[[rslt]][["All.collections"]][,"Adjusted.Pvalue"]),,drop=FALSE]	
					else if(rslt=="Sig.pvals.in.both") 
						gsca@result[[rslt]][["All.collections"]]<<-
								gsca@result[[rslt]][["All.collections"]][order(gsca@result[[rslt]][["All.collections"]][,"GSEA.Pvalue"]),,drop=FALSE]		
					else if(rslt=="Sig.adj.pvals.in.both")
						gsca@result[[rslt]][["All.collections"]]<<-
								gsca@result[[rslt]][["All.collections"]][order(gsca@result[[rslt]][["All.collections"]][,"GSEA.Adj.Pvalue"]),,drop=FALSE]							
				}					
			}
		})

		if(doGSOA)
			rslt.gscs <- names(gsca@result$HyperGeo.results)		
		if(doGSEA)
			rslt.gscs <- names(gsca@result$GSEA.results)	
		for(i in 1:length(rslt.gscs)) {
			##########################################
			##           	HyperGeo pages 		     #
			##########################################
			if(doGSOA) {
				##write hits
				if(rslt.gscs[i] %in% gscs)
					writeHits(object = gsca, gscs = rslt.gscs[i], species = species, 
						ntop = ntop, allSig = allSig, filepath = dirs['doc'])
				hyper.filenames <- getTopGeneSets(object = gsca, 
					resultName = "HyperGeo.results", gscs = rslt.gscs[i], 
					ntop = ntop, allSig = allSig)
				##enrichment map for hypergeo tests
				if(length(hyper.filenames[[1]])>0) {
					if(rslt.gscs[i] %in% gscs) 
						map.gscs<-rslt.gscs[i]		
					else if(rslt.gscs[i]=="All.collections") 
						map.gscs<-gscs
					if("Gene.Set.Term" %in% colnames(gsca@result$HyperGeo.results[[rslt.gscs[i]]]))
						gsNameType<-"term"
					else 
						gsNameType<-"id"
					plotEnrichMap(gsca, resultName="HyperGeo.results",gscs=map.gscs, ntop=ntop, allSig=allSig, gsNameType=gsNameType, displayEdgeLabel=FALSE, 
							layout="layout.fruchterman.reingold", filepath=dirs['image'], filename=paste("hypergeo_map",i,".png",sep=""), 
							output="png", width=800, height=800, pointsize=18)				
				}
				htmlfile <- file.path(dirs['html'], paste("hyperg", i, ".html", sep=""))
				##create htmls
				writeHTSAHtmlHead(experimentName = experimentName, 
					htmlfile = htmlfile, rootdir = "..")
				##Produce the tabs
				writeHTSAHtmlTab(enrichmentAnalysis = gsca@result, 
					tab = c("GSCA", "NWA")[c(Rep.gsca, Rep.nwa)], 
					htmlfile = htmlfile, rootdir = "..", index = TRUE)
			
				##Produce table
				gs.names <- rownames(gsca@result$HyperGeo.results[[rslt.gscs[i]]])
				##data table
				allcol.names<-colnames(gsca@result$HyperGeo.results[[rslt.gscs[i]]])
				gsca@result$HyperGeo.results[[rslt.gscs[i]]][,setdiff(allcol.names,"Gene.Set.Term")] <- signif(gsca@result$HyperGeo.results[[rslt.gscs[i]]][,setdiff(allcol.names,"Gene.Set.Term")], digits = 4)
				dat.tab <- data.frame(Gene.Set.name=rownames(gsca@result$HyperGeo.results[[rslt.gscs[i]]]), gsca@result$HyperGeo.results[[rslt.gscs[i]]], stringsAsFactors=FALSE)
				##colnames(dat.tab)[1] <- "Gene.Set.name"
				this.row <- nrow(gsca@result$HyperGeo.results[[rslt.gscs[i]]])
				this.col <- ncol(gsca@result$HyperGeo.results[[rslt.gscs[i]]])
				if(this.row>0) {
					##hyperlink table 
					href.tab <- array(NA, dim = c(this.row, this.col+1, 3))
					dimnames(href.tab)[[3]] <- c("href", "target", "title")
					dimnames(href.tab)[[1]] <- gs.names
					##hyperlinks for kegg gene sets
					if(rslt.gscs[i] %in% keggGSCs) {
						href.tab[, 1, 1] <- 
							paste("http://www.genome.jp/dbget-bin/www_bget?pathway:", gs.names, sep="")
						href.tab[, 1, 2] <- "_blank"
						href.tab[, 1, 3] <- gs.names
					}
					##hyperlinks for go gene sets
					if(rslt.gscs[i] %in% goGSCs) {
						gogsnames2web <- sapply(gs.names, 
							function(gogsname) {
								sub(pattern = "(\\D*$)", replacement = "", 
									x = sub(pattern = "(\\D*)", replacement = "", x = gogsname, perl = TRUE), perl = TRUE)
							}
						)
						gogsnames2doc <- sapply(gs.names, 
							function(gogsname) {
								sub(pattern = "(\\D*$)", replacement = "", x = gogsname, perl = TRUE)
							}
						)
						href.tab[, 1, 1] <- 
							paste("http://www.ebi.ac.uk/QuickGO/GTerm?id=GO:", gogsnames2web, sep="")
						href.tab[, 1, 2] <- "_blank"
						href.tab[, 1, 3] <- gs.names
					}
					if(length(hyper.filenames[[1]])>0) {
						href.tab[names(hyper.filenames[[1]]), which(allcol.names=="Observed.Hits")+1, 1] <- 
								paste("../doc/", sub("\\W","_", hyper.filenames[[1]], perl=TRUE), ".txt", sep = "")
						href.tab[names(hyper.filenames[[1]]), which(allcol.names=="Observed.Hits")+1, 2] <- "_blank"
						href.tab[names(hyper.filenames[[1]]), which(allcol.names=="Observed.Hits")+1, 3] <- "Observed.hits"					
					}
					##highlight table
					signif.tab <- matrix(NA, this.row, this.col+1)
					colnames(signif.tab) <- rep("class", this.col+1)
					signif.tab[which(gsca@result$HyperGeo.results[[rslt.gscs[i]]][, "Adjusted.Pvalue"] < gsca@para$pValueCutoff), which(allcol.names=="Adjusted.Pvalue")+1] <- "signif"
					##row attribute table
					row.attr.tab <- matrix("even", this.row, 1)
					colnames(row.attr.tab) <- "class"
					row.attr.tab[which(1:this.row%%2 == 1), 1] <- "odd"
					##Generate and write table 
					writeHTSAHtmlTable(
							dat.tab = dat.tab, 
							href.tab = href.tab, 
							signif.tab = signif.tab, 
							row.attr.tab = row.attr.tab,
							tab.class = "result",
							tab.name = paste(rslt.gscs[i], ' Hyperg. Tests', sep=""),
							htmlfile = htmlfile
					)
				}
				writeHTSAHtmlTail(htmlfile = htmlfile)			
			} 
			##########################################
			##           	GSEA pages	 		     #
			##########################################
			if(doGSEA) {
				gsea.filenames <- getTopGeneSets(object = gsca, resultName = "GSEA.results", 
						gscs = rslt.gscs[i], ntop = ntop, allSig = allSig)
				if(length(gsea.filenames[[1]])>0) {
					if(rslt.gscs[i] %in% gscs)
						plotGSEA(object = gsca, gscs = rslt.gscs[i], ntop = ntop, 
								allSig = allSig, filepath = dirs['image'], output="png", width=800, height=800)
					if(rslt.gscs[i] %in% gscs) 
						map.gscs<-rslt.gscs[i]		
					else if(rslt.gscs[i]=="All.collections") 
						map.gscs<-gscs
					if("Gene.Set.Term" %in% colnames(gsca@result$GSEA.results[[rslt.gscs[i]]]))
						gsNameType<-"term"
					else 
						gsNameType<-"id"
					plotEnrichMap(gsca, gscs=map.gscs, ntop=ntop, allSig=allSig, gsNameType=gsNameType, displayEdgeLabel=FALSE, 
							layout="layout.fruchterman.reingold", filepath=dirs['image'], filename=paste("gsea_map",i,".png",sep=""), 
							output="png", width=800, height=800, pointsize=18)				
				}
				htmlfile <- file.path(dirs['html'], paste("gsea", i, ".html", sep = ""))
				##create htmls
				writeHTSAHtmlHead(experimentName = experimentName, 
					htmlfile = htmlfile, rootdir = "..")
				##Produce the tabs
				writeHTSAHtmlTab(enrichmentAnalysis = gsca@result, 
					tab = c("GSCA","NWA")[c(Rep.gsca,Rep.nwa)], 
					htmlfile = htmlfile, rootdir = "..", index = TRUE)
				##Produce table
				gs.names <- rownames(gsca@result$GSEA.results[[rslt.gscs[i]]])
				top.gs.id <- match(names(gsea.filenames[[1]]), gs.names)
				##data table
				this.row <- nrow(gsca@result$GSEA.results[[rslt.gscs[i]]])
				this.col <- ncol(gsca@result$GSEA.results[[rslt.gscs[i]]])
				if(this.row>0) {
					allcol.names<-colnames(gsca@result$GSEA.results[[rslt.gscs[i]]])
					gsca@result$GSEA.results[[rslt.gscs[i]]][,setdiff(allcol.names,"Gene.Set.Term")] <- signif(gsca@result$GSEA.results[[rslt.gscs[i]]][,setdiff(allcol.names,"Gene.Set.Term")], digits = 4)
					dat.tab <- data.frame(Gene.Set.name=rownames(gsca@result$GSEA.results[[rslt.gscs[i]]]), gsca@result$GSEA.results[[rslt.gscs[i]]], Plots=rep("", this.row), stringsAsFactors=FALSE)
					if(length(gsea.filenames[[1]])>0)
						dat.tab[top.gs.id, this.col+2] <- "plot"
					##colnames(dat.tab)[1] <- "Gene.Set.name"
					##colnames(dat.tab)[this.col+2] <- "Plots"
					##hyperlink table 
					href.tab <- array(NA, dim = c(this.row, this.col+2, 3))
					dimnames(href.tab)[[3]] <- c("href", "target", "title")				
					##hyperlinks for kegg gene sets
					if(rslt.gscs[i] %in% keggGSCs) {
						href.tab[, 1, 1] <- 
							paste("http://www.genome.jp/dbget-bin/www_bget?pathway:", gs.names, sep="")
						href.tab[, 1, 2] <- "_blank"
						href.tab[, 1, 3] <- gs.names
					}
					##hyperlinks for go gene sets
					if(rslt.gscs[i] %in% goGSCs) {
						gogsnames2web <- sapply(gs.names, 
								function(gogsname) {
									sub(pattern = "(\\D*$)", replacement = "", 
										x = sub(pattern = "(\\D*)", replacement = "",x = gogsname, perl = TRUE), perl = TRUE)
								}
						)
						gogsnames2doc<-sapply(gs.names, 
								function(gogsname) {
									sub(pattern = "(\\D*$)", replacement = "", x = gogsname, perl = TRUE)
								}
						)
						href.tab[, 1, 1] <- paste("http://www.ebi.ac.uk/QuickGO/GTerm?id=GO:", gogsnames2web, sep="")
						href.tab[, 1, 2] <- "_blank"
						href.tab[, 1, 3] <- gs.names
					}
					if(length(gsea.filenames[[1]])>0) {
						href.tab[top.gs.id, this.col+2, 1] <- paste("../image/gsea_plots", sub("\\W","_", gsea.filenames[[1]], perl=TRUE), ".png", sep="")
						href.tab[top.gs.id, this.col+2, 2] <- "_blank"
						href.tab[top.gs.id, this.col+2, 3] <- "gseaplots"	
					}
					##highlight table
					signif.tab <- matrix(NA, this.row, this.col+2)
					colnames(signif.tab) <- rep("class", this.col+2)
					signif.tab[which(gsca@result$GSEA.results[[rslt.gscs[i]]][,which(allcol.names=="Adjusted.Pvalue")] < gsca@para$pValueCutoff), which(allcol.names=="Adjusted.Pvalue")+1] <- "signif"
					##row attribute table
					row.attr.tab <- matrix("even", this.row, 1)
					colnames(row.attr.tab) <- "class"
					row.attr.tab[which(1:this.row%%2 == 1), 1] <- "odd"
					##Generate and write table 
					writeHTSAHtmlTable(
							dat.tab = dat.tab, 
							href.tab = href.tab, 
							signif.tab = signif.tab, 
							row.attr.tab = row.attr.tab,
							tab.class = "result",
							tab.name = paste(rslt.gscs[i], ' GSEA', sep=""),
							htmlfile = htmlfile
					)
				}
				writeHTSAHtmlTail(htmlfile = htmlfile)			
			}

			##########################################
			##	     enrichment map pages		 	 #
			##########################################
			maphtmlfile <- file.path(dirs['html'], paste("enrichment_map", i, ".html", sep = ""))
			writeHTSAHtmlHead(experimentName = experimentName, 
					htmlfile = maphtmlfile, rootdir = "..")
			writeHTSAHtmlTab(enrichmentAnalysis = gsca@result, 
					tab = c("GSCA","NWA")[c(Rep.gsca,Rep.nwa)], 
					htmlfile = maphtmlfile, rootdir = "..", index = TRUE)
			##place enrichment map to maphtml
			cat('<table class="enrichment map"><tr>', append = TRUE, 
				file = maphtmlfile)
			if(doGSEA && length(gsea.filenames[[1]])>0)
				cat('<td> <img src="../image/gsea_map', 
						i, '.png" align="top" width="800" height="800"> </td>', 
						sep = "", append = TRUE, file = maphtmlfile)
			if(doGSOA && length(hyper.filenames[[1]])>0)
				cat('<td> <img src="../image/hypergeo_map', 
						i, '.png" align="top" width="800" height="800"> </td>', 
						sep = "", append = TRUE, file = maphtmlfile)
			cat('</tr></table>', append = TRUE, 
				file = maphtmlfile)
			writeHTSAHtmlTail(htmlfile = maphtmlfile)	
			##########################################
			##	     enrichment summary pages	 	 #
			##########################################
			if(doGSOA && doGSEA) {
				htmlfile = file.path(dirs['html'], paste("enrichment", i, ".html", sep=""))
				writeHTSAHtmlHead(experimentName = experimentName, 
					htmlfile = htmlfile, rootdir = "..")
				##Produce the tabs
				writeHTSAHtmlTab(enrichmentAnalysis = gsca@result, 
					tab = c("GSCA", "NWA")[c(Rep.gsca, Rep.nwa)], 
					htmlfile = htmlfile, rootdir = "..", index = TRUE)
				##data table
				this.row <- nrow(gsca@result$Sig.adj.pvals.in.both[[rslt.gscs[i]]])
				this.col <- ncol(gsca@result$Sig.adj.pvals.in.both[[rslt.gscs[i]]])
				if(this.row > 0) {
					allcol.names<-colnames(gsca@result$Sig.adj.pvals.in.both[[rslt.gscs[i]]])
					gsca@result$Sig.adj.pvals.in.both[[rslt.gscs[i]]][,setdiff(allcol.names,"Gene.Set.Term")] <- signif(gsca@result$Sig.adj.pvals.in.both[[rslt.gscs[i]]][,setdiff(allcol.names,"Gene.Set.Term")], digits = 4)
					dat.tab <- data.frame(Gene.Set.name=rownames(gsca@result$Sig.adj.pvals.in.both[[rslt.gscs[i]]]), gsca@result$Sig.adj.pvals.in.both[[rslt.gscs[i]]], stringsAsFactors=FALSE)
					##colnames(dat.tab)[1] <- "Gene.Set.name"
					##row attribute table
					row.attr.tab <- matrix("even", this.row, 1)
					colnames(row.attr.tab) <- "class"
					row.attr.tab[which(1:this.row%%2 == 1), 1] <- "odd"
					##Generate and write table 
					writeHTSAHtmlTable(
							dat.tab = dat.tab, 
							href.tab = NULL, 
							signif.tab = NULL, 
							row.attr.tab = row.attr.tab,
							tab.class = "result",
							tab.name = paste("Gene sets with significant adjusted p-value in both hypergeometric test and GSEA: ", rslt.gscs[i], sep=""),
							htmlfile = htmlfile
					)
				}
				writeHTSAHtmlTail(htmlfile = htmlfile)			
			}
		}
	}
	##########################################
	##           	NWA pages	 		     #
	##########################################
	if(Rep.nwa) {
		nwAnalysisGraphFile <- "EnrichedSubNw.png"
		##plot subnetwork
		plotSubNet(nwa, filepath = dirs['image'], filename = paste(nwAnalysisGraphFile, sep = ""), output="png", width=800, height=800)
		htmlfile = file.path(dirs['html'], "network.html")
		writeHTSAHtmlHead(experimentName = experimentName, 
			htmlfile = htmlfile, rootdir = "..")
		##Produce the tabs
		writeHTSAHtmlTab(enrichmentAnalysis = gsca@result, 
			tab = c("GSCA", "NWA")[c(Rep.gsca,Rep.nwa)], 
			htmlfile = htmlfile, rootdir = "..", index = TRUE)	
		cat(paste('\n <hr/> \n <br>', 'Click <a href="../doc/subnetNodes.txt" target="_blank" title="Enriched Subnetwork">here</a> to get Entrez identifiers and symbols of nodes in identified subnetwork! <br> \n\n',sep=""),
				file = htmlfile, append = TRUE)
		cat('<table class="result"><tr><td> <img src="../image/', 
			nwAnalysisGraphFile, '" align="top" width="800" height="800"> </td></tr></table>', 
			sep = "", append = TRUE, file = htmlfile)
		writeHTSAHtmlTail(htmlfile = htmlfile)	
		htmlfile = file.path(dirs['html'], "subnetNodes.html") 
		##Check that the nwAnalysisOutput has the right format
		if(!is.null(nwa@result$label)) {
			EnrichSNnodes <- cbind(nodes(nwa@result$subnw), nwa@result$labels)
			colnames(EnrichSNnodes) <- c("Entrez Identifier", "Symbol")
		} else {
			EnrichSNnodes <- matrix(nodes(nwa@result$subnw), ncol = 1)
			colnames(EnrichSNnodes) <- c("Entrez Identifier")			
		}
		this.row <- nrow(EnrichSNnodes)
		if(this.row > 0) {
			write.table(EnrichSNnodes, file = file.path(dirs['doc'], "subnetNodes.txt"), 
				row.names = FALSE, quote = FALSE, sep = "\t")			
		}
	}
}
