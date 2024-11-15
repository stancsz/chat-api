import os
import shutil
import subprocess
import zipfile

# Define paths
package_dir = 'package'
zip_file = 'app.zip'
app_src = 'src/app.py'
requirements_file = 'src/requirements.txt'

# Clean up old package and zip file
if os.path.exists(package_dir):
    shutil.rmtree(package_dir)
if os.path.exists(zip_file):
    os.remove(zip_file)

# Create package directory
os.makedirs(package_dir)

# Install dependencies from requirements.txt if it exists
if os.path.exists(requirements_file):
    subprocess.check_call(['pip', 'install', '--target', package_dir, '-r', requirements_file])
else:
    # If you have dependencies listed directly in the script, install them here
    subprocess.check_call(['pip', 'install', '--target', package_dir, 'flask', 'mangum'])

# Copy application code
shutil.copy(app_src, package_dir)

# Create a ZIP file for Lambda deployment
with zipfile.ZipFile(zip_file, 'w', zipfile.ZIP_DEFLATED) as zipf:
    for root, dirs, files in os.walk(package_dir):
        for file in files:
            filepath = os.path.join(root, file)
            arcname = os.path.relpath(filepath, package_dir)
            zipf.write(filepath, arcname)
