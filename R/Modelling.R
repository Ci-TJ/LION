#' Format RNA/Protein Sequences According to the Index
#' @description This function generates a list of sequences according to the specified indices.
#' The sequence list can be used as input for feature extraction or prediction.
#'
#' @param idx specifying the sequence indices.
#' @param seqs sequences loaded by function \code{\link[seqinr]{read.fasta}} from \code{\link[seqinr]{seqinr-package}}. Or a list of sequences.
#'
#' @return This function returns a list.
#'
#' @details This function is useful for formatting the sequences using the specified indices (or names) and a sequence list.
#' For example, the names of RNA-protein interaction pairs have been provided, but the sequences
#' are randomly listed in one file. This function can generate a list containing the sequences whose names are listed
#' in \code{idx} object.
#' See examples below.
#'
#' @examples
#' data(demoIDX)
#' data(demoPositiveSeq)
#'
#' new_RNA <- formatSeq(demoIDX$RNA_index, demoPositiveSeq$RNA.positive)
#' new_Pro <- formatSeq(demoIDX$Pro_index, demoPositiveSeq$Pro.positive)
#'
#' names(demoPositiveSeq$Pro.positive)
#' names(demoPositiveSeq$RNA.positive)
#'
#' names(new_RNA)
#' names(new_Pro)
#'
#' # new_RNA and new_Pro can be further used to extract features.
#'
#'
#' @export

formatSeq <- function(idx, seqs) {
        # tmp <- c()
        # for (x in idx) {
        #         seqTmp <- seqs[names(seqs) == x]
        #         seqTmp <- seqTmp[1]
        #         tmp <- c(tmp, seqTmp)
        # }
        # tmp
        unlist(lapply(idx, function(x) seqs[names(seqs) == x][1]), recursive = F)
}

#' Normalize Data
#' @description This function is used to normalize dataset.
#' @param dataset input dataset. As a data frame.
#' @param direction \code{"row"} or {"column"} to indicate the normalization direction (see details).
#' @param returnNorm logical. Used for \code{direction = "column"}. The function will return normalized
#' data that can be used to process new dataset (test sets, for example).
#' Ignored when \code{direction = "row"}.
#' @param ignoreColumn numeric or \code{NULL}. Input the column number of the dataset
#' to indicate which column(s) will not be normalized. Default: \code{NULL}.
#'
#' @return If \code{direction = "column"} and \code{returnNorm = TRUE},
#' the function returns a list containing normalized dataset and normalization data.
#' Otherwise, only return the processed dataset.
#'
#'
#' @details The function provides two normalization strategies: by row or by column.
#' If by row, the dataset will be processed with equation (see reference):
#' d_\emph{i} = (f_\emph{i} - min\{f_1, f_2, ...\}) / max\{f_1, f_2, ...\}.
#' f_1, f_2, ..., f_\emph{i} are the original values of each row.
#'
#' If by column, the dataset will be processed with:
#' d_\emph{i} = (f_\emph{i} - min\{f_1, f_2, ...\}) / (max\{f_1, f_2, ...\} - min\{f_1, f_2, ...\}).
#'
#' @section References:
#' Shen J, Zhang J, Luo X, \emph{et al}.
#' Predicting protein-protein interactions based only on sequences information.
#' Proc. Natl. Acad. Sci. U. S. A. 2007; 104:4337-41
#'
#' @examples
#'
#' data(demoPositiveSeq)
#' seqRNA <- demoPositiveSeq$RNA.positive
#' seqPro <- demoPositiveSeq$Pro.positive
#'
#' dataset <- featureFreq(seqRNA = seqRNA, seqPro = seqPro, label = "Interact",
#'                        featureMode = "conc", computePro = "DeNovo", k.Pro = 3,
#'                        k.RNA = 2, normalize = "none", parallel.cores = 2)
#'
#' processed_1 <- normalizeData(dataset, direction = "row", ignoreColumn = 1)
#' processed_2 <- normalizeData(dataset[,-1], direction = "column",
#'                              returnNorm = TRUE, ignoreColumn = NULL)
#'
#' @export

