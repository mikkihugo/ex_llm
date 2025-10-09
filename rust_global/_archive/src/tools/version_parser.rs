//! Version parsing and range handling
//!
//! Handles semantic versioning, version ranges, and code snippet compatibility.

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::cmp::Ordering;

/// Version specifier types
#[derive(Debug, Clone, PartialEq)]
pub enum VersionSpecifier {
    /// Exact version: "1.2.3"
    Exact(String),
    /// Latest: "latest" or "@latest"
    Latest,
    /// LTS: "lts" or "@lts"
    Lts,
    /// Stable: "stable" or "@stable"
    Stable,
    /// Beta: "beta" or "@beta"
    Beta,
    /// Alpha: "alpha" or "@alpha"
    Alpha,
    /// Next: "next" or "@next"
    Next,
    /// Range: ">=1.0.0 <2.0.0"
    Range(VersionRange),
}

/// Version range
#[derive(Debug, Clone, PartialEq)]
pub struct VersionRange {
    pub constraints: Vec<VersionConstraint>,
}

/// Version constraint
#[derive(Debug, Clone, PartialEq)]
pub enum VersionConstraint {
    GreaterThan(String),
    GreaterThanOrEqual(String),
    LessThan(String),
    LessThanOrEqual(String),
    Tilde(String),      // ~1.2.3
    Caret(String),      // ^1.2.3
    Equals(String),
}

/// Parsed version
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Version {
    pub major: u32,
    pub minor: u32,
    pub patch: u32,
    pub prerelease: Option<String>,
    pub build: Option<String>,
}

/// Version compatibility info
#[derive(Debug, Serialize)]
pub struct VersionCompatibility {
    pub is_compatible: bool,
    pub breaking_changes: Vec<String>,
    pub new_features: Vec<String>,
    pub bug_fixes: Vec<String>,
    pub migration_notes: Vec<String>,
}

impl VersionSpecifier {
    /// Parse version specifier from string
    pub fn parse(spec: &str) -> Result<Self> {
        let spec = spec.trim();
        
        match spec {
            "latest" | "@latest" => Ok(VersionSpecifier::Latest),
            "lts" | "@lts" => Ok(VersionSpecifier::Lts),
            "stable" | "@stable" => Ok(VersionSpecifier::Stable),
            "beta" | "@beta" => Ok(VersionSpecifier::Beta),
            "alpha" | "@alpha" => Ok(VersionSpecifier::Alpha),
            "next" | "@next" => Ok(VersionSpecifier::Next),
            _ if spec.starts_with('@') => Ok(VersionSpecifier::Exact(spec[1..].to_string())),
            _ if spec.contains("||") => {
                // Handle OR ranges like "1.x || 2.x"
                let ranges = spec.split("||").map(|r| VersionRange::parse(r.trim())).collect::<Result<Vec<_>>>()?;
                Ok(VersionSpecifier::Range(VersionRange::or(ranges)))
            },
            _ if spec.contains(' ') => {
                // Handle space-separated ranges like ">=1.0.0 <2.0.0"
                Ok(VersionSpecifier::Range(VersionRange::parse(spec)?))
            },
            _ => {
                // Check if it's a range operator
                if spec.starts_with(">=") {
                    Ok(VersionSpecifier::Range(VersionRange::parse(spec)?))
                } else if spec.starts_with(">") {
                    Ok(VersionSpecifier::Range(VersionRange::parse(spec)?))
                } else if spec.starts_with("<=") {
                    Ok(VersionSpecifier::Range(VersionRange::parse(spec)?))
                } else if spec.starts_with("<") {
                    Ok(VersionSpecifier::Range(VersionRange::parse(spec)?))
                } else if spec.starts_with("~") {
                    Ok(VersionSpecifier::Range(VersionRange::parse(spec)?))
                } else if spec.starts_with("^") {
                    Ok(VersionSpecifier::Range(VersionRange::parse(spec)?))
                } else {
                    // Assume exact version
                    Ok(VersionSpecifier::Exact(spec.to_string()))
                }
            }
        }
    }

    /// Check if a version matches this specifier
    pub fn matches(&self, version: &Version) -> bool {
        match self {
            VersionSpecifier::Exact(exact) => {
                version.to_string() == *exact
            },
            VersionSpecifier::Latest => {
                // This would need to be resolved against available versions
                true
            },
            VersionSpecifier::Lts => {
                // This would need to be resolved against LTS versions
                true
            },
            VersionSpecifier::Stable => {
                version.prerelease.is_none()
            },
            VersionSpecifier::Beta => {
                version.prerelease.as_ref().map_or(false, |p| p.contains("beta"))
            },
            VersionSpecifier::Alpha => {
                version.prerelease.as_ref().map_or(false, |p| p.contains("alpha"))
            },
            VersionSpecifier::Next => {
                version.prerelease.is_some()
            },
            VersionSpecifier::Range(range) => {
                range.matches(version)
            }
        }
    }

