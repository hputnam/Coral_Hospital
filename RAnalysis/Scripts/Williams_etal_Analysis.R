#last modified 20200530
#Use of this code must be accompanied by a citation to Williams et al 

rm(list=ls()) #clears workspace 

#Install and Load necessary libraries
if("lubridate" %in% rownames(installed.packages()) == 'FALSE') install.packages('lubridate') 
if("tidyverse" %in% rownames(installed.packages()) == 'FALSE') install.packages('tidyverse') 
if("seacarb" %in% rownames(installed.packages()) == 'FALSE') install.packages('seacarb') 
if("vegan" %in% rownames(installed.packages()) == 'FALSE') install.packages('vegan') 
if("emmeans" %in% rownames(installed.packages()) == 'FALSE') install.packages('emmeans') 
if("gridExtra" %in% rownames(installed.packages()) == 'FALSE') install.packages('gridExtra') 

library(lubridate)
library(tidyverse)
library(seacarb) 
library(vegan)
library(emmeans)
library(gridExtra)

##### DISCRETE pH CALCULATIONS 
path <-("RAnalysis/Data/pH_Calibration_Files") #set path to calibration files
file.names<-list.files(path = path, pattern = "csv$") #list all the file names in the folder to get only get the csv files
pH.cals <- data.frame(matrix(NA, nrow=length(file.names), ncol=3, dimnames=list(file.names,c("Date", "Intercept", "Slope")))) #generate a 3 column dataframe with specific column names

for(i in 1:length(file.names)) { # for every file in list start at the first and run this following function
  Calib.Data <-read.table(file.path(path,file.names[i]), header=TRUE, sep=",", na.string="NA", as.is=TRUE) #reads in the data files
  file.names[i]
  model <-lm(mVTris ~ TTris, data=Calib.Data) #runs a linear regression of mV as a function of temperature
  coe <- coef(model) #extracts the coeffecients
  summary(model)$r.squared #extracts the r squared
  plot(Calib.Data$mVTris, Calib.Data$TTris) #plots the regression data
  pH.cals[i,2:3] <- coe #inserts coefficients in the dataframe
  pH.cals[i,1] <- substr(file.names[i],1,8) #stores the file name in the Date column
}
colnames(pH.cals) <- c("Calib.Date",  "Intercept",  "Slope") #rename columns
pH.cals #view data

#constants for use in pH calculation 
R <- 8.31447215 #gas constant in J mol-1 K-1 
F <-96485.339924 #Faraday constant in coulombs mol-1

#read in probe measurements of pH, temperature from tanks
daily <- read.csv("RAnalysis/Data/Daily_Temp_pH_Sal.csv", header=TRUE, sep=",", na.strings="NA") #load data with a header, separated by commas, with NA as NA

#merge with Seawater chemistry file
SW.chem <- merge(pH.cals, daily, by="Calib.Date")

#Calculate total pH
mvTris <- SW.chem$Temperature*SW.chem$Slope+SW.chem$Intercept #calculate the mV of the tris standard using the temperature mv relationships in the measured standard curves 
STris<-35 #salinity of the Tris
phTris<- (11911.08-18.2499*STris-0.039336*STris^2)*(1/(SW.chem$Temperature+273.15))-366.27059+ 0.53993607*STris+0.00016329*STris^2+(64.52243-0.084041*STris)*log(SW.chem$Temperature+273.15)-0.11149858*(SW.chem$Temperature+273.15) #calculate the pH of the tris (Dickson A. G., Sabine C. L. and Christian J. R., SOP 6a)
SW.chem$pH.Total<-phTris+(mvTris/1000-SW.chem$pH.MV/1000)/(R*(SW.chem$Temperature+273.15)*log(10)/F) #calculate the pH on the total scale (Dickson A. G., Sabine C. L. and Christian J. R., SOP 6a)

#### Test for differences in parameters by treatment
### Temperature
boxplot(SW.chem$Temperature ~SW.chem$Treatment) #view raw data

