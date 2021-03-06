#!/usr/bin/env Rscript

# install BioC packages


source("http://bioconductor.org/biocLite.R")

if (Sys.getenv("USE_DEVEL") == "TRUE")
{
    if (packageVersion("BiocInstaller")$minor %% 2 == 0)
    {
        useDevel()
    }
}

pkgs <- c("affxparser", "affy", "affyio", "affylmGUI", "annaffy", "annotate",
    "AnnotationDbi", "AnnotationHub", "aroma.light", "BatchExperiments",  "BatchJobs", "BayesPeak",
    "baySeq", "Biobase", "BiocParallel", "BiocStyle",
    "biomaRt", "Biostrings", "BSgenome", "Category", "ChIPpeakAnno",
    "chipseq", "ChIPseqR", "ChIPsim", "CSAR", "cummeRbund", "DESeq", "DEXSeq",
    "DiffBind", "DNAcopy",  "dplyr", "dsQTL",
    "DynDoc", "EDASeq", "edgeR", "ensemblVEP", "gage",
    "genefilter", "geneplotter", "GenomeGraphs", "genomeIntervals",
    "GenomicFeatures", "GenomicRanges", "Genominator", "GEOquery", "GGBase",
    "GGtools", "girafe", "goseq", "GOstats", "graph", "GSEABase", "HilbertVis",
    "htmltools",
    "impute", "IRanges", "limma", 
    "knitr",
    "MEDIPS", "multtest", "oneChannelGUI", "PAnnBuilder",
    "preprocessCore", "qpgraph", "qrqc", "R453Plus1Toolbox", "RBGL",
    "Repitools", "rGADEM", "Rgraphviz", "Ringo", "rmarkdown", "Rmpi", "Rolexa", 
    "RNAseqData.HNRNPC.bam.chr14",
    "Rsamtools",
    "Rsubread", "rtracklayer", "segmentSeq", "seqbias", "seqLogo", "ShortRead",
    "snow",
    "snpStats", "splots", "SRAdb", "tkWidgets", "VariantAnnotation", "vsn",
    "widgetTools", "yaml", "zlibbioc")

ap <- rownames(available.packages(
    contrib.url(biocinstallRepos()['BioCann'], getOption("pkgType"))))
annoPkgs <- 
    ap[grep("^org\\.|^BSgenome\\.|^PolyPhen\\.|^SIFT\\.|^TxDb\\.", ap)]

## Annotation pkgs are ~20GB. Only install them if the user
## has specified doing so in the config.yml file.

if (Sys.getenv("INSTALL_ANNOTATION_PACKAGES") == "TRUE")
    pkgs <- c(pkgs, annoPkgs)


for (pkg in pkgs)
{
    tryCatch(x <- find.package(pkg),
        silent=TRUE,
        error=function(e) 
        {
            tryCatch(biocLite(pkg, ask=FALSE, suppressUpdates=TRUE),
                warning=function(w){
                    msg <- conditionMessage(w)
                    if (grepl("had non-zero exit status", msg))
                        stop(msg)
                })
        })
}



tryCatch(biocLite(ask=FALSE),
    warning=function(w){
        msg <- conditionMessage(w)
        if (grepl("had non-zero exit status", msg))
            stop(msg)
    })