normalizeData <- function(dataset, direction = c("row", "column"),
                          returnNorm = TRUE, ignoreColumn = NULL) {

        direction <- match.arg(direction)

        if (!is.null(ignoreColumn)) dataset_new <- dataset[,-ignoreColumn] else dataset_new <- dataset

        if (direction == "column") {
                normMin <- apply(dataset_new, 2, min)
                normMax <- apply(dataset_new, 2, max)

                freq.out <- apply(dataset_new, 1, function(x) {
                        out <- (x - normMin) / (normMax - normMin)
                })
                freq.out <- t(freq.out)
        } else {
                normMin <- apply(dataset_new, 1, min)
                normMax <- apply(dataset_new, 1, max)

                freq.out <- apply(dataset_new, 2, function(x) {
                        out <- (x - normMin) / normMax
                })
        }

        dataset_out <- as.data.frame(freq.out)
        dataset_out <- Internal.checkNa(dataset_out)
        if (!is.null(ignoreColumn)) dataset_out <- cbind(dataset_out, dataset[,ignoreColumn, drop = F])

        if (direction == "column" & returnNorm) {
                dataset_out <- list(feature = dataset_out,
                                    normData = list(direction = direction,
                                                    normMin = normMin, normMax = normMax))
        }
        dataset_out
}

#' Evaluation of Random Forest Classifier with K-Fold Cross Validation
#' @param datasets a list containing one or several input datasets. See examples.
#' @param label.col an integer. Column number of the label.
#' @param positive.class \code{NULL} or string. Which class is the positive class? Should be one
#' of the classes in label column. The first class in label column will be selected
#' as the positive class if leave \code{positive.class = NULL}.
#' @param folds.num an integer. Number of folds. Default \code{10} for 10-fold cross validation.
#' @param ntree parameter for random forest. Default: 1500. See \code{\link[randomForest]{randomForest}}.
#' @param seed random seed for data splitting. Integer.
#' @param parallel.cores an integer specifying the number of cores for parallel computation. Default: \code{2}.
#' Set \code{parallel.cores = -1} to run with all the cores. \code{parallel.cores} should be == -1 or >= 1.
#' @param ... other parameters passed to \code{\link[randomForest]{randomForest}} function.
#' @return This function return the performance of \emph{k}-fold CV.
#'
#' @importFrom caret createFolds
#' @importFrom caret confusionMatrix
#' @importFrom randomForest randomForest
#' @importFrom parallel makeCluster
#' @importFrom parallel clusterExport
#' @importFrom parallel parSapply
#' @importFrom parallel stopCluster
#' @importFrom parallel detectCores
#' @seealso \code{\link{randomForest_RFE}}, \code{\link{randomForest_tune}}, \code{\link[randomForest]{randomForest}}
#'
#'
#' @examples
#'
#' # Following codes only show how to use this function
#' # and cannot reflect the genuine performance of tools or classifiers.
#'
#' data(demoPositiveSeq)
#' data(demoNegativeSeq)
#'
#' dataPositive <- featureFreq(seqRNA = demoPositiveSeq$RNA.positive,
#'                             seqPro = demoPositiveSeq$Pro.positive,
#'                             label = "Interact", featureMode = "conc",
#'                             computePro = "DeNovo", k.Pro = 3, k.RNA = 2,
#'                             normalize = "none", parallel.cores = 2)
#'
#' dataNegative <- featureFreq(seqRNA = demoNegativeSeq$RNA.negative,
#'                             seqPro = demoNegativeSeq$Pro.negative,
#'                             label = "Non.Interact", featureMode = "conc",
#'                             computePro = "DeNovo", k.Pro = 3, k.RNA = 2,
#'                             normalize = "none", parallel.cores = 2)
#'
#' dataset <- rbind(dataPositive, dataNegative)
#'
#' Perf_CV <- randomForest_CV(datasets = list(dataset), label.col = 1, ntree = 100,
#'                            parallel.cores = 2, mtry = 20)
#'
#' # if you have more than one input dataset,
#' # use "datasets = list(dataset1, dataset2, dataset3)".
#'
#' @export

