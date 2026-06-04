package com.iam;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class IamDashboardApplication {
    public static void main(String[] args) {
        SpringApplication.run(IamDashboardApplication.class, args);
        System.out.println("\n==============================================");
        System.out.println(" Enterprise IAM Dashboard Started!");
        System.out.println(" Open: http://localhost:8080");
        System.out.println("==============================================\n");
    }
}
