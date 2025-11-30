import os
import json

# Step 1: Open the folder '/data' in the current directory
folder_path = 'data'

# Step 2: Read a list of file names and cache them to a list
file_list = os.listdir(folder_path)

# Step 3: Ask the user for a string to search in file names
search_string = input("Enter the string to search in file names: ")

# Step 4: Find all file names that contain the input string and cache them to a list
matched_files = [file for file in file_list if search_string in file]
print("Matched files:", matched_files)

# Step 5: Open these files as JSON
issue_urls = []

for file in matched_files:
    file_path = os.path.join(folder_path, file)
    try:
        with open(file_path, 'r') as json_file:
            data = json.load(json_file)
            # Step 6: Find "issueUrl" key in JSON file and cache it
            if "issueUrl" in data:
                issue_urls.append(data["issueUrl"])
    except Exception as e:
        print(f"Error reading file {file}: {e}")

# Step 7: Print the result
print("Issue URLs found in the files:", issue_urls)
for url in issue_urls:
    print(url)
