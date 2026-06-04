package com.iam.service;

import com.iam.model.IamUserModel;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.iam.IamClient;
import software.amazon.awssdk.services.iam.model.*;

import java.util.*;
import java.util.stream.Collectors;

@Service
public class IamService {

    // Uses root credentials from ~/.aws/credentials
    private final IamClient iamClient = IamClient.builder()
            .region(Region.AWS_GLOBAL)
            .build();

    public List<IamUserModel> getAllUsers() {
        List<IamUserModel> users = new ArrayList<>();
        try {
            for (User user : iamClient.listUsers().users()) {
                IamUserModel model = new IamUserModel();
                model.setUsername(user.userName());
                model.setArn(user.arn());
                model.setCreateDate(user.createDate().toString());

                ListMfaDevicesResponse mfa = iamClient.listMFADevices(
                        ListMfaDevicesRequest.builder().userName(user.userName()).build());
                model.setMfaActive(!mfa.mfaDevices().isEmpty());

                ListGroupsForUserResponse grp = iamClient.listGroupsForUser(
                        ListGroupsForUserRequest.builder().userName(user.userName()).build());
                String groups = grp.groups().stream().map(Group::groupName)
                        .collect(Collectors.joining(", "));
                model.setGroups(groups.isEmpty() ? "No Group" : groups);
                model.setStatus("Active");
                users.add(model);
            }
        } catch (Exception e) {
            System.err.println("Error fetching users: " + e.getMessage());
        }
        return users;
    }

    public List<Map<String, String>> getAllGroups() {
        List<Map<String, String>> groups = new ArrayList<>();
        try {
            for (Group group : iamClient.listGroups().groups()) {
                Map<String, String> g = new HashMap<>();
                g.put("groupName", group.groupName());

                ListAttachedGroupPoliciesResponse p = iamClient.listAttachedGroupPolicies(
                        ListAttachedGroupPoliciesRequest.builder()
                                .groupName(group.groupName()).build());
                g.put("policies", p.attachedPolicies().stream()
                        .map(AttachedPolicy::policyName).collect(Collectors.joining(", ")));

                GetGroupResponse members = iamClient.getGroup(
                        GetGroupRequest.builder().groupName(group.groupName()).build());
                g.put("memberCount", String.valueOf(members.users().size()));
                groups.add(g);
            }
        } catch (Exception e) {
            System.err.println("Error fetching groups: " + e.getMessage());
        }
        return groups;
    }

    public List<Map<String, String>> getAllRoles() {
        List<Map<String, String>> roles = new ArrayList<>();
        try {
            iamClient.listRoles().roles().stream()
                    .filter(r -> r.roleName().contains("Role"))
                    .forEach(role -> {
                        Map<String, String> r = new HashMap<>();
                        r.put("roleName", role.roleName());
                        r.put("arn", role.arn());
                        r.put("createDate", role.createDate().toString());
                        roles.add(r);
                    });
        } catch (Exception e) {
            System.err.println("Error fetching roles: " + e.getMessage());
        }
        return roles;
    }

    public Map<String, Object> getDashboardStats() {
        Map<String, Object> stats = new HashMap<>();
        try {
            stats.put("userCount", iamClient.listUsers().users().size());
            stats.put("groupCount", iamClient.listGroups().groups().size());
            stats.put("policyCount", iamClient.listPolicies(
                    ListPoliciesRequest.builder().scope("Local").build()).policies().size());
            stats.put("roleCount", iamClient.listRoles().roles().stream()
                    .filter(r -> r.roleName().contains("Role")).count());
            long mfaCount = iamClient.listUsers().users().stream().filter(user -> {
                ListMfaDevicesResponse mfa = iamClient.listMFADevices(
                        ListMfaDevicesRequest.builder().userName(user.userName()).build());
                return !mfa.mfaDevices().isEmpty();
            }).count();
            stats.put("mfaCount", mfaCount);
        } catch (Exception e) {
            stats.put("userCount", 0); stats.put("groupCount", 0);
            stats.put("policyCount", 0); stats.put("roleCount", 0); stats.put("mfaCount", 0);
        }
        return stats;
    }

    // ADMIN ONLY: Onboard
    public Map<String, String> createUser(String username, String department, String employeeId) {
        Map<String, String> result = new HashMap<>();
        try {
            iamClient.createUser(CreateUserRequest.builder()
                    .userName(username)
                    .tags(Tag.builder().key("Department").value(department).build(),
                          Tag.builder().key("EmployeeID").value(employeeId).build(),
                          Tag.builder().key("Project").value("IAM-Project").build())
                    .build());
            iamClient.createLoginProfile(CreateLoginProfileRequest.builder()
                    .userName(username).password("Welcome@2026!").passwordResetRequired(true).build());
            iamClient.addUserToGroup(AddUserToGroupRequest.builder()
                    .userName(username).groupName(department).build());
            result.put("status", "success");
            result.put("message", "✅ User " + username + " onboarded into " + department + " group. Temp password: Welcome@2026!");
        } catch (Exception e) {
            result.put("status", "error");
            result.put("message", e.getMessage());
        }
        return result;
    }

    // ADMIN ONLY: Promote
    public Map<String, String> promoteUser(String username, String oldGroup, String newGroup) {
        Map<String, String> result = new HashMap<>();
        try {
            iamClient.removeUserFromGroup(RemoveUserFromGroupRequest.builder()
                    .userName(username).groupName(oldGroup).build());
            iamClient.addUserToGroup(AddUserToGroupRequest.builder()
                    .userName(username).groupName(newGroup).build());
            result.put("status", "success");
            result.put("message", "✅ " + username + " promoted: " + oldGroup + " → " + newGroup);
        } catch (Exception e) {
            result.put("status", "error");
            result.put("message", e.getMessage());
        }
        return result;
    }

    // ADMIN ONLY: Offboard
    public Map<String, String> offboardUser(String username) {
        Map<String, String> result = new HashMap<>();
        try {
            // Remove from all groups
            iamClient.listGroupsForUser(ListGroupsForUserRequest.builder()
                    .userName(username).build()).groups().forEach(g ->
                iamClient.removeUserFromGroup(RemoveUserFromGroupRequest.builder()
                        .userName(username).groupName(g.groupName()).build()));

            // Delete login profile
            try { iamClient.deleteLoginProfile(
                    DeleteLoginProfileRequest.builder().userName(username).build());
            } catch (Exception ignored) {}

            // Delete access keys
            iamClient.listAccessKeys(ListAccessKeysRequest.builder()
                    .userName(username).build()).accessKeyMetadata().forEach(k ->
                iamClient.deleteAccessKey(DeleteAccessKeyRequest.builder()
                        .userName(username).accessKeyId(k.accessKeyId()).build()));

            // Deactivate MFA
            iamClient.listMFADevices(ListMfaDevicesRequest.builder()
                    .userName(username).build()).mfaDevices().forEach(d ->
                iamClient.deactivateMFADevice(DeactivateMfaDeviceRequest.builder()
                        .userName(username).serialNumber(d.serialNumber()).build()));

            // Delete user
            iamClient.deleteUser(DeleteUserRequest.builder().userName(username).build());

            result.put("status", "success");
            result.put("message", "✅ " + username + " fully offboarded and deleted");
        } catch (Exception e) {
            result.put("status", "error");
            result.put("message", e.getMessage());
        }
        return result;
    }
}
