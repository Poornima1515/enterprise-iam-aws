package com.iam.controller;

import com.iam.model.AuditEvent;
import com.iam.model.LoggedInUser;
import com.iam.service.CloudTrailService;
import com.iam.service.Ec2Service;
import com.iam.service.IamService;
import com.iam.service.LocalEventService;
import jakarta.servlet.http.HttpSession;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class DashboardController {

    @Autowired private IamService iamService;
    @Autowired private CloudTrailService cloudTrailService;
    @Autowired private Ec2Service ec2Service;
    @Autowired private LocalEventService localEventService;

    private LoggedInUser getUser(HttpSession session) {
        return (LoggedInUser) session.getAttribute("loggedInUser");
    }

    private ResponseEntity<?> unauthorized(String msg) {
        Map<String, String> err = new HashMap<>();
        err.put("error", msg);
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(err);
    }

    // ===== DASHBOARD (Admin only) =====
    @GetMapping("/dashboard")
    public ResponseEntity<?> getDashboard(HttpSession session) {
        LoggedInUser user = getUser(session);
        if (user == null) return unauthorized("Not logged in");
        if (!user.getRole().equals("Admin")) return unauthorized("Admin access required");

        Map<String, Object> dashboard = new HashMap<>();
        dashboard.put("stats", iamService.getDashboardStats());
        dashboard.put("cloudtrail", cloudTrailService.getTrailStatus());
        dashboard.put("ec2", ec2Service.getInstanceStatus());
        dashboard.put("recentEvents", cloudTrailService.getRecentEvents(5));
        return ResponseEntity.ok(dashboard);
    }

    // ===== LIVE FEED — merges local events + CloudTrail =====
    @GetMapping("/feed")
    public ResponseEntity<?> getLiveFeed(HttpSession session) {
        LoggedInUser user = getUser(session);
        if (user == null) return unauthorized("Not logged in");
        if (!user.getRole().equals("Admin")) return unauthorized("Admin access required");

        // Merge local (immediate) + CloudTrail (delayed) events
        List<AuditEvent> merged = new ArrayList<>();
        merged.addAll(localEventService.getRecentEvents(5));      // instant local events
        merged.addAll(cloudTrailService.getRecentEvents(8));       // CloudTrail (may be delayed)

        // Return up to 10, deduplication by eventName+time approximate
        return ResponseEntity.ok(merged.stream().limit(10).toList());
    }

    // ===== IAM USERS =====
    @GetMapping("/users")
    public ResponseEntity<?> getUsers(HttpSession session) {
        LoggedInUser user = getUser(session);
        if (user == null) return unauthorized("Not logged in");
        if (!user.getRole().equals("Admin")) return unauthorized("Admin access required");
        return ResponseEntity.ok(iamService.getAllUsers());
    }

    // ===== IAM GROUPS =====
    @GetMapping("/groups")
    public ResponseEntity<?> getGroups(HttpSession session) {
        LoggedInUser user = getUser(session);
        if (user == null) return unauthorized("Not logged in");
        if (!user.getRole().equals("Admin")) return unauthorized("Admin access required");
        return ResponseEntity.ok(iamService.getAllGroups());
    }

    // ===== IAM ROLES =====
    @GetMapping("/roles")
    public ResponseEntity<?> getRoles(HttpSession session) {
        LoggedInUser user = getUser(session);
        if (user == null) return unauthorized("Not logged in");
        if (!user.getRole().equals("Admin")) return unauthorized("Admin access required");
        return ResponseEntity.ok(iamService.getAllRoles());
    }

    // ===== AUDIT LOGS =====
    @GetMapping("/audit")
    public ResponseEntity<?> getAudit(@RequestParam(defaultValue = "20") int limit,
                                       HttpSession session) {
        LoggedInUser user = getUser(session);
        if (user == null) return unauthorized("Not logged in");
        if (!user.getRole().equals("Admin") && !user.getRole().equals("Auditor"))
            return unauthorized("Admin or Auditor access required");
        return ResponseEntity.ok(cloudTrailService.getRecentEvents(limit));
    }

    // ===== EC2 STATUS =====
    @GetMapping("/ec2/status")
    public ResponseEntity<?> getEc2Status(HttpSession session) {
        LoggedInUser user = getUser(session);
        if (user == null) return unauthorized("Not logged in");
        if (!user.getRole().equals("Admin") && !user.getRole().equals("Developer")
            && !user.getRole().equals("Tester") && !user.getRole().equals("DatabaseAdmin"))
            return unauthorized("Access denied for your role");
        return ResponseEntity.ok(ec2Service.getInstanceStatus());
    }

    // ===== CLOUDTRAIL STATUS =====
    @GetMapping("/cloudtrail/status")
    public ResponseEntity<?> getCloudTrailStatus(HttpSession session) {
        LoggedInUser user = getUser(session);
        if (user == null) return unauthorized("Not logged in");
        if (!user.getRole().equals("Admin") && !user.getRole().equals("Auditor"))
            return unauthorized("Admin or Auditor access required");
        return ResponseEntity.ok(cloudTrailService.getTrailStatus());
    }

    // ===== ONBOARD (Admin only) — returns credentials =====
    @PostMapping("/workflow/onboard")
    public ResponseEntity<?> onboard(@RequestBody Map<String, String> req, HttpSession session) {
        LoggedInUser user = getUser(session);
        if (user == null) return unauthorized("Not logged in");
        if (!user.getRole().equals("Admin")) return unauthorized("Only Admin can onboard employees");

        Map<String, String> result = iamService.createUser(
                req.get("username"), req.get("department"), req.get("employeeId"));

        // Log to local event feed immediately
        if ("success".equals(result.get("status"))) {
            localEventService.addEvent(
                "CreateUser",
                user.getUsername(),
                "Onboarded " + req.get("username") + " into " + req.get("department")
            );
            localEventService.addEvent(
                "AddUserToGroup",
                user.getUsername(),
                req.get("username") + " → " + req.get("department")
            );
        }
        return ResponseEntity.ok(result);
    }

    // ===== PROMOTE (Admin only) =====
    @PostMapping("/workflow/promote")
    public ResponseEntity<?> promote(@RequestBody Map<String, String> req, HttpSession session) {
        LoggedInUser user = getUser(session);
        if (user == null) return unauthorized("Not logged in");
        if (!user.getRole().equals("Admin")) return unauthorized("Only Admin can promote employees");

        Map<String, String> result = iamService.promoteUser(
                req.get("username"), req.get("oldGroup"), req.get("newGroup"));

        if ("success".equals(result.get("status"))) {
            localEventService.addEvent(
                "RemoveUserFromGroup",
                user.getUsername(),
                req.get("username") + " removed from " + req.get("oldGroup")
            );
            localEventService.addEvent(
                "AddUserToGroup",
                user.getUsername(),
                req.get("username") + " → " + req.get("newGroup")
            );
        }
        return ResponseEntity.ok(result);
    }

    // ===== OFFBOARD (Admin only) =====
    @PostMapping("/workflow/offboard")
    public ResponseEntity<?> offboard(@RequestBody Map<String, String> req, HttpSession session) {
        LoggedInUser user = getUser(session);
        if (user == null) return unauthorized("Not logged in");
        if (!user.getRole().equals("Admin")) return unauthorized("Only Admin can offboard employees");

        Map<String, String> result = iamService.offboardUser(req.get("username"));

        if ("success".equals(result.get("status"))) {
            localEventService.addEvent(
                "DeleteUser",
                user.getUsername(),
                "Offboarded " + req.get("username")
            );
        }
        return ResponseEntity.ok(result);
    }
}
