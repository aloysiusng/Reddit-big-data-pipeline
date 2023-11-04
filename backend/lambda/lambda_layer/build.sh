#!/bin/bash

# Change to the directory
echo "Creating and changing to the package directory"
mkdir packages
cd packages

# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate
# Check if the virtual environment is activated
if [ "$VIRTUAL_ENV" != "" ]; then
    echo "Virtual environment is activated."
else
    echo "Error: Virtual environment is not activated!"
    exit 1
fi

# Install dependencies
mkdir python
cd python
pip install --upgrade setuptools pip
pip install -r ../../requirements.txt -t ./

# Remove unnecessary files
rm -rf *dist-info

# Go back to the package directory
cd ..

# Create a zip file
zip -r python_dependencies.zip python

mv python_dependencies.zip ../python_dependencies.zip

echo "Done!"