    /// Get code snippet compatibility warning
    pub fn get_compatibility_warning(&self, current_version: &Version) -> Option<String> {
        match self {
            VersionSpecifier::Range(range) => {
                if let Some(constraint) = range.constraints.first() {
                    match constraint {
                        VersionConstraint::GreaterThanOrEqual(ver) | 
                        VersionConstraint::GreaterThan(ver) => {
                            if let Ok(min_ver) = Version::parse(ver) {
                                if current_version.major != min_ver.major {
                                    return Some(format!(
                                        "⚠️  Major version mismatch: Code requires {} but you have {}.{}.{} - API may have breaking changes!",
                                        ver, current_version.major, current_version.minor, current_version.patch
                                    ));
                                }
                            }
                        },
                        _ => {}
                    }
                }
                None
            },
            _ => None
        }
    }
}

impl VersionRange {
    /// Parse version range from string
    pub fn parse(spec: &str) -> Result<Self> {
        let constraints = spec.split_whitespace()
            .map(|constraint| {
                if constraint.starts_with(">=") {
                    Ok(VersionConstraint::GreaterThanOrEqual(constraint[2..].to_string()))
                } else if constraint.starts_with(">") {
                    Ok(VersionConstraint::GreaterThan(constraint[1..].to_string()))
                } else if constraint.starts_with("<=") {
                    Ok(VersionConstraint::LessThanOrEqual(constraint[2..].to_string()))
                } else if constraint.starts_with("<") {
                    Ok(VersionConstraint::LessThan(constraint[1..].to_string()))
                } else if constraint.starts_with("~") {
                    Ok(VersionConstraint::Tilde(constraint[1..].to_string()))
                } else if constraint.starts_with("^") {
                    Ok(VersionConstraint::Caret(constraint[1..].to_string()))
                } else if constraint.starts_with("=") {
                    Ok(VersionConstraint::Equals(constraint[1..].to_string()))
                } else {
                    // Assume equals if no operator
                    Ok(VersionConstraint::Equals(constraint.to_string()))
                }
            })
            .collect::<Result<Vec<_>>>()?;

        Ok(VersionRange { constraints })
    }

    /// Create OR range from multiple ranges
    pub fn or(ranges: Vec<VersionRange>) -> Self {
        // Flatten all constraints
        let constraints = ranges.into_iter()
            .flat_map(|r| r.constraints)
            .collect();
        VersionRange { constraints }
    }

    /// Check if version matches this range
    pub fn matches(&self, version: &Version) -> bool {
        self.constraints.iter().all(|constraint| {
            match constraint {
                VersionConstraint::GreaterThan(ver) => {
                    if let Ok(ver) = Version::parse(ver) {
                        version > &ver
                    } else {
                        false
                    }
                },
                VersionConstraint::GreaterThanOrEqual(ver) => {
                    if let Ok(ver) = Version::parse(ver) {
                        version >= &ver
                    } else {
                        false
                    }
                },
                VersionConstraint::LessThan(ver) => {
                    if let Ok(ver) = Version::parse(ver) {
                        version < &ver
                    } else {
                        false
                    }
                },
                VersionConstraint::LessThanOrEqual(ver) => {
                    if let Ok(ver) = Version::parse(ver) {
                        version <= &ver
                    } else {
                        false
                    }
                },
                VersionConstraint::Tilde(ver) => {
                    if let Ok(ver) = Version::parse(ver) {
                        version.major == ver.major && version.minor == ver.minor && version >= &ver
                    } else {
                        false
                    }
                },
                VersionConstraint::Caret(ver) => {
                    if let Ok(ver) = Version::parse(ver) {
                        if ver.major == 0 {
                            // For 0.x versions, only patch changes are allowed
                            version.major == ver.major && version.minor == ver.minor && version >= &ver
                        } else {
                            // For 1.x+ versions, minor and patch changes are allowed
                            version.major == ver.major && version >= &ver
                        }
                    } else {
                        false
                    }
                },
                VersionConstraint::Equals(ver) => {
                    version.to_string() == *ver
                }
            }
        })
    }
}

