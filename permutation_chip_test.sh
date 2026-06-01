#!/bin/bash

# Check if correct number of arguments are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <reference.bed> <query.bed> <genome.file>"
    exit 1
fi

REFERENCE=$1
QUERY=$2
GENOME=$3
ITERATIONS=10000
TEMP_COUNTS="shuffled_counts.tmp"

# 1. Calculate Observed Overlaps
# -u reports the feature in A once if it has any overlaps in B
OBSERVED=$(bedtools intersect -a "$REFERENCE" -b "$QUERY" -u | wc -l)
echo "Observed intersections: $OBSERVED"

# Clear/create temp file
> "$TEMP_COUNTS"

echo "Running $ITERATIONS permutations..."

# 2. Perform Permutations
for i in $(seq 1 "$ITERATIONS"); do
    # Shuffle the query file
    # Intersect with reference and count
    COUNT=$(bedtools shuffle -i "$QUERY" -g "$GENOME" | \
            bedtools intersect -a "$REFERENCE" -b - -u | wc -l)
    
    echo "$COUNT" >> "$TEMP_COUNTS"
    
    # Progress indicator every 500 iterations
    if (( i % 500 == 0 )); then
        echo "Completed $i iterations..."
    fi
done

# 3. Calculate P-value
# P-value = (Number of times Shuffled >= Observed) / Total Iterations
GREATER_THAN_OBS=$(awk -v obs="$OBSERVED" '$1 >= obs {count++} END {print count+0}' "$TEMP_COUNTS")

# Use bc for floating point math
P_VALUE=$(echo "scale=5; $GREATER_THAN_OBS / $ITERATIONS" | bc -l)

echo "---------------------------------------"
echo "Results:"
echo "Observed Overlaps: $OBSERVED"
echo "Iterations where shuffled >= observed: $GREATER_THAN_OBS"
echo "Empirical P-value: $P_VALUE"
echo "---------------------------------------"

# Clean up
rm "$TEMP_COUNTS"