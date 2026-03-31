# ============================================================
# PS8 - Econ 5253
# Matrix Manipulation, Optimization, and Simulated Data
# ============================================================

# Load required packages
library(nloptr)
library(modelsummary)

# ============================================================
# Q4: Simulate the data
# ============================================================

# Set seed for reproducibility
set.seed(100)

# Define dimensions
N <- 100000   # Number of observations
K <- 10       # Number of variables (including intercept)

# Create X matrix: N x K
# First column is all 1's (intercept), remaining 9 columns are standard normal draws
X <- cbind(1, matrix(rnorm(N * (K - 1)), nrow = N, ncol = K - 1))

# Generate error term: drawn from N(0, sigma^2) where sigma = 0.5
eps <- rnorm(N, mean = 0, sd = 0.5)

# Define the true beta vector
beta <- c(1.5, -1, -0.25, 0.75, 3.5, -2, 0.5, 1, 1.25, 2)

# Generate Y = X*beta + epsilon
Y <- X %*% beta + eps

# ============================================================
# Q5: OLS closed-form solution
# beta_hat = (X'X)^{-1} X'Y
# ============================================================

beta_hat_OLS <- solve(t(X) %*% X) %*% (t(X) %*% Y)
print(beta_hat_OLS)

# ============================================================
# Q6: OLS via Gradient Descent
# ============================================================

# Define the OLS objective function (sum of squared residuals)
ols_obj <- function(beta, Y, X) {
  return(sum((Y - X %*% beta)^2))
}

# Define the gradient of the OLS objective function
# Gradient = -2 * X'(Y - X*beta)
ols_gradient <- function(beta, Y, X) {
  return(-2 * t(X) %*% (Y - X %*% beta))
}

# Set gradient descent parameters
alpha <- 0.0000003   # Learning rate (step size)
max_iter <- 10000     # Maximum number of iterations
tol <- 1e-6           # Convergence tolerance

# Initialize beta at zeros
beta_gd <- rep(0, K)

# Run gradient descent loop
for (i in 1:max_iter) {
  # Compute the gradient at the current beta
  grad <- ols_gradient(beta_gd, Y, X)
  
  # Update beta by stepping in the direction of negative gradient
  beta_gd <- beta_gd - alpha * as.vector(grad)
  
  # Check for convergence: stop if gradient is small enough
  if (sqrt(sum(grad^2)) < tol) {
    cat("Converged at iteration", i, "\n")
    break
  }
}

# Print gradient descent estimate
print(beta_gd)


# ============================================================
# Q7: OLS via nloptr (L-BFGS and Nelder-Mead)
# ============================================================

# --- L-BFGS algorithm (uses gradient) ---
result_lbfgs <- nloptr(
  x0 = rep(0, K),              # Starting values
  eval_f = ols_obj,             # Objective function
  eval_grad_f = ols_gradient,   # Gradient function
  opts = list(
    algorithm = "NLOPT_LD_LBFGS",   # L-BFGS (gradient-based)
    xtol_rel = 1e-12,               # Convergence tolerance
    maxeval = 10000                  # Max iterations
  ),
  Y = Y, X = X                  # Extra arguments passed to obj and gradient
)

# Print L-BFGS estimates
cat("L-BFGS estimates:\n")
print(result_lbfgs$solution)

# --- Nelder-Mead algorithm (derivative-free) ---
result_nm <- nloptr(
  x0 = rep(0, K),              # Starting values
  eval_f = ols_obj,             # Objective function only (no gradient needed)
  opts = list(
    algorithm = "NLOPT_LN_NELDERMEAD",  # Nelder-Mead (no gradient)
    xtol_rel = 1e-12,                   # Convergence tolerance
    maxeval = 100000                     # More iterations since derivative-free is slower
  ),
  Y = Y, X = X
)

# Print Nelder-Mead estimates
cat("Nelder-Mead estimates:\n")
print(result_nm$solution)


# ============================================================
# Q8: MLE via nloptr (L-BFGS)
# ============================================================

# Define the negative log-likelihood function for linear regression
# theta = c(beta, sigma), so theta has K+1 elements
mle_obj <- function(theta, Y, X) {
  beta <- theta[1:(length(theta) - 1)]
  sig  <- theta[length(theta)]
  
  # Negative log-likelihood (we minimize, so negate the LL)
  n <- nrow(X)
  ll <- -(n/2) * log(2 * pi) - n * log(sig) - sum((Y - X %*% beta)^2) / (2 * sig^2)
  return(-ll)
}

# Gradient of the negative log-likelihood (provided in the problem set)
mle_gradient <- function(theta, Y, X) {
  grad <- as.vector(rep(0, length(theta)))
  beta <- theta[1:(length(theta) - 1)]
  sig  <- theta[length(theta)]
  grad[1:(length(theta) - 1)] <- -t(X) %*% (Y - X %*% beta) / (sig^2)
  grad[length(theta)] <- dim(X)[1] / sig - crossprod(Y - X %*% beta) / (sig^3)
  return(grad)
}

# Use OLS estimates as starting values for better convergence
start_beta <- as.vector(beta_hat_OLS)
start_sig  <- sqrt(sum((Y - X %*% beta_hat_OLS)^2) / N)

# Run L-BFGS optimization
result_mle <- nloptr(
  x0 = c(start_beta, start_sig),   # Smart starting values
  eval_f = mle_obj,                 # Negative log-likelihood
  eval_grad_f = mle_gradient,       # Gradient from PS8
  opts = list(
    algorithm = "NLOPT_LD_LBFGS",
    xtol_rel = 1e-12,
    maxeval = 10000
  ),
  Y = Y, X = X
)

# Print MLE estimates (first K are beta, last one is sigma)
cat("MLE beta estimates:\n")
print(result_mle$solution[1:K])
cat("MLE sigma estimate:\n")
print(result_mle$solution[K + 1])


# ============================================================
# Q9: OLS the easy way using lm()
# ============================================================

# Run OLS regression using lm()
# -1 suppresses the automatic intercept since X already has a column of 1's
ols_lm <- lm(Y ~ X - 1)

# Print summary to console
summary(ols_lm)

# Preview regression table in RStudio Viewer
modelsummary(ols_lm)

# Export regression table to a .tex file using modelsummary
models <- list("OLS via lm()" = ols_lm)
modelsummary(models, output = "PS8_regression.tex")

# Automatically add [H] to the .tex file to force table placement
tex <- readLines("PS8_regression.tex")
tex <- sub("\\\\begin\\{table\\}", "\\\\begin{table}[H]", tex)
writeLines(tex, "PS8_regression.tex")

