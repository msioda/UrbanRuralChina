##mixed linear models for 16S dataset
##model of taxa ~ time + urbanRural + 1|subjectI
##also perform nonparametric (Wilcox) test

rm(list=ls())

library("pscl")
library("lmtest")
library("nlme")

setwd("")

taxaLevels <- c("phylum","class","order","family","genus", "otu")

for(taxa in taxaLevels ) 
{
  print(taxa)
  inFileName <- paste( taxa,  "_taxaAsColumnsLogNorm_WithMetadata.txt", sep ="")
  if(taxa=="otu") {
    inFileName <- "abundantOTUForwardTaxaAsColumnsLogNormalWithMetadata.txt"
  }
  myT <-read.table(inFileName,header=TRUE,sep="\t")
  numCols <- ncol(myT)
  myColClasses <- c(rep("character",5), rep("numeric", numCols-5))
  if(taxa=="otu") { #missing read number
    myColClasses <- c(rep("character",4), rep("numeric", numCols-4))
  }
  myT <-read.table(inFileName,header=TRUE,sep="\t",colClasses=myColClasses)
  
  ##add read number to OTU and remove diversity measures
  if(taxa=="otu") {
    ##add read number
    readNumber = rep("1", nrow(myT))
    myT <- cbind(myT[,1], readNumber, myT[,-1])
    names(myT)[1] = "sampleID"
    ##remove diversity measures
    myT = myT[,-(6:8)]
    numCols = ncol(myT)
  }
  
  # only the forward reads
  myT <- myT[ which( myT$readNumber == "1"), ]
  
  names <- vector()
  pValuesTime <- vector()
  pValuesSubject <- vector()
  pValuesUrbanRural <- vector()
  meanTaxa <- vector()
  meanUrban <- vector()
  meanUrban1 <- vector()
  meanUrban2 <- vector()
  meanRural <- vector()
  meanRural1 <- vector()
  meanRural2 <- vector()
  sdTaxa <- vector()
  sdUrban <- vector()
  sdUrban1 <- vector()
  sdUrban2 <- vector()
  sdRural <- vector()
  sdRural1 <- vector()
  sdRural2 <- vector()
  pValuesUrbanRuralWilcoxT1 <- vector()
  pValuesUrbanRuralWilcoxT2 <- vector()
  pValuesUrbanRuralWilcoxAll <- vector()
  r.squared <- vector()
  index <- 1
  
  ##p values
  for(i in 6:numCols) {
    if(sum(myT[,i] != 0 ) > nrow(myT) / 4) {
      
      bug <- myT[,i]
      meanTaxa[index] <- mean(bug)
      meanUrban[index] <- mean(bug[myT$ruralUrban=="urban"])
      meanRural[index] <- mean(bug[myT$ruralUrban=="rural"])
      meanUrban1[index] <- mean(bug[myT$ruralUrban=="urban" & myT$timepoint=="first_A"])
      meanRural1[index] <- mean(bug[myT$ruralUrban=="rural" & myT$timepoint=="first_A"])
      meanUrban2[index] <- mean(bug[myT$ruralUrban=="urban" & myT$timepoint=="second_B"])
      meanRural2[index] <- mean(bug[myT$ruralUrban=="rural" & myT$timepoint=="second_B"])
      sdTaxa[index] <- sd(bug)
      sdUrban[index] <- sd(bug[myT$ruralUrban=="urban"])
      sdRural[index] <- mean(bug[myT$ruralUrban=="rural"])
      sdUrban1[index] <- sd(bug[myT$ruralUrban=="urban" & myT$timepoint=="first_A"])
      sdRural1[index] <- sd(bug[myT$ruralUrban=="rural" & myT$timepoint=="first_A"])
      sdUrban2[index] <- sd(bug[myT$ruralUrban=="urban" & myT$timepoint=="second_B"])
      sdRural2[index] <- sd(bug[myT$ruralUrban=="rural" & myT$timepoint=="second_B"])
      time <- factor(myT$timepoint)
      patientID <- factor(myT$patientID )
      urbanRural <- factor(myT$ruralUrban)
      
      myFrame <- data.frame(bug, time, patientID, urbanRural )
      
      fullModel <- gls( bug~  time + urbanRural , method="REML",correlation=corCompSymm(form=~1|factor(patientID)),
                        data = myFrame )
      
      reducedModel <- gls( bug~  time + urbanRural , method="REML",	data = myFrame )
      
      fullModelLME <- lme(bug~  time + urbanRural , method="REML", random = ~1|factor(patientID), data = myFrame)		
      
      pValuesTime[index] <- anova(fullModelLME)$"p-value"[2]
      pValuesUrbanRural[index] <- anova(fullModelLME)$"p-value"[3]
      pValuesSubject[index] <-  anova(fullModelLME, reducedModel)$"p-value"[2]
      intraclassCoefficient<- coef(fullModel$modelStruct[1]$corStruct,unconstrained=FALSE)[[1]]
      names[index] = names(myT)[i]
      
      ###R^2
      fit = fitted(fullModelLME)
      ave = mean(bug)
      num = (bug - fit)^2
      denom = (bug - ave)^2
      r.squared[index] = 1 - sum(num)/sum(denom)
      
      ##non parametric test
      pValuesUrbanRuralWilcoxAll[index] = wilcox.test(bug~urbanRural)$p.value
      
      time1 = myT$timepoint=="first_A"
      bug1 = myT[time1, i]
      urb1 = factor(myT$ruralUrban[time1])
      time2 = myT$timepoint=="second_B"
      bug2 = myT[time2, i]
      urb2 = factor(myT$ruralUrban[time2])
      
      pValuesUrbanRuralWilcoxT1[index] = wilcox.test(bug1~urb1)$p.value
      pValuesUrbanRuralWilcoxT2[index] = wilcox.test(bug2~urb2)$p.value
      
      index=index+1
      
    }
  }
  dFrame <- data.frame(names, meanTaxa, sdTaxa, meanUrban, sdUrban, meanUrban1, sdUrban1, meanUrban2, sdUrban2,
                       meanRural, sdRural, meanRural1, sdRural1, meanRural2, sdRural2,
                       pValuesTime ,pValuesSubject, pValuesUrbanRural,
                       pValuesUrbanRuralWilcoxT1, pValuesUrbanRuralWilcoxT2, pValuesUrbanRuralWilcoxAll)
  dFrame$UrbanToRural <- ((meanUrban1 + meanUrban2)/2) / ((meanRural1 + meanRural2)/2)
  dFrame$adjustedPtime <- p.adjust( dFrame$pValuesTime, method = "BH" )
  dFrame$adjustedPsubject <- p.adjust( dFrame$pValuesSubject, method = "BH" )
  dFrame$adjustedPurbanRural <- p.adjust( dFrame$pValuesUrbanRural, method = "BH" )
  dFrame$adjustedPurbanRuralWilcoxT1 <- p.adjust(dFrame$pValuesUrbanRuralWilcoxT1, method="BH")
  dFrame$adjustedPurbanRuralWilcoxT2 <- p.adjust(dFrame$pValuesUrbanRuralWilcoxT2, method="BH")
  dFrame$adjustedPurbanRuralWilcoxAll <- p.adjust(dFrame$pValuesUrbanRuralWilcoxAll, method="BH")
  dFrame$r.squared = r.squared
  dFrame <- dFrame[order(dFrame$adjustedPurbanRural),]
  write.table(dFrame, file=paste("otuModel_pValues_", taxa, ".txt",sep=""), sep="\t",row.names=FALSE)
  
  ##plots
  pdf(paste("16S_model_boxplots_", taxa, ".pdf", sep=""), height=9, width=10)
  for(i in 1:nrow(dFrame)) {
    name = dFrame$names[i]
    abun = myT[,names(myT)==name]
    if(taxa=="otu") {
      name = sub("X", "OTU", name)
    }
    
    df = data.frame(id=myT$patientID, ruralUrban=myT$ruralUrban, time=myT$timepoint, abun)
    df$time = ifelse(df$time=="first_A", "timepoint 1", "timepoint 2")
    
    layout(matrix(c(rep(1,3), 2:5, rep(6,2)), ncol=3, byrow = T), heights=c(.2,1,1))
    
    ##title
    par(mar=rep(0,4))
    plot(0, xlab="", ylab="", type="n", axes=F, xlim=c(-1,1), ylim=c(-1,1))
    graphMain =  paste("16S ", ifelse(taxa=="otu", "OTU", taxa), ": ", name, 
                       "\npAdjRuralUrban=", format(dFrame$adjustedPurbanRural[i], digits=3), 
                        "; pAdjTime=", format(dFrame$adjustedPtime[i],digits=3), 
                        "; pAdjSubject=", format(dFrame$adjustedPsubject[i], digits=3), sep="")
    text(0,0,graphMain, adj=.5, cex=2)
    
    ##rural vs. urban both timepoints combined
    par(mar=c(4,4,4,1))
    boxplot(df$abun~factor(df$ruralUrban), ylab="log relative abundance", main="rual vs. urban both timepoints")
    points(df$abun~jitter(as.numeric(factor(df$ruralUrban))), 
           col=ifelse(df$ruralUrban=="rural", "blue", "red"),
           pch=ifelse(df$time=="timepoint 1", 16, 17))
    
    ##rural vs. urban separated timepoints
    t1 = df[df$time=="timepoint 1",]
    t2 = df[df$time=="timepoint 2",]
    boxplot(t1$abun~factor(t1$ruralUrban), ylab="log relative abundance", main="rual vs. urban time 1")
    points(t1$abun~jitter(as.numeric(factor(t1$ruralUrban))), 
           col=ifelse(t1$ruralUrban=="rural", "blue", "red"),
           pch=ifelse(t1$time=="timepoint 1", 16, 17))
    boxplot(t2$abun~factor(t2$ruralUrban), ylab="log relative abundance", main="rual vs. urban time 2")
    points(t2$abun~jitter(as.numeric(factor(t2$ruralUrban))), 
           col=ifelse(t2$ruralUrban=="rural", "blue", "red"),
           pch=ifelse(t2$time=="timepoint 1", 16, 17))
    
    ##time
    boxplot(df$abun~factor(df$time), ylab="log relative abundance", main="time 1 vs. time 2")
    points(df$abun~jitter(as.numeric(factor(df$time))), 
           col=ifelse(df$ruralUrban=="rural", "blue", "red"),
           pch=ifelse(df$time=="timepoint 1", 16, 17))
    
    ##subject id
    boxplot(df$abun~factor(df$id), ylab="log relative abundance", main="subject ID", las=2)
    points(df$abun~factor(df$id), 
           col=ifelse(df$ruralUrban=="rural", "blue", "red"),
           pch=ifelse(df$time=="timepoint 1", 16, 17))
    
  }
  dev.off()
}