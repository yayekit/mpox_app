# Load required libraries
library(xgboost)
library(data.table)
library(ggplot2)
library(TTR)      # For calculating rolling statistics
library(caret)    # For cross-validation
library(lubridate) # For date manipulation

# Load data
data <- fread("file0.csv")

# Convert 'Date' column to Date format if it exists
if ("Date" %in% names(data)) {
  data[, Date := as.Date(Date)]
}

# Feature Engineering: Create Lagged Features, Rolling Statistics, and Time-Based Features
data[, `:=`(
  lag_1 = shift(p_avg_all_ages, 1), 
  lag_2 = shift(p_avg_all_ages, 2),
  lag_3 = shift(p_avg_all_ages, 3),
  lag_4 = shift(p_avg_all_ages, 4),
  lag_5 = shift(p_avg_all_ages, 5),
  roll_mean_3 = SMA(p_avg_all_ages, n = 3),
  roll_sd_3 = runSD(p_avg_all_ages, n = 3),
  roll_mean_5 = SMA(p_avg_all_ages, n = 5),
  roll_sd_5 = runSD(p_avg_all_ages, n = 5)
), by = Entity]

# Create time-based features if Date column exists
if ("Date" %in% names(data)) {
  data[, `:=`(
    month = month(Date),
    quarter = quarter(Date),
    year = year(Date)
  )]
}

# Remove rows with NA values
data <- na.omit(data)

# Prepare Training and Test Data (80% training, 20% testing)
set.seed(123)
train_size <- floor(0.8 * nrow(data))
train_data <- data[1:train_size]
test_data  <- data[(train_size + 1):nrow(data)]

# Feature Columns
features <- c("lag_1", "lag_2", "lag_3", "lag_4", "lag_5",
              "roll_mean_3", "roll_sd_3", "roll_mean_5", "roll_sd_5",
              "month", "quarter", "year")

# Ensure all feature columns exist
features <- features[features %in% names(data)]

# Prepare Matrices for XGBoost
train_matrix <- as.matrix(train_data[, ..features])
train_label  <- train_data$p_avg_all_ages

test_matrix <- as.matrix(test_data[, ..features])
test_label  <- test_data$p_avg_all_ages

# Define Hyperparameter Grid for Tuning
xgb_grid <- expand.grid(
  nrounds = seq(50, 150, by = 50),
  max_depth = seq(3, 9, by = 2),
  eta = c(0.01, 0.05, 0.1),
  gamma = c(0, 0.1, 0.2),
  colsample_bytree = c(0.7, 1),
  min_child_weight = c(1, 5),
  subsample = c(0.7, 1)
)

# Perform Time-Series Cross-Validation
train_control <- trainControl(
  method = "timeslice",
  initialWindow = floor(0.6 * nrow(train_matrix)),
  horizon = floor(0.2 * nrow(train_matrix)),
  fixedWindow = TRUE,
  skip = 0,
  summaryFunction = defaultSummary,
  verboseIter = TRUE
)

# Train the XGBoost Model with Hyperparameter Tuning
set.seed(123)
xgb_model <- train(
  x = train_matrix,
  y = train_label,
  method = "xgbTree",
  trControl = train_control,
  tuneGrid = xgb_grid,
  metric = "RMSE"
)

# Display Best Hyperparameters
cat("Best Model Hyperparameters:\n")
print(xgb_model$bestTune)

# Predict on Test Data
predictions <- predict(xgb_model, newdata = test_matrix)

# Evaluate Performance with Additional Metrics
test_rmse <- sqrt(mean((test_label - predictions)^2))
test_mae  <- mean(abs(test_label - predictions))
test_r2   <- cor(test_label, predictions)^2

cat(sprintf("Test RMSE: %.4f\n", test_rmse))
cat(sprintf("Test MAE: %.4f\n", test_mae))
cat(sprintf("Test R-squared: %.4f\n", test_r2))

# Check for Overfitting by Evaluating on Training Data
train_predictions <- predict(xgb_model, newdata = train_matrix)
train_rmse <- sqrt(mean((train_label - train_predictions)^2))

cat(sprintf("Training RMSE: %.4f\n", train_rmse))

# Plot Actual vs Predicted Values
if ("Date" %in% names(test_data)) {
  test_data[, Prediction := predictions]
  ggplot(test_data, aes(x = Date)) +
    geom_line(aes(y = p_avg_all_ages, color = "Actual"), size = 1) +
    geom_line(aes(y = Prediction, color = "Predicted"), size = 1, linetype = "dashed") +
    labs(title = "Actual vs. Predicted Values", x = "Date", y = "Excess Mortality (%)") +
    scale_color_manual(values = c("Actual" = "blue", "Predicted" = "red")) +
    theme_minimal()
} else {
  # If Date is not available, use index
  ggplot() +
    geom_line(aes(x = 1:length(test_label), y = test_label, color = "Actual"), size = 1) +
    geom_line(aes(x = 1:length(predictions), y = predictions, color = "Predicted"), size = 1, linetype = "dashed") +
    labs(title = "Actual vs. Predicted Values", x = "Time", y = "Excess Mortality (%)") +
    scale_color_manual(values = c("Actual" = "blue", "Predicted" = "red")) +
    theme_minimal()
}

# Plot Variable Importance
importance <- varImp(xgb_model, scale = FALSE)
plot(importance, top = 10, main = "Top 10 Important Variables")
