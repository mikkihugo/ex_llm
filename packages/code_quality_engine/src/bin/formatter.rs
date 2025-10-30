//! Output Formatting for CLI Results

use anyhow::Result;
use serde_json::json;
use std::io::{self, Write};
use std::fs;

use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct AnalysisResult {
    pub quality_score: f64,
    pub issues_count: usize,
    pub recommendations: Vec<Recommendation>,
    pub metrics: std::collections::HashMap<String, f64>,
    pub patterns_detected: Vec<String>,
    pub intelligence_collected: bool,
    pub per_file_metrics: Vec<PerFileMetric>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Recommendation {
    pub r#type: String,
    pub severity: String,
    pub message: String,
    pub file: Option<String>,
    pub line: Option<usize>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct PerFileMetric {
    pub file: String,
    pub mi: Option<f64>,
    pub cc: Option<f64>,
}

pub struct OutputFormatter {
    format: String,
}

impl OutputFormatter {
    pub fn new(format: String) -> Self {
        Self { format }
    }

    pub fn output(&self, result: &AnalysisResult, output_path: Option<&std::path::Path>) -> Result<()> {
        let writer: Box<dyn io::Write> = if let Some(path) = output_path {
            Box::new(std::fs::File::create(path)?)
        } else {
            Box::new(io::stdout())
        };
        
        match self.format.as_str() {
            "json" => self.output_json_writer(result, writer),
            "sarif" => self.output_sarif_writer(result, writer),
            "html" => self.output_html_writer(result, writer),
            "junit" => self.output_junit_writer(result, writer),
            "github" => self.output_github_writer(result, writer),
            "text" | _ => self.output_text_writer(result, writer),
        }
    }
    
    fn output_text(&self, result: &AnalysisResult) -> Result<()> {
        self.output_text_writer(result, Box::new(io::stdout()))
    }
    
    fn output_text_writer(&self, result: &AnalysisResult, mut writer: Box<dyn io::Write>) -> Result<()> {
        writeln!(writer, "🎯 Singularity Code Quality Analysis")?;
        writeln!(writer, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")?;
        writeln!(writer, "Quality Score:     {:.1}/10", result.quality_score)?;
        writeln!(writer, "Issues Found:      {}", result.issues_count)?;
        writeln!(
            writer,
            "Recommendations:   {}",
            result.recommendations.len()
        )?;
        writeln!(writer)?;

        if !result.recommendations.is_empty() {
            writeln!(writer, "📋 Recommendations:")?;
            for rec in &result.recommendations {
                let severity_icon = match rec.severity.as_str() {
                    "high" => "🔴",
                    "medium" => "🟡",
                    "low" => "🟢",
                    _ => "⚪",
                };
                writeln!(
                    writer,
                    "  {} {}: {}",
                    severity_icon, rec.r#type, rec.message
                )?;
            }
            writeln!(writer)?;
        }

        if !result.patterns_detected.is_empty() {
            writeln!(writer, "🔍 Patterns Detected:")?;
            for pattern in &result.patterns_detected {
                writeln!(writer, "  • {}", pattern)?;
            }
            writeln!(writer)?;
        }

        if result.intelligence_collected {
            writeln!(
                writer,
                "🧠 Intelligence data collected (anonymized) to improve analysis"
            )?;
        }

        if !result.per_file_metrics.is_empty() {
            writeln!(
                writer,
                "📈 Files with metrics: {}",
                result.per_file_metrics.len()
            )?;
        }

        Ok(())
    }

    fn output_json(&self, result: &AnalysisResult) -> Result<()> {
        self.output_json_writer(result, Box::new(io::stdout()))
    }
    
    fn output_json_writer(&self, result: &AnalysisResult, mut writer: Box<dyn io::Write>) -> Result<()> {
        serde_json::to_writer_pretty(&mut writer, result)?;
        writeln!(writer)?;
        Ok(())
    }

    fn output_sarif(&self, result: &AnalysisResult) -> Result<()> {
        self.output_sarif_writer(result, Box::new(io::stdout()))
    }
    
    fn output_sarif_writer(&self, result: &AnalysisResult, mut writer: Box<dyn io::Write>) -> Result<()> {
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
        serde_json::to_writer_pretty(&mut writer, &sarif)?;
        writeln!(writer)?;
        Ok(())
    }
    
    fn output_html_writer(&self, result: &AnalysisResult, mut writer: Box<dyn io::Write>) -> Result<()> {
        let html = generate_html_report(result);
        write!(writer, "{}", html)?;
        Ok(())
    }
    
    fn output_junit_writer(&self, result: &AnalysisResult, mut writer: Box<dyn io::Write>) -> Result<()> {
        let junit = generate_junit_xml(result);
        write!(writer, "{}", junit)?;
        Ok(())
    }
    
    fn output_github_writer(&self, result: &AnalysisResult, _writer: Box<dyn io::Write>) -> Result<()> {
        // GitHub Actions annotations use stdout with special format
        for rec in &result.recommendations {
            let level = match rec.severity.as_str() {
                "critical" | "high" => "error",
                "medium" => "warning",
                _ => "notice",
            };
            
            if let Some(ref file) = rec.file {
                println!("::{} file={}", level, file);
                if let Some(line) = rec.line {
                    println!("::{} file={},line={}", level, file, line);
                }
                println!("::{} {}", level, rec.message);
            } else {
                println!("::{} {}", level, rec.message);
            }
        }
        Ok(())
    }
}

fn generate_html_report(result: &AnalysisResult) -> String {
    format!(r#"<!DOCTYPE html>
<html>
<head>
    <title>Singularity Code Quality Report</title>
    <style>
        body {{ font-family: sans-serif; margin: 40px; }}
        .score {{ font-size: 48px; font-weight: bold; color: {}; }}
        .issue {{ margin: 10px 0; padding: 10px; border-left: 4px solid {}; }}
        .critical {{ border-color: #d32f2f; }}
        .high {{ border-color: #f57c00; }}
        .medium {{ border-color: #fbc02d; }}
        .low {{ border-color: #388e3c; }}
    </style>
</head>
<body>
    <h1>🎯 Singularity Code Quality Analysis</h1>
    <div class="score" style="color: {};">Quality Score: {:.1}/10</div>
    <p>Issues Found: {}</p>
    <p>Recommendations: {}</p>
    
    <h2>📋 Recommendations</h2>
    {}
    
    <h2>🔍 Patterns Detected</h2>
    <ul>{}</ul>
</body>
</html>"#,
        if result.quality_score >= 8.0 { "#388e3c" } else if result.quality_score >= 6.0 { "#fbc02d" } else { "#d32f2f" },
        if result.quality_score >= 8.0 { "#388e3c" } else if result.quality_score >= 6.0 { "#fbc02d" } else { "#d32f2f" },
        if result.quality_score >= 8.0 { "#388e3c" } else if result.quality_score >= 6.0 { "#fbc02d" } else { "#d32f2f" },
        result.quality_score,
        result.issues_count,
        result.recommendations.len(),
        result.recommendations.iter().map(|rec| {
            format!(
                r#"<div class="issue {}"><strong>{}:</strong> {}<br><small>{}</small></div>"#,
                rec.severity,
                rec.r#type,
                rec.message,
                rec.file.as_ref().map(|f| format!("File: {}", f)).unwrap_or_default()
            )
        }).collect::<Vec<_>>().join("\n"),
        result.patterns_detected.iter().map(|p| format!("<li>{}</li>", p)).collect::<Vec<_>>().join("\n")
    )
}

fn generate_junit_xml(result: &AnalysisResult) -> String {
    let mut xml = format!(r#"<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="Code Quality Scanner" tests="{}" failures="{}" errors="{}">"#,
        result.recommendations.len(),
        result.recommendations.iter().filter(|r| r.severity == "high" || r.severity == "critical").count(),
        result.recommendations.iter().filter(|r| r.severity == "critical").count()
    );
    
    for rec in result.recommendations.iter() {
        xml.push_str(&format!(r#"
    <testcase name="{}" classname="{}">"#,
                rec.r#type,
                rec.file.as_ref().unwrap_or(&"unknown".to_string())
            ));
        
        if rec.severity == "high" || rec.severity == "critical" {
            xml.push_str(&format!(r#"
      <failure message="{}">{}</failure>"#,
                rec.message,
                ""
            ));
        }
        
        xml.push_str("\n    </testcase>");
    }
    
    xml.push_str("\n  </testsuite>\n</testsuites>");
    xml
}

fn main() -> anyhow::Result<()> {
    // Minimal entrypoint; real CLI uses singularity_scanner
    Ok(())
}
