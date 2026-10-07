"""Send synthetic OTLP spans to a local Aspire dashboard."""
import sys

from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

proto = sys.argv[1]
n_traces = int(sys.argv[2])
per = int(sys.argv[3])

if proto == "http":
    from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter

    exp = OTLPSpanExporter(endpoint="http://localhost:4318/v1/traces")
else:
    from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

    exp = OTLPSpanExporter(endpoint="http://localhost:4317", insecure=True)

tp = TracerProvider(resource=Resource.create({"service.name": f"demo-api-{proto}"}))
tp.add_span_processor(BatchSpanProcessor(exp, max_export_batch_size=512))
t = tp.get_tracer("load")

for _ in range(n_traces):
    with t.start_as_current_span("GET /orders", kind=trace.SpanKind.SERVER) as s:
        s.set_attribute("http.request.method", "GET")
        s.set_attribute("url.path", "/orders")
        s.set_attribute("http.response.status_code", 200)
        for j in range(per - 1):
            with t.start_as_current_span(f"db.query {j}", kind=trace.SpanKind.CLIENT) as c:
                c.set_attribute("db.system", "postgresql")
                c.set_attribute("db.statement", "SELECT * FROM orders WHERE id = @p0")

tp.force_flush()
tp.shutdown()
print(f"sent {n_traces * per} spans via {proto}")
