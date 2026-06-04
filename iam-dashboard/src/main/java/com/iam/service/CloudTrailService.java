package com.iam.service;

import com.iam.model.AuditEvent;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.cloudtrail.CloudTrailClient;
import software.amazon.awssdk.services.cloudtrail.model.*;

import java.util.*;

@Service
public class CloudTrailService {

    private final CloudTrailClient client = CloudTrailClient.builder()
            .region(Region.US_EAST_1).build();

    @Value("${app.cloudtrail.name}")
    private String trailName;

    public List<AuditEvent> getRecentEvents(int max) {
        List<AuditEvent> events = new ArrayList<>();
        try {
            client.lookupEvents(LookupEventsRequest.builder()
                    .lookupAttributes(LookupAttribute.builder()
                            .attributeKey(LookupAttributeKey.EVENT_SOURCE)
                            .attributeValue("iam.amazonaws.com").build())
                    .maxResults(max).build())
                    .events().forEach(e -> {
                        AuditEvent a = new AuditEvent();
                        a.setEventName(e.eventName());
                        a.setUsername(e.username() != null ? e.username() : "AWS Service");
                        a.setEventTime(e.eventTime().toString());
                        a.setEventSource("iam.amazonaws.com");
                        events.add(a);
                    });
        } catch (Exception e) {
            System.err.println("CloudTrail error: " + e.getMessage());
        }
        return events;
    }

    public Map<String, Object> getTrailStatus() {
        Map<String, Object> status = new HashMap<>();
        try {
            GetTrailStatusResponse r = client.getTrailStatus(
                    GetTrailStatusRequest.builder().name(trailName).build());
            status.put("isLogging", r.isLogging());
            status.put("trailName", trailName);
            status.put("latestDeliveryTime", r.latestDeliveryTime() != null
                    ? r.latestDeliveryTime().toString() : "N/A");
            status.put("status", r.isLogging() ? "Active" : "Stopped");
        } catch (Exception e) {
            status.put("isLogging", false);
            status.put("status", "Error");
            status.put("trailName", trailName);
        }
        return status;
    }
}
