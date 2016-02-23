### General function for murmur models ###
## Methods to implement:
# Bayes_full: Full Bayesian model with all random effects correlated
# Bayes_uni: Univariate Bayesian models
# Bayes_orth: Full Bayesian with all random effects uncorrelated
# lmer_uni: Unviariate lmer models
# lmer_orth: Univariate lmer models with random effects uncorrelated

### TODO ###
# Split X in Xwithin and Xbetween
# Allow specification of X such as L1_X to add lagged predictor
# Formula input?
# Single outcome not yet possible...

murmur <- function(
  Y, # Data frame containing outcome variables. OR 
  X, # Data frame containing predictors. IF MISSING, DO VAR
  ID, # Vector with IDs
  time,
  method = c("Bayes_full","Bayes_uni","Bayes_orth","lmer_uni","lmer_orth"), # method to use, see above
  standardization = c("within","grand","none"), # What standardization to use?
  data, # If X, Y and ID are character strings, use this data frame.
  ...
){
  # Argument checks:
  method <- match.arg(method)
  standardization <- match.arg(standardization)
  
  # If data argument is used, extract relevant columns:
  if (missing(data)){
    if (is.character(Y)){
      stop("Y is character. Perhaps you forgot to use the data argument?")
    }
    # First make Y correct data frame, then make data Y:
    if (is.vector(Y) || is.matrix(Y)){
      Y <- as.data.frame(Y)
    }
    if (!is.data.frame(Y)){
      stop("Y must be a vector, matrix or data frame")
    }
    if (is.null(names(Y))){
      names(Y) <- paste0("YVAR",seq_len(ncol(Y)))
    }
    data <- Y
    Y <- names(Y)
    
    # Add ID column:
    if (missing(ID)){
      ID <- rep(1,nrow(data))
    }
    
    stopifnot(is.vector(ID))
    data[['IDVAR']] <- ID
    ID <- 'IDVAR'
    
    if (!missing(time)){
      data[['TIMEVAR']] <- time
      time <- 'TIMEVAR'
    }
    
    # Add X columns, if not missing (otherwise they are added later):
    if (!missing(X)){
      if (is.vector(X) || is.matrix(X)){
        X <- as.data.frame(X)
      }
      if (!is.data.frame(X)){
        stop("X must be a vector, matrix or data frame")
      }
      if (is.null(names(X))){
        names(X) <- paste0("XVAR_",seq_len(nY))
      }
      data <- cbind(data,X)
      X <- names(X)
    }
    
  }
  
  # Test if Y and ID are character vectors, and repressent column names in data:
  if (!is.character(Y) || !all(Y %in% names(data))){
    stop("Variables in Y not present in dataset")
  }
  if (missing(ID)){
    data[['IDVAR']] <- rep(1,nrow(data))
  }
  if (!is.character(ID) || !all(ID %in% names(data))){
    stop("Variables in ID not present in dataset")
  }
  if (missing(time)){
    data <- data %>% group_by_(ID) %>% 
      mutate(TIMEVAR = seq_len(n()))
    time <- 'TIMEVAR'
  }
  data <- data %>% group_by_(ID) %>% 
    mutate_(TIMEVAR_DISCRETE = as.formula(paste0("~","as.numeric(as.factor(",time,"))")))
  time <- "TIMEVAR_DISCRETE"

  # If X missing, set to VAR model:
  if (missing(X) || any(grepl("^L\\d*_",X))){
    if (missing(X)){
      X <- paste0("L1_",Y)
    }

    # Don't slice, just augment....
    preds <- gsub("^L\\d*_","",X)
    Xtemp <- data  %>% ungroup %>% select_(.dots = c(preds,ID,time))
    for (i in grep("^L\\d*_",X)){
      Lag <- as.numeric(unlist(regmatches(X[i],regexpr("(?<=^L)\\d*",X[i],perl=TRUE))))
      Xtemp <- Xtemp %>% group_by_(ID) %>% 
        mutate_(.dots = setNames(list(as.formula(paste0("~ c(rep(NA,Lag),",preds[i],"[1:(n()-Lag)])"))), X[i]))
    }
    Xtemp <- Xtemp %>% select_(.dots = c(X,ID,time))
    data <- data %>% left_join(Xtemp, c(ID,time))
  }

  ### Standardization ###
  if (standardization == "within"){
    for (i in unique(data[[ID]])){
      data[data[[ID]] == i,names(data)%in%c(X,Y)] <- data[data[[ID]] == i,names(data)%in%c(X,Y)] %>% mutate_each(funs(betterscale))
    }
  } else if (standardization == "grand"){
    data[,names(data)%in%c(X,Y)] <- data[,names(data)%in%c(X,Y)] %>% mutate_each(funs(betterscale))
  }
  
  #### ESTIMATION ####
  if (method == "Bayes_full"){
    Results <- Bayes_full(Y,X,ID,data,...)
  } else {
    stop(paste0("Method '",method,"' not yet implemented."))
  }

  # For now just return results:
  return(Results)
}