randomForest_CV <- function(datasets = list(), label.col = 1,
                            positive.class = NULL, folds.num = 10,
                            ntree = 1500, seed = 1, parallel.cores = 2, ...) {

        message("+ Initializing...  ", Sys.time())
        for (i in 1:length(datasets)) {
                names(datasets[[i]])[[label.col]] <- "label"
                datasets[[i]]$label <- as.factor(datasets[[i]]$label)
        }

        all_folds <- lapply(datasets, function(x) {
                set.seed(seed)
                folds <- caret::createFolds(x$label, k = folds.num, returnTrain = TRUE)
        })

        parallel.cores <- ifelse(parallel.cores == -1, parallel::detectCores(), parallel.cores)
        parallel.cores <- ifelse(parallel.cores > folds.num, folds.num, parallel.cores)

        cl <- parallel::makeCluster(parallel.cores)

        if (is.null(positive.class)) {
                positive.class <- as.character(datasets[[1]]$label[[1]])
        } else {
                if (!positive.class %in% datasets[[1]]$label) stop("positive.class should be NULL or one of the classes in label.")
        }
        parallel::clusterExport(cl, varlist = c("datasets", "all_folds", "positive.class", "ntree"), envir = environment())

        message("\n+ ", folds.num, "-fold CV Processing...\n")
        perf.res <- parallel::parSapply(cl, 1:folds.num, function(x, ...) {
                trainSet <- c()
                testSet <- c()
                for (i in 1:length(datasets)) {
                        dataset_tmp <- datasets[[i]]
                        fold_tmp <- all_folds[[i]]
                        train_tmp <- dataset_tmp[fold_tmp[[x]],]
                        test_tmp <- dataset_tmp[-fold_tmp[[x]],]

                        trainSet <- rbind(trainSet, train_tmp)
                        testSet <- rbind(testSet, test_tmp)
                }

                RF_mod <- randomForest::randomForest(label ~ ., data = trainSet,
                                                     ntree = ntree, ...)
                res <- predict(RF_mod, testSet, type = "response")

                confusion.res <- caret::confusionMatrix(data.frame(res)[,1], testSet$label,
                                                        positive = positive.class,
                                                        mode = "everything")
                confusion.tab <- confusion.res$table
                TP <- confusion.tab[row.names(confusion.tab) == positive.class,
                                    colnames(confusion.tab) == positive.class]
                TN <- confusion.tab[row.names(confusion.tab) != positive.class,
                                    colnames(confusion.tab) != positive.class]

                FN <- confusion.tab[row.names(confusion.tab) != positive.class,
                                    colnames(confusion.tab) == positive.class]
                FP <- confusion.tab[row.names(confusion.tab) == positive.class,
                                    colnames(confusion.tab) != positive.class]
                N  <- sum(confusion.res$table)
                S  <- (TP + FN) / N
                P  <- (TP + FP) / N
                MCC <- ((TP / N) - (S * P)) / sqrt(P * S * (1 - S) * (1 - P))
                Hm <- (2 * confusion.res$byClass[1] * confusion.res$byClass[2]) / (confusion.res$byClass[1] + confusion.res$byClass[2])
                # MCC <- ((TP * TN) - (FP * FN)) / sqrt((TP + FP) * (TP + FN) * (TN + FP) * (TN + FN))

                performance.res <- data.frame(TP = TP, TN = TN, FP = FP, FN = FN,
                                              Sensitivity = confusion.res$byClass[1],
                                              Specificity = confusion.res$byClass[2],
                                              Accuracy    = confusion.res$overall[1],
                                              HarmonicMean = Hm,
                                              F.Measure   = confusion.res$byClass[7],
                                              MCC         = MCC,
                                              Kappa       = confusion.res$overall[2])

        }, ... = ...)

        parallel::stopCluster(cl)
        Ave.res <- apply(perf.res, 1, as.numeric)
        Ave.res <- as.data.frame(t(Ave.res))
        Ave.res$Ave.Res <- rowMeans(Ave.res)
        message("- Performance:")
        print(round(t(Ave.res[ncol(Ave.res)]), digits = 4)[,-c(1:4)])
        message("\n+ Completed.   ", Sys.time())
        Ave.res
}

