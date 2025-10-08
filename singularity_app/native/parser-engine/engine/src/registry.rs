/// Manages the registration and retrieval of language capsules.
/// The `ParserRegistry` serves as a centralized store for all available parsers.

use dashmap::DashMap;
use parking_lot::RwLock;
use std::collections::HashMap;
use std::sync::Arc;

use crate::error::ParserError;
use crate::{
    LanguageCapsule, LanguageId, ParseContext, ParseOptions, ParsedDocument, Result,
    SourceDescriptor,
};

/// Handle returned when registering capsules.
#[derive(Clone)]
pub struct CapsuleHandle {
    capsule: Arc<dyn LanguageCapsule>,
}

impl CapsuleHandle {
    pub fn info(&self) -> &crate::LanguageInfo {
        self.capsule.info()
    }
}

/// Registry storing all available language capsules.
pub struct ParserRegistry {
    capsules: DashMap<LanguageId, Arc<dyn LanguageCapsule>>, // keyed by id
    by_extension: DashMap<String, Vec<LanguageId>>,          // extension -> language ids
    fallback_chain: RwLock<Vec<LanguageId>>,
}

impl ParserRegistry {
    pub fn builder() -> ParserRegistryBuilder {
        ParserRegistryBuilder::default()
    }

    pub fn get(&self, id: &LanguageId) -> Option<Arc<dyn LanguageCapsule>> {
        self.capsules
            .get(id)
            .map(|capsule| Arc::clone(capsule.value()))
    }

    pub fn detect_language(
        &self,
        descriptor: &SourceDescriptor,
    ) -> Option<Arc<dyn LanguageCapsule>> {
        if let Some(lang) = descriptor.language.as_ref() {
            let id = LanguageId::new(lang.to_string());
            if let Some(capsule) = self.get(&id) {
                return Some(capsule);
            }
        }

        if let Some(ext) = descriptor.extension() {
            if let Some(ids) = self.by_extension.get(ext) {
                for id in ids.iter() {
                    if let Some(capsule) = self.get(id) {
                        if capsule.matches(descriptor) {
                            return Some(capsule);
                        }
                    }
                }
            }
        }

        for id in self.fallback_chain.read().iter() {
            if let Some(capsule) = self.get(id) {
                if capsule.matches(descriptor) {
                    return Some(capsule);
                }
            }
        }

        None
    }

    pub fn parse(
        &self,
        context: &ParseContext,
        descriptor: &SourceDescriptor,
        source: &str,
        options: &ParseOptions,
    ) -> Result<ParsedDocument> {
        let capsule = self
            .detect_language(descriptor)
            .ok_or_else(|| ParserError::NoMatchingCapsule(descriptor.path.display().to_string()))?;

        capsule.parse(context, descriptor, source, options)
    }
}

/// Builder to assist with registry construction.
pub struct ParserRegistryBuilder {
    capsules: HashMap<LanguageId, Arc<dyn LanguageCapsule>>,
    fallback: Vec<LanguageId>,
}

impl Default for ParserRegistryBuilder {
    fn default() -> Self {
        Self {
            capsules: HashMap::new(),
            fallback: Vec::new(),
        }
    }
}

impl ParserRegistryBuilder {
    pub fn register_capsule(mut self, capsule: Arc<dyn LanguageCapsule>) -> Self {
        let info = capsule.info();
        let id = info.id.clone();
        self.capsules.insert(id.clone(), capsule);
        if !self.fallback.contains(&id) {
            self.fallback.push(id);
        }
        self
    }

    pub fn build(self) -> ParserRegistry {
        let dash = DashMap::new();
        let ext_map = DashMap::new();

        for (id, capsule) in self.capsules.into_iter() {
            let info = capsule.info().clone();
            dash.insert(id.clone(), Arc::clone(&capsule));
            for ext in info.extensions.iter() {
                ext_map
                    .entry(ext.to_string())
                    .or_insert_with(Vec::new)
                    .push(id.clone());
            }
        }

        ParserRegistry {
            capsules: dash,
            by_extension: ext_map,
            fallback_chain: RwLock::new(self.fallback),
        }
    }
}
