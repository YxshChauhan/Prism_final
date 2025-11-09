#!/bin/bash

# AirLink Test Files Generation Script
# Generates standardized test files for comprehensive testing

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_FILES_DIR="$SCRIPT_DIR"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Create directory structure
create_directories() {
    log "Creating directory structure..."
    mkdir -p "$TEST_FILES_DIR/photos"
    mkdir -p "$TEST_FILES_DIR/videos"
    mkdir -p "$TEST_FILES_DIR/documents"
    mkdir -p "$TEST_FILES_DIR/large"
    mkdir -p "$TEST_FILES_DIR/generated"
    log_success "Directories created"
}

# Generate small test files
generate_small_files() {
    log "Generating small test files..."
    
    # 1KB text file
    dd if=/dev/urandom bs=1024 count=1 2>/dev/null | base64 > "$TEST_FILES_DIR/generated/text_1kb.txt"
    
    # 10KB text file
    dd if=/dev/urandom bs=1024 count=10 2>/dev/null | base64 > "$TEST_FILES_DIR/generated/text_10kb.txt"
    
    # 100KB binary file
    dd if=/dev/urandom of="$TEST_FILES_DIR/generated/binary_100kb.bin" bs=1024 count=100 2>/dev/null
    
    # 500KB data file
    dd if=/dev/urandom of="$TEST_FILES_DIR/generated/data_500kb.dat" bs=1024 count=500 2>/dev/null
    
    log_success "Small files generated"
}

# Generate medium test files
generate_medium_files() {
    log "Generating medium test files..."
    
    # 1MB file
    dd if=/dev/urandom of="$TEST_FILES_DIR/generated/file_1mb.bin" bs=1M count=1 2>/dev/null
    
    # 5MB file
    dd if=/dev/urandom of="$TEST_FILES_DIR/generated/file_5mb.bin" bs=1M count=5 2>/dev/null
    
    # 10MB file
    dd if=/dev/urandom of="$TEST_FILES_DIR/generated/file_10mb.bin" bs=1M count=10 2>/dev/null
    
    # 25MB file
    dd if=/dev/urandom of="$TEST_FILES_DIR/generated/file_25mb.bin" bs=1M count=25 2>/dev/null
    
    log_success "Medium files generated"
}

# Generate large test files
generate_large_files() {
    log "Generating large test files..."
    
    # 50MB file
    dd if=/dev/urandom of="$TEST_FILES_DIR/generated/file_50mb.bin" bs=1M count=50 2>/dev/null
    
    # 100MB file
    dd if=/dev/urandom of="$TEST_FILES_DIR/generated/file_100mb.bin" bs=1M count=100 2>/dev/null
    
    # 200MB file (optional, takes time)
    if [ "$GENERATE_LARGE" = "true" ]; then
        log "Generating 200MB file (this may take a while)..."
        dd if=/dev/urandom of="$TEST_FILES_DIR/generated/file_200mb.bin" bs=1M count=200 2>/dev/null
    fi
    
    log_success "Large files generated"
}

# Generate special test files
generate_special_files() {
    log "Generating special test files..."
    
    # Empty file
    touch "$TEST_FILES_DIR/generated/empty_file.txt"
    
    # Unicode filename
    echo "Unicode test content" > "$TEST_FILES_DIR/generated/unicode_名前_test.txt"
    
    # File with spaces
    echo "Spaces in filename test" > "$TEST_FILES_DIR/generated/file with spaces.txt"
    
    # Very long filename
    echo "Long filename test" > "$TEST_FILES_DIR/generated/very_long_filename_that_exceeds_normal_limits_and_tests_filesystem_boundaries_with_many_characters.txt"
    
    log_success "Special files generated"
}

# Generate photo test files
generate_photos() {
    log "Generating photo test files..."
    
    # Small photo (100KB)
    dd if=/dev/urandom of="$TEST_FILES_DIR/photos/photo_100kb.jpg" bs=1024 count=100 2>/dev/null
    
    # Medium photo (2MB)
    dd if=/dev/urandom of="$TEST_FILES_DIR/photos/photo_2mb.jpg" bs=1M count=2 2>/dev/null
    
    # Large photo (5MB)
    dd if=/dev/urandom of="$TEST_FILES_DIR/photos/photo_5mb.png" bs=1M count=5 2>/dev/null
    
    log_success "Photo files generated"
}