#calculate mean by treatment
mean.temp.trt <- SW.chem %>%
  group_by(Treatment) %>%
  summarise(mean = mean(Temperature, na.rm = T), 
            d = sd(Temperature, na.rm = T))
mean.temp.trt

#t.test between treatment levels
temp.mod <- t.test(Temperature ~ Treatment, data=SW.chem) #t.test
temp.mod

### pH
boxplot(SW.chem$pH.Total ~SW.chem$Treatment) #view raw data

#calculate mean by treatment
mean.pH.trt <- SW.chem %>%
  group_by(Treatment) %>%
  summarise(mean = mean(pH.Total, na.rm = T), 
            sd = sd(pH.Total, na.rm = T))
mean.pH.trt

#t.test between treatment levels
pH.mod <- t.test(pH.Total ~ Treatment, data=SW.chem) #t.test
pH.mod

### Light
LightData<-read.csv('RAnalysis/Data/Light_Data.csv', header=T, sep=",") # load data 
boxplot(PPFD ~ Treatment, data=LightData) #plot raw data
range(LightData$PPFD)

#calculate mean by treatment
mean.light.trt <- LightData %>%
  group_by(Treatment) %>%
  summarise(mean = mean(PPFD), 
            sd = sd(PPFD))
mean.light.trt

#t.test between treatment levels
light.mod <- t.test(PPFD ~ Treatment, data=LightData) #t.test
light.mod

### Flow
FlowData<-read.csv('RAnalysis/Data/Flow_rate.csv', header=T, sep=",") # load data 
FlowData$Flow.rate.ml.min <- (FlowData$Volume.ml/FlowData$Time.sec)*60 #calculate rate ml per sec
FlowData$Flow.rate.L.hr <- (FlowData$Flow.rate.ml.min/1000)*60 #calculate rate L per hr
boxplot(Flow.rate.L.hr ~ Treatment, data=FlowData) #plot raw data
range(FlowData$Flow.rate.L.hr)

#calculate mean by treatment
mean.flow.trt <- FlowData %>%
  group_by(Treatment) %>%
  summarise(mean = mean(Flow.rate.L.hr), 
            sd = sd(Flow.rate.L.hr))
mean.flow.trt 

#calculate overall mean 
mean.flow <- FlowData %>%
  summarise(mean = mean(Flow.rate.L.hr), 
            sd = sd(Flow.rate.L.hr))
mean.flow 

#t.test between treatment levels
flow.mod <- t.test(Flow.rate.L.hr ~ Treatment, data=FlowData) #t.test
flow.mod

##### CONTINUOUS TEMPERATURE DATA FROM HOBO LOGGERS #####
#Acclimation period data
#2019-05-09 00:00:00 to 2019-05-13 16:45:00

