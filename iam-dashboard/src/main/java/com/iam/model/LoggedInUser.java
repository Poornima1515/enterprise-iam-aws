package com.iam.model;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class LoggedInUser {
    private String username;
    private String role;         // Admin, Developer, Tester, DatabaseAdmin, Auditor
    private String accessKeyId;
    private String secretAccessKey;
    private String displayName;
}
