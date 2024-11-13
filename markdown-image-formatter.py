# Save this as format_markdown.py

import re
import os
import argparse
from typing import List, Tuple

class MarkdownImageFormatter:
    def __init__(self, input_file: str):
        self.input_file = input_file
        self.output_file = self._generate_output_filename(input_file)
        self.image_alignments = {
            'left': '<p align="left">![{alt}]({src})</p>',
            'center': '<p align="center">![{alt}]({src})</p>',
            'right': '<p align="right">![{alt}]({src})</p>'
        }
        
    def _generate_output_filename(self, input_file: str) -> str:
        base, ext = os.path.splitext(input_file)
        return f"{base}_formatted{ext}"
    
    def _parse_image_tag(self, line: str) -> Tuple[str, str, str]:
        pattern = r'!\[(.*?)\]\((.*?)\)'
        match = re.search(pattern, line)
        if match:
            return match.group(0), match.group(1), match.group(2)
        return None, None, None
    
    def _detect_alignment(self, line: str) -> str:
        if '<p align="center">' in line:
            return 'center'
        elif '<p align="right">' in line:
            return 'right'
        return 'left'
    
    def format_images(self, default_alignment: str = 'center') -> List[str]:
        if default_alignment not in self.image_alignments:
            raise ValueError(f"Invalid alignment. Choose from: {', '.join(self.image_alignments.keys())}")
        
        formatted_lines = []
        
        with open(self.input_file, 'r', encoding='utf-8') as file:
            for line in file:
                if not line.strip():
                    formatted_lines.append(line)
                    continue
                
                image_tag, alt_text, source = self._parse_image_tag(line)
                if image_tag:
                    current_alignment = self._detect_alignment(line)
                    formatted_image = self.image_alignments[current_alignment].format(
                        alt=alt_text,
                        src=source
                    )
                    formatted_lines.append(formatted_image + '\n')
                else:
                    formatted_lines.append(line)
        
        return formatted_lines
    
    def save_formatted_file(self, lines: List[str]) -> str:
        with open(self.output_file, 'w', encoding='utf-8') as file:
            file.writelines(lines)
        return self.output_file

def main():
    # Set up command line argument parser
    parser = argparse.ArgumentParser(
        description='Format image alignments in markdown files'
    )
    parser.add_argument(
        'input_file',
        help='Path to the input markdown file'
    )
    parser.add_argument(
        '--alignment',
        choices=['left', 'center', 'right'],
        default='center',
        help='Default alignment for images (default: center)'
    )
    
    # Parse command line arguments
    args = parser.parse_args()
    
    try:
        # Check if input file exists
        if not os.path.exists(args.input_file):
            raise FileNotFoundError(f"Input file not found: {args.input_file}")
            
        # Create formatter instance
        formatter = MarkdownImageFormatter(args.input_file)
        
        # Format the images
        print(f"Formatting images in {args.input_file}...")
        formatted_lines = formatter.format_images(default_alignment=args.alignment)
        
        # Save the formatted file
        output_file = formatter.save_formatted_file(formatted_lines)
        print(f"Successfully created formatted file: {output_file}")
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())