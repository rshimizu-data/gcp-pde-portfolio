def calc_mean_diff(baseline, recent):
    if baseline == 0:
        return 0
    return (recent - baseline) / baseline
