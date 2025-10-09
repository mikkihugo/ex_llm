use std::fs;
use std::path::Path;
use std::sync::Arc;

use crate::{
    discover_sources, DiscoveryOptions, ParseContext, ParseOptions, ParsedDocument, ParserError,
    ParserRegistry, SourceDescriptor,
};

const DEFAULT_MAX_BYTES: usize = 5 * 1024 * 1024;

/// Implements a high-level interface for managing parsing operations.
/// The `UniversalParser` coordinates parsing across multiple sources and capsules.
#[derive(Clone)]
pub struct UniversalParser {
    registry: Arc<ParserRegistry>,
    default_options: ParseOptions,
}

impl UniversalParser {
    pub fn new(registry: Arc<ParserRegistry>) -> Self {
        Self {
            registry,
            default_options: ParseOptions {
                max_bytes: Some(DEFAULT_MAX_BYTES),
                ..ParseOptions::default()
            },
        }
    }

    pub fn with_options(registry: Arc<ParserRegistry>, options: ParseOptions) -> Self {
        Self {
            registry,
            default_options: options,
        }
    }

    pub fn registry(&self) -> &Arc<ParserRegistry> {
        &self.registry
    }

    pub fn parse_file(
        &self,
        context: &ParseContext,
        path: &Path,
    ) -> Result<ParsedDocument, ParserError> {
        let mut descriptor = SourceDescriptor::new(path);
        let metadata = fs::metadata(path)?;
        descriptor.size_bytes = metadata.len();
        descriptor.last_modified = metadata.modified().ok().map(|ts| ts.into());

        self.parse_descriptor(context, descriptor)
    }

    pub fn parse_descriptor(
        &self,
        context: &ParseContext,
        descriptor: SourceDescriptor,
    ) -> Result<ParsedDocument, ParserError> {
        let options = self.default_options.clone();

        if let Some(max) = options.max_bytes {
            if (descriptor.size_bytes as usize) > max {
                return Err(ParserError::FileTooLarge {
                    path: descriptor.path.display().to_string(),
                    size: descriptor.size_bytes,
                    max,
                });
            }
        }

        let source = fs::read_to_string(&descriptor.path)?;
        self.registry.parse(context, &descriptor, &source, &options)
    }

    pub fn parse_descriptors<I>(
        &self,
        context: &ParseContext,
        descriptors: I,
    ) -> Result<Vec<ParsedDocument>, ParserError>
    where
        I: IntoIterator<Item = SourceDescriptor>,
    {
        descriptors
            .into_iter()
            .map(|descriptor| self.parse_descriptor(context, descriptor))
            .collect()
    }

    pub fn parse_tree(
        &self,
        context: &ParseContext,
        root: &Path,
        discovery: &DiscoveryOptions,
    ) -> Result<Vec<ParsedDocument>, ParserError> {
        let descriptors = discover_sources(root, discovery)?;
        self.parse_descriptors(context, descriptors)
    }
}
