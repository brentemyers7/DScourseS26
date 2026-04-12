# Problem Set 9
# Using cross-validation to tune linear regression prediction models
# via LASSO, ridge regression, and elastic net

# Load the necessary libraries
library(tidyverse)
library(tidymodels)
library(glmnet)

# Load the Boston housing data from the mlbench package
# Original UCI source was down, so using mlbench's built-in copy
library(mlbench)
data(BostonHousing)
housing <- as_tibble(BostonHousing)

# Convert chas from factor to numeric (the recipe will re-factor it later)
housing$chas <- as.numeric(as.character(housing$chas))

# Verify rows, columns, variable types, and dimensions of the dataset
glimpse(housing)
dim(housing)

# Set the random seed for reproducibility
set.seed(123456)

# Split data into 80% training and 20% testing
housing_split <- initial_split(housing, prop = 0.8)
housing_train <- training(housing_split)
housing_test  <- testing(housing_split)

# Check the dimensions of the training and testing sets
dim(housing_train)
dim(housing_test)

# Create a recipe to preprocess the housing data:
# 1. Log-transform the outcome (medv)
# 2. Convert chas (0/1) to a factor
# 3. Create interaction terms among all continuous predictors
# 4. Create 6th-degree polynomial terms for all continuous predictors
# This expands the feature space from 13 predictors to 74
housing_recipe <- recipe(medv ~ ., data = housing) %>%
  step_log(all_outcomes()) %>%
  step_bin2factor(chas) %>%
  step_interact(terms = ~ crim:zn:indus:rm:age:rad:tax:
                  ptratio:b:lstat:dis:nox) %>%
  step_poly(crim, zn, indus, rm, age, rad, tax, ptratio, b,
            lstat, dis, nox, degree = 6)

# Prep the recipe on training data and apply it
housing_prep <- housing_recipe %>% prep(housing_train, retain = TRUE)
housing_train_prepped <- housing_prep %>% juice()
housing_test_prepped  <- housing_prep %>% bake(new_data = housing_test)

# Separate X and Y for training and testing
housing_train_x <- housing_train_prepped %>% select(-medv)
housing_test_x  <- housing_test_prepped  %>% select(-medv)
housing_train_y <- housing_train_prepped %>% select(medv)
housing_test_y  <- housing_test_prepped  %>% select(medv)

# Check dimensions: should be 404 x 75 (74 predictors + 1 outcome)
dim(housing_train_prepped)

# ===========================================================
# LASSO (alpha = 1): penalizes absolute value of coefficients
# Can shrink coefficients exactly to zero (variable selection)
# ===========================================================

# Fit LASSO with 6-fold CV to find optimal lambda
lasso_fit <- cv.glmnet(x = as.matrix(housing_train_x),
                       y = as.matrix(housing_train_y),
                       alpha = 1,
                       nfolds = 6)

# Optimal lambda value
lasso_fit$lambda.min

# In-sample predictions and RMSE (using lambda.min)
lasso_train_pred <- predict(lasso_fit, s = lasso_fit$lambda.min,
                            newx = as.matrix(housing_train_x))
lasso_in_rmse <- sqrt(mean((housing_train_y$medv - lasso_train_pred)^2))
lasso_in_rmse

# Out-of-sample predictions and RMSE
lasso_test_pred <- predict(lasso_fit, s = lasso_fit$lambda.min,
                           newx = as.matrix(housing_test_x))
lasso_out_rmse <- sqrt(mean((housing_test_y$medv - lasso_test_pred)^2))
lasso_out_rmse

# ===========================================================
# Ridge Regression (alpha = 0): penalizes squared coefficients
# Shrinks coefficients toward zero but never eliminates them
# ===========================================================

# Fit Ridge with 6-fold CV to find optimal lambda
ridge_fit <- cv.glmnet(x = as.matrix(housing_train_x),
                       y = as.matrix(housing_train_y),
                       alpha = 0,
                       nfolds = 6)

# Optimal lambda value
ridge_fit$lambda.min

