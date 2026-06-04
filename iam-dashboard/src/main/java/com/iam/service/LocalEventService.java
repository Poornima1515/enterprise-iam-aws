package com.iam.service;

import com.iam.model.AuditEvent;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedList;
import java.util.List;

/**
 * Local in-memory event log for immediate feedback in the live feed.
 * CloudTrail takes 5-15 minutes to deliver events, so we keep a local
 * log of recent admin actions to show in the dashboard feed instantly.
 */
@Service
public class LocalEventService {

    private static final int MAX_EVENTS = 50;
    private final LinkedList<AuditEvent> localEvents = new LinkedList<>();

    public void addEvent(String eventName, String username, String details) {
        AuditEvent event = new AuditEvent();
        event.setEventName(eventName);
        event.setUsername(username);
        event.setEventTime(Instant.now().toString());
        event.setEventSource("dashboard.local");
        synchronized (localEvents) {
            localEvents.addFirst(event);
            if (localEvents.size() > MAX_EVENTS) localEvents.removeLast();
        }
    }

    public List<AuditEvent> getRecentEvents(int max) {
        synchronized (localEvents) {
            return new ArrayList<>(localEvents.subList(0, Math.min(max, localEvents.size())));
        }
    }
}
