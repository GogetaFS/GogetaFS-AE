import scipy.stats as stats
import pandas as pd

with open("./performance-comparison-table", "r") as f:
    df = pd.read_csv(f, delim_whitespace=True, engine='python')
    
# Define your two samples
sample1 = df[df["file_system"] == "Light-Dedup-J-64bits-disable-dedup"]["bandwidth(MiB/s)"]
sample2 = df[df["file_system"] == "NOVA-Improve"]["bandwidth(MiB/s)"]

# Perform the t-test
t_statistic, p_value = stats.ttest_ind(sample1, sample2)

# Print the results
print("T-Statistic:", t_statistic)
print("P-Value:", p_value)