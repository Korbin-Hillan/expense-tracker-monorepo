export function initTelemetry() {
  // Optional OpenTelemetry setup: enabled only if OTEL_ENABLED=true
  if (process.env.OTEL_ENABLED !== 'true') return;
  (async () => {
    try {
      const { NodeSDK } = await import('@opentelemetry/sdk-node');
      const { getNodeAutoInstrumentations } = await import('@opentelemetry/auto-instrumentations-node');
      const { OTLPTraceExporter } = await import('@opentelemetry/exporter-trace-otlp-http');

      const exporter = new OTLPTraceExporter({
        url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || undefined,
        headers: process.env.OTEL_EXPORTER_OTLP_HEADERS || undefined,
      });

      const sdk = new NodeSDK({
        traceExporter: exporter,
        instrumentations: [getNodeAutoInstrumentations({
          '@opentelemetry/instrumentation-fs': { enabled: false },
        })],
      });
      sdk.start();
      process.on('SIGTERM', async () => {
        await sdk.shutdown();
      });
    } catch (e) {
      console.warn('Telemetry init failed or packages missing:', e);
    }
  })();
}