# Generate video test files
generate_videos() {
    log "Generating video test files..."
    
    # Small video (10MB)
    dd if=/dev/urandom of="$TEST_FILES_DIR/videos/video_10mb.mp4" bs=1M count=10 2>/dev/null
    
    # Medium video (50MB)
    dd if=/dev/urandom of="$TEST_FILES_DIR/videos/video_50mb.mp4" bs=1M count=50 2>/dev/null
    
    if [ "$GENERATE_LARGE" = "true" ]; then
        # Large video (100MB)
        log "Generating 100MB video file..."
        dd if=/dev/urandom of="$TEST_FILES_DIR/videos/video_100mb.mov" bs=1M count=100 2>/dev/null
    fi
    
    log_success "Video files generated"
}

# Generate document test files
generate_documents() {
    log "Generating document test files..."
    
    # Small document (50KB)
    dd if=/dev/urandom bs=1024 count=50 2>/dev/null | base64 > "$TEST_FILES_DIR/documents/document_50kb.txt"
    
    # Medium document (500KB)
    dd if=/dev/urandom bs=1024 count=500 2>/dev/null | base64 > "$TEST_FILES_DIR/documents/document_500kb.txt"
    
    # Large document (2MB)
    dd if=/dev/urandom of="$TEST_FILES_DIR/documents/document_2mb.pdf" bs=1M count=2 2>/dev/null
    
    log_success "Document files generated"
}

# Generate checksums for all files
generate_checksums() {
    log "Generating SHA-256 checksums..."
    
    local checksums_file="$TEST_FILES_DIR/checksums.txt"
    
    # Create header
    cat > "$checksums_file" << EOF
# AirLink Test Files - SHA-256 Checksums
# Generated: $(date)
# 
# Format: <checksum>  <filepath>
#
# Verify with: sha256sum -c checksums.txt
# Or individual: sha256sum <filepath>

EOF
    
    # Generate checksums for all test files
    find "$TEST_FILES_DIR" -type f \( -name "*.txt" -o -name "*.bin" -o -name "*.dat" -o -name "*.jpg" -o -name "*.png" -o -name "*.mp4" -o -name "*.mov" -o -name "*.pdf" \) ! -name "checksums.txt" ! -name "README.md" -print0 | while IFS= read -r -d '' file; do
        if command -v sha256sum &> /dev/null; then
            sha256sum "$file" | sed "s|$TEST_FILES_DIR/||" >> "$checksums_file"
        elif command -v shasum &> /dev/null; then
            shasum -a 256 "$file" | sed "s|$TEST_FILES_DIR/||" >> "$checksums_file"
        fi
    done
    
    log_success "Checksums generated: $checksums_file"
}

# Display summary
display_summary() {
    log "Test files generation summary:"
    echo ""
    echo "Directory structure:"
    du -sh "$TEST_FILES_DIR"/* 2>/dev/null | grep -v "README.md" | grep -v "checksums.txt" | grep -v "generate_test_files.sh" || true
    echo ""
    
    local total_files=$(find "$TEST_FILES_DIR" -type f ! -name "README.md" ! -name "checksums.txt" ! -name "generate_test_files.sh" ! -name ".gitkeep" | wc -l)
    echo "Total test files: $total_files"
    
    if [ -f "$TEST_FILES_DIR/checksums.txt" ]; then
        local checksum_count=$(grep -v "^#" "$TEST_FILES_DIR/checksums.txt" | grep -v "^$" | wc -l)
        echo "Checksums generated: $checksum_count"
    fi
    
    echo ""
    log_success "Test files generation completed!"
}

# Main execution
main() {
    log "Starting AirLink test files generation..."
    echo ""
    
    # Parse arguments
    GENERATE_LARGE="false"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --large)
                GENERATE_LARGE="true"
                log "Large file generation enabled"
                shift
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --large    Generate large files (200MB+)"
                echo "  --help     Show this help message"
                echo ""
                exit 0
                ;;
            *)
                log_warning "Unknown option: $1"
                shift
                ;;
        esac
    done
    
    # Create directories
    create_directories
    
    # Generate files
    generate_small_files
    generate_medium_files
    generate_large_files
    generate_special_files
    generate_photos
    generate_videos
    generate_documents
    
    # Generate checksums
    generate_checksums
    
    # Display summary
    display_summary
}

# Run main function
main "$@"
