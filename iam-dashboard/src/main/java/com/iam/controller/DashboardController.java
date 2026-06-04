package com.iam.controller;

import com.iam.model.LoggedInUser;
import com.iam.service.CloudTrailService;
import com.iam.service.Ec2Service;
import com.iam.service.IamService;
import jakarta.servlet.http.HttpSession;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api")
@CrossOrigin(origins = "*")
public class DashboardController {

    @Autowired private IamService iamService;
    @Autowired private CloudTrailService cloudTrailService;
    @Autowired private Ec2Service ec2Service;

    // ===== AUTH CHECK HELPER =====
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

    // ===== IAM USERS (Admin only) =====
    @GetMapping("/users")
    public ResponseEntity<?> getUsers(HttpSession session) {
        LoggedInUser user = getUser(session);
        if (user == null) return unauthorized("Not logged in");
        if (!user.getRole().equals("Admin")) return unauthorized("Admin access required");
        return ResponseEntity.ok(iamService.getAllUsers());
    }

    // ===== IAM GROUPS (Admin only) =====
    @GetMapping("/groups")
    public ResponseEntity<?> getGroups(HttpSession session) {
        LoggedInUser user = getUser(session);
        if (user == null) return unauthorized("Not logged in");
        if (!user.getRole().equals("Admin")) return unauthorized("Admin access required");
        return ResponseEntity.ok(iamService.getAllGroups());
    }

    // ===== IAM ROLES (Admin only) =====
    @GetMapping("/roles")
    public ResponseEntity<?> getRoles(HttpSession session) {
        LoggedInUser user = getUser(session);
        if (user == null) return unauthorized("Not logged in");
        if (!user.getRole().equals("Admin")) return unauthorized("Admin access required");
        return ResponseEntity.ok(iamService.getAllRoles());
    }

    // ===== AUDIT LOGS (Admin + Auditor) =====
    @GetMapping("/audit")
    public ResponseEntity<?> getAudit(@RequestParam(defaultValue = "20") int limit,
                                       HttpSession session) {
        LoggedInUser user = getUser(session);
        if (user == null) return unauthorized("Not logged in");
        if (!user.getRole().equals("Admin") && !user.getRole().equals("Auditor"))
            return unauthorized("Admin or Auditor access required");
        return ResponseEntity.ok(cloudTrailService.getRecentEvents(limit));
    }

    // ===== EC2 STATUS (Admin + Developer + Tester) =====
    @GetMapping("/ec2/status")
    public ResponseEntity<?> getEc2Status(HttpSession session) {
        LoggedInUser user = getUser(session);
        if (user == null) return unauthorized("Not logged in");
        if (!user.getRole().equals("Admin") &&
            !user.getRole().equals("Developer") &&
            !user.getRole().equals("Tester"))
            return unauthorized("Access denied for your role");
        return ResponseEntity.ok(ec2Service.getInstanceStatus());
    }

    // ===== CLOUDTRAIL STATUS (Admin + Auditor) =====
    @GetMapping("/cloudtrail/status")
    public ResponseEntity<?> getCloudTrailStatus(HttpSession session) {
        LoggedInUser user = getUser(session);
        if (user == null) return unauthorized("Not logged in");
        if (!user.getRole().equals("Admin") && !user.getRole().equals("Auditor"))
            return unauthorized("Admin or Auditor access required");
        return ResponseEntity.ok(cloudTrailService.getTrailStatus());
    }

    // ===== ONBOARD (Admin only) =====
    @PostMapping("/workflow/onboard")
    public ResponseEntity<?> onboard(@RequestBody Map<String, String> req,
                                      HttpSession session) {
        LoggedInUser user = getUser(session);
        if (user == null) return unauthorized("Not logged in");
        if (!user.getRole().equals("Admin")) return unauthorized("Only Admin can onboard employees");
        return ResponseEntity.ok(iamService.createUser(
                req.get("username"), req.get("department"), req.get("employeeId")));
    }

    // ===== PROMOTE (Admin only) =====
    @PostMapping("/workflow/promote")
    public ResponseEntity<?> promote(@RequestBody Map<String, String> req,
                                      HttpSession session) {
        LoggedInUser user = getUser(session);
        if (user == null) return unauthorized("Not logged in");
        if (!user.getRole().equals("Admin")) return unauthorized("Only Admin can promote employees");
        return ResponseEntity.ok(iamService.promoteUser(
                req.get("username"), req.get("oldGroup"), req.get("newGroup")));
    }

    // ===== OFFBOARD (Admin only) =====
    @PostMapping("/workflow/offboard")
    public ResponseEntity<?> offboard(@RequestBody Map<String, String> req,
                                       HttpSession session) {
        LoggedInUser user = getUser(session);
        if (user == null) return unauthorized("Not logged in");
        if (!user.getRole().equals("Admin")) return unauthorized("Only Admin can offboard employees");
        return ResponseEntity.ok(iamService.offboardUser(req.get("username")));
    }
}
