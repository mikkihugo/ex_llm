//! Semantic Version Matching with Fuzzy Fallback
//!
//! Allows queries at different specificity levels:
//! - Major: "14" → matches any 14.x.x
//! - Minor: "14.1" → matches any 14.1.x
//! - Patch: "14.1.0" → exact match
//!
//! With smart fallback:
//! Query "14.1.0" → Try 14.1.0 → Try 14.1.x → Try 14.x.x

use serde::{Deserialize, Serialize};
use std::cmp::Ordering;
use std::fmt;

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct SemVer {
  pub major: u32,
  pub minor: Option<u32>,
  pub patch: Option<u32>,
  pub pre_release: Option<String>,
  pub build: Option<String>,
}

impl SemVer {
  /// Parse semantic version from string
  ///
  /// # Examples
  /// ```ignore
  /// SemVer::parse("14") → SemVer { major: 14, minor: None, patch: None }
  /// SemVer::parse("14.1") → SemVer { major: 14, minor: Some(1), patch: None }
  /// SemVer::parse("14.1.0") → SemVer { major: 14, minor: Some(1), patch: Some(0) }
  /// SemVer::parse("14.1.0-beta.1") → With pre_release
  /// ```
  pub fn parse(version: &str) -> Result<Self, String> {
    let (version_core, build) = if let Some((v, b)) = version.split_once('+') {
      (v, Some(b.to_string()))
    } else {
      (version, None)
    };

    let (version_numbers, pre_release) =
      if let Some((v, pr)) = version_core.split_once('-') {
        (v, Some(pr.to_string()))
      } else {
        (version_core, None)
      };

    let parts: Vec<&str> = version_numbers.split('.').collect();

    if parts.is_empty() {
      return Err("Empty version string".to_string());
    }

    let major = parts[0]
      .parse()
      .map_err(|_| format!("Invalid major version: {}", parts[0]))?;

    let minor = if parts.len() > 1 {
      Some(
        parts[1]
          .parse()
          .map_err(|_| format!("Invalid minor version: {}", parts[1]))?,
      )
    } else {
      None
    };

    let patch = if parts.len() > 2 {
      Some(
        parts[2]
          .parse()
          .map_err(|_| format!("Invalid patch version: {}", parts[2]))?,
      )
    } else {
      None
    };

    Ok(Self {
      major,
      minor,
      patch,
      pre_release,
      build,
    })
  }

  /// Get specificity level (1 = major, 2 = minor, 3 = patch)
  pub fn specificity(&self) -> u8 {
    if self.patch.is_some() {
      3
    } else if self.minor.is_some() {
      2
    } else {
      1
    }
  }

  /// Check if this version matches the pattern
  ///
  /// # Examples
  /// ```ignore
  /// pattern "14" matches "14.0.0", "14.1.0", "14.99.99"
  /// pattern "14.1" matches "14.1.0", "14.1.5" but NOT "14.2.0"
  /// pattern "14.1.0" matches only "14.1.0"
  /// ```
  pub fn matches(&self, pattern: &SemVer) -> bool {
    // Major must always match
    if self.major != pattern.major {
      return false;
    }

    // If pattern has minor, it must match
    if let Some(pattern_minor) = pattern.minor {
      match self.minor {
        Some(self_minor) if self_minor == pattern_minor => {
          // Continue checking patch
        }
        _ => return false,
      }
    } else {
      // CodePattern only specifies major, any minor matches
      return true;
    }

    // If pattern has patch, it must match
    if let Some(pattern_patch) = pattern.patch {
      match self.patch {
        Some(self_patch) if self_patch == pattern_patch => {
          // Exact match
        }
        _ => return false,
      }
    } else {
      // CodePattern only specifies major.minor, any patch matches
      return true;
    }

    // Pre-release matching (if pattern specifies pre-release, must match)
    if pattern.pre_release.is_some() {
      return self.pre_release == pattern.pre_release;
    }

    true
  }

  /// Generate fallback patterns
  ///
  /// # Example
  /// ```ignore
  /// "14.1.0" → ["14.1.0", "14.1", "14"]
  /// "14.1" → ["14.1", "14"]
  /// "14" → ["14"]
  /// ```
  pub fn fallback_patterns(&self) -> Vec<SemVer> {
    let mut patterns = vec![self.clone()];

    // If we have patch, add minor-only pattern
    if self.patch.is_some() && self.minor.is_some() {
      patterns.push(SemVer {
        major: self.major,
        minor: self.minor,
        patch: None,
        pre_release: None,
        build: None,
      });
    }

    // If we have minor or patch, add major-only pattern
    if self.minor.is_some() {
      patterns.push(SemVer {
        major: self.major,
        minor: None,
        patch: None,
        pre_release: None,
        build: None,
      });
    }

    patterns
  }

  /// Check if this is more specific than another version
  pub fn more_specific_than(&self, other: &SemVer) -> bool {
    self.specificity() > other.specificity()
  }
}

impl fmt::Display for SemVer {
  fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
    write!(f, "{}", self.major)?;

    if let Some(minor) = self.minor {
      write!(f, ".{}", minor)?;

      if let Some(patch) = self.patch {
        write!(f, ".{}", patch)?;
      }
    }