#' Determine mtry for Random Forest Classifier Using K-Fold Cross Validation
#' @param datasets should be a list containing one or several input datasets. If input several datasets, stratified cross validation will be performed. See examples.
#' @param label.col an integer. Column number of the label.
#' @param positive.class \code{NULL} or string. Which class is the positive class? Should be one
#' of the classes in label column. The first class in label column will be selected
#' as the positive class if leave \code{positive.class = NULL}.
#' @param folds.num an integer. Number of folds. Default \code{10} for 10-fold cross validation.
#' @param ntree integer, number of trees to grow. See \code{\link[randomForest]{randomForest}}.
#' Default: \code{3000}.
#' @param mtry.ratios (only when \code{mode = "retrain"}) used to indicate the ratios of \code{mtry} when tuning the random forest classifier.
#' \code{mtry} = ratio of mtry * number of features Default: \code{c(0.1, 0.2, 0.4, 0.6, 0.8)}.
#' @param seed random seed for data splitting. Integer.
#' @param return.model logical. If \code{TRUE}, the function will return a random forest
#' model built with the optimal \code{ntree}. The training set is the combination of all input datasets.
#' @param parallel.cores an integer specifying the number of cores for parallel computation. Default: \code{2}.
#' Set \code{parallel.cores = -1} to run with all the cores. \code{parallel.cores} should be == -1 or >= 1.
#' @param ... other parameters (except \code{ntree} and \code{mtry}) passed to \code{\link[randomForest]{randomForest}} function.
#' @return If \code{return.model = TRUR}, the function returns a random forest model.
#' If \code{FALSE}, the function returns the optimal \code{ntree} and the performance.
#'
#'
#' @importFrom caret createFolds
#' @importFrom caret confusionMatrix
#' @importFrom randomForest randomForest
#' @importFrom parallel makeCluster
#' @importFrom parallel clusterExport
#' @importFrom parallel parSapply
#' @importFrom parallel stopCluster
#' @importFrom parallel detectCores
#' @seealso \code{\link{randomForest_RFE}}, \code{\link{randomForest_CV}}, \code{\link[randomForest]{randomForest}}
#'
#' @examples
#'
#' # Following codes only show how to use this function
#' # and cannot reflect the genuine performance of tools or classifiers.
#'
#' data(demoPositiveSeq)
#' data(demoNegativeSeq)
#'
#' RNA.positive <- demoPositiveSeq$RNA.positive
#' Pro.positive <- demoPositiveSeq$Pro.positive
#' RNA.negative <- demoNegativeSeq$RNA.negative
#' Pro.negative <- demoNegativeSeq$Pro.negative
#'
#' dataPositive <- featureFreq(seqRNA = RNA.positive, seqPro = Pro.positive,
#'                             label = "Interact", featureMode = "conc",
#'                             computePro = "DeNovo", k.Pro = 3, k.RNA = 2,
#'                             normalize = "none", parallel.cores = 2)
#'
#' dataNegative <- featureFreq(seqRNA = RNA.negative, seqPro = Pro.negative,
#'                             label = "Non.Interact", featureMode = "conc",
#'                             computePro = "DeNovo", k.Pro = 3, k.RNA = 2,
#'                             normalize = "none", parallel.cores = 2)
#'
#' dataset <- rbind(dataPositive, dataNegative)
#'
#' Perf_tune <- randomForest_tune(datasets = list(dataset), label.col = 1,
#'                                positive.class = "Interact", folds.num = 5,
#'                                ntree = 150, seed = 123,
#'                                return.model = TRUE, parallel.cores = 2,
#'                                importance = TRUE)
#'
#' # if you have more than one input dataset,
#' # use "datasets = list(dataset1, dataset2, dataset3)".
#'
#' @export

