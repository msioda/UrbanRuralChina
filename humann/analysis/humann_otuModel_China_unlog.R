##models for HUMAnN results

rm(list=ls())

library("pscl")
library("lmtest")
library("nlme")

setwd("")

levels = c("module", "pathway")

for(lev in levels) {
  print(lev)
  file = paste("humann_keggAsCol_withRurUrb_", lev, ".txt", sep="")
  table = read.table(file, header=T, sep="\t")
  ncol = ncol(table)
  table = read.table(file, header=T, sep="\t", colClasses=c(rep("character", 2), rep("numeric", ncol-2)))
  
  desc = read.table(paste("humann_keggAsRow_", lev, ".txt", sep=""), sep="\t", quote="", 
                    header=T, stringsAsFactors = F)
  
  names <- vector()
  description <- vector()
  pValuesUrbanRural <- vector()
  mean <- vector()
  sd <- vector()
  meanUrban <- vector()
  sdUrban <- vector()
  meanRural <- vector()
  sdRural <- vector()
  pValuesUrbanRuralWilcox <- vector()
  r.squared <- vector()
  index <- 1
  
  ##p-values
  for(i in 7:ncol) {
    if(sum(table[,i] != 0 ) > nrow(table) / 4) {
      
      kegg <- table[,i]
      mean[index] <- mean(kegg)
      sd[index] <- sd(kegg)
      meanUrban[index] <- mean(kegg[table$ruralUrban=="urban"])
      meanRural[index] <- mean(kegg[table$ruralUrban=="rural"])
      sdUrban[index] <- sd(kegg[table$ruralUrban=="urban"])
      sdRural[index] <- sd(kegg[table$ruralUrban=="rural"])
      urbanRural <- factor(table$ruralUrban)
      
      ##abbreviation and description
      names[index] = names(table)[i]
      description[index] = desc$NAME[desc$sampleID==names[index]]
      
      ##linear model
      model = lm(kegg~urbanRural)
      pValuesUrbanRural[index] = anova(model)$`Pr(>F)`[1]
      r.squared[index] = summary(model)$r.squared
      
      ##non parametric test
      pValuesUrbanRuralWilcox[index] = wilcox.test(kegg~urbanRural)$p.value
      
      index=index+1
      
    }
  }
  
  dFrame <- data.frame(kegg=names, name=description,
                       mean, sd, meanUrban, sdUrban, meanRural, sdRural,
                       pValuesUrbanRural, pValuesUrbanRuralWilcox)
  dFrame$UrbanToRural <- meanUrban / meanRural
  dFrame$adjustedPurbanRural <- p.adjust( dFrame$pValuesUrbanRural, method = "BH" )
  dFrame$adjustedPurbanRuralWilcox <- p.adjust(dFrame$pValuesUrbanRuralWilcox, method="BH")
  dFrame$r.squared = r.squared
  dFrame <- dFrame[order(dFrame$pValuesUrbanRural),]
  write.table(dFrame, file=paste("humann_otuModel_pValues_unlog_", lev, ".txt",sep=""), sep="\t",row.names=FALSE)
  
  ##plot
  pdf(paste("humann_model_boxplots_", lev, ".pdf", sep=""), height=5, width=5)
  for(i in 1:nrow(dFrame)) {
    name = dFrame$kegg[i]
    abun = table[,names(table)==name]
    
    graphMain =  paste("WGS ", lev, ": ", name,
                       "\npAdjRuralUrban= ", format(dFrame$adjustedPurbanRural[i],digits=3), sep="")
    boxplot(abun~urbanRural, main=graphMain, ylab="log relative abundance", cex.main=1, outline=F, ylim=range(abun))
    points(abun~jitter(as.numeric(urbanRural)), pch=16, col=ifelse(urbanRural=="rural", "blue", "red"))
  }
  dev.off()
}