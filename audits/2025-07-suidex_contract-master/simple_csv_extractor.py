#!/usr/bin/env python3
"""
Simple CSV Extractor for Victory Token Allocation Tests
Just extracts the data - no fancy features
"""

import sys
import csv

def extract_data(log_file):
    """Extract CSV data from Move test log"""
    print(f"Reading {log_file}...")
    
    with open(log_file, 'r') as f:
        lines = f.readlines()
    
    csv_data = []
    i = 0
    
    while i < len(lines):
        line = lines[i].strip()
        
        # Found start of CSV block
        if '[debug] "CSV_DATA_START"' in line:
            # Get next 12 numbers
            numbers = []
            j = i + 1
            
            while j < len(lines) and len(numbers) < 12:
                next_line = lines[j].strip()
                
                if '[debug] "CSV_DATA_END"' in next_line:
                    break
                    
                # Extract number from debug line
                if next_line.startswith('[debug] ') and '"' not in next_line:
                    number = next_line.replace('[debug] ', '').strip()
                    if number.isdigit():
                        numbers.append(number)
                
                j += 1
            
            # If we got 12 numbers, add to data
            if len(numbers) == 12:
                csv_data.append(numbers)
                print(f"Week {numbers[0]} extracted")
            
            i = j
        else:
            i += 1
    
    return csv_data

def write_csv(data, output_file):
    """Write data to CSV file"""
    print(f"Writing {output_file}...")
    
    header = ['Week', 'Phase', 'EmissionRate', 'LPPercent', 'SinglePercent', 
              'VictoryPercent', 'DevPercent', 'LPEmission', 'SingleEmission',
              'VictoryEmission', 'DevEmission', 'TotalEmission']
    
    with open(output_file, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(header)
        
        # Sort by week number
        sorted_data = sorted(data, key=lambda x: int(x[0]))
        
        for row in sorted_data:
            writer.writerow(row)
    
    print(f"Done! {len(data)} weeks saved to {output_file}")

def main():
    if len(sys.argv) != 3:
        print("Usage: python3 simple_extractor.py <log_file> <output_csv>")
        print("Example: python3 simple_extractor.py test_output.log data.csv")
        sys.exit(1)
    
    log_file = sys.argv[1]
    output_file = sys.argv[2]
    
    try:
        data = extract_data(log_file)
        
        if data:
            write_csv(data, output_file)
            print(f"\nSuccess! Extracted {len(data)} weeks")
        else:
            print("No data found in log file")
            
    except FileNotFoundError:
        print(f"Error: {log_file} not found")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()