randomForest_tune <- function(datasets = list(), label.col = 1,
                              positive.class = NULL, folds.num = 10,
                              ntree = 3000,
                              mtry.ratios = c(0.1, 0.2, 0.4, 0.6, 0.8),
                              seed = 1, return.model = TRUE,
                              parallel.cores = 2, ...) {

        message("+ Initializing...  ", Sys.time())
        for (i in 1:length(datasets)) {
                names(datasets[[i]])[[label.col]] <- "label"
                datasets[[i]]$label <- as.factor(datasets[[i]]$label)
        }

        all_folds <- lapply(datasets, function(x, ...) {
                set.seed(seed)
                folds <- caret::createFolds(x$label, k = folds.num, returnTrain = TRUE)
        }, ... = ...)

        if (is.null(positive.class)) {
                positive.class <- as.character(datasets[[1]]$label[[1]])
        } else {
                if (!positive.class %in% datasets[[1]]$label) stop("positive.class should be NULL or one of the classes in label.")
        }

        mtry.ratios <- sort(unique(mtry.ratios))
        perf_tune <- data.frame()

        parallel.cores <- ifelse(parallel.cores == -1, parallel::detectCores(), parallel.cores)
        parallel.cores <- ifelse(parallel.cores > folds.num, folds.num, parallel.cores)

        if (parallel.cores == 2 & folds.num != 2) message("- Users can try to set parallel.cores = -1 to use all cores!")

        cl <- parallel::makeCluster(parallel.cores)

        message("\n+ Processing...")
        for (mtry.ratio in mtry.ratios) {
                mtry <- floor((ncol(datasets[[1]]) - 1) * mtry.ratio)
                message("- mtryRatio: ", mtry.ratio, " (mtry: ", mtry, ")", "   ", Sys.time())

                mtry_res <- Internal.randomForest_CV(datasets = datasets, label.col = label.col,
                                             positive.class = positive.class, ntree = ntree,
                                             mtry = mtry,
                                             folds.num = folds.num, all_folds = all_folds,
                                             cl = cl, ...)
                mtry_perf <- t(mtry_res[folds.num + 1])
                row.names(mtry_perf) <- paste0("mtryRatio_", mtry.ratio)
                perf_tune <- rbind(perf_tune, mtry_perf)

                print(round(mtry_perf, digits = 4)[,-c(1:4)])
        }
        parallel::stopCluster(cl)

        output <- mtry.ratios[which.max(perf_tune$Accuracy)]
        message("- Optimal mtryRatio: ", output)
        mtry_optimal <- floor((ncol(datasets[[1]]) - 1) * output)

        if (return.model) {
                message("\n+ Training the model...   ", Sys.time())
                trainSet <- do.call("rbind", datasets)
                output <- randomForest::randomForest(label ~ ., data = trainSet,
                                                     ntree = ntree, mtry = mtry_optimal, ...)
        } else {
                output = list(ntree = output, performance = perf_tune)
        }
        message("\n+ Completed.   ", Sys.time())
        output
}

#' Feature Selection Using Random Forest Classifier and Recursive Feature Elimination
#' @param datasets should be a list containing one or several input datasets. See examples.
#' @param label.col an integer. The number of label column.
#' @param positive.class \code{NULL} or string. Which class is the positive class? Should be one
#' of the classes in label column. The first class in label column will be selected
#' as the positive class if leave \code{positive.class = NULL}.
#' @param featureNum.range is the range of feature number in each RFE iteration.
#' For example, if the original feature set has 100 features and \code{featureNum.range = c(10, 50, 80)},
#' 20 low-ranked features will be eliminated in the first iteration, and 80 features are used to build
#' model in the second iteration (All features are used in the first iteration). If leave \code{NULL},
#' RFE will iterate five times according to feature set,
#' i.e. \code{c(1, 26, 50, 75, 100)} for 100-dimension feature set.
#' @param folds.num an integer. Number of folds. Default \code{10} for 10-fold cross validation.
#' @param ntree parameter for random forest. Default: 1500. See \code{\link[randomForest]{randomForest}}.
#' @param seed random seed for data splitting. Integer.
#' @param parallel.cores an integer specifying the number of cores for parallel computation. Default: \code{2}.
#' Set \code{parallel.cores = -1} to run with all the cores. \code{parallel.cores} should be == -1 or >= 1.
#' @param ... other parameters passed to \code{\link[randomForest]{randomForest}} function.
#' @return The function returns a list containing importance scores and relevant performance of the features.
#'
#'
#' @importFrom caret createFolds
#' @importFrom caret confusionMatrix
#' @importFrom randomForest randomForest
#' @importFrom parallel makeCluster
#' @importFrom parallel clusterExport
#' @importFrom parallel parSapply
#' @importFrom parallel stopCluster
#' @importFrom parallel detectCores
#' @seealso \code{\link{randomForest_CV}}, \code{\link{randomForest_tune}}, \code{\link[randomForest]{randomForest}}
#'
#' @examples
#'
#' # Following codes only show how to use this function
#' # and cannot reflect the genuine performance of tools or classifiers.
#'
#' data(demoPositiveSeq)
#' data(demoNegativeSeq)
#'
#' RNA.positive <- demoPositiveSeq$RNA.positive
#' Pro.positive <- demoPositiveSeq$Pro.positive
#' RNA.negative <- demoNegativeSeq$RNA.negative
#' Pro.negative <- demoNegativeSeq$Pro.negative
#'
#' dataPositive <- featureFreq(seqRNA = RNA.positive, seqPro = Pro.positive,
#'                             label = "Interact", featureMode = "conc",
#'                             computePro = "DeNovo", k.Pro = 3, k.RNA = 2,
#'                             normalize = "none", parallel.cores = 2)
#'
#' dataNegative <- featureFreq(seqRNA = RNA.negative, seqPro = Pro.negative,
#'                             label = "Non.Interact", featureMode = "conc",
#'                             computePro = "DeNovo", k.Pro = 3, k.RNA = 2,
#'                             normalize = "none", parallel.cores = 2)
#'
#' dataset <- rbind(dataPositive, dataNegative)
#'
#' Perf_RFE <- randomForest_RFE(datasets = list(dataset), label.col = 1,
#'                              positive.class = "Interact",
#'                              featureNum.range = c(20, 50, 100),
#'                              folds.num = 5, ntree = 50, seed = 123,
#'                              parallel.cores = 2, mtry = 20)
#'
#' # if you have more than one input dataset,
#' # use "datasets = list(dataset1, dataset2, dataset3)".
#'
#' @export

