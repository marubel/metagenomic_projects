#' Test taxa for differences in abundance
#' @param s A data frame of sample info.
#' @param cts A matrix of OTU counts (rows) for each sample (columns).
#' @param g A factor of sample groups to be tested.
#' @param a A chearacter vector of OTU assignments.
test_taxon_abundance <- function (s, cts, var="study_group", a=NULL, min_fraction=0.5) {
  # Limit OTU table to samples in provided data frame
  cts <- cts[, s$SampleID]
  #browser()
  cts <- cts[rownames(cts) %in% names(a), ]
  cts <- cts[match(names(a), rownames(cts)), ]
  cts <- rowsum(cts, as.character(a))
  
  # Matrix of OTU proportions
  props <- sweep(cts, 2, colSums(cts), `/`)

  # Empty result
  res <- list()

  # Detect OTUs present in < 5 samples
  frac_present <- function (x) sum(x > 0) / length(x)
  too_rare <- apply(cts, 1, function (x) frac_present(x) < min_fraction)

  res$tests <- apply(cts[!too_rare,], 1, function (x) kruskal.test(x,s[[var]]))

  res$df <- data.frame(
    Taxon = names(res$tests),
    Stat = sapply(res$tests, `[[`, "statistic"),
    Pval = sapply(res$tests, `[[`, "p.value"))
  res$df <- within(res$df, {
    Fdr <- p.adjust(Pval, method="fdr")
  })
  res$df <- arrange(res$df, Pval)
  
  plotdf <- melt(props, varnames=c("Taxon", "SampleID"), value.name="Proportion")
  plotdf <- merge(plotdf, res$df, by="Taxon", all.x=T, all.y=F)
  plotdf <- subset(plotdf, Pval < 0.05)
  plotdf <- merge(plotdf, s, by="SampleID", all.x=T, all.y=F)
  plotdf$Taxon <- reorder(plotdf$Taxon, plotdf$Pval)

  #browser()
  res$plot <- ggplot(plotdf) + 
    geom_boxplot(aes_string(x=var, y="Proportion")) +
    facet_wrap(~ Taxon, scales="free_y", ncol=2) +
    theme_classic() +
    theme(axis.text.x = element_text(angle=60, hjust=1))

  class(res) <- "taxon_abundance_tests"
  res
}
print.taxon_abundance_tests <- function (x) {
  print(x$plot)
  print(subset(x$df, Pval < 0.05))
}