##### Acclimation Temperature
# ##### QC Acclimation Hobo Files #####
# Tankempty.Acc <- rep("NA", 351)
# Tank3.Acc <- read.csv("RAnalysis/Data/Hobo_Loggers/20190510/20190510_Tank_3.csv", sep=",", skip=c(2), header=FALSE, na.strings = "NA")[ ,2:3]
# Tank3.Acc <- na.omit(Tank3.Acc)
# Tank4.Acc <- read.csv("RAnalysis/Data/Hobo_Loggers/20190510/20190510_Tank_4.csv", sep=",", skip=c(2), header=FALSE, na.strings = "NA")[ ,2:3]
# Tank4.Acc <- na.omit(Tank4.Acc)
# Tank5.Acc <- read.csv("RAnalysis/Data/Hobo_Loggers/20190510/20190510_Tank_5.csv", sep=",", skip=c(2), header=FALSE, na.strings = "NA")[ ,2:3]
# Tank5.Acc <- na.omit(Tank5.Acc)
# data.acc <- data.frame(Tank3.Acc$V2, as.numeric(Tankempty.Acc), as.numeric(Tankempty.Acc), Tank3.Acc$V3, Tank4.Acc$V3, Tank5.Acc$V3, as.numeric(Tankempty.Acc))
# colnames(data.acc) <- c("Date.Time", "Tank1", "Tank2","Tank3", "Tank4","Tank5", "Tank6")
# data.acc$Date.Time <- parse_date_time(data.acc$Date.Time, "%m/%d/%y %I:%M:%S %p" , tz="HST")
# 
# #2019-05-09 00:00:00
# data.acc <- data.acc[217:nrow(data.acc),]
# head(data.acc)
# tail(data.acc)
# # Read in temp data after hobo logger stop start
# Tank1.e <- read.csv("RAnalysis/Data/Hobo_Loggers/20190514/20190514_Tank_1.csv", sep=",", skip=c(2), header=FALSE, na.strings = "NA")[ ,2:3]
# Tank2.e <- read.csv("RAnalysis/Data/Hobo_Loggers/20190514/20190514_Tank_2.csv", sep=",", skip=c(2), header=FALSE, na.strings = "NA")[ ,2:3]
# Tank2.e <- Tank2.e[1:nrow(Tank1.e),]
# Tank3.e <- read.csv("RAnalysis/Data/Hobo_Loggers/20190514/20190514_Tank_3.csv", sep=",", skip=c(2), header=FALSE, na.strings = "NA")[ ,2:3]
# Tank3.e <- Tank3.e[1:nrow(Tank1.e),]
# Tank4.e <- read.csv("RAnalysis/Data/Hobo_Loggers/20190514/20190514_Tank_4.csv", sep=",", skip=c(2), header=FALSE, na.strings = "NA")[ ,2:3]
# Tank4.e <- Tank4.e[1:nrow(Tank1.e),]
# Tank5.e <- read.csv("RAnalysis/Data/Hobo_Loggers/20190514/20190514_Tank_5.csv", sep=",", skip=c(2), header=FALSE, na.strings = "NA")[ ,2:3]
# Tank5.e <- Tank5.e[1:nrow(Tank1.e),]
# Tank6.e <- read.csv("RAnalysis/Data/Hobo_Loggers/20190514/20190514_Tank_6.csv", sep=",", skip=c(2), header=FALSE, na.strings = "NA")[ ,2:3]
# Tank6.e <- Tank6.e[1:nrow(Tank1.e),]
# 
# data.e <- cbind(Tank1.e, Tank2.e$V3, Tank3.e$V3, Tank4.e$V3, Tank5.e$V3, Tank6.e$V3)
# colnames(data.e) <- c("Date.Time", "Tank1","Tank2", "Tank3", "Tank4", "Tank5", "Tank6")
# data.e$Date.Time <- parse_date_time(data.e$Date.Time, "%m/%d/%y %H:%M" , tz="HST")
# 
# # identify end of acclimation data 2019-05-13 16:45:00
# data.e.acc <- data.e[1:313,]
# tail(data.e.acc)
# #combine logger files for full acclimation data
# data.acc <- rbind(data.acc,data.e.acc) 
# head(data.acc)
# tail(data.acc)
# #Save acclimation data to file
# write.csv(data.acc,file="RAnalysis/Data/Acclimation.Temperature_data.csv")

##### Read In QCd Acclimation Temperature Data #####
# Read in Acclimation Temperature data
temp.acc.data <- read.csv("RAnalysis/Data/Acclimation.Temperature_data.csv", sep=",", header=TRUE, na.strings = "NA")
temp.acc.data <- temp.acc.data[,-1] #remove row numbers
temp.acc.data$Date.Time <- parse_date_time(temp.acc.data$Date.Time, "YmdHMS" , tz="HST") #convert to POSIXct date-time object
head(temp.acc.data)
tail(temp.acc.data)

