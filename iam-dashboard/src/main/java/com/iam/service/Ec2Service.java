package com.iam.service;

import org.springframework.stereotype.Service;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.ec2.Ec2Client;
import software.amazon.awssdk.services.ec2.model.*;

import java.util.HashMap;
import java.util.Map;

@Service
public class Ec2Service {

    private final Ec2Client ec2Client = Ec2Client.builder()
            .region(Region.US_EAST_1).build();

    public Map<String, String> getInstanceStatus() {
        Map<String, String> status = new HashMap<>();
        try {
            DescribeInstancesResponse response = ec2Client.describeInstances(
                    DescribeInstancesRequest.builder()
                            .filters(Filter.builder().name("tag:Name")
                                    .values("EC2-ProjectServer").build()).build());
            if (!response.reservations().isEmpty() &&
                !response.reservations().get(0).instances().isEmpty()) {
                Instance i = response.reservations().get(0).instances().get(0);
                status.put("instanceId", i.instanceId());
                status.put("state", i.state().nameAsString());
                status.put("instanceType", i.instanceTypeAsString());
                status.put("privateIp", i.privateIpAddress() != null ? i.privateIpAddress() : "N/A");
                status.put("publicIp", i.publicIpAddress() != null ? i.publicIpAddress() : "N/A");
                status.put("name", "EC2-ProjectServer");
            } else {
                status.put("instanceId", "Not found"); status.put("state", "unknown");
            }
        } catch (Exception e) {
            status.put("instanceId", "Error"); status.put("state", "error");
        }
        return status;
    }
}