    if let Some(pre) = &self.pre_release {
      write!(f, "-{}", pre)?;
    }

    if let Some(build) = &self.build {
      write!(f, "+{}", build)?;
    }

    Ok(())
  }
}

impl PartialOrd for SemVer {
  fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
    Some(self.cmp(other))
  }
}

impl Ord for SemVer {
  fn cmp(&self, other: &Self) -> Ordering {
    // Compare major
    match self.major.cmp(&other.major) {
      Ordering::Equal => {}
      ord => return ord,
    }

    // Compare minor
    match (self.minor, other.minor) {
      (Some(a), Some(b)) => match a.cmp(&b) {
        Ordering::Equal => {}
        ord => return ord,
      },
      (Some(_), None) => return Ordering::Greater,
      (None, Some(_)) => return Ordering::Less,
      (None, None) => return Ordering::Equal,
    }

    // Compare patch
    match (self.patch, other.patch) {
      (Some(a), Some(b)) => a.cmp(&b),
      (Some(_), None) => Ordering::Greater,
      (None, Some(_)) => Ordering::Less,
      (None, None) => Ordering::Equal,
    }
  }
}

/// Version matching result with specificity
#[derive(Debug, Clone)]
pub struct VersionMatch {
  pub version: String,
  pub specificity: u8,
  pub is_exact: bool,
}

#[cfg(test)]
mod tests {
  use super::*;

  #[test]
  fn test_parse_versions() {
    let v1 = SemVer::parse("14").unwrap();
    assert_eq!(v1.major, 14);
    assert_eq!(v1.minor, None);
    assert_eq!(v1.specificity(), 1);

    let v2 = SemVer::parse("14.1").unwrap();
    assert_eq!(v2.major, 14);
    assert_eq!(v2.minor, Some(1));
    assert_eq!(v2.patch, None);
    assert_eq!(v2.specificity(), 2);

    let v3 = SemVer::parse("14.1.0").unwrap();
    assert_eq!(v3.major, 14);
    assert_eq!(v3.minor, Some(1));
    assert_eq!(v3.patch, Some(0));
    assert_eq!(v3.specificity(), 3);

    let v4 = SemVer::parse("14.1.0-beta.1").unwrap();
    assert_eq!(v4.pre_release, Some("beta.1".to_string()));
  }

  #[test]
  fn test_version_matching() {
    let pattern_major = SemVer::parse("14").unwrap();
    let pattern_minor = SemVer::parse("14.1").unwrap();
    let pattern_patch = SemVer::parse("14.1.0").unwrap();

    let v14_0_0 = SemVer::parse("14.0.0").unwrap();
    let v14_1_0 = SemVer::parse("14.1.0").unwrap();
    let v14_1_5 = SemVer::parse("14.1.5").unwrap();
    let v14_2_0 = SemVer::parse("14.2.0").unwrap();
    let v15_0_0 = SemVer::parse("15.0.0").unwrap();

    // Major pattern matches all 14.x.x
    assert!(v14_0_0.matches(&pattern_major));
    assert!(v14_1_0.matches(&pattern_major));
    assert!(v14_1_5.matches(&pattern_major));
    assert!(v14_2_0.matches(&pattern_major));
    assert!(!v15_0_0.matches(&pattern_major));

    // Minor pattern matches all 14.1.x
    assert!(!v14_0_0.matches(&pattern_minor));
    assert!(v14_1_0.matches(&pattern_minor));
    assert!(v14_1_5.matches(&pattern_minor));
    assert!(!v14_2_0.matches(&pattern_minor));

    // Patch pattern matches only 14.1.0
    assert!(v14_1_0.matches(&pattern_patch));
    assert!(!v14_1_5.matches(&pattern_patch));
    assert!(!v14_2_0.matches(&pattern_patch));
  }

  #[test]
  fn test_fallback_patterns() {
    let v = SemVer::parse("14.1.0").unwrap();
    let fallbacks = v.fallback_patterns();

    assert_eq!(fallbacks.len(), 3);
    assert_eq!(fallbacks[0].to_string(), "14.1.0");
    assert_eq!(fallbacks[1].to_string(), "14.1");
    assert_eq!(fallbacks[2].to_string(), "14");

    let v2 = SemVer::parse("14.1").unwrap();
    let fallbacks2 = v2.fallback_patterns();
    assert_eq!(fallbacks2.len(), 2);
    assert_eq!(fallbacks2[0].to_string(), "14.1");
    assert_eq!(fallbacks2[1].to_string(), "14");
  }

  #[test]
  fn test_version_ordering() {
    let v1 = SemVer::parse("14.0.0").unwrap();
    let v2 = SemVer::parse("14.1.0").unwrap();
    let v3 = SemVer::parse("14.1.5").unwrap();
    let v4 = SemVer::parse("15.0.0").unwrap();

    assert!(v1 < v2);
    assert!(v2 < v3);
    assert!(v3 < v4);

    let mut versions = vec![v4.clone(), v1.clone(), v3.clone(), v2.clone()];
    versions.sort();
    assert_eq!(versions, vec![v1, v2, v3, v4]);
  }
}