#set legend info
tmp.col <- c("lightblue", "pink", "coral","blue","red", "darkblue")
tnks <- c("Tank 1", "Tank 2","Tank 3", "Tank 4","Tank 5", "Tank 6")

#Plot acclimation temperatures
par(mar=c(6,6,2,2)) #sets the bottom, left, top and right
plot(temp.acc.data$Date.Time, temp.acc.data$Tank1, cex=0.2, col="lightblue", ylim=c(25,32), ylab="Temperature °C", xlab="Date and Time", las=2)
points(temp.acc.data$Date.Time, temp.acc.data$Tank2, cex=0.2, col="pink")
points(temp.acc.data$Date.Time, temp.acc.data$Tank3, cex=0.2, col="coral")
points(temp.acc.data$Date.Time, temp.acc.data$Tank4, cex=0.2, col="blue")
points(temp.acc.data$Date.Time, temp.acc.data$Tank5, cex=0.2, col="red")
points(temp.acc.data$Date.Time, temp.acc.data$Tank6, cex=0.2, col="darkblue")
legend(temp.acc.data$Date.Time[10], 32, legend=tnks, col=tmp.col, cex=0.6, lty=1, box.lty=0)

#average acclimation temperature
acc.temp <- as.matrix(temp.acc.data[,2:7])
mean(acc.temp, na.rm = T)
sd(acc.temp, na.rm = T)

##### Experimental Temperature #####
#Experimental period data
#2019-05-13 17:00:00 to 2019-06-07 16:30:00
# ##### QC Experimental Hobo Files #####
# # Read in temp data after hobo logger stop start
# Tank1 <- read.csv("RAnalysis/Data/Hobo_Loggers/20190607/20190607_Tank_1.1.csv", sep=",", skip=c(2), header=FALSE, na.strings = "NA")[ ,2:3]
# Tank1 <- Tank1[1:2383,]
# Tank2 <- read.csv("RAnalysis/Data/Hobo_Loggers/20190607/20190607_Tank_2.1.csv", sep=",", skip=c(2), header=FALSE, na.strings = "NA")[ ,2:3]
# Tank2 <- Tank2[1:nrow(Tank1),]
# Tank3 <- read.csv("RAnalysis/Data/Hobo_Loggers/20190607/20190607_Tank_3.csv", sep=",", skip=c(2), header=FALSE, na.strings = "NA")[ ,2:3]
# Tank3 <- Tank3[1:nrow(Tank1),]
# Tank4 <- read.csv("RAnalysis/Data/Hobo_Loggers/20190607/20190607_Tank_4.1.csv", sep=",", skip=c(2), header=FALSE, na.strings = "NA")[ ,2:3]
# Tank4 <- Tank4[1:nrow(Tank1),]
# Tank5 <- read.csv("RAnalysis/Data/Hobo_Loggers/20190607/20190607_Tank_5.1.csv", sep=",", skip=c(2), header=FALSE, na.strings = "NA")[ ,2:3]
# Tank5 <- Tank5[1:nrow(Tank1),]
# Tank6 <- read.csv("RAnalysis/Data/Hobo_Loggers/20190607/20190607_Tank_6.1.csv", sep=",", skip=c(2), header=FALSE, na.strings = "NA")[ ,2:3]
# Tank6 <- Tank6[1:nrow(Tank1),]
# 
# data.exp <- cbind(Tank1, Tank2$V3, Tank3$V3, Tank4$V3, Tank5$V3, Tank6$V3)
# colnames(data.exp) <- c("Date.Time", "Tank1","Tank2", "Tank3", "Tank4", "Tank5", "Tank6")
# head(data.exp)
# data.exp$Date.Time <- parse_date_time(data.exp$Date.Time, "%m/%d/%y %I:%M:%S %p" , tz="HST")
# 
# #Find start of treatment
# data.e.trt <- data.e[314:396,] #start of exposure 2019-05-13 17:00:00 to start of data in hobo file set 2019-05-14 13:30:00
# head(data.e.trt)
# tail(data.e.trt)
# # data in hobo file set 20190607 starts at 2019-05-14 13:45:00
# head(data.exp)
# 
# # combine hobo files to full exposure dataset
# data.exp <- rbind(data.e.trt, data.exp)
# head(data.exp)
# tail(data.exp)
# 
# write.csv(data.exp,file="RAnalysis/Data/Experimental.Temperature_data.csv")