randomForest_RFE <- function(datasets = list(), label.col = 1, positive.class = NULL,
                             featureNum.range = NULL, folds.num = 10,
                             ntree = 1500, seed = 1, parallel.cores = 2, ...) {

        message("+ Initializing...  ", Sys.time())
        for (len_datasets in 1:length(datasets)) {
                names(datasets[[len_datasets]])[[label.col]] <- "label"
                datasets[[len_datasets]]$label <- as.factor(datasets[[len_datasets]]$label)
        }

        if (length(datasets) > 1) {
                chk.colnames <- data.frame(sapply(datasets, colnames), stringsAsFactors = F)
                if (!all(sapply(2:ncol(chk.colnames), function(x) all.equal(chk.colnames[[x]], chk.colnames[[1]])))) {
                        stop("The datasets should have identical feature set!")
                }
        }

        all_folds <- lapply(datasets, function(x) {
                set.seed(seed)
                folds <- caret::createFolds(x$label, k = folds.num, returnTrain = TRUE)
        })

        parallel.cores <- ifelse(parallel.cores == -1, parallel::detectCores(), parallel.cores)
        parallel.cores <- ifelse(parallel.cores > folds.num, folds.num, parallel.cores)

        cl <- parallel::makeCluster(parallel.cores)

        if (is.null(positive.class)) {
                positive.class <- as.character(datasets[[1]]$label[[1]])
        } else {
                if (!positive.class %in% datasets[[1]]$label) stop("positive.class should be NULL or one of the classes in label.")
        }

        if (is.null(featureNum.range)) {
                featureNum.range <- round(seq(1, (ncol(datasets[[1]]) - 1), length.out = 5))
        } else {
                featureNum.range <- featureNum.range[featureNum.range <= (ncol(datasets[[1]]) - 1) & featureNum.range > 0]
        }

        featureNum.range <- unique(c(featureNum.range, ncol(datasets[[1]]) - 1))
        featureNum.range <- sort(featureNum.range, decreasing = TRUE)
        varName <-  names(datasets[[1]])[-label.col]

        outRes <- c()
        j <- 1

        for (i in featureNum.range) {

                message("\n+ Dataset Loaded.   ", Sys.time())
                message("- Current Iteration: ", j, "   ")
                message("- Remained Iteration: ", length(featureNum.range) - j)

                j <- j + 1

                if (i < (ncol(datasets[[1]]) - 1)) {
                        message("- Discarded Features:")
                        cat(varName[(i + 1):length(varName)], fill = TRUE, labels = " ", sep = "  ")
                }

                for (num_dataset in 1:length(datasets)) {
                        datasets[[num_dataset]] <- datasets[[num_dataset]][c("label", varName[1:i])]
                }

                message("- Current Features: ")
                # cat(names(datasetNew)[-label.col], fill = TRUE, labels = " ", sep = "  ")
                cat(varName[1:i], fill = TRUE, labels = " ", sep = "  ")

                parallel::clusterExport(cl, varlist = c("datasets", "all_folds", "positive.class", "ntree"), envir = environment())

                outInfo <- parallel::parSapply(cl, 1:folds.num, function(x, ...) {
                        trainSet <- c()
                        testSet <- c()
                        for (len_datasets in 1:length(datasets)) {
                                dataset_tmp <- datasets[[len_datasets]]
                                fold_tmp <- all_folds[[len_datasets]]
                                train_tmp <- dataset_tmp[fold_tmp[[x]],]
                                test_tmp <- dataset_tmp[-fold_tmp[[x]],]

                                trainSet <- rbind(trainSet, train_tmp)
                                testSet <- rbind(testSet, test_tmp)
                        }

                        RF.mod <- randomForest::randomForest(label ~ ., data = trainSet,
                                                             ntree = ntree, importance = TRUE, ...)
                        res <- predict(RF.mod, testSet, type = "response")

                        confusion.res <- caret::confusionMatrix(data.frame(res)[,1], testSet$label,
                                                                positive = positive.class,
                                                                mode = "everything")
                        confusion.tab <- confusion.res$table
                        TP <- confusion.tab[row.names(confusion.tab) == positive.class,
                                            colnames(confusion.tab) == positive.class]
                        TN <- confusion.tab[row.names(confusion.tab) != positive.class,
                                            colnames(confusion.tab) != positive.class]

                        FN <- confusion.tab[row.names(confusion.tab) != positive.class,
                                            colnames(confusion.tab) == positive.class]
                        FP <- confusion.tab[row.names(confusion.tab) == positive.class,
                                            colnames(confusion.tab) != positive.class]
                        N  <- sum(confusion.res$table)
                        S  <- (TP + FN) / N
                        P  <- (TP + FP) / N
                        MCC <- ((TP / N) - (S * P)) / sqrt(P * S * (1 - S) * (1 - P))
                        Hm <- (2 * confusion.res$byClass[1] * confusion.res$byClass[2]) / (confusion.res$byClass[1] + confusion.res$byClass[2])
                        # MCC <- ((TP * TN) - (FP * FN)) / sqrt((TP + FP) * (TP + FN) * (TN + FP) * (TN + FN))

                        performance.res <- data.frame(TP = TP, TN = TN, FP = FP, FN = FN,
                                                      Sensitivity = confusion.res$byClass[1],
                                                      Specificity = confusion.res$byClass[2],
                                                      Accuracy    = confusion.res$overall[1],
                                                      HarmonicMean = Hm,
                                                      F.Measure   = confusion.res$byClass[7],
                                                      MCC         = MCC,
                                                      Kappa       = confusion.res$overall[2])

                        importantScore <- RF.mod$importance
                        importantScore <- importantScore[,ncol(importantScore)]

                        outInfo <- list(performance.res, importantScore)
                }, ... = ...)

                perf.res <- outInfo[1,]
                perf.res <- sapply(perf.res, unlist)
                perf.res <- as.data.frame(perf.res)
                perf.res$AveRes <- rowMeans(perf.res)

                impScore <- outInfo[2,]
                impScore <- sapply(impScore, unlist)
                impScore <- as.data.frame(impScore)
                impScore$AveRes <- rowMeans(impScore)

                Interation <- list(ImportantScore = impScore, Performance = perf.res)
                outRes <- c(outRes, list(Interation))

                varName <- row.names(impScore)[order(impScore$AveRes, decreasing =  TRUE)]

                message("- Performance:")
                print(round(t(perf.res[(folds.num + 1)]), digits = 4)[,-c(1:4)])
        }
        parallel::stopCluster(cl)
        outNames <- paste0("FeatureNum.", featureNum.range)
        names(outRes) <- outNames

        message("\n+ Completed.   ", Sys.time())

        outRes
}