# In-sample predictions and RMSE
ridge_train_pred <- predict(ridge_fit, s = ridge_fit$lambda.min,
                            newx = as.matrix(housing_train_x))
ridge_in_rmse <- sqrt(mean((housing_train_y$medv - ridge_train_pred)^2))
ridge_in_rmse

# Out-of-sample predictions and RMSE
ridge_test_pred <- predict(ridge_fit, s = ridge_fit$lambda.min,
                           newx = as.matrix(housing_test_x))
ridge_out_rmse <- sqrt(mean((housing_test_y$medv - ridge_test_pred)^2))
ridge_out_rmse

# ===========================================================
# OPTIONAL/ADDITIONAL: Elastic Net (alpha = 0.5)
# A blend of LASSO and ridge; not required by the PS but
# referenced in the problem set introduction
# ===========================================================

# Fit Elastic Net with 6-fold CV
enet_fit <- cv.glmnet(x = as.matrix(housing_train_x),
                      y = as.matrix(housing_train_y),
                      alpha = 0.5,
                      nfolds = 6)

# Optimal lambda value
enet_fit$lambda.min

# In-sample predictions and RMSE
enet_train_pred <- predict(enet_fit, s = enet_fit$lambda.min,
                           newx = as.matrix(housing_train_x))
enet_in_rmse <- sqrt(mean((housing_train_y$medv - enet_train_pred)^2))
enet_in_rmse

# Out-of-sample predictions and RMSE
enet_test_pred <- predict(enet_fit, s = enet_fit$lambda.min,
                          newx = as.matrix(housing_test_x))
enet_out_rmse <- sqrt(mean((housing_test_y$medv - enet_test_pred)^2))
enet_out_rmse



# ===========================================================
# Generate LaTeX tables for the writeup
# ===========================================================

# Table 1: LASSO and Ridge results (required)
results_table <- paste0(
  "\\begin{table}[H]\n",
  "\\centering\n",
  "\\caption{Cross-Validation Results: LASSO and Ridge Regression}\n",
  "\\label{tab:results}\n",
  "\\begin{tabular}{lccc}\n",
  "\\hline\\hline\n",
  "Model & Optimal $\\lambda$ & In-Sample RMSE & Out-of-Sample RMSE \\\\\n",
  "\\hline\n",
  sprintf("LASSO ($\\alpha = 1$) & %.6f & %.4f & %.4f \\\\\n",
          lasso_fit$lambda.min, lasso_in_rmse, lasso_out_rmse),
  sprintf("Ridge ($\\alpha = 0$) & %.5f & %.4f & %.4f \\\\\n",
          ridge_fit$lambda.min, ridge_in_rmse, ridge_out_rmse),
  "\\hline\\hline\n",
  "\\end{tabular}\n",
  "\\end{table}\n"
)
cat(results_table, file = "results_table.tex")

# Table 2: All three models including Elastic Net (additional)
enet_table <- paste0(
  "\\begin{table}[H]\n",
  "\\centering\n",
  "\\caption{Cross-Validation Results: All Three Models (Including Elastic Net)}\n",
  "\\label{tab:enet_results}\n",
  "\\begin{tabular}{lccc}\n",
  "\\hline\\hline\n",
  "Model & Optimal $\\lambda$ & In-Sample RMSE & Out-of-Sample RMSE \\\\\n",
  "\\hline\n",
  sprintf("LASSO ($\\alpha = 1$) & %.6f & %.4f & %.4f \\\\\n",
          lasso_fit$lambda.min, lasso_in_rmse, lasso_out_rmse),
  sprintf("Elastic Net ($\\alpha = 0.5$) & %.6f & %.4f & %.4f \\\\\n",
          enet_fit$lambda.min, enet_in_rmse, enet_out_rmse),
  sprintf("Ridge ($\\alpha = 0$) & %.5f & %.4f & %.4f \\\\\n",
          ridge_fit$lambda.min, ridge_in_rmse, ridge_out_rmse),
  "\\hline\\hline\n",
  "\\end{tabular}\n",
  "\\end{table}\n"
)
cat(enet_table, file = "enet_table.tex")