##### Read In QCd Experimental Temperature Data #####
# Read in Experimental Temperature data
temp.exp.data <- read.csv("RAnalysis/Data/Experimental.Temperature_data.csv", sep=",", header=TRUE, na.strings = "NA")
temp.exp.data <- temp.exp.data[,-1] #remove row numbers
temp.exp.data$Date.Time <- parse_date_time(temp.exp.data$Date.Time, "YmdHMS" , tz="HST") #convert to POSIXct date-time object
head(temp.exp.data)
tail(temp.exp.data)

#set legend info
tmp.col <- c("lightblue", "pink", "coral","blue","red", "darkblue")
tnks <- c("Tank 1", "Tank 2","Tank 3", "Tank 4","Tank 5", "Tank 6")

#plot experimental period
par(mar=c(6,6,2,2)) #sets the bottom, left, top and right
plot(temp.exp.data$Date.Time, temp.exp.data$Tank1, cex=0.2, col="lightblue", ylim=c(25,32), ylab="Temperature °C", xlab="Date and Time", las=2)
points(temp.exp.data$Date.Time, temp.exp.data$Tank2, cex=0.2, col="pink")
points(temp.exp.data$Date.Time, temp.exp.data$Tank3, cex=0.2, col="coral")
points(temp.exp.data$Date.Time, temp.exp.data$Tank4, cex=0.2, col="blue")
points(temp.exp.data$Date.Time, temp.exp.data$Tank5, cex=0.2, col="red")
points(temp.exp.data$Date.Time, temp.exp.data$Tank6, cex=0.2, col="darkblue")
legend(temp.exp.data$Date.Time[5], 32, legend=tnks, col=tmp.col, cex=0.6, lty=1, box.lty=0)

#max temp hold
#2019-05-22 16:00:00 to 2019-06-07 16:30:00 
max.data <-  temp.exp.data[885:nrow(temp.exp.data),]
head(max.data)
tail(max.data)

#High Treatment average max temperature hold
Heat.max.temp.hold <- as.matrix(max.data[,c(3,4,6)])
mean(Heat.max.temp.hold, na.rm = TRUE)
sd(Heat.max.temp.hold, na.rm = TRUE)

#Ambient Treatment average max temperature hold
Amb.max.temp.hold <- as.matrix(max.data[,c(2,5,7)])
mean(Amb.max.temp.hold, na.rm = TRUE)
sd(Amb.max.temp.hold, na.rm = TRUE)

#average difference between treatments at max temperature hold
mean(Heat.max.temp.hold, na.rm = TRUE) - mean(Amb.max.temp.hold, na.rm = TRUE)

#combine all temp data
all.data <- rbind(temp.acc.data, temp.exp.data)

par(mar=c(6,6,2,2)) #sets the bottom, left, top and right
plot(all.data$Date.Time, all.data$Tank1, cex=0.2, col="lightblue", ylim=c(24,32), ylab="Temperature °C", xlab="Date and Time", las=2)
points(all.data$Date.Time, all.data$Tank2, cex=0.2, col="pink")
points(all.data$Date.Time, all.data$Tank3, cex=0.2, col="coral")
points(all.data$Date.Time, all.data$Tank4, cex=0.2, col="blue")
points(all.data$Date.Time, all.data$Tank5, cex=0.2, col="red")
points(all.data$Date.Time, all.data$Tank6, cex=0.2, col="darkblue")
legend(all.data$Date.Time[5], 32, legend=tnks, col=tmp.col, cex=0.6, lty=1, box.lty=0)


