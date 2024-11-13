#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re
import argparse
from pathlib import Path
import string

def sanitize_ref_id(text):
    """
    Convert text to a valid reference ID by:
    1. Converting to lowercase
    2. Replacing spaces and special characters with hyphens
    3. Removing any invalid characters
    4. Ensuring it starts with a letter
    """
    # Convert to lowercase and replace spaces with hyphens
    text = text.lower().strip()
    
    # Replace common special characters with hyphens
    text = re.sub(r'[&+,/\\. ]', '-', text)
    
    # Remove any other special characters
    valid_chars = "-_" + string.ascii_lowercase + string.digits
    text = ''.join(c for c in text if c in valid_chars)
    
    # Replace multiple hyphens with a single hyphen
    text = re.sub(r'-+', '-', text)
    
    # Remove leading and trailing hyphens
    text = text.strip('-')
    
    # Ensure it starts with a letter (if it doesn't, prepend 'img-')
    if not text or not text[0].isalpha():
        text = 'img-' + text
    
    return text

def convert_images_to_link_definitions(content):
    """
    Convert inline image references to link definitions in markdown content.
    Returns the modified content and a dictionary of link definitions.
    """
    # Regular expression to match markdown image syntax
    # ![alt text](url "optional title")
    image_pattern = r'!\[(.*?)\]\((.*?)(?:\s+"(.*?)")?\)'
    
    # Find all image references
    images = re.finditer(image_pattern, content)
    definitions = {}
    modified_content = content
    
    for i, match in enumerate(images, 1):
        alt_text = match.group(1)
        url = match.group(2)
        title = match.group(3)
        
        # Create a reference id based on alt text or a number if alt text is empty
        ref_id = sanitize_ref_id(alt_text) if alt_text else f'image-{i}'
        
        # Ensure unique reference ID
        base_ref_id = ref_id
        counter = 1
        while ref_id in definitions:
            ref_id = f"{base_ref_id}-{counter}"
            counter += 1
        
        # Create the reference link syntax
        if title:
            definitions[ref_id] = f'[{ref_id}]: {url} "{title}"'
        else:
            definitions[ref_id] = f'[{ref_id}]: {url}'
            
        # Replace the original image syntax with reference syntax
        original = match.group(0)
        replacement = f'![{alt_text}][{ref_id}]'
        modified_content = modified_content.replace(original, replacement)
    
    return modified_content, definitions

def process_file(input_file, output_file=None):
    """
    Process a markdown file and convert image references to link definitions.
    """
    # Read input file
    input_path = Path(input_file)
    if not input_path.exists():
        raise FileNotFoundError(f"Input file not found: {input_file}")
    
    content = input_path.read_text(encoding='utf-8')
    
    # Convert images to link definitions
    modified_content, definitions = convert_images_to_link_definitions(content)
    
    # Add link definitions to the end of the content
    if definitions:
        modified_content += '\n\n<!-- Image Link Definitions -->\n' + '\n'.join(definitions.values()) + '\n'
    
    # Write to output file or print to console
    if output_file:
        output_path = Path(output_file)
        output_path.write_text(modified_content, encoding='utf-8')
        print(f"Processed content written to: {output_file}")
        
        # Print statistics
        print(f"\nConversion Statistics:")
        print(f"Total images converted: {len(definitions)}")
        print(f"Link definitions added: {len(definitions)}")
    else:
        print(modified_content)

def main():
    parser = argparse.ArgumentParser(
        description="Convert markdown inline images to reference-style links"
    )
    parser.add_argument(
        'input_file',
        help="Input markdown file path"
    )
    parser.add_argument(
        '-o', '--output',
        help="Output file path (optional, defaults to stdout)",
        required=False
    )
    
    args = parser.parse_args()
    
    try:
        process_file(args.input_file, args.output)
    except Exception as e:
        print(f"Error: {e}")
        exit(1)

if __name__ == "__main__":
    main()