import scipy.stats as stats
import pandas as pd

with open("./performance-comparison-table-cp-all-dram", "r") as f:
    df_cp = pd.read_csv(f, delim_whitespace=True, engine='python')
with open("./performance-comparison-table-trace-all-dram", "r") as f:
    df_trace = pd.read_csv(f, delim_whitespace=True, engine='python')


for df in [df_cp, df_trace]:
    if df is df_cp:
        # Define your two samples
        sample1 = df[df["file_system"] == "Light-Dedup-J-64bits"]["second_bw"]
        sample2 = df[df["file_system"] == "Light-Dedup-J"]["second_bw"]
    else:
        sample1 = df[df["file_system"] == "Light-Dedup-J-64bits"]["bandwidth(MiB/s)"]
        sample2 = df[df["file_system"] == "Light-Dedup-J"]["bandwidth(MiB/s)"]

    # Perform the t-test
    t_statistic, p_value = stats.ttest_ind(sample1, sample2)

    # Print the results
    print("T-Statistic:", t_statistic)
    print("P-Value:", p_value)