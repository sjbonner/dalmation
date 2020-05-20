##' @importFrom stats coef formula gaussian rnorm runif sd
##' @importFrom dglm dglm
##'
generateJAGSinits <- function(mean.model,variance.model,jags.data){

    inits <- lapply(1:3,function(i){

        cat("     Initializing chain",i,"...\n")
        
    ## Initial response when rounding
    if(is.null(jags.data$y))
      y <- runif(jags.data$n,jags.data$lower,jags.data$upper)
    else
      y <- jags.data$y
    
    ## Mean formula
    if(is.null(mean.model$fixed) && is.null(mean.model$random)){
      stop("You have specified no fixed or random effects for the mean component of the model.\n\n")
    }
    else if(i==1 || is.null(mean.model$random)){ # Only fixed effects
      mean.formula <- formula("y ~ jags.data$mean.fixed - 1")
    }
    else if(i==2 || is.null(mean.model$fixed)){ # Only random effects
      mean.formula <- formula("y ~ jags.data$mean.random - 1")
    }
    else{ # Mixed effects
      mean.formula <- formula("y ~ jags.data$mean.fixed + jags.data$mean.random - 1")
    }
    
    # Variance formula
    if(is.null(variance.model$fixed) && is.null(variance.model$random)){
      stop("You have specified no fixed or random effects for the variance component of the model.\n\n")
    }
    else if(i==1 || is.null(variance.model$random)){ # Only fixed effects
      variance.formula <- formula("epsilonsq ~ jags.data$variance.fixed - 1")
    }
    else if(i==2 || is.null(variance.model$fixed)){ # Only random effects
      variance.formula <- formula("epsilonsq ~ jags.data$variance.random - 1")
    }
    else{ # Mixed effects
      variance.formula <- formula("epsilonsq ~ jags.data$variance.fixed + jags.data$variance.random - 1")
    }
    
    ##### My simple implementation of a double glm fit non-iteratively #####
    # ## Fit linear regression model
    # if(!is.null(mean.model$fixed$link))
    #   meanlm <- glm(mean.formula,family = gaussian(link=mean.model$fixed$link))
    # else
    #   meanlm <- lm(mean.formula)
    # 
    # ## Extract coefficients for fixed and random components of model
    # mean.coeff <- coef(meanlm)
    # 
    # fixed.mean <- mean.coeff[grep("fixed",names(mean.coeff))]
    # random.mean <- mean.coeff[grep("random",names(mean.coeff))]
    # 
    # ## Variance model
    # 
    # # Extract squared residuals from mean model
    # epsilonsq <- residuals(meanlm)^2
    # 
    # # Fit gamma GLM to squared residuals
    # variancelm <- glm(variance.formula,family=Gamma(link=variance.model$fixed$link))
    # 
    # # Extract coefficients
    # variance.coeff <- coef(variancelm)
    # fixed.variance <- variance.coeff[grep("fixed",names(variance.coeff))]
    # random.variance <- variance.coeff[grep("random",names(variance.coeff))]
    # 
    
    # Set link functions to identity if not specified
    if(is.null(mean.model$fixed$link))
      mean.model$fixed$link <- "identity"
    
    if(is.null(variance.model$fixed$link))
      variance.model$fixed$link <- "identity"
      
    # Fit double GLM (without random effects)
    dlink <- variance.model$fixed$link # I don't understand, but this is necessary.

    dglmfit <- dglm::dglm(formula=mean.formula,
                 dformula=variance.formula,
                 family=gaussian(link=mean.model$fixed$link),
                 dlink=dlink)
    
    # Extract coefficients of mean model
    mean.coeff <- coef(dglmfit)
 
    tmp <- grep("fixed",names(mean.coeff))
    if(length(tmp)>0)
      fixed.mean <- mean.coeff[tmp]
    else
      fixed.mean <- NULL
    
    tmp <- grep("random",names(mean.coeff))
    if(length(tmp)>0)
      random.mean <- mean.coeff[tmp]
    else
      random.mean <- NULL
    
    ## Compute random effects sd for mean
    if(!is.null(mean.model$random)){
      if(i %in% c(2,3)){
        ## Compute random effects standard deviations
        ncomp <- jags.data[[paste0(mean.model$random$name,".ncomponents")]]
        levels <- jags.data[[paste0(mean.model$random$name,".levels")]]
        
        sd.mean <- sapply(1:ncomp, function(j) sd(mean.coeff[which(levels==j)],na.rm=TRUE))
        
        ## Randomly fill in any missing random effects
        miss <- which(is.na(random.mean))
        
        if(length(miss) > 0){
          random.mean[miss] <- rnorm(length(miss),0,sd.mean[levels[miss]])
        }
      }
      else{
        ## Set random effects standard deviation to be very small
        ncomp <- jags.data[[paste0(mean.model$random$name,".ncomponents")]]
        
        sd.mean <- rep(.001,ncomp)
      }
    }
    else{
      sd.mean <- NULL
    }
    
    # Extract coefficients of variance model
    variance.coeff <- coef(dglmfit$dispersion)
    
    tmp <- grep("fixed",names(variance.coeff))
    if(length(tmp)>0)
      fixed.variance <- variance.coeff[tmp]
    else
      fixed.variance <- NULL
    
    tmp <- grep("random",names(variance.coeff))
    if(length(tmp)>0)
      random.variance <- variance.coeff[tmp]
    else
      random.variance <- NULL
    
    ## Compute random effects sd for variance
    if(!is.null(variance.model$random)){
      if(i %in% c(2,3)){
        ## Compute random effects standard deviations
        ncomp <- jags.data[[paste0(variance.model$random$name,".ncomponents")]]
        levels <- jags.data[[paste0(variance.model$random$name,".levels")]]
        
        sd.variance <- sapply(1:ncomp, function(j) sd(variance.coeff[which(levels==j)],na.rm=TRUE))
        
        ## Randomly fill in any missing random effects
        miss <- which(is.na(random.variance))
        
        if(length(miss) > 0){
          random.variance[miss] <- rnorm(length(miss),0,sd.variance[levels[miss]])
        }
      }
      else{
        ## Set random effects standard deviation to be very small
        ncomp <- jags.data[[paste0(variance.model$random$name,".ncomponents")]]
        
        sd.variance <- rep(.001,ncomp)
      }
    }
    else{
      sd.variance <- NULL
    }
    
    ## Construct initial values list
    if(is.null(jags.data$y))
      setJAGSInits(mean.model,
                   variance.model,
                   y=y,
                   fixed.mean=fixed.mean,
                   fixed.variance = fixed.variance,
                   random.mean=random.mean,
                   sd.mean=sd.mean,
                   random.variance=random.variance,
                   sd.variance = sd.variance)
    else
      setJAGSInits(mean.model,
                   variance.model,
                   fixed.mean=fixed.mean,
                   fixed.variance = fixed.variance,
                   random.mean=random.mean,
                   sd.mean=sd.mean,
                   random.variance=random.variance,
                   sd.variance = sd.variance)
  })
  
  ## Return initial values list
  inits
}

