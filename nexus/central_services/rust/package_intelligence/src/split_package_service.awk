#!/usr/bin/awk -f

# Split package service into focused servers
BEGIN {
    # Registry server modules
    registry_modules = "collector github graphql"
    
    # Metadata server modules  
    metadata_modules = "storage package_file_watcher"
    
    # Security server modules
    security_modules = "github_advisory npm_advisory rustsec_advisory"
    
    # Analysis server modules
    analysis_modules = "engine embedding extractor template template_validator prompts"
    
    # Search server modules
    search_modules = "search cache"
    
    # Shared library modules
    shared_modules = "storage collector"
}

# Extract module declarations
/^pub mod [a-zA-Z_]+;/ {
    module = $2
    gsub(/;/, "", module)
    
    if (module ~ /collector|github|graphql/) {
        print "// Registry server module: " module > "/home/mhugo/code/singularity/rust/server/package_registry_server/src/modules.txt"
    } else if (module ~ /storage|package_file_watcher/) {
        print "// Metadata server module: " module > "/home/mhugo/code/singularity/rust/server/package_metadata_server/src/modules.txt"
    } else if (module ~ /engine|embedding|extractor|template|prompts/) {
        print "// Analysis server module: " module > "/home/mhugo/code/singularity/rust/server/package_analysis_server/src/modules.txt"
    } else if (module ~ /search|cache/) {
        print "// Search server module: " module > "/home/mhugo/code/singularity/rust/server/package_search_server/src/modules.txt"
    }
}

# Extract struct definitions
/^pub struct [A-Z]/ {
    struct_name = $3
    print "// Struct: " struct_name
}
