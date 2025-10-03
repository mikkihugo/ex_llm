/**
 * @license
 * Copyright 2025 Google LLC
 * SPDX-License-Identifier: Apache-2.0
 */
/**
 * A strategy that attempts a list of child strategies in order (Chain of Responsibility).
 */
export class CompositeStrategy {
    name;
    strategies;
    /**
     * Initializes the CompositeStrategy.
     * @param strategies The strategies to try, in order of priority. The last strategy must be terminal.
     * @param name The name of this composite configuration (e.g., 'router' or 'composite').
     */
    constructor(strategies, name = 'composite') {
        this.strategies = strategies;
        this.name = name;
    }
    async route(context, config, baseLlmClient) {
        const startTime = performance.now();
        // Separate non-terminal strategies from the terminal one.
        // This separation allows TypeScript to understand the control flow guarantees.
        const nonTerminalStrategies = this.strategies.slice(0, -1);
        const terminalStrategy = this.strategies[this.strategies.length - 1];
        // Try non-terminal strategies, allowing them to fail gracefully.
        for (const strategy of nonTerminalStrategies) {
            try {
                const decision = await strategy.route(context, config, baseLlmClient);
                if (decision) {
                    return this.finalizeDecision(decision, startTime);
                }
            }
            catch (error) {
                console.error(`[Routing] Strategy '${strategy.name}' failed. Continuing to next strategy. Error:`, error);
            }
        }
        // If no other strategy matched, execute the terminal strategy.
        try {
            const decision = await terminalStrategy.route(context, config, baseLlmClient);
            return this.finalizeDecision(decision, startTime);
        }
        catch (error) {
            console.error(`[Routing] Critical Error: Terminal strategy '${terminalStrategy.name}' failed. Routing cannot proceed. Error:`, error);
            throw error;
        }
    }
    /**
     * Helper function to enhance the decision metadata with composite information.
     */
    finalizeDecision(decision, startTime) {
        const endTime = performance.now();
        const totalLatency = endTime - startTime;
        // Combine the source paths: composite_name/child_source (e.g. 'router/default')
        const compositeSource = `${this.name}/${decision.metadata.source}`;
        return {
            ...decision,
            metadata: {
                ...decision.metadata,
                source: compositeSource,
                latencyMs: decision.metadata.latencyMs || totalLatency,
            },
        };
    }
}
//# sourceMappingURL=compositeStrategy.js.map