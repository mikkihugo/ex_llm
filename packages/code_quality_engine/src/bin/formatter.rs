//! Output Formatting for CLI Results

use std::io::{self, Write};
use anyhow::Result;
use serde_json::json;

use super::AnalysisResult;

pub struct OutputFormatter {
    format: String,
}

impl OutputFormatter {
    pub fn new(format: String) -> Self {
        Self { format }
    }

    pub fn output(&self, result: &AnalysisResult) -> Result<()> {
        match self.format.as_str() {
            "json" => self.output_json(result),
            "sarif" => self.output_sarif(result),
            "text" | _ => self.output_text(result),
        }
    }

    fn output_text(&self, result: &AnalysisResult) -> Result<()> {
        let stdout = io::stdout();
        let mut handle = stdout.lock();

        writeln!(handle, "🎯 Singularity Code Quality Analysis")?;
        writeln!(handle, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")?;
        writeln!(handle, "Quality Score:     {:.1}/10", result.quality_score)?;
        writeln!(handle, "Issues Found:      {}", result.issues_count)?;
        writeln!(handle, "Recommendations:   {}", result.recommendations.len())?;
        writeln!(handle)?;

        if !result.recommendations.is_empty() {
            writeln!(handle, "📋 Recommendations:")?;
            for rec in &result.recommendations {
                let severity_icon = match rec.severity.as_str() {
                    "high" => "🔴",
                    "medium" => "🟡",
                    "low" => "🟢",
                    _ => "⚪",
                };
                writeln!(handle, "  {} {}: {}", severity_icon, rec.r#type, rec.message)?;
            }
            writeln!(handle)?;
        }

        if !result.patterns_detected.is_empty() {
            writeln!(handle, "🔍 Patterns Detected:")?;
            for pattern in &result.patterns_detected {
                writeln!(handle, "  • {}", pattern)?;
            }
            writeln!(handle)?;
        }

        if result.intelligence_collected {
            writeln!(handle, "🧠 Intelligence data collected (anonymized) to improve analysis")?;
        }

        Ok(())
    }

    fn output_json(&self, result: &AnalysisResult) -> Result<()> {
        let stdout = io::stdout();
        let mut handle = stdout.lock();

        serde_json::to_writer_pretty(&mut handle, result)?;
        writeln!(handle)?;
        Ok(())
    }

    fn output_sarif(&self, result: &AnalysisResult) -> Result<()> {
        // SARIF (Static Analysis Results Interchange Format) for GitHub integration
        let sarif = json!({
            "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
            "version": "2.1.0",
            "runs": [{
                "tool": {
                    "driver": {
                        "name": "Singularity Code Quality Scanner",
                        "version": env!("CARGO_PKG_VERSION"),
                        "informationUri": "https://singularity.dev"
                    }
                },
                "results": result.recommendations.iter().map(|rec| {
                    json!({
                        "ruleId": rec.r#type,
                        "level": match rec.severity.as_str() {
                            "high" => "error",
                            "medium" => "warning",
                            "low" => "note",
                            _ => "note"
                        },
                        "message": {
                            "text": rec.message
                        },
                        "locations": rec.file.as_ref().map(|file| vec![json!({
                            "physicalLocation": {
                                "artifactLocation": {
                                    "uri": file
                                },
                                "region": rec.line.map(|line| json!({"startLine": line}))
                            }
                        })]).unwrap_or_default()
                    })
                }).collect::<Vec<_>>()
            }]
        });

        let stdout = io::stdout();
        let mut handle = stdout.lock();
        serde_json::to_writer_pretty(&mut handle, &sarif)?;
        writeln!(handle)?;
        Ok(())
    }
}