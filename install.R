#!/usr/bin/env Rscript

# install BioC packages

source("http://bioconductor.org/biocLite.R")

if (Sys.getenv("USE_DEVEL") == "TRUE")
    useDevel()


biocLite(c("affxparser", "affy", "affyio", "affylmGUI", "annaffy", "annotate",
    "AnnotationDbi", "aroma.light", "BayesPeak", "baySeq", "Biobase", 
    "biomaRt", "Biostrings", "BSgenome", "Category", "ChIPpeakAnno",
    "chipseq", "ChIPseqR", "ChIPsim", "CSAR", "cummeRbund", "DESeq", "DEXSeq",
    "DiffBind", "DNAcopy", "DynDoc", "EDASeq", "edgeR", "ensemblVEP", "gage",
    "genefilter", "geneplotter", "GenomeGraphs", "genomeIntervals",
    "GenomicFeatures", "GenomicRanges", "Genominator", "GEOquery", "GGBase",
    "GGtools", "girafe", "goseq", "GOstats", "graph", "GSEABase", "HilbertVis",
    "impute", "IRanges", "limma", "MEDIPS", "multtest", "oneChannelGUI", "PAnnBuilder",
    "preprocessCore", "qpgraph", "qrqc", "R453Plus1Toolbox", "RBGL",
    "Repitools", "rGADEM", "Rgraphviz", "Ringo", "Rolexa", "Rsamtools",
    "Rsubread", "rtracklayer", "segmentSeq", "seqbias", "seqLogo", "ShortRead",
    "snpStats", "splots", "SRAdb", "tkWidgets", "VariantAnnotation", "vsn",
    "widgetTools", "zlibbioc"))

#Rmpi, BiocParallel, BatchJobs
