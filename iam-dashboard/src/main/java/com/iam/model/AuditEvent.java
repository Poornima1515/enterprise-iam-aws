package com.iam.model;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class AuditEvent {
    private String eventName;
    private String username;
    private String eventTime;
    private String eventSource;
}