#' Evaluate Predicted Result
#' @description This function can evaluate prediction based on reference labels and predicted results.
#' @param reference a factor/character string of classes to be used as the true results.
#' @param prediction a factor/character string of predicted classes.
#' @param positive.class \code{NULL} or string. Which class is the positive class? Should be one
#' of the classes in label column. The first class in label column will be selected
#' as the positive class if leave \code{positive.class = NULL}.
#'
#' @return A dataframe that reports TP, TN, FP, FN, Sensitivity, Specificity, Accuracy,
#' F-Measure (F1-Score), MCC (Matthews Correlation Coefficient), Cohen's Kappa, etc.
#'
#' @details \code{reference} and \code{prediction} should have exactly the same classes.
#' More information please refer to \code{\link[caret]{confusionMatrix}}.
#'
#' @section References:
#' Kuhn M.
#' Building predictive models in R using the caret package.
#' Journal of statistical software. 2008; 28(5):1-26.
#'
#' @importFrom caret confusionMatrix
#' @seealso \code{\link[caret]{confusionMatrix}}
#'
#' @examples
#'
#' # Following codes only show how to use this function
#' # and cannot reflect the genuine performance of tools or classifiers.
#'
#' data(demoPositiveSeq)
#' seqRNA <- demoPositiveSeq$RNA.positive
#' seqPro <- demoPositiveSeq$Pro.positive
#'
#' # Predicting ncRNA-protein pairs using RPISeq (web-based):
#'
#' Res_RPISeq <- run_RPISeq(seqRNA = seqRNA, seqPro = seqPro,
#'                          parallel.cores = 2) # Network is required.
#'
#' # Evaluating the result:
#'
#' perf_RPISeq <- evaluatePrediction(reference = rep("Non.Interact", 20),
#'                                   prediction = Res_RPISeq$RPISeq_Web_RF_pred,
#'                                   positive.class = "Non.Interact")
#'
#' @export