Fig.Temp <- ggplot(all.data, aes(x=Date.Time)) + 
  geom_point(aes(x=Date.Time, y=Tank1), colour="lightblue", cex=0.5) +
  geom_point(aes(x=Date.Time, y=Tank2), colour="pink", cex=0.5) + 
  geom_point(aes(x=Date.Time, y=Tank3), colour="coral", cex=0.5) + 
  geom_point(aes(x=Date.Time, y=Tank4), colour="blue", cex=0.5) + 
  geom_point(aes(x=Date.Time, y=Tank5), colour="red", cex=0.5) + 
  geom_point(aes(x=Date.Time, y=Tank6), colour="darkblue", cex=0.5) + 
  geom_vline(color="grey", xintercept = as.numeric(all.data$Date.Time[1335])) +
  geom_vline(color="grey", xintercept = as.numeric(all.data$Date.Time[2518])) +
  geom_vline(color="grey", xintercept = as.numeric(all.data$Date.Time[2900])) +
  annotate("text", x=as.POSIXct(as.Date("2019-05-22")), y=25.7, label = "T1", size = 5) +
  annotate("text", x=as.POSIXct(as.Date("2019-06-03")), y=25.7,  label = "T3", size = 5) +
  annotate("text", x=as.POSIXct(as.Date("2019-06-07")), y=25.7,  label = "T5", size = 5) +
  annotate("text", x=as.POSIXct(as.Date("2019-05-10")), y=32, label = "B", size = 7) +
  xlab("Date") +
  ylab(expression(paste("Temperature °C"))) +
  theme_bw() + #Set the background color
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=2), #Set the text angle
        axis.line = element_line(color = 'black'), #Set the axes color
        panel.border = element_blank(), #Set the border
        panel.grid.major = element_blank(), #Set the major gridlines
        panel.grid.minor = element_blank(), #Set the minor gridlines
        plot.background=element_blank(),  #Set the plot background
        legend.position= "right") + #remove legend background
  theme(plot.title = element_text(face = 'bold', 
                                  size = 10, 
                                  hjust = 0))
Fig.Temp

##### ANALYSIS OF PHOTOGRAPHIC COLOR SCORE #####

Color.Data <- read.csv("RAnalysis/Data/Coral_Color_Data.csv", header=T, sep=",", na.string="NA") #read in data file
Color.Data <-na.omit(Color.Data)
Color.Data <- Color.Data[Color.Data$Timepoint != "Time6", ]
Color.Data$Red.Norm.Coral <- Color.Data$Red.Coral/Color.Data$Red.Standard #normalize to color standard
Color.Data$Green.Norm.Coral <- Color.Data$Green.Coral/Color.Data$Green.Standard #normalize to color standard
Color.Data$Blue.Norm.Coral <- Color.Data$Blue.Coral/Color.Data$Blue.Standard #normalize to color standard

par(mfrow=c(1,3))
plot(Color.Data$Red.Coral ~ Color.Data$Tank)
plot(Color.Data$Green.Coral ~ Color.Data$Tank)
plot(Color.Data$Blue.Coral ~ Color.Data$Tank)

par(mfrow=c(1,3))
plot(Color.Data$Red.Norm.Coral ~ Color.Data$Tank)
plot(Color.Data$Green.Norm.Coral ~ Color.Data$Tank)
plot(Color.Data$Blue.Norm.Coral ~ Color.Data$Tank)

blch.scor <- as.matrix(cbind(Color.Data$Red.Norm.Coral,Color.Data$Green.Norm.Coral,Color.Data$Blue.Norm.Coral)) #create matrix
rownames(blch.scor) <- Color.Data$PLUG.ID #name columns in dataframe

dist <- vegdist(blch.scor, method="euclidean") #calculate distance matrix of color scores

