package com.iam.model;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.io.Serializable;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class LoggedInUser implements Serializable {
    private static final long serialVersionUID = 1L;
    private String username;
    private String role;         // Admin, Developer, Tester, DatabaseAdmin, Auditor
    private String accessKeyId;
    private String secretAccessKey;
    private String displayName;
}
