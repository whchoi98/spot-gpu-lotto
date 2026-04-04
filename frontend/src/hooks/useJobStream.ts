import { useEffect, useRef, useState } from "react";
import type { JobStatus } from "@/lib/types";

interface StatusEvent {
  status: JobStatus;
  [key: string]: unknown;
}

export function useJobStream(jobId: string) {
  const [events, setEvents] = useState<StatusEvent[]>([]);
  const [connected, setConnected] = useState(false);
  const sourceRef = useRef<EventSource | null>(null);

  useEffect(() => {
    const es = new EventSource(`/api/jobs/${jobId}/stream`);
    sourceRef.current = es;
    es.onopen = () => setConnected(true);
    es.addEventListener("status", (e) => {
      try {
        const data = JSON.parse(e.data) as StatusEvent;
        setEvents((prev) => [...prev, data]);
        if (["succeeded", "failed", "cancelled"].includes(data.status)) {
          es.close();
          setConnected(false);
        }
      } catch { /* ignore parse errors */ }
    });
    es.onerror = () => { setConnected(false); es.close(); };
    return () => { es.close(); setConnected(false); };
  }, [jobId]);

  const latestStatus = events.length > 0 ? events[events.length - 1]!.status : null;
  return { events, connected, latestStatus };
}