PCA.color <- princomp(dist) #run principal components Analysis
summary(PCA.color) # view variance explained by PCs
Blch <- as.data.frame(PCA.color$scores[,1]) #extract PC1
Blch$PLUG.ID <- rownames(blch.scor) #provide sample names
Blch  <- cbind(Blch, Color.Data$Date, Color.Data$Treatment, Color.Data$Species) #make a dataframe of PC1 and experiment factors
colnames(Blch) <- c("Bleaching.Score", "PLUG.ID", "Timepoint", "Treatment", "Species")
Blch$Group <- paste(Blch$Timepoint, Blch$Treatment, Blch$Species)
Blch$SpGroup <- paste(Blch$Treatment, Blch$Species)
Blch$Bleaching.Score <- -Blch$Bleaching.Score

x<- Blch #assign values to test data frame to look for outliers
dev.off()
par(mar=c(10,4,2,2)) #bottom, left, top and right margins respectively
boxplot(Bleaching.Score ~ Group, data = x, lwd = 1, ylab = 'PC1Color', las=2, cex=0.8) #plot boxplot of PC1 color score by Genotype and timepoint

mod1 <- aov(sqrt(Bleaching.Score+200) ~ Timepoint*Treatment*Species, data=Blch) #run an ANOVA by Genotype
par(mfrow=c(1,3))
hist(residuals(mod1)) #look at normality of data
boxplot(residuals(mod1)) #look at normality of data
plot(mod1$fitted.values, mod1$residuals)
summary(mod1)
marginal <- lsmeans(mod1, ~ Timepoint*Treatment*Species)

ph.diffs <- multcomp::cld(marginal,
          alpha=0.05,
          Letters=letters,
          adjust="tukey")

ph.diffs <- ph.diffs[order( ph.diffs$Treatment, ph.diffs$Species),]
ph.diffs

All.Means <- Blch %>%
  group_by(Timepoint,SpGroup, Treatment,Species) %>%
  summarise(mean = mean(Bleaching.Score),
            se = std.error(Bleaching.Score))
All.Means <- as.data.frame(All.Means)
Empty.Means <-  read.csv("RAnalysis/Data/empty_plot_info.csv", header=T, sep=",", na.string="NA") #read in data file
All.Means <- rbind(Empty.Means, All.Means)

cols <- c("blue", "red")

Fig.All <- ggplot(All.Means, aes(x=Timepoint, y=mean, group=SpGroup)) + 
  geom_line(aes(linetype= Species, colour=Treatment, group=SpGroup), position = position_dodge(width = 0.1), alpha=0.5) + # colour, group both depend on cond2
  geom_errorbar(aes(ymin=mean-se, ymax=mean+se), colour="black", width=0, size=0.5, position = position_dodge(width = 0.1)) +
  geom_point(aes(colour=Treatment, shape=Species), size = 2, position = position_dodge(width = 0.1)) +
  scale_colour_manual(values=cols) +
  geom_vline(xintercept = c(4.2,7.2,8.2), lty=1, color = "grey") +
  annotate("text",fontface = 'italic', x=2.3, y=-1, label = "Pocillopora acuta", size = 3) +
  annotate("text", fontface = 'italic', x=2.3, y=6.5, label = "Montipora capitata", size = 3) +
  annotate("text", x=1, y=20, label = "A", size = 7) +
  xlab("Date") +
  ylab(expression(paste("Color Score"))) +
  theme_bw() + #Set the background color
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1), #Set the text angle
        axis.line = element_line(color = 'black'), #Set the axes color
        panel.border = element_blank(), #Set the border
        panel.grid.major = element_blank(), #Set the major gridlines
        panel.grid.minor = element_blank(), #Set the minor gridlines
        plot.background=element_blank(),  #Set the plot background
        legend.position= "null") #remove legend background

Fig.All

Bch.Figs <- arrangeGrob(Fig.All, Fig.Temp, ncol=1)
ggsave(file="RAnalysis/Output/Figure.S1.pdf", Bch.Figs, width = 4, height = 6, units = c("in"))




