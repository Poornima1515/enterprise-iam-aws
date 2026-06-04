package com.iam.service;

import com.iam.model.LoggedInUser;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.iam.IamClient;
import software.amazon.awssdk.services.iam.model.*;
import software.amazon.awssdk.services.sts.StsClient;
import software.amazon.awssdk.services.sts.model.GetCallerIdentityResponse;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class AuthService {

    // Authenticate using access key and secret key
    // Determines the user's role from their IAM group
    public LoggedInUser authenticate(String accessKeyId, String secretAccessKey) {
        try {
            // Step 1: Verify credentials using STS
            AwsBasicCredentials creds = AwsBasicCredentials.create(accessKeyId, secretAccessKey);
            StaticCredentialsProvider credsProvider = StaticCredentialsProvider.create(creds);

            StsClient stsClient = StsClient.builder()
                    .region(Region.US_EAST_1)
                    .credentialsProvider(credsProvider)
                    .build();

            GetCallerIdentityResponse identity = stsClient.getCallerIdentity();
            String arn = identity.arn();

            // Extract username from ARN
            // ARN format: arn:aws:iam::ACCOUNT:user/username
            String username = arn.substring(arn.lastIndexOf("/") + 1);

            // Step 2: Get user's groups using root credentials (admin client)
            IamClient adminIamClient = IamClient.builder()
                    .region(Region.AWS_GLOBAL)
                    .build();

            ListGroupsForUserResponse groupResponse = adminIamClient.listGroupsForUser(
                    ListGroupsForUserRequest.builder().userName(username).build());

            List<String> groups = groupResponse.groups().stream()
                    .map(Group::groupName)
                    .collect(Collectors.toList());

            // Step 3: Determine role from group
            String role = determineRole(groups);

            LoggedInUser user = new LoggedInUser();
            user.setUsername(username);
            user.setRole(role);
            user.setAccessKeyId(accessKeyId);
            user.setSecretAccessKey(secretAccessKey);
            user.setDisplayName(formatDisplayName(username));

            return user;

        } catch (Exception e) {
            System.err.println("Auth failed: " + e.getMessage());
            return null;
        }
    }

    private String determineRole(List<String> groups) {
        if (groups.contains("Admin")) return "Admin";
        if (groups.contains("Developer")) return "Developer";
        if (groups.contains("Tester")) return "Tester";
        if (groups.contains("DatabaseAdmin")) return "DatabaseAdmin";
        if (groups.contains("Auditor")) return "Auditor";
        return "Unknown";
    }

    private String formatDisplayName(String username) {
        // admin-user → Admin User
        String[] parts = username.split("[-_.]");
        StringBuilder sb = new StringBuilder();
        for (String part : parts) {
            if (!part.isEmpty()) {
                sb.append(Character.toUpperCase(part.charAt(0)))
                  .append(part.substring(1)).append(" ");
            }
        }
        return sb.toString().trim();
    }
}