evaluatePrediction <- function(reference, prediction, positive.class = NULL) {

        if (is.null(positive.class)) positive.class <- as.character(reference[[1]])

        if (!is.factor(reference)) reference <- as.factor(reference)
        if (!is.factor(prediction)) prediction <- as.factor(prediction)

        if (length(levels(reference)) == 1 & length(levels(prediction)) == 1) stop("Two classes are required!")
        if (length(levels(reference)) == 1) reference <- factor(reference, levels = levels(prediction))
        if (length(levels(prediction)) == 1) prediction <- factor(prediction, levels = levels(reference))
        if (length(unique(c(levels(reference), levels(prediction)))) != 2) stop("Classes in reference and prediction cannot match!")
        if (!positive.class %in% levels(reference)) stop("positive.class should be NULL or one of the classes of reference/prediction!")

        confusion.res <- caret::confusionMatrix(prediction,
                                                reference,
                                                positive = positive.class,
                                                mode = "everything")
        confusion.tab <- confusion.res$table
        TP <- confusion.tab[row.names(confusion.tab) == positive.class,
                            colnames(confusion.tab) == positive.class]
        TN <- confusion.tab[row.names(confusion.tab) != positive.class,
                            colnames(confusion.tab) != positive.class]

        FN <- confusion.tab[row.names(confusion.tab) != positive.class,
                            colnames(confusion.tab) == positive.class]
        FP <- confusion.tab[row.names(confusion.tab) == positive.class,
                            colnames(confusion.tab) != positive.class]

        N  <- sum(confusion.res$table)
        S  <- (TP + FN) / N
        P  <- (TP + FP) / N
        MCC <- ((TP / N) - (S * P)) / sqrt(P * S * (1 - S) * (1 - P))
        Hm <- (2 * confusion.res$byClass[1] * confusion.res$byClass[2]) / (confusion.res$byClass[1] + confusion.res$byClass[2])
        # MCC <- ((TP * TN) - (FP * FN)) / sqrt((TP + FP) * (TP + FN) * (TN + FP) * (TN + FN))

        performance.res <- data.frame(TP = TP, TN = TN, FP = FP, FN = FN,
                                      Sensitivity = confusion.res$byClass[1],
                                      Specificity = confusion.res$byClass[2],
                                      Precision   = confusion.res$byClass['Precision'],
                                      Accuracy    = confusion.res$overall[1],
                                      BalancedAccuracy = confusion.res$byClass['Balanced Accuracy'],
                                      HarmonicMean = Hm,
                                      F.Measure   = confusion.res$byClass[7],
                                      MCC         = MCC,
                                      Kappa       = confusion.res$overall[2])
        row.names(performance.res) <- NULL
        performance.res
}