##' Set initial values for \code{dalmatian}
##'
##' Allows the user to set initial values for \code{dalmatian}. Any values
##' not specified will by initialized by \code{JAGS}.
##' @title Set initial values for \code{dalmatian}
##' @param mean.model Model list specifying the structure of the mean. (list)
##' @param variance.model Model list specifyint the structure of the variance. (list)
##' @param fixed.mean Initial values for the fixed effects of the mean. (numeric)
##' @param fixed.variance Initial values for the fixed effects of the variance. (numeric)
##' @param y Inital values for the true response. This should only be specified if the \code{rounding = TRUE} in the main call to dalmatian.
##' @param random.mean Initial values for the random effects of the mean. (numeric)
##' @param sd.mean Initial values for the standard deviation of the random effects of the mean. (numeric)
##' @param random.variance Initial values for the random effects of the variance. (numeric
##' @param sd.variance Initial values for the standard deviation of the random effects of the variance. (numeric)
##' @return inits (list)
##' @author Simon Bonner
##' @export
##' 
##' @examples 
##' ## Load pied flycatcher data
##' data(pied_flycatchers_1)
##' 
##' ## Create variables bounding the true load
##' pfdata$lower=ifelse(pfdata$load==0,log(.001),log(pfdata$load-.049))
##' pfdata$upper=log(pfdata$load+.05)
##' 
##' ## Load output from previously run model
##' load(system.file("Pied_Flycatchers_1","pfresults.RData",package="dalmatian"))
##' 
##' ## Set initial values for a new run of the same model
##' inits <- lapply(1:3,function(i){
##'   setJAGSInits(pfresults$mean.model,
##'                pfresults$variance.model,
##'                y = runif(nrow(pfdata),pfdata$lower,pfdata$upper),
##'                fixed.mean = tail(pfresults$coda[[i]],1)[1:4],
##'                fixed.variance = tail(pfresults$coda[[i]],1)[5:7],
##'                sd.mean = 1)
##' })
setJAGSInits <- function(mean.model,
                         variance.model,
                         fixed.mean=NULL,
                         fixed.variance=NULL,
                         y=NULL,
                         random.mean=NULL,
                         sd.mean=NULL,
                         random.variance=NULL,
                         sd.variance=NULL){

    ## Initialize list of initial values
    inits <- list()

    ## Set initial data values
    if(!is.null(y)){
      inits$y <- y
    }
    ## Set initial values for mean component of model
    ## 1) Fixed effects
    if(!is.null(fixed.mean)){
        inits[[mean.model$fixed$name]] <- fixed.mean
    }

    ## 2) Random effects
    if(!is.null(random.mean)){
        inits[[paste0(mean.model$random$name,".tmp")]] <- random.mean
    }

    ## 3) Random effects variances
    if(!is.null(sd.mean)){
        ## Generate redundant variables for Gelman's parametrization of half-t
        ncomp <- length(sd.mean)

        ## Compute variance parameter
        tau <- 1/sd.mean^2

        ## Set initial values
        inits[[paste0("redun.",mean.model$random$name)]] <- rep(1,ncomp)
        inits[[paste0("tau.",mean.model$random$name)]] <- tau
    }

    ## Set initial values for variance component of model
    ## 1) Fixed effects
    if(!is.null(fixed.variance)){
        inits[[variance.model$fixed$name]] <- fixed.variance
    }

    ## 2) Random effects
    if(!is.null(random.variance)){
        inits[[paste0(variance.model$random$name,".tmp")]] <- random.variance
    }

    ## 3) Random effects variance
    if(!is.null(sd.variance)){
        ## Generate redundant variables for Gelman's parametrization of half-t
        ncomp <- length(sd.variance)

        ## Compute variance parameter
        tau <- 1/sd.variance^2

        ## Set initial values
        inits[[paste0("redun.",variance.model$random$name)]] <- rep(1,ncomp)
        inits[[paste0("tau.",variance.model$random$name)]] <- tau
    }

    return(inits)
}

