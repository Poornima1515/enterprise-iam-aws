package com.iam.controller;

import com.iam.model.LoggedInUser;
import com.iam.service.AuthService;
import jakarta.servlet.http.HttpSession;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/auth")
@CrossOrigin(origins = "*")
public class AuthController {

    @Autowired
    private AuthService authService;

    @PostMapping("/login")
    public Map<String, Object> login(@RequestBody Map<String, String> request,
                                     HttpSession session) {
        Map<String, Object> response = new HashMap<>();
        String accessKeyId = request.get("accessKeyId");
        String secretAccessKey = request.get("secretAccessKey");

        if (accessKeyId == null || secretAccessKey == null ||
            accessKeyId.isBlank() || secretAccessKey.isBlank()) {
            response.put("success", false);
            response.put("message", "Access Key ID and Secret Access Key are required");
            return response;
        }

        LoggedInUser user = authService.authenticate(accessKeyId, secretAccessKey);

        if (user == null || user.getRole().equals("Unknown")) {
            response.put("success", false);
            response.put("message", "Invalid credentials or user has no assigned group");
            return response;
        }

        // Store in session
        session.setAttribute("loggedInUser", user);

        response.put("success", true);
        response.put("username", user.getUsername());
        response.put("role", user.getRole());
        response.put("displayName", user.getDisplayName());
        response.put("message", "Login successful");
        return response;
    }

    @PostMapping("/logout")
    public Map<String, Object> logout(HttpSession session) {
        session.invalidate();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("message", "Logged out successfully");
        return response;
    }

    @GetMapping("/me")
    public Map<String, Object> getMe(HttpSession session) {
        Map<String, Object> response = new HashMap<>();
        LoggedInUser user = (LoggedInUser) session.getAttribute("loggedInUser");
        if (user == null) {
            response.put("loggedIn", false);
        } else {
            response.put("loggedIn", true);
            response.put("username", user.getUsername());
            response.put("role", user.getRole());
            response.put("displayName", user.getDisplayName());
        }
        return response;
    }
}
