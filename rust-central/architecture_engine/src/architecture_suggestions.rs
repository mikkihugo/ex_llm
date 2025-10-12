    fn generate_microservice_suggestions(
        &self,
        description: &str,
        context: Option<&str>,
    ) -> Vec<String> {
        let base_name = self.extract_base_name(description);
        vec![format!("{}-service", base_name.to_kebab_case())]
    }
    fn generate_microservice_suggestions(
        &self,
        description: &str,
        context: Option<&str>,
    ) -> Vec<String> {
        let base_name = self.extract_base_name(description);
        let mut suggestions = Vec::new();

        // Microservice naming patterns (kebab-case)
        suggestions.extend(vec![
            format!("{}", base_name.to_kebab_case()),
            format!("{}-service", base_name.to_kebab_case()),
            format!("{}-microservice", base_name.to_kebab_case()),
            format!("{}-api", base_name.to_kebab_case()),
            format!("{}-gateway", base_name.to_kebab_case()),
        ]);

        // Common microservice suffixes
        let suffixes = vec![
            "service",
            "microservice",
            "api",
            "gateway",
            "proxy",
            "handler",
            "processor",
            "worker",
            "consumer",
            "producer",
            "manager",
            "controller",
            "coordinator",
            "orchestrator",
            "aggregator",
            "dispatcher",
            "router",
            "broker",
            "adapter",
            "bridge",
            "connector",
            "interface",
            "client",
            "server",
            "agent",
            "daemon",
        ];

        for suffix in &suffixes {
            suggestions.extend(vec![
                format!("{}-{}", base_name.to_kebab_case(), suffix),
                format!("{}-{}", base_name.to_kebab_case(), suffix),
            ]);
        }

        // Domain-specific microservice patterns
        let domains = vec![
            "user",
            "auth",
            "payment",
            "order",
            "inventory",
            "shipping",
            "notification",
            "email",
            "sms",
            "push",
            "analytics",
            "logging",
            "monitoring",
            "metrics",
            "tracing",
            "audit",
            "compliance",
            "billing",
            "subscription",
            "catalog",
            "search",
            "recommendation",
            "chat",
            "messaging",
            "queue",
            "event",
            "stream",
            "batch",
        ];

        for domain in &domains {
            if description.to_lowercase().contains(domain) {
                suggestions.extend(vec![
                    format!("{}-{}", domain, base_name.to_kebab_case()),
                    format!("{}-{}-service", domain, base_name.to_kebab_case()),
                    format!("{}-{}-api", domain, base_name.to_kebab_case()),
                    format!("{}-{}-gateway", domain, base_name.to_kebab_case()),
                ]);
            }
        }

        // Architecture patterns
        suggestions.extend(vec![
            format!("{}-core", base_name.to_kebab_case()),
            format!("{}-shared", base_name.to_kebab_case()),
            format!("{}-common", base_name.to_kebab_case()),
            format!("{}-base", base_name.to_kebab_case()),
            format!("{}-foundation", base_name.to_kebab_case()),
        ]);

        // Environment patterns
        suggestions.extend(vec![
            format!("{}-dev", base_name.to_kebab_case()),
            format!("{}-test", base_name.to_kebab_case()),
            format!("{}-staging", base_name.to_kebab_case()),
            format!("{}-prod", base_name.to_kebab_case()),
            format!("{}-local", base_name.to_kebab_case()),
        ]);

        // Version patterns
        suggestions.extend(vec![
            format!("{}-v1", base_name.to_kebab_case()),
            format!("{}-v2", base_name.to_kebab_case()),
            format!("{}-v3", base_name.to_kebab_case()),
            format!("{}-next", base_name.to_kebab_case()),
            format!("{}-beta", base_name.to_kebab_case()),
            format!("{}-alpha", base_name.to_kebab_case()),
        ]);

        // Language-specific patterns
        suggestions.extend(vec![
            format!("{}-go", base_name.to_kebab_case()),
            format!("{}-rust", base_name.to_kebab_case()),
            format!("{}-js", base_name.to_kebab_case()),
            format!("{}-ts", base_name.to_kebab_case()),
            format!("{}-py", base_name.to_kebab_case()),
            format!("{}-java", base_name.to_kebab_case()),
            format!("{}-ex", base_name.to_kebab_case()),
            format!("{}-gleam", base_name.to_kebab_case()),
        ]);

        // Container patterns
        suggestions.extend(vec![
            format!("{}-container", base_name.to_kebab_case()),
            format!("{}-pod", base_name.to_kebab_case()),
            format!("{}-deployment", base_name.to_kebab_case()),
            format!("{}-daemonset", base_name.to_kebab_case()),
            format!("{}-statefulset", base_name.to_kebab_case()),
        ]);

        // Cloud patterns
        suggestions.extend(vec![
            format!("{}-aws", base_name.to_kebab_case()),
            format!("{}-gcp", base_name.to_kebab_case()),
            format!("{}-azure", base_name.to_kebab_case()),
            format!("{}-k8s", base_name.to_kebab_case()),
            format!("{}-docker", base_name.to_kebab_case()),
        ]);

        suggestions
    }
    fn generate_library_suggestions(
        &self,
        description: &str,
        context: Option<&str>,
    ) -> Vec<String> {
        let base_name = self.extract_base_name(description);
        let mut suggestions = Vec::new();

        // Library naming patterns
        suggestions.extend(vec![
            format!("{}", base_name.to_lowercase()),
            format!("{}lib", base_name.to_lowercase()),
            format!("{}_lib", base_name.to_lowercase()),
            format!("{}-lib", base_name.to_lowercase()),
            format!("lib{}", base_name.to_lowercase()),
            format!("lib_{}", base_name.to_lowercase()),
            format!("lib-{}", base_name.to_lowercase()),
        ]);

        // Common library suffixes
        let suffixes = vec![
            "lib",
            "libs",
            "library",
            "libraries",
            "core",
            "common",
            "shared",
            "utils",
            "utilities",
            "helpers",
            "helpers",
            "tools",
            "toolkit",
            "kit",
            "pack",
            "package",
            "pkg",
            "sdk",
            "api",
            "client",
            "server",
            "engine",
            "framework",
            "platform",
            "base",
            "foundation",
            "foundation",
            "common",
            "shared",
            "core",
            "base",
        ];

        for suffix in &suffixes {
            suggestions.extend(vec![
                format!("{}{}", base_name.to_lowercase(), suffix),
                format!("{}_{}", base_name.to_lowercase(), suffix),
                format!("{}-{}", base_name.to_lowercase(), suffix),
                format!("{}{}", suffix, base_name.to_lowercase()),
                format!("{}_{}", suffix, base_name.to_lowercase()),
                format!("{}-{}", suffix, base_name.to_lowercase()),
            ]);
        }

        // Language-specific library patterns
        suggestions.extend(vec![
            format!("{}-go", base_name.to_lowercase()),
            format!("{}-rust", base_name.to_lowercase()),
            format!("{}-js", base_name.to_lowercase()),
            format!("{}-ts", base_name.to_lowercase()),
            format!("{}-py", base_name.to_lowercase()),
            format!("{}-java", base_name.to_lowercase()),
            format!("{}-cpp", base_name.to_lowercase()),
            format!("{}-ex", base_name.to_lowercase()),
            format!("{}-gleam", base_name.to_lowercase()),
        ]);

        // Package manager patterns
        suggestions.extend(vec![
            format!("@{}", base_name.to_lowercase()),
            format!("@{}", base_name.to_lowercase()),
            format!("{}", base_name.to_lowercase()),
            format!("{}", base_name.to_lowercase()),
        ]);

        // Version patterns
        suggestions.extend(vec![
            format!("{}-v1", base_name.to_lowercase()),
            format!("{}-v2", base_name.to_lowercase()),
            format!("{}-v3", base_name.to_lowercase()),
            format!("{}-next", base_name.to_lowercase()),
            format!("{}-beta", base_name.to_lowercase()),
            format!("{}-alpha", base_name.to_lowercase()),
        ]);

        suggestions
    }
    fn generate_monorepo_suggestions(
        &self,
        description: &str,
        context: Option<&str>,
    ) -> Vec<String> {
        let base_name = self.extract_base_name(description);
        let mut suggestions = Vec::new();

        // HashiCorp-style naming patterns
        if description.to_lowercase().contains("hashicorp")
            || description.to_lowercase().contains("hash")
            || context.map_or(false, |c| c.to_lowercase().contains("hashicorp"))
        {
            // HashiCorp patterns: terraform, consul, vault, nomad, waypoint
            suggestions.extend(vec![
                format!("{}", base_name.to_lowercase()),
                format!("{}-{}", base_name.to_lowercase(), "core"),
                format!("{}-{}", base_name.to_lowercase(), "cli"),
                format!("{}-{}", base_name.to_lowercase(), "sdk"),
                format!("{}-{}", base_name.to_lowercase(), "api"),
                format!("{}-{}", base_name.to_lowercase(), "server"),
                format!("{}-{}", base_name.to_lowercase(), "agent"),
                format!("{}-{}", base_name.to_lowercase(), "client"),
                format!("{}-{}", base_name.to_lowercase(), "provider"),
                format!("{}-{}", base_name.to_lowercase(), "plugin"),
            ]);
        }

        // Google-style naming patterns
        if description.to_lowercase().contains("google")
            || description.to_lowercase().contains("gcp")
            || context.map_or(false, |c| c.to_lowercase().contains("google"))
        {
            // Google patterns: kubernetes, tensorflow, protobuf, gRPC
            suggestions.extend(vec![
                format!("{}", base_name.to_lowercase()),
                format!("{}-{}", base_name.to_lowercase(), "k8s"),
                format!("{}-{}", base_name.to_lowercase(), "tf"),
                format!("{}-{}", base_name.to_lowercase(), "pb"),
                format!("{}-{}", base_name.to_lowercase(), "grpc"),
                format!("{}-{}", base_name.to_lowercase(), "api"),
                format!("{}-{}", base_name.to_lowercase(), "sdk"),
                format!("{}-{}", base_name.to_lowercase(), "client"),
                format!("{}-{}", base_name.to_lowercase(), "server"),
                format!("{}-{}", base_name.to_lowercase(), "operator"),
            ]);
        }
    }
