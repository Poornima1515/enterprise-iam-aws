package com.iam.model;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class IamUserModel {
    private String username;
    private String arn;
    private String createDate;
    private boolean mfaActive;
    private String groups;
    private String status;
}
