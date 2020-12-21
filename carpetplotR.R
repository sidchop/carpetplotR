#!/usr/bin/env Rscript

# Sidhant Chopra
# 8/12/220
# carpetplotR make carpet plots from fmri (.nii) data

# usage: ./exampleRScript1.r -a thisisa -b hiagain
#        ./exampleRScript1.r --avar thisisa --bvar hiagain


invisible(setwd(system("pwd", intern = T)))
r = getOption("repos")
r["CRAN"] = "http://cran.us.r-project.org"
options(repos = r)
list.of.packages <- c("optparse", "RColorBrewer", "matrixStats",
                      "shape", "RNifti")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) {message(paste0("Installing ", new.packages))
   install.packages(new.packages)}
invisible(sapply(list.of.packages, library, character.only = TRUE))


option_list = list(
   make_option(c("-f", "--file"), type="character", default=NULL, 
               help='[Required] fMRI file in .nii or .nii.gz format.\n Mininal useage:\n
               Rscript carpetplotR.R -f fmri_file.nii.gz'),
   make_option(c("-m", "--mask"), type="character", default="NULL", 
               help="[Optional] Tissue mask file in .nii or .nii.gz format which matches the dimentions of the fMRI file,
               where the voxels are labelled:  1=gm, 2=wm. 3=csf. If you have run fmriprep
               you can use the '${subj}_bold_space-${template}_dseg.nii.gz' file. If you provide a mask file,
               the voxels will first be sorted acording to tissue type."),
   make_option(c("-o", "--output_filename"), type="character", default="carperplot", 
               help='Output file path and name [default= %default].\n E.g. 
               Rscript carpetplotR.R -f fmri_file.nii.gz -o "path/to/output/"'),
   make_option(c("-r", "--ordering"), type="character", default="random, gs", 
               help='Voxel ordering: random, gs (global signal) or both.\n E.g. -r "random, gs" [Default]', metavar="character"),
   make_option(c("-g", "--gs"), type="character", default=NULL, 
               help="a .txt file with the global signal (gs), if not provided, gs will be extracted from provided fmri"),
   make_option(c("-i", "--image"), type="character", default="jpeg", 
               help='image device to use: "jpeg" [Default], png or tiff'),
  # make_option(c("-r", "--resample"), type="integer", default=1, 
  #               help="[optional] Resample mask to a voxel size (r by r by r) which matches the fmri dataset", metavar="integer"),
   make_option(c("-l", "--limits"), type="double", default=1.2, 
               help="[Optional] a sets a +upper and -lower z-score limit on the color bar. Default = 1.2. Stops outliers dominating colour scale"),
   make_option(c("-t", "--title"), type="character", default="", 
               help="[Optional] A title that will appear at the top of the plot. "),
   make_option(c("-d", "--downsamplefactor"), type="integer", default=1, 
               help="[optional] downsample the image by a factor; WARNING: Currently this a very sime method of seleting the n'th timepoint. I would not use a downsamplefactor > 2 ")
   
); 



opt_parser = OptionParser(option_list=option_list);
opt = parse_args(opt_parser,);

if (is.null(opt$file)){
   print_help(opt_parser)
   stop("Atleast one argument must be supplied (.nii or .nii.gz fmri input file)", call.=FALSE)
}

lim <- c(-opt$limits, opt$limits)
mask <- opt$mask != "NULL"
message("Running carpetplotR... ")

random_ordering <- gs_ordering <- FALSE
if(!is.na(grep("random",opt$ordering) || grep("gs",opt$ordering) == 1)) {
   if(isTRUE(grep("random",opt$ordering)==1)){message("Random ordering selected.")
      random_ordering <- TRUE}
   if(isTRUE(grep("gs",opt$ordering)==1)){message("Global signal ordering selected.")
      gs_ordering <- TRUE}
} else {
   stop('Please select a valid voxel ordering method: e.g. -o "random", or -o "gs", or -o "random, gs" [Default]')
}


make_cp <- function(Matrix, lim=lim, lengthdim=NULL, title = "") {
   rf <- colorRampPalette(c("black", "white"))
   r <- rf(10)
   image(x = 1:nrow(Matrix), 
         y = 1:ncol(Matrix),
         zlim = lim,
         Matrix, useRaster=TRUE, 
         col = r,
         xlab = "Time", ylab = "Voxel",
         yaxt='n',
         main = opt$title,
         cex.main = 2,
         cex.lab = 1.5,
         cex.axis = 1.25)
   if(mask == TRUE) {
      rect(xleft = 0 , xright = 1, ytop =lengthdim[1], 
           ybottom = 1, col = "green",lwd = 0)
      
      rect(xleft = 0, xright = 1, ytop = (lengthdim[1]+lengthdim[2]), 
           ybottom = lengthdim[1]+1, col = "blue",lwd = 0)
      
      rect(xleft = 0, xright = 1, ytop =(lengthdim[1]+lengthdim[2]+lengthdim[3]), 
           ybottom =  (lengthdim[1]+lengthdim[2]+1), col = "red",lwd = 0)
   }
   #  lines((GMR+sum(lengthdim)+100)*3, 1:length(GMR),col = "blue",  lwd = 100)
   
}

timeseries2matrix <- function(img, mask) { #borrowed from ANTsR - all credit to https://github.com/ANTsX/ANTsR
   m = as.array(mask)
   
   labs <- sort(unique(m[m > 0.001]))
   
   if (!all( labs == round(labs) ))
      stop("Mask image must be binary or integer labels")
   
   if (length(labs) == 1) {
      logmask <- (m == 1)  
   } else {
      logmask <- (m > 0)
   }
   i = as.array(img)
   # mat = apply(i, 4, function(x) x[logmask])
   
   mat <- img[logmask]
   dim(mat) <- c(sum(logmask), dim(img)[length(dim(img))])
   mat <- t(mat)
   if (length(labs) == 1) 
      return(mat)
   maskvec <- m[logmask]
   mmat <- matrix(
      rowMeans(mat[, maskvec == labs[1], drop = FALSE]), 
      ncol = 1)
   for (i in 2:length(labs)) {
      newmat <- matrix(
         rowMeans(mat[, maskvec == labs[i], drop = FALSE]),
         ncol = 1)
      mmat <- cbind(mmat, newmat)
   }
   colnames(mmat) <- paste("L", labs)
   return(mmat)
}
ds_factor=opt$downsamplefactor

img <- RNifti::readNifti(opt$file, internal=F)
if(mask == TRUE) {
   Mask <- RNifti::readNifti(opt$mask, internal=F)
   #do voxel size and dimentions of the atlas and mask match?
   if(all(dim(img)[1:3] == dim(Mask)[1:3])) {message("Image and mask dimentions match.")} else {
      stop(paste0("Image and mask dimentions (3D) do not match.  Mask dim = ",dim(Mask), 
                  "Image dim = ", dim(img)))
   }
   
}


# optional resampling for mask and fmri data [Not needed for now]
#if(!is.null(opt$resample)) {mask <- ANTsRCore::resampleImage(mask, c(opt$resample,opt$resample,opt$resample), useVoxels = F, interpType = 1)
#print("resampling tissue mask.....")}

#mask 1=gm, 2=wm. 3=csf
if(mask == TRUE) {lengthdim <- NULL
Matrix = timeseries2matrix(img = img, mask = Mask == 1)
lengthdim[1] <- dim(Matrix)[2]

for (m in 2:3){
   matrix = timeseries2matrix(img = img, mask = Mask == m)
   lengthdim[m] <-  dim(matrix)[2]
   Matrix <- cbind(Matrix,matrix)
}
}

#Make mean mask
if(mask == FALSE) {
   message("No tissue mask provided, using whole brain mean mask.")
   mean_mask <- rowMeans(img, dims = 3)
   message("Converting nifti to matrix.")
   Matrix = timeseries2matrix(img = img, mask = mean_mask > 0)
   message(paste0("Matrix dimentions: ", dim(Matrix)[1], " by ", dim(Matrix)[2]))
}

if(random_ordering==TRUE) {
   #Downsample - currently only taking the nth data point, should be rolling mean i think
   Matrix_ds <- Matrix[seq(from=1,to=dim(Matrix)[1],by=ds_factor), ]
   message("Making carpetplot with random ordering.")
   
   
   if(opt$image == 'jpeg'){grDevices::jpeg(paste0(opt$output_filename,"_random_ordering.jpeg"))}
   if(opt$image == 'png'){grDevices::png(paste0(opt$output_filename,"_random_ordering.png"))}
   if(opt$image == 'tiff'){grDevices::tiff(paste0(opt$output_filename,"_random_ordering.tiff"))}
   
   
   make_cp(scale(Matrix_ds), lengthdim = lengthdim, lim = lim, title = opt$title)
   
   invisible(dev.off())
}

if(gs_ordering==TRUE) {
   #extract global signal at this point 
   if(!is.null(opt$gs)) {
      message("Global signal provided by user.")
      GS <- scan(opt$gs)
   }
   
   if(is.null(opt$gs)) {
      message("Extracting global signal from provised fMRI dataset.")
      GS <- rowMeans(Matrix)
   }
   
   GS <- scale(GS)
   if(mask == TRUE) {
      message("Sorting voxels by global signal.")
      gmrcor_1 <- order(rank(-cor(GS, scale(Matrix[,c(1:lengthdim[1])]))))
      gmrcor_2 <- order(rank(-cor(GS, scale(Matrix[,c((lengthdim[1]+1):(lengthdim[1]+lengthdim[2]))]))))
      gmrcor_3 <- order(rank(-cor(GS, scale(Matrix[,c((lengthdim[1]+lengthdim[2]+1):(lengthdim[1] + 
                                                                                        lengthdim[2] + 
                                                                                        lengthdim[3]))]))))
      gmrcor_2 <- gmrcor_2 + as.numeric(length(gmrcor_1))
      gmrcor_3 <- gmrcor_3 + as.numeric(length(gmrcor_1) + length(gmrcor_2))
      
      rank <- c(gmrcor_1, gmrcor_2, gmrcor_3)   
   }
   
   
   if(mask == FALSE) {
      message("Sorting voxels by Global signal.")
      rank <- order(rank(-cor(GS, scale(Matrix))))
   }
   
   Matrix <- Matrix[,c(rank)]
   Matrix_ds <- Matrix[seq(from=1,to=dim(Matrix)[1],by=ds_factor), ]
   #scale (zscore)
   message("Making carpetplot with GS ordering.")
   if(opt$image == 'jpeg'){grDevices::jpeg(paste0(opt$output_filename,"_gs_ordering.jpeg"))}
   if(opt$image == 'png'){grDevices::png(paste0(opt$output_filename,"_gs_ordering.png"))}
   if(opt$image == 'tiff'){grDevices::tiff(paste0(opt$output_filename,"_gs_ordering.tiff"))}
   
   
   make_cp(Matrix = scale(Matrix_ds), lengthdim = lengthdim, lim = lim)
   invisible(dev.off())
   
}