impl Version {
    /// Parse version from string
    pub fn parse(version: &str) -> Result<Self> {
        let version = version.trim();
        
        // Split on + for build metadata
        let (version, build) = if let Some(pos) = version.find('+') {
            (version[..pos].to_string(), Some(version[pos+1..].to_string()))
        } else {
            (version.to_string(), None)
        };
        
        // Split on - for prerelease
        let (version, prerelease) = if let Some(pos) = version.find('-') {
            (version[..pos].to_string(), Some(version[pos+1..].to_string()))
        } else {
            (version, None)
        };
        
        // Parse major.minor.patch
        let parts: Vec<&str> = version.split('.').collect();
        if parts.len() < 3 {
            return Err(anyhow::anyhow!("Invalid version format: {}", version));
        }
        
        let major = parts[0].parse()?;
        let minor = parts[1].parse()?;
        let patch = parts[2].parse()?;
        
        Ok(Version {
            major,
            minor,
            patch,
            prerelease,
            build,
        })
    }

    /// Convert to string
    pub fn to_string(&self) -> String {
        let mut version = format!("{}.{}.{}", self.major, self.minor, self.patch);
        if let Some(prerelease) = &self.prerelease {
            version.push('-');
            version.push_str(prerelease);
        }
        if let Some(build) = &self.build {
            version.push('+');
            version.push_str(build);
        }
        version
    }

    /// Check compatibility with another version
    pub fn check_compatibility(&self, other: &Version) -> VersionCompatibility {
        let mut breaking_changes = Vec::new();
        let mut new_features = Vec::new();
        let mut bug_fixes = Vec::new();
        let mut migration_notes = Vec::new();
        
        let is_compatible = if self.major != other.major {
            breaking_changes.push(format!("Major version changed from {} to {}", self.major, other.major));
            migration_notes.push("Check breaking changes documentation".to_string());
            false
        } else if self.minor != other.minor {
            new_features.push(format!("Minor version changed from {} to {}", self.minor, other.minor));
            true
        } else if self.patch != other.patch {
            bug_fixes.push(format!("Patch version changed from {} to {}", self.patch, other.patch));
            true
        } else {
            true
        };

        VersionCompatibility {
            is_compatible,
            breaking_changes,
            new_features,
            bug_fixes,
            migration_notes,
        }
    }
}

impl PartialOrd for Version {
    fn partial_cmp(&self, other: &Version) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

impl Ord for Version {
    fn cmp(&self, other: &Version) -> Ordering {
        match self.major.cmp(&other.major) {
            Ordering::Equal => {
                match self.minor.cmp(&other.minor) {
                    Ordering::Equal => {
                        match self.patch.cmp(&other.patch) {
                            Ordering::Equal => {
                                // Compare prerelease
                                match (&self.prerelease, &other.prerelease) {
                                    (None, None) => Ordering::Equal,
                                    (None, Some(_)) => Ordering::Greater,
                                    (Some(_), None) => Ordering::Less,
                                    (Some(a), Some(b)) => a.cmp(b),
                                }
                            },
                            other => other,
                        }
                    },
                    other => other,
                }
            },
            other => other,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_version_parsing() {
        let v = Version::parse("1.2.3").unwrap();
        assert_eq!(v.major, 1);
        assert_eq!(v.minor, 2);
        assert_eq!(v.patch, 3);
        assert_eq!(v.prerelease, None);
        assert_eq!(v.build, None);
    }

    #[test]
    fn test_version_with_prerelease() {
        let v = Version::parse("1.2.3-beta.1").unwrap();
        assert_eq!(v.major, 1);
        assert_eq!(v.minor, 2);
        assert_eq!(v.patch, 3);
        assert_eq!(v.prerelease, Some("beta.1".to_string()));
        assert_eq!(v.build, None);
    }

    #[test]
    fn test_version_with_build() {
        let v = Version::parse("1.2.3+20240115").unwrap();
        assert_eq!(v.major, 1);
        assert_eq!(v.minor, 2);
        assert_eq!(v.patch, 3);
        assert_eq!(v.prerelease, None);
        assert_eq!(v.build, Some("20240115".to_string()));
    }

    #[test]
    fn test_version_range_parsing() {
        let range = VersionRange::parse(">=1.0.0 <2.0.0").unwrap();
        assert_eq!(range.constraints.len(), 2);
    }

    #[test]
    fn test_version_specifier_parsing() {
        assert_eq!(VersionSpecifier::parse("@latest").unwrap(), VersionSpecifier::Latest);
        assert_eq!(VersionSpecifier::parse("^1.2.3").unwrap(), VersionSpecifier::Range(VersionRange::parse("^1.2.3").unwrap()));
        assert_eq!(VersionSpecifier::parse("1.2.3").unwrap(), VersionSpecifier::Exact("1.2.3".to_string()));
    }
}
