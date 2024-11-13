# Advanced WordPress Deployment on AWS

This guide provides a comprehensive and optimized approach to deploying a secure, scalable, and highly available WordPress environment on AWS. By leveraging AWS services such as VPC, Bastion Host, RDS with Multi-AZ, EC2 Auto Scaling, Application Load Balancer (ALB), and NAT Gateway, this deployment ensures robust performance, enhanced security, and seamless scalability to handle varying traffic loads.

## Table of Contents

- [Advanced WordPress Deployment on AWS](#advanced-wordpress-deployment-on-aws)
  - [Table of Contents](#table-of-contents)
  - [Architecture Overview](#architecture-overview)
  - [Prerequisites](#prerequisites)
  - [Infrastructure Components](#infrastructure-components)
    - [1. Virtual Private Cloud (VPC) \& Subnets](#1-virtual-private-cloud-vpc--subnets)
    - [2. Bastion Host](#2-bastion-host)
    - [3. NAT Gateway](#3-nat-gateway)
    - [4. MySQL RDS Database](#4-mysql-rds-database)
    - [5. WordPress EC2 Instances](#5-wordpress-ec2-instances)
    - [6. Application Load Balancer (ALB)](#6-application-load-balancer-alb)
    - [7. Auto Scaling Group (ASG)](#7-auto-scaling-group-asg)
  - [Security Groups Configuration](#security-groups-configuration)
  - [Deployment Steps](#deployment-steps)
    - [Step 1: Create VPC and Subnets](#step-1-create-vpc-and-subnets)
      - [Create a VPC](#create-a-vpc)
      - [Configure Route Tables](#configure-route-tables)
    - [Step 2: Launch Bastion Host](#step-2-launch-bastion-host)
    - [Step 3: Verify NAT Gateway and Route Table Configuration](#step-3-verify-nat-gateway-and-route-table-configuration)
    - [Step 4: Set Up MySQL RDS Database](#step-4-set-up-mysql-rds-database)
    - [Step 5: Launch WordPress EC2 Instances](#step-5-launch-wordpress-ec2-instances)
    - [Step 6: Set Up Application Load Balancer](#step-6-set-up-application-load-balancer)
    - [Step 7: Configure Auto Scaling Group](#step-7-configure-auto-scaling-group)
    - [Step 8: Connect WordPress to RDS](#step-8-connect-wordpress-to-rds)
    - [Step 9: Finalize WordPress Setup via Browser](#step-9-finalize-wordpress-setup-via-browser)
  - [Monitoring and Maintenance](#monitoring-and-maintenance)
  - [Conclusion](#conclusion)
  - [Clean-Up](#clean-up)
    - [1. Terminate EC2 Instances](#1-terminate-ec2-instances)
    - [2. Delete RDS Instances](#2-delete-rds-instances)
    - [3. Delete Load Balancers](#3-delete-load-balancers)
    - [4. Delete Auto Scaling Groups](#4-delete-auto-scaling-groups)
    - [5. Delete NAT Gateway](#5-delete-nat-gateway)
    - [6. Delete VPC and Subnets](#6-delete-vpc-and-subnets)
    - [7. Delete Security Groups](#7-delete-security-groups)
    - [8. Delete Key Pairs (Optional)](#8-delete-key-pairs-optional)
    - [9. Review and Confirm](#9-review-and-confirm)
  - [Additional Best Practices](#additional-best-practices)
  - [Troubleshooting Tips](#troubleshooting-tips)

---

## Architecture Overview

The deployment architecture is meticulously crafted to ensure high availability, scalability, and security. Below are the core components and their roles:

1. **Virtual Private Cloud (VPC)**:
   - **Purpose**: Provides an isolated network environment within AWS, ensuring network-level security and control.
   - **Configuration**: Comprises both public and private subnets spread across multiple Availability Zones (AZs) to enhance fault tolerance.

2. **Subnets**:
   - **Public Subnets**:
     - **CIDR Blocks**: `10.0.0.0/20`, `10.0.16.0/20`, `10.0.32.0/20`
     - **Usage**: Hosts the Application Load Balancer (ALB) and Bastion Host, facilitating internet access for public-facing services.
   - **Private Subnets**:
     - **CIDR Blocks**: `10.0.128.0/20`, `10.0.144.0/20`, `10.0.160.0/20`
     - **Usage**: Hosts EC2 instances for WordPress and the MySQL RDS Database, ensuring these critical components are not directly accessible from the internet.

3. **Bastion Host**:
   - **Purpose**: Acts as a secure gateway for SSH access to EC2 instances within private subnets, eliminating the need to expose these instances directly to the internet.
   - **Placement**: Deployed in a public subnet to allow SSH access from trusted IPs.

4. **NAT Gateway**:
   - **Purpose**: Allows instances in private subnets to initiate outbound IPv4 traffic to the internet (e.g., for updates, plugin downloads) while preventing inbound traffic from the internet.
   - **Placement**: Deployed in a public subnet.
   - **Features**: Highly available within an AZ, managed by AWS, ensuring minimal maintenance overhead.

5. **MySQL RDS Database**:
   - **Engine**: MySQL
   - **Placement**: Private Subnet
   - **Purpose**: Securely stores WordPress data, ensuring data isolation and protection.
   - **Features**: Automated backups, Multi-AZ deployment for high availability and fault tolerance, read replicas (optional), and encryption at rest and in transit for enhanced security.

6. **WordPress EC2 Instances**:
   - **AMI**: Ubuntu
   - **Placement**: Private Subnets
   - **Purpose**: Hosts the WordPress application.
   - **Access**: Managed via SSH through the Bastion Host.
   - **Management**: Automated scaling and management through an Auto Scaling Group (ASG) using a Launch Template for consistency and ease of deployment.

7. **Application Load Balancer (ALB)**:
   - **Placement**: Public Subnets
   - **Purpose**: Distributes incoming HTTP/HTTPS traffic to WordPress EC2 instances, ensuring balanced load and fault tolerance.
   - **Features**: Health checks, SSL termination (optional), and integration with Auto Scaling for dynamic traffic management.

8. **Auto Scaling Group (ASG)**:
   - **Placement**: Private Subnets
   - **Purpose**: Automatically adjusts the number of EC2 instances hosting WordPress based on traffic and load, ensuring optimal performance and cost-efficiency.
   - **Configuration**:
     - **Minimum Instances**: 1
     - **Maximum Instances**: 3
     - **Desired Capacity**: 2
     - **Scaling Policies**: Based on CPU utilization.

![Architecture Diagram](./images/Cloud%20Architecture(2).png)

*Figure 1: Deployment Architecture Overview*

---

## Prerequisites

Before proceeding, ensure you have the following:

- **AWS Account** with necessary permissions to create VPCs, subnets, EC2 instances, RDS databases, ALBs, NAT Gateways, and Auto Scaling Groups.
- **SSH Key Pairs** for accessing EC2 instances and the Bastion Host.
- **IAM Roles and Policies** as required for the services.
- **Domain Name** (optional) for accessing the WordPress site via a custom DNS.

---

## Infrastructure Components

### 1. Virtual Private Cloud (VPC) & Subnets

- **VPC CIDR Block:** `10.0.0.0/16`
- **Subnets:**
  - **Public Subnets:** 3
    - **CIDR Blocks:** `10.0.0.0/20`, `10.0.16.0/20`, `10.0.32.0/20`
    - **Usage:** ALB, Bastion Host, and NAT Gateway.
  - **Private Subnets:** 3
    - **CIDR Blocks:** `10.0.128.0/20`, `10.0.144.0/20`, `10.0.160.0/20`
    - **Usage:** WordPress EC2 instances and MySQL RDS Database.
- **Purpose:** Isolate the network environment for WordPress deployment with separation between public-facing and internal resources.

### 2. Bastion Host

- **AMI:** Amazon Linux 2 / Ubuntu
- **Placement:** Public Subnet
- **Purpose:** Provides secure SSH access to EC2 instances located in private subnets.
- **Access:** SSH access restricted to trusted IPs (e.g., your office or home IP).
- **Security Considerations:**
  - Harden the bastion host by disabling unnecessary services.
  - Regularly update and patch the bastion host.
  - Use multi-factor authentication (MFA) if possible.

### 3. NAT Gateway

- **Placement:** Public Subnet
- **Purpose:** Allows instances in private subnets to initiate outbound IPv4 traffic to the internet while preventing inbound traffic from the internet.
- **Features:**
  - Highly available within an AZ.
  - Managed by AWS, reducing maintenance overhead.
  - Facilitates updates and downloads for WordPress instances without exposing them directly to the internet.

### 4. MySQL RDS Database

- **Engine:** MySQL
- **Placement:** Private Subnet
- **Purpose:** Store WordPress data securely.
- **Features:**
  - **Automated Backups:** Enables point-in-time recovery.
  - **Multi-AZ Deployment:** Ensures high availability and fault tolerance.
  - **Read Replicas:** (Optional) For scaling read-heavy workloads.
  - **Encryption:** At rest and in transit for enhanced security.

### 5. WordPress EC2 Instances

- **AMI:** Ubuntu
- **Placement:** Private Subnets
- **Purpose:** Host the WordPress application.
- **Access:** Managed via SSH through the Bastion Host.
- **Management:** Automated scaling and management through an Auto Scaling Group (ASG) using a Launch Template for consistency and ease of deployment.

### 6. Application Load Balancer (ALB)

- **Placement:** Public Subnets
- **Purpose:** Distribute incoming HTTP/HTTPS traffic to WordPress EC2 instances.
- **Features:**
  - **Health Checks:** Monitors the health of WordPress instances.
  - **SSL Termination:** (Optional) Handles SSL certificates for HTTPS traffic.
  - **Integration with Auto Scaling:** Ensures that new instances are automatically added to the load balancer.

### 7. Auto Scaling Group (ASG)

- **Placement:** Private Subnets
- **Purpose:** Automatically adjust the number of EC2 instances hosting WordPress based on traffic and load, ensuring optimal performance and cost-efficiency.
- **Configuration:**
  - **Minimum Instances:** 1
  - **Maximum Instances:** 3
  - **Desired Capacity:** 2
  - **Scaling Policies:** Based on CPU utilization or request count.
  - **Launch Template:** Ensures that all instances are launched with the same configuration, including the installation of WordPress and necessary dependencies.

---

## Security Groups Configuration

Properly configuring security groups is crucial for ensuring that each component can communicate securely while minimizing exposure to potential threats.

- **Bastion Host Security Group:**
  - **Inbound:**
    - SSH (port 22) from trusted IPs (e.g., your office or home IP).
  - **Outbound:**
    - All traffic to allow SSH connections to EC2 instances in private subnets.
  
- **WordPress EC2 Security Group:**
  - **Inbound:**
    - HTTP (port 80) from ALB Security Group.
    - SSH (port 22) from Bastion Host Security Group (if SSH access is needed directly).
  - **Outbound:**
    - MySQL (port 3306) to RDS Security Group.
    - Outbound internet access via NAT Gateway (automatically handled by route tables).
    - All other necessary outbound traffic.
  
- **RDS Security Group:**
  - **Inbound:** MySQL (port 3306) from WordPress EC2 Security Group.
  - **Outbound:** None (default deny).
  
- **ALB Security Group:**
  - **Inbound:** HTTP (port 80) and HTTPS (port 443) from anywhere (`0.0.0.0/0`).
  - **Outbound:** HTTP/HTTPS to WordPress EC2 Security Group.
  
- **Auto Scaling Group Security Group:**
  - **Inbound:** HTTP (port 80) and HTTPS (port 443) from ALB Security Group.
  - **Outbound:** MySQL (port 3306) to RDS Security Group and necessary outbound traffic.

---

## Deployment Steps

### Step 1: Create VPC and Subnets

#### Create a VPC

1. **Navigate to the VPC Console:**

   - Log in to the [AWS Management Console](https://aws.amazon.com/console/).
   - From the **Services** menu, select **VPC**.

     ![VPC Console](./images/1.%20VPC%20console.png)

   *Figure 2: Navigating to the VPC Console*

2. **Click on "Create VPC":**

   - In the VPC dashboard, click on the **Create VPC** button.

     ![Create VPC](./images/2.%20Create%20VPC.png)

   *Figure 3: Creating a New VPC*

3. **Configure VPC Settings:**
   - **Name Tag:** `wordpress-vpc`
   - **IPv4 CIDR Block:** `10.0.0.0/16
  
     ![VPC Set](./images/2.1%20VPC%20set%201.png)
   - **Tenancy:** Default (unless you require dedicated instances)
   - **Set number of availabilty zones and public & private subnets:**
  
     ![VPC Set](./images/2.2%20VPC%20set%203.png)
   - **Customize subnet CIDR blocks:**

     ![VPC Set](./images/2.3%20VPC%20set%202.png)

   - **NAT gatway deployment:**
  
      ![VPC Set](./images/3.nat-gw%20&%20dns%20opt.png)

   - **Enable DNS Hostnames:** Yes

1. **Create the VPC:**
   - Click **Create** to finalize.

     ![VPC Created](./images/4.create%20vpc.png)

     **VPC review:**
     ![VPC Preview](./images/5.vpc%20preview.png)

     *Figure 4: VPC Creation Confirmation*

#### Configure Route Tables

1. **Configure Public Route Table:**
   - A public route table is created by default with your VPC.
   - **Verify Routes:**
     - **Destination:** `10.0.0.0/16` (local)
     - **Destination:** `0.0.0.0/0` (Internet)
       - **Target:** Internet Gateway (IGW) attached to your VPC.
   - **Associate Public Subnets:**
     - Select the public route table (usually named `main` unless renamed).

      ![pub route table](./images/7.%20assoc%20pub%20subnet-pbrtb.png)

     - Go to the **Subnet Associations** tab.

     ![pub route table](./images/8.%20assoc%20pubsubnet%202.png)

     - Click **Edit subnet associations**.
     - Check all **public subnets** (`public-subnet-1`, `public-subnet-2`, `public-subnet-3`).

      ![pub route table](./images/9.%20assoc%20pubsubnet%203.png)

     - Click **Save associations**.

2. **Configure Private Route Table:**
   - **Create a New Route Table:**
     - In the VPC console, select **Route Tables**.
     - Click **Create route table**.
     - **VPC:** `wordpress-vpc`
     - Click **Create**.
   - **Associate Private Subnets:**
     - Select the newly created `private-route-table`.

     ![priv route table](./images/10.%20assoc%20priv%20subnet-prvrtb.png)

     - Go to the **Subnet Associations** tab.

     ![priv route table](./images/11.%20assoc%20priv%20subnet-prvrtb%202.png)

     - Click **Edit subnet associations**.
     - Check all **private subnets** (`private-subnet-1` through `private-subnet-6`).

     ![priv route table](./images/12.%20assoc%20priv%20subnet-prvrtb%203.png)

     *Figure 8: Configuring Private Route Table*

     - Click **Save associations**.
   - **No Internet Gateway Route:**
     - Private subnets do not have direct internet access. Outbound traffic is routed through the a NAT Gateway in each availability zone.

---

### Step 2: Launch Bastion Host

A Bastion Host serves as the secure entry point for SSH access to your private EC2 instances. By placing the Bastion Host in a public subnet, you can securely access your WordPress instances without exposing them directly to the internet.

1. **Launch EC2 Instance for Bastion Host:**

   1. **Navigate to the EC2 Console:**

      - Log in to the [AWS Management Console](https://aws.amazon.com/console/).
      - From the **Services** menu, select **EC2**.

        ![EC2 Console](./images/13.%20EC2%20console.png)

        *Figure 9: Navigating to the EC2 Console*

   2. **Click on "Launch Instance":**

      - In the EC2 dashboard, click on the **Launch Instance** button.

        ![Launch Instance](./images/13.5%20Launch%20instance.png)

      *Figure 10: Launching a New EC2 Instance*

   3. **Configure Instance Details:**
      - **Name Tag:** `Bastion-WordPress`

        ![Bastion config](./images/14.%20bastion%20name%20tag.png)

        **AMI:** Ubuntu

        ![Bastion config](./images/15%20ubuntu%20AMI.png)

      - **Instance Type:** `t2.micro` *(Adjust based on requirements)*

        ![Bastion config](./images/16.%20bastion%20inst%20type.png)

      - **Key Pair:** Select your **SSH key pair** or create a new one.
        - *If creating a new key pair, follow the prompts to download the `.pem` file securely.*

        ![Bastion config](./images/17.%20bastion%20keypair.png)

        ![Bastion config](./images/18.%20bastion%20keypair2.png)

      - **Network:** `wordpress-vpc`

        ![Bastion config](./images/19.%20bastion%20vpc.png)

      - **Subnet:** Select one of the **public subnets** (`public-subnet-1`, `public-subnet-2`, `public-subnet-3`).
      - **Auto-assign Public IP:** **Yes**

        ![Bastion config](./images/20.%20bastion%20vpc%202.png)

      - **IAM Role:** Assign if necessary (e.g., for Systems Manager access).

   4. **Add Storage:**
      - Configure as needed (default settings are typically sufficient for a Bastion Host).

   6. **Configure Security Group:**
      - **Create a new security group** or select an existing one.
      - **Inbound Rules:**
        - **SSH:** Port 22 from your trusted IPs (e.g., `203.0.113.0/24`)
      - **Outbound Rules:**
        - **All traffic** to allow the Bastion Host to communicate with EC2 instances in private subnets.
      - **Example Configuration:**

        ![Bastion SG Outbound](./images/21.%20bastion%20vpc%20sg.png)

      *Figure 13: Bastion Host Security Group Rules*

   7. **Review and Launch:**
      - Review all configurations.
      - Click **Launch Instance**.

        ![Launch Confirmation](./images/22.%20bastion%20instance%20launch.png)

      *Figure 14: Launching the Bastion Host EC2 Instance*

   8. **Wait for Instance Initialization:**
      - Ensure the Bastion Host instance status is **running** and **passed** all status health checks.

        ![Bastion Running](./images/23.%20bastion%20running.png)

      *Figure 15: Bastion Host EC2 Instance Running*

2. **Harden the Bastion Host:**

   - **Disable Password Authentication:**
     - Ensure SSH access is only possible via key pairs by editing the SSH configuration.

       ```bash
       sudo vim /etc/ssh/sshd_config
       ```

       - Set `PasswordAuthentication no`
       - Restart SSH service:

         ```bash
         sudo systemctl restart sshd
         ```

   - **Regular Updates:**
     - Regularly update the OS and installed packages to patch vulnerabilities.

       ```bash
       sudo yum update -y
       ```

   - **Monitor Logs:**
     - Implement logging and monitoring to track access and detect any unauthorized attempts.

       ```bash
       sudo tail -f /var/log/secure
       ```

---

### Step 3: Verify NAT Gateway and Route Table Configuration

A NAT Gateway allows instances in private subnets to initiate outbound IPv4 traffic to the internet (e.g., for updates, plugin downloads) while preventing inbound traffic. In this setup, the NAT Gateway and its association with private subnets were automatically created using the ***VPC*** setup. Therefore, you only need to verify the NAT Gateway and its correct assignment to private subnets.

1. **Verify NAT Gateway Configuration:**

   1. **Navigate to the VPC Console:**

      - From the **Services** menu, select **VPC**.

        ![VPC Console](./images/1.%20VPC%20console.png)

      *Figure: Navigating to the VPC Console*

   2. **Select "NAT Gateways" from the left menu.**

      - Confirm that NAT Gateways are listed and in the **Available** state.
      - Ensure there is a NAT Gateway associated with each of your public subnets (e.g., `public-subnet-1`, `public-subnet-2`, `public-subnet-3`).

        ![NAT Gateways Verification](./images/25.%20NatGW%20config%20review.png)

        ![NAT Gateways Verification](./images/24.%20NatGW%20config%20review%202.png)

        *Figure: Verifying NAT Gateways*

2. **Verify Route Table Configuration:**

   1. **Navigate to "Route Tables" in the VPC Console.**

      - Under **Your VPCs**, select **Route Tables**.

   2. **Select the private route tables (e.g., `private-route-table-1`, `private-route-table-2`) assigned to your private subnets.**

   3. **Verify Routes:**
      - Check that each private route table has the following route:
        - **Destination:** `0.0.0.0/0`
        - **Target:** The NAT Gateway (`nat-xxxxxxxx`).
      - Ensure that traffic for `0.0.0.0/0` is directed through the NAT Gateway in the private subnets.

      ![Private Route Table Verification](./images/Private%20Route-table%20verification.png)

      ![Private Route Table Verification](./images/Private%20Route-table%20verification%202.png)

      ![Private Route Table Verification](./images/Private%20Route-table%20verification%203.png)

      *Figure: Verifying Route Table Association with NAT Gateway*

3. **Confirm Connectivity:**

   - Launch a temporary EC2 instance in one of your private subnets.
   - SSH into the instance and confirm that it can access the internet by running:

     ```bash
     sudo apt update
     ```

   - If the update completes successfully, the NAT Gateway is functioning correctly.

     ![EC2 Internet Access Verification](./images/ASG%20Test%203-update.png)

     *Figure: Verifying Internet Access through NAT Gateway*

---

### Step 4: Set Up MySQL RDS Database

To enhance the availability and reliability of your WordPress database, this setup configures the MySQL RDS instance with Multi-AZ deployment. Multi-AZ ensures that your database remains available in the event of infrastructure failures by automatically provisioning and maintaining a synchronous standby replica in a different Availability Zone.

1. **Launch RDS Instance:**

   1. **Navigate to the RDS Console:**

      - From the **Services** menu, select **RDS**.

   2. **Click on "Create Database":**

      - Click the **Create database** button.

        ![Create RDS](./images/26.%20RDS%20console.png)

        *Figure 25: Creating a New RDS Instance*

   3. **Configure Database Settings:**
      - **Engine Type:** Select **MySQL**.
       ![RDS config](./images/27.%20RDS%20select%20dB%20engine.png)
      - **Edition:** Choose the appropriate MySQL version.
      - **Use Case:** Select **Dev/Test** to enable Multi-AZ deployment.

        ![RDS config](./images/28.%20RDS%20multi-az%20set.png)

      - **DB Instance Identifier:** `wordpress-db`

        ![RDS config](./images/29.%20RDS%20db%20inst%20identifier.png)

      - **Master Username:** `admin`
      - **Master Password:** `YourStrongPassword` *(Replace with a strong password)*
      - **Confirm Password:** `YourStrongPassword`

        ![DB Credentials](./images/30.%20RDS%20credentials%20set.png)

      *Figure 26: Database Credentials Configuration*

   4. **Configure Instance Specifications:**
      - **DB Instance Class:** Select `db.t3.micro` for free-tier or a higher instance class based on your needs.

        ![DB Instance Class](./images/30.%20RDS%20db%20instance%20class.png)

      - **Storage:** Allocate sufficient storage (e.g., `20 GB`) and enable **Storage Autoscaling** if necessary.
      - **Storage Type:** Choose `General Purpose (SSD)` for balanced performance.

        ![DB storage](./images/32.%20RDS%20storage.png)

      *Figure 27: DB Storage Class Selection*

   5. **Set Up Connectivity:**
      - **Virtual Private Cloud (VPC):** Select `wordpress-vpc`.

   ![RDS VPC](./images/33.%20RDS%20vpc.png)

      - **Subnet Group:** *A subnet group is created automatically consisting of the 3 private subnet groups created earlier.*
      - **Public Access:** **No** (ensures the database is not accessible from the internet).
      - **VPC Security Groups:**
        - **Create a new security group** or select an existing one.
        - **Inbound Rules:** Allow MySQL traffic (`port 3306`) from the WordPress EC2 Security Group.

      ![RDS Security Group](./images/34.%20RDS%20create%20sg.png)
      ![RDS Security Group](./images/35.%20RDS%20sg%20name.png)
      *Figure 28: RDS Security Group Configuration*

      - **Database authentication:** Select **Password authentication**
      - **Monitoring:** Enable **Enhanced monitoring**

      ![RDS db auth & monitor](./images/37.%20RDS%20db%20auth&monitor.png)

   6. **Additional Configuration:**

      - **Database options:**

      ![Database options](./images/38.%20RDS%20add%20config.png)

      - **Backup:** Disable automated backups for this project.

      ![DB backup](./images/39.%20RDS%20backup%20disable.png)

      - **Encryption:** Enable encryption at rest and in transit for enhanced security.

      ![DB encryption](./images/40.%20RDS%20encrypt%20opt.png)

      - **Maintenance:** Set preferred maintenance windows to minimize impact.

   7. **Launch the RDS Instance:**
      - Review all settings.
      - Click **Create Database**.
      - Wait for the RDS instance status to become **Available**.

      ![RDS Launch](./images/41.%20RDS%20create%20db.png)
      **Creation in progress:**
      ![RDS create in progress](./images/42.%20RDS%20create%20in%20progress.png)
      **Creation successful:**
      ![RDS create successful](./images/43.%20RDS%20create%20success.png)

      *Figure 29: Launching RDS Instance*

2. **Note the RDS Endpoint and Port:**
   - After the RDS instance is available, note the **Endpoint** and **Port** for configuring WordPress.

   ![RDS Endpoint](./images/44.%20RDS%20endpoint&port.png)

   *Figure 30: RDS Endpoint Information*

3. **Verify Multi-AZ Deployment:**
   - In the RDS console, check that your database instance has a **Standby** in a different AZ.

   ![Multi-AZ Status](./images/45.%20RDS%20multi-AZ%20status.png)

   *Figure 31: RDS Multi-AZ Deployment Confirmation*

---

### Step 5: Launch WordPress EC2 Instances

1. **Launch EC2 Instance:**

   1. **Navigate to the EC2 Console:**

      - From the **Services** menu, select **EC2**.

      ![EC2 Console](./images/13.%20EC2%20console.png)

      *Figure 32: Navigating to the EC2 Console*

   2. **Click on "Launch Instance":**

      - In the EC2 dashboard, click on the **Launch Instance** button.

      ![Launch Instance](./images/13.5%20Launch%20instance.png)

      *Figure 33: Launching a New EC2 Instance for WordPress*

   3. **Configure Instance Details:**
      - **Name Tag:** `WordPress-Server`
      - **AMI:** Ubuntu Server 20.04 LTS (or the latest stable version)

      ![wordpress AMI](./images/15%20ubuntu%20AMI.png)

      - **Instance Type:** `t3.micro` *(Adjust based on requirements)*

      ![Instance type](./images/16.%20bastion%20inst%20type.png)

      - **Key Pair:** Select your **SSH key pair** or create a new one.
        - *We will use the key pair to SSH into your instance via the Bastion Host.*
        - *If creating a new key pair, follow the prompts to download the `.pem` file securely.*
        - *We would be using the same key pair created for he bastion host*

      ![wordpres key pair][key pair]

      - **Network:** `wordpress-vpc`
      - **Subnet:** Select one of the **private subnets** (`private-subnet-1` through `private-subnet-3`).
      - **Auto-assign Public IP:** **Disable**
      - **IAM Role:** Assign if necessary (e.g., for Systems Manager access).

      ![Configure Instance][def]

      *Figure 34: Configuring Instance Details for WordPress Server*

   4. **Add Storage:**
      - Configure as needed (e.g., `20 GB` General Purpose SSD).

      ![Add Storage](./images/52.%20wordpress%20ebs%20storage.png)

      *Figure 35: Adding Storage to WordPress EC2 Instance*

   5. **Add Tags:**
      - Add tags for identification:
        - **Key:** `Name`
        - **Value:** `WordPress-Server`

   6. **Configure Security Group:**
      - **Create a new security group** or select an existing one.

      ![wordpress SG](./images/49.%20wordpress%20create%20SG.png)
      **SG name & description:**
      ![wordpress SG](./images/50.%20wordpress%20SG%20name&description.png)

      - **Inbound Rules:**
        - **HTTP:** Port 80 from ALB Security Group - # *Configured after ALB is created*

         ![ALB-to-Wordpress-HTTP](./images/103.%20ALB%20update%20ingress%20rule%204.png)

        - **SSH:** Port 22 from Bastion Host Security Group *(if direct SSH access is needed)*

         ![Bastion-to-Wordpress-SSH](./images/51.%20wordpress%20ingress%20rule.png)

      - **Outbound Rules:**
        - **MySQL:** Port 3306 to RDS Security Group
        - **All traffic:** Allow outbound as necessary.

      *Figure 37: WordPress EC2 Security Group Rules*

   7. **Configure User Data:**
      - In **Advanced Details**, attach the user data script file **"wordpress-ubuntu-sh"** or **copy & paste** the entire script included in this repository into the user data section to install and configure WordPress on boot.
      - **Note:** Detailed comments are included in the wordpress installation script for easy comprehension of commands and required packages.

      ![User Data](./images/wordpress%20userdata.png)

      *Figure 38: Configuring User Data for WordPress Installation*

   8. **Review and Launch:**
      - Review all configurations.
      - Click **Launch Instance**.

   9. **Wait for Instance Initialization:**
      - Ensure the instance status is **running** and **passed** all status health checks.

      ![wordpress Running](./images/54.%20wordpress%20instance%20running.png)

      *Figure 40: WordPress EC2 Instance Running*

---

### Step 6: Set Up Application Load Balancer

1. **Create Application Load Balancer (ALB):**

   1. **Navigate to the EC2 Console and Select "Load Balancers":**

      - From the **Services** menu, select **EC2**.
      - In the EC2 dashboard, under **Load Balancing**, select **Load Balancers**.
      - Click **Create Load Balancer**.

      ![Load Balancers Navigation](./images/55.%20ALB%20create%20new.png)

      - Choose **Application Load Balancer**.

      ![Load Balancers Navigation](./images/56.%20ALB%20create%20new%202.png)

      *Figure 45: Navigating to Load Balancers*

   2. **Configure ALB Settings:**
      - **Name:** `WordPress-ALB`
      - **Scheme:** Internet-facing
      - **IP Address Type:** IPv4
      - **Listeners:** HTTP (port 80)

      ![ALB Settings](./images/57.%20ALB%20basic%20config.png)

      *Figure 46: ALB Configuration Settings*

   3. **Select VPC and Availability Zones:**
      - **VPC:** `wordpress-vpc`
      - **Availability Zones:** Select all **public subnets** (`public-subnet-1`, `public-subnet-2`, `public-subnet-3`).

      ![ALB Availability Zones](./images/58.%20ALB%20network%20mapping.png)

      *Figure 47: Selecting VPC & Availability Zones for ALB*

   4. **Configure Security Groups:**
      - **Create a new security group** or select an existing one.

      ![ALB New Security Group](./images/59.%20ALB%20SG%20create.png)

      ![ALB SG inbound rule](./images/60.%20ALB%20SG%20config%201.png)

      - **Inbound Rules:**
        - **HTTP:** Port 80 from anywhere (`0.0.0.0/0`)

      ![ALB SG inbound rule](./images/61.%20ALB%20SG%20config%20ingress%20rule.png)

      - **Outbound Rules:**
        - **All Traffic:** To WordPress EC2 Security Group.

          ![ALB SG outbound rule](./images/62.%20ALB%20SG%20config%20egress%20rule.png)

      *Figure 48: Configuring ALB Security Group*

      - **Save the security group** and select it for the ALB.
      - **Tags:** Add tags (Optional)
      Click on **Create security group**
    ![Save ALB Security Group](./images/63.%20ALB%20SG%20create%20complete.png)
      *Select SG for ALB:*
     ![Select ALB Security Group](./images/64.%20ALB%20select%20SG.png)

      *Figure 49: Selecting ALB Security Group*

   5. **Configure Listeners and Routing:**
      - **Target Group:** We would be creating a new target group for this project.

2. **Create Target Group:**

   1. **Click on "Create target group":**

      ![ALB create new TG](./images/65.%20ALB%20TG%20create.png)

      - Select **Instances** as the target type.

      ![ALB TG config](./images/66.%20ALB%20TG%20basic%20config.png)

      - **Name:** `WordPress-TG`
      - **Protocol:** HTTP
      - **Port:** 80
      - **VPC:** `wordpress-vpc`

      ![ALB TG config](./images/67.%20ALB%20TG%20name%20&%20vpc%20set.png)

      - **Health Checks:**
        - **Protocol:** HTTP
        - **Path:** `/`
      - **Advanced health check settings:** Use defaults or adjust as needed.

      ![ALB TG health check](./images/68.%20ALB%20TG%20health%20check%20set.png)

      - **Tags:** Add tags(Optional) & **click** on **Next** to proceed.

      ![Add TG tags](./images/69.%20ALB%20TG%20tag%20set%20&%20'Next'.png)

   2. **Register Targets:**
      - Select the **WordPress EC2 instances** you launched.
      - Click **Include as pending below**.
      - Click **Create target group**.

      ![Register Targets](./images/70.%20ALB%20TG%20register%20target%20instance.png)

      ![Create Target Group](./images/71.%20ALB%20TG%20review%20and%20create.png)

      *Figure 43: Registering EC2 Instances to Target Group*

   3. **Verify Target Group Health:**
      - After a few minutes, ensure that the targets are **healthy**.

      ![Target Group Healthy](./images/71.5%20Target%20Group-healthy.png)

      *Figure 44: Target Group Healthy Status*

   4. **Select Target group for ALB:** Navigate back to **listeners and routing** configuration and select the newly created Target group.

      ![Select Target Group](./images/73.%20ALB%20TG%20select.png)

   5. **Review and Create:**
      - Review all settings.
      - Click **Create Load Balancer**.
      - Wait for the ALB to be provisioned.

      ![ALB Review Configuration](./images/74.%20ALB%20Review.png)
      Click **Create load balancer**
      ![ALB create](./images/75.%20ALB%20create%20complete.png)

      *Figure 51: Reviewing ALB Configuration*

      *ALB in provisioning state:*
      ![ALB Provisioning](./images/76.%20ALB%20provisioning%20state.png)

      *Figure 52: Provisioning Load Balancer*

   6. **Verify Load Balancer:**
      - Once the ALB status is **active**, note the **DNS name**. This will be used to access your WordPress site.

      ![ALB Active](./images/77.%20ALB%20active%20&%20dns%20name.png)

      *Figure 53: ALB Active and DNS Name*

---

### Step 7: Configure Auto Scaling Group

Implementing an Auto Scaling Group (ASG) ensures that your WordPress deployment can handle varying traffic loads by automatically adjusting the number of EC2 instances.

1. **Create a Launch Template from an Existing WordPress Instance:**

   Instead of creating a new launch template from scratch, you will create a launch template based on an existing WordPress EC2 instance to replicate its configuration across your Auto Scaling Group.

   1. **Create a Launch Template from the Existing Instance:**

      1. **Navigate to the EC2 Console:**
         - From the **Services** menu, select **EC2**.
         - In the EC2 dashboard, under **Instances**, select **Instances**.

      2. **Select the Existing WordPress EC2 Instance:**
         - Locate the running WordPress EC2 instance.
         - Right-click the instance and select **Create Template from Instance**.

           ![ASG launch temp from wordpress server](./images/80.%20ASG%20launch%20template%201.png)

      3. **Configure the Launch Template:**
         - **Launch template name:** `WordPress-Project`
         - **Template version description:** `A dev webserver for WordPress`

            ![ASG launch temp config](./images/81.%20ASG%20lauch%20temp%202.png)

         - **Instance type:** Keep the existing instance type (e.g., `t3.micro`).
         - **Key pair:** Use the key pair associated with the WordPress instance.
         - **Network settings:**
           - **VPC:** `wordpress-vpc`
           - **Subnets:** Select private subnets (`private-subnet-1`, `private-subnet-2`, `private-subnet-3`).
         - **Security groups:** Select the WordPress EC2 Security Group already associated with the instance.
         - **User data:** The user data script will be automatically populated from the instance. Ensure it contains the configuration for installing and setting up WordPress.

           ![ASG launh temp userdata](./images/83.%20ASG%20launch%20temp%204(userdata).png)

         - **Storage:** Configure storage as needed (e.g., retain the same disk size and type as the existing instance).

      4. **Create the Launch Template:**
         - Click **Create launch template**.

           ![Create Launch Template](./images/85.%20ASG%20create%20launch%20template.png)

           *Figure: Creating Launch Template from an Existing WordPress Instance*

           ![Launch Template review](./images/86.%20ASG%20launch%20temp%20review.png)

           *Figure: Review Launch Template from an Existing WordPress Instance*

2. **Create Auto Scaling Group:**

   1. **Navigate to "Auto Scaling Groups" in the EC2 Console:**

      - From the **Services** menu, select **EC2**.
      - In the EC2 dashboard, under **Auto Scaling**, select **Auto Scaling Groups**.

        ![ASG create new](./images/78.%20ASG%20navi.png)

      - Click **Create Auto Scaling group**.

        ![ASG create new](./images/79.%20ASG%20create.png)

   2. **Configure Auto Scaling Group:**
      - **Auto Scaling group name:** `WordPress-ASG`
      - **Launch template:** Select the launch template created from the existing WordPress instance (`WordPress-Project`)

        ![Launch Template select](./images/87.%20ASG%20select%20launch%20temp.png)

      - **Version:** Latest
      - Click **Next**.

        ![Launch Template Next](./images/88.%20ASG%20select%20launch%20temp%202.png)

   3. **Configure VPC and Subnets:**
      - **VPC:** `wordpress-vpc`
      - **Subnets:** Select all **private subnets** (`private-subnet-1` through `private-subnet-3`)
      - Click **Next**.

        ![Launch Template VPC](./images/90.%20ASG%20config%20network(vpc).png)

   4. **Configure Advanced Options:**
      Integrate our ASG with our existing load balancer. We would carry out a few configurations as follows.
      - **Load Balancing:** Select the **Attach to an existing load balancer** option, and select the target group associated with the load balancer.

      ![ASG integrate ALB](./images/91.%20ASG%20config%20alb.png)

      *Select Target group:*
      ![ASG integrate ALB](./images/92.%20ASG%20config%20alb%202.png)

      - **Health Checks:** Enable **EC2 and ELB health checks**.
      - **Instance Protection:** Enable if you want to protect specific instances from scale-in events.

      ![ASG integrate ALB-healthcheck](./images/93.%20ASG%20alb%20config%203-health%20check.png)

      - Click **Next**.

      ![ASG integrate ALB-next](./images/94.%20ASG%20alb%20config%204.png)

   5. **Configure Group Size and Scaling Policies:**
      - **Desired capacity:** `2`
      - **Minimum capacity:** `1`
      - **Maximum capacity:** `3`

      ![ASG group size](./images/95.%20ASG%20config%20group%20size.png)

      - **Scaling policies:**
        - **Target Tracking Scaling Policy:**
          - **Metric type:** Average CPU Utilization
          - **Target value:** `50%`
          - This policy will add or remove instances to maintain the average CPU utilization around 50%.

      ![ASG scaling policy](./images/96.%20ASG%20config%20scale%20policy.png)

      - Click **Next**.

      ![ASG config - next](./images/97.%20ASG%20config%207-next.png)

   6. **Configure Notifications (Optional):**
      - Set up SNS topics for notifications on scaling events if desired.
       *We wouldn't be setting notifications for this project*
      - Click **Next**.

      ![ASG config-notifi](./images/98.%20ASG%20config%208-notifi.png)

   7. **Configure Tags:**
      - No tags

      ![ASG config-tags](./images/98.5%20asg%20config%20tag.png)

   8. **Review and Create:**
      - Review all configurations.
      - Click **Create Auto Scaling Group**.

      ![ASG review & create](./images/99.%20ASG%20config%20create%20complete.png)

      - Confirm that the ASG is created and instances are launched accordingly.

3. **Test Auto Scaling Group Functionality:**

   After creating the ASG, you can test its scaling behavior by applying stress to the instance's CPU. This can be done by installing and running a stress test tool on one of the WordPress instances.

   1. **Connect to the WordPress EC2 Instance:**
      - Use SSH to connect from the Bastion Host to one of the running WordPress EC2 instances launched by the Auto Scaling Group.
        - Navigate to EC2 console, and copy the public IP of the bastion host instance and the private IP of any of the wordpress instances.
        - Next, open a terminal on your local machine and input the below command. Replace the IPs of the instances accordingly.
        - **Note:** Ensure you are currently in the directory/folder where your key pair is located.
      - **SSH tunnel command:**

       ```bash
         ssh -A -i `/path/to/bastion-key-pair.pem` -o ProxyCommand="ssh -A -i bastion.pem ubuntu@<Bastion_Host_Public_IP> -W %h:%p" ubuntu@<WordPress_EC2_Private_IP>
        ```

        **Expected Output:**
        ![SSH tunnel command](./images/ASG%20Test%20-%20ssh%20into%20wordpress.png)

        ![SSH tunnel command](./images/ASG%20Test%202%20-%20ssh%20into%20wordpress.png)

   2. **Install the "stress" Tool:**
      - Once succesfully connected to the wordpress instance, run the following commands to install the `stress` tool on the instance:

      ```bash
        sudo apt update
        sudo apt install stress -y
        ```

      ![ASG stress test](./images/ASG%20Test%203-update.png)

      ![ASG stress test](./images/ASG%20Test%204-install%20stress.png)

   3. **Run the Stress Test:**
      - Execute the `stress` command to create CPU load:

        ```bash
        stress --cpu 4 --timeout 300
        ```

         ![ASG stress test-run stress command](./images/ASG%20Test%205-start%20stress%20test.png)
         **Expected Output:**
         ![ASG stress test-run stress command](./images/ASG%20Test%206-start%20stress%20test.png)

      - This will apply stress to the CPU using 4 cores for 5 minutes (300 seconds).

   4. **Monitor Auto Scaling Behavior:**
      - In the **EC2 Auto Scaling Groups** console, monitor the scaling behavior. The Auto Scaling Group should detect the high CPU utilization and scale out by adding more instances as per the scaling policies configured earlier.

   5. **Stop the Stress Test:**
      - Once the test is complete, or you see the ASG scaling up, you can stop the stress test by using `Ctrl+C`.
      **ASG scale up:**
      ![ASG Monitoring-High](./images/ASG%20scale%20up.png)
      **CloudWatch monitor:**
      ![CW-alarm-high](./images/CW%20alarm%20high.png)

        **ASG scale down:**
        ![ASG Monitoring-Low](./images/ASG%20scale%20down.png)
        **CloudWatch monitor:**
        ![CW-alarm-low](./images/CW%20alarm%20low.png)

        *Figure: Monitoring ASG Activity*

### Step 8: Connect WordPress to RDS

Connecting your WordPress EC2 instances to the MySQL RDS database is essential for WordPress to store and retrieve data. Follow the steps below to securely configure this connection.

1. **Verify RDS Instance Availability**

   Ensure that your RDS instance is up and running.

   - **Check RDS Status:**

     Navigate to the [RDS Console](https://console.aws.amazon.com/rds/) and ensure that the `wordpress` instance status is **Available**.

     ![RDS Status](./images/RDS%20status.png)

     *Figure 66: RDS Instance Status*

2. **Ensure Security Group Permissions**

   Confirm that the RDS security group allows inbound traffic from the WordPress EC2 instances.

   - **Verify/Edit RDS Security Group:**

     1. **Select the Security Group:**
        - In the RDS console, select your RDS instance.
        - Under **Connectivity & security**, find the **VPC security groups** and click on the relevant security group.

      ![RDS Security Group Selection](./images/RDS%20SG%20select.png)

        *Figure 67: Selecting RDS Security Group*

     2. **Edit Inbound Rules:**
        - Click on the **Inbound rules** tab.
        - Click **Edit inbound rules**.
        - Add a rule:
          - **Type:** MySQL/Aurora
          - **Protocol:** TCP
          - **Port Range:** 3306
          - **Source:** Select **Custom** and choose the WordPress EC2 Security Group.
        - Click **Save rules**.

      ![RDS Security Group Inbound Rules](./images/RDS%20SG%20inbound%20rules.png)

        *Figure 68: RDS Security Group Inbound Rules*

3. **SSH into the WordPress EC2 Instance via Bastion Host**

   Access your WordPress servers to verify the configuration files set up using the user data script securely through the Bastion Host.

   - **Connect to Bastion Host:**
     - Open a terminal on your local machine.
     - Use the SSH key pair associated with the Bastion Host.
     - Connect to the Bastion Host:

       ```bash
       ssh -i /path/to/bastion-key-pair.pem ubuntu@<Bastion_Host_Public_IP>
       ```

       **Note:** Replace `/path/to/bastion-key-pair.pem` with your SSH key path and `<Bastion_Host_Public_IP>` with the Bastion Host's public IP address.

   - **From Bastion Host, SSH into WordPress EC2 Instance:**
     - Use the private IP address of the WordPress EC2 instance.

       ```bash
       ssh -i /path/to/wordpress-key-pair.pem ubuntu@<WordPress_EC2_Private_IP>
       ```

       **Note:** Replace `/path/to/wordpress-key-pair.pem` with your WordPress EC2 key pair path and `<WordPress_EC2_Private_IP>` with the instance's private IP address.

     - **Alternatively, Using SSH tunneling:**
       - SSH tunneling through the bastion host

       ```bash
         ssh -A -i `/path/to/bastion-key-pair.pem` -o ProxyCommand="ssh -A -i `/path/to/bastion-key-pair.pem` ubuntu@<Bastion_Host_Public_IP> -W %h:%p" ubuntu@<WordPress_EC2_Private_IP>
        ```

   1. **Navigate to WordPress Directory:**
      Once connected to the WordPress EC2 instance, navigate to the directory where WordPress is installed.

      ```bash
      cd /var/www/html
      ```

      ![Navigate to WordPress Directory](./images/Verify%20wp-config.png)

      *Figure 69: Navigating to WordPress Directory*

   2. **Verify configuration in `wp-config.php`:**
      Open the `wp-config.php` file using a text editor like nano.

      ```bash
        sudo nano wp-config.php
      ```

      ![Edit wp-config](./images/Verify%20wp-config%202.png)

      ![Edit wp-config](./images/Verify%20wp-config%203.png)

      *Figure 70: Editing wp-config.php*

      **Note:** Replace `sudo nano` with your preferred text editor (e.g., `sudo vim`)

   3. **Verify Database Settings:**

      Locate the following lines and verify they have been successfully replaced with your RDS database details:

      ```php
        define('DB_NAME', 'WordPressDB');
        define('DB_USER', 'admin');
        define('DB_PASSWORD', 'YourStrongPassword');
        define('DB_HOST', 'wordpress-db.xxxxxxxx.us-east-1.rds.amazonaws.com:3306');
      ```

      **Important:**
      - Replace `'YourStrongPassword'` with your actual RDS password.
      - Replace `'wordpress-db.xxxxxxxx.us-east-1.rds.amazonaws.com'` with your RDS endpoint.

      **Expected Output:**
      ![DB setting verification](./images/Verify%20wp-config%204.png)

      **Verify Authentication Unique Keys and Salts:**
      - **Note:** Generate these using the [WordPress.org secret-key service](https://api.wordpress.org/secret-key/1.1/salt/).
      - Verify the placeholder keys in `wp-config.php` were replaced with the generated ones.

      **Expected Output:**

      ![Auth & Salts Inserted](./images/Verify%20wp-config%204-auth&salts%20keys.png)

      *Figure 71: Authentication Unique Keys and Salts*

      - **Save and Exit:**
        - Press `Ctrl + X`, then `Y`, and `Enter` to save changes.

   4. **Restart Apache to Apply Changes:**
      After updating the configuration, restart the Apache web server:

      ```bash
      sudo systemctl restart apache2
      ```

      **Verification of Apache:**
      Check the status of Apache to ensure it's running without errors:

      ```bash
      sudo systemctl status apache2
      ```

      ![Apache status command](./images/Verify%20wp-config%205-apache%20stat.png)

      **Expected Output:**

      ![Apache Status](./images/Verify%20apache%20status.png)

      *Figure 72: Apache Status Confirmation*

   5. **Automate Configuration Across ASG Instances:**
      To ensure that all instances launched by the ASG have the correct configuration:
      - **Use a Shared File System:** Consider using Amazon EFS to share files across instances.
      - **Leverage Configuration Management Tools:** Tools like Ansible, Chef, or AWS Systems Manager can automate configuration.
      - **Update Launch Template User Data:** Ensure the user data script includes all necessary steps to configure WordPress correctly on each instance.

      *Example: Adding EFS Mounting in User Data Script*  -  **Optional**

      ```bash
      #!/bin/bash
      sudo apt update
      sudo apt upgrade -y
      sudo apt install -y apache2 php php-mysql amazon-efs-utils

      # Mount EFS
      sudo mkdir -p /mnt/efs
      sudo mount -t efs fs-12345678:/ /mnt/efs
      sudo chown -R www-data:www-data /mnt/efs

      # Link WordPress directory to EFS
      sudo rm -rf /var/www/html/*
      sudo ln -s /mnt/efs /var/www/html

      # Restart Apache
      sudo systemctl restart apache2
      ```

      *Note: Replace `fs-12345678` with your EFS file system ID.*

---

### Step 9: Finalize WordPress Setup via Browser

1. **Retrieve ALB DNS Name:**

   1. **Navigate to the EC2 Console and Select "Load Balancers":**

      - From the **Services** menu, select **EC2**.
      - In the EC2 dashboard, under **Load Balancing**, select **Load Balancers**.
      - Click on your created Load Balancer for the WordPress server, **"WordPress-ALB"**.
      - Copy the **DNS Name**.

      ![ALB DNS Information](./images/ALB%20resource%20map%20and%20DNS%20name.png)

      *Figure 73: ALB DNS Information*

2. **Access WordPress Installation Wizard:**

   1. **Open a Web Browser:**
      - Navigate to `http://<ALB_DNS_Name>`.
      - ***Note:*** Replace `<ALB_DNS_Name>` with the copied DNS name (e.g., `http://wordpress-alb-1234567890.us-east-1.elb.amazonaws.com`).

   2. **Expected Output:**
      - You should see the WordPress installation page.

      ![WordPress Install](./images/Wordpress%20install%20start.png)

      *Figure 74: WordPress Installation Wizard*

3. **Complete the WordPress Installation:**
   - **Set up the following:**
     - **Site Title:** Enter your desired site title.
     - **Username:** Create an admin username.
     - **Password:** Set a strong password.
     - **Your Email:** Provide an admin email address.
     - **Search Engine Visibility:** Choose whether to discourage search engines from indexing the site.
   - Click **Install WordPress**.

   **Expected Output:**

   ![WordPress Setup](./images/Wordpress%20install%20wizard.png)

   *Figure: Completing WordPress Installation*

4. **Log in to WordPress Dashboard:**

   - Once installed, log in using the admin credentials you created.

   **Expected Output:**

   ![WordPress Login](./images/Wordpresss%20login.png)

   *Figure 76: WordPress Login Page*

   - **Access WordPress Dashboard:**

     ![WordPress Dashboard](./images/wordpress%20dashboard.png)

     **Access using Application load balancer DNS name:**
     ![WordPress web URL](./images/Wordpress%20webinterface%20using%20ALB%20DNS%20name.png)

     *Figure: WordPress Dashboard*

---

## Monitoring and Maintenance

Maintaining and monitoring your WordPress deployment ensures that your site remains secure, performs optimally, and can scale according to demand.

1. **Enable CloudWatch Monitoring:**
   - **Metrics:** Monitor CPU utilization, memory usage, disk I/O, and network traffic.
   - **Alarms:** Set up alarms for thresholds (e.g., high CPU usage) to trigger scaling actions or notifications.
   - **Dashboards:** Create custom dashboards to visualize key metrics.

2. **Implement Logging:**
   - **Access Logs:** Enable ALB access logs for traffic analysis.
     - Navigate to the ALB settings and enable access logs, specifying an S3 bucket for storage.
   - **Application Logs:** Use Amazon CloudWatch Logs to collect and monitor logs from WordPress and Apache.
     - Install and configure the CloudWatch agent on EC2 instances.
   - **Bastion Host Logs:** Monitor SSH access logs to detect unauthorized access attempts.
     - Regularly review `/var/log/auth.log` (Ubuntu) or `/var/log/secure` (Amazon Linux).

3. **Regular Backups:**
   - **RDS Backups:** Ensure automated backups are enabled for the RDS instance.
     - Consider using snapshots for point-in-time recovery.
   - **WordPress Files:** Use Amazon S3 or EFS for storing backups of WordPress files and configurations.
     - Implement lifecycle policies for automated backups.

4. **Security Updates:**
   - Regularly update the operating system and installed packages on EC2 instances.

     ```bash
     sudo apt update && sudo apt upgrade -y
     ```

   - Apply security patches to WordPress plugins and themes.
   - Use security plugins (e.g., Wordfence) to enhance WordPress security.

5. **Scaling Policies Review:**
   - Periodically review and adjust ASG scaling policies based on traffic patterns and performance metrics.
   - Optimize scaling thresholds to better match actual usage.

6. **Cost Management:**
   - Use AWS Cost Explorer to monitor and optimize costs.
   - Implement budget alerts to stay informed about spending.
   - Right-size instances based on utilization patterns.

---

## Conclusion

Deploying an advanced WordPress setup on AWS provides a robust, scalable, and secure environment for hosting your website. This architecture leverages key AWS services to ensure high availability, efficient traffic management, and enhanced security:

- **VPC**: Provides network isolation.
- **Bastion Host**: Enables secure SSH access to private EC2 instances.
- **NAT Gateway**: Facilitates secure outbound internet access for private instances.
- **EC2**: Hosts WordPress application servers.
- **RDS with Multi-AZ**: Manages the WordPress database with high availability and fault tolerance.
- **ALB**: Distributes incoming traffic.
- **Auto Scaling Group (ASG)**: Ensures scalability and high availability of WordPress instances.

The separation of public and private subnets enhances security by isolating critical components like the database and application servers. Implementing security groups and a Bastion Host further fortifies the infrastructure against unauthorized access. The addition of a NAT Gateway ensures that private instances can securely access the internet for necessary updates and downloads without being exposed. Furthermore, the Auto Scaling Group ensures that your WordPress deployment can handle varying traffic loads, maintaining optimal performance and reliability.

The Multi-AZ deployment of the RDS MySQL database provides resilience against AZ-specific failures, ensuring that your WordPress site remains operational even in the face of infrastructure issues. This deployment strategy not only meets current requirements but also offers flexibility for future expansions and integrations.

---

## Clean-Up

To avoid unnecessary charges, it's crucial to clean up all AWS resources created during this deployment when they're no longer needed. Follow these steps to terminate and delete the resources:

### 1. Terminate EC2 Instances

1. **Navigate to the EC2 Console:**
   - From the **Services** menu, select **EC2**.

2. **Select the Instances:**
   - Select the instances associated with the WordPress deployment (excluding the Bastion Host if you wish to retain it).

3. **Terminate Instances:**
   - Click **Actions** > **Instance State** > **Terminate Instance**.
   - Confirm the termination.

   ![Terminate EC2 Instances](./images/Terminate%20Instances.png)

   ![Terminate EC2 Instances 2](./images/Terminate%20Instances%202.png)

   *Figure 78: Terminating EC2 Instances*

### 2. Delete RDS Instances

1. **Navigate to the RDS Console:**
   - From the **Services** menu, select **RDS**.

2. **Select the RDS Instance:**
   - Select the `wordpress` RDS instance.

3. **Delete RDS Instance:**
   - Click **Actions** > **Delete**.
   - Follow the prompts to confirm deletion.
   - **Optional:** Retain automated backups if needed.

   ![Delete RDS Instance](./images/Terminate%20RDS.png)

   ![Delete RDS Instance 2](./images/Terminate%20RDS%202.png)

   ![Delete RDS Instance 3](./images/Terminate%20RDS%203.png)

   *Figure 79: Deleting RDS Instance*

### 3. Delete Load Balancers

1. **Navigate to the EC2 Console and Select "Load Balancers":**
   - From the **Services** menu, select **EC2**.
   - In the EC2 dashboard, under **Load Balancing**, select **Load Balancers**.

2. **Select the ALB:**
   - Select the `WordPress-ALB`.

3. **Delete Load Balancer:**
   - Click **Actions** > **Delete Load Balancer**.
   - Confirm the deletion.

   ![Delete ALB](./images/Terminate%20ALB.png)

   ![Delete ALB 2](./images/Terminate%20ALB%202.png)

   *Figure 80: Deleting Application Load Balancer*

### 4. Delete Auto Scaling Groups

1. **Navigate to the EC2 Console and Select "Auto Scaling Groups":**
   - From the **Services** menu, select **EC2**.
   - In the EC2 dashboard, under **Auto Scaling**, select **Auto Scaling Groups**.

2. **Select the ASG:**
   - Select the `WordPressASG`.

3. **Delete Auto Scaling Group:**
   - Click **Actions** > **Delete Auto Scaling Group**.
   - Confirm the deletion and choose whether to retain or delete the Launch Template.

   ![Delete ASG](./images/Terminate%20ASG.png)

   ![Delete ASG 2](./images/Terminate%20ASG%202.png)

   ![Delete ASG 3](./images/Terminate%20ASG%203.png)

   *Figure 81: Deleting Auto Scaling Group*

### 5. Delete NAT Gateway

1. **Navigate to the VPC Console:**
   - From the **Services** menu, select **VPC**.

2. **Select "NAT Gateways":**
   - In the VPC dashboard, select **NAT Gateways** from the left menu.

3. **Select the NAT Gateway:**
   - Select the `NAT-Gateway`.

4. **Delete NAT Gateway:**
   - Click **Actions** > **Delete NAT Gateway**.
   - Confirm the deletion.

5. **Release Elastic IP:**
   - After deleting the NAT Gateway, navigate to **Elastic IPs** in the EC2 Console.
   - Select the Elastic IP associated with the NAT Gateway.
   - Click **Actions** > **Release Elastic IP address**.
   - Confirm the release.

6. **Repeat deletion steps for the two(2) remaining NAT Gateways**

   ![Release Elastic IP](./images/Terminate%20eip.png)

   ![Release Elastic IP 2](./images/Terminate%20eip%202.png)

   *Figure 82: Releasing Elastic IP*

### 6. Delete VPC and Subnets

1. **Navigate to the VPC Console:**
   - From the **Services** menu, select **VPC**.

2. **Select the VPC:**
   - Select the `WordPress-vpc`.

3. **Ensure All Dependencies Are Detached or Deleted:**
   - Make sure all subnets, route tables, gateways, and other dependencies are detached or deleted.

4. **Delete VPC:**
   - Click **Actions** > **Delete VPC**.
   - Confirm the deletion.

   ![Delete VPC](./images/Terminate%20VPC.png)

   ![Delete VPC 2](./images/Terminate%20VPC%202.png)

   *Figure 83: Deleting VPC*

### 7. Delete Security Groups

1. **Ensure No Other Resources Are Using the Security Groups:**

2. **Navigate to the Security Groups Section:**
   - In the VPC or EC2 console, select **Security Groups**.

3. **Select the Security Groups:**
   - Select the security groups created for Bastion Host, WordPress, ALB, and RDS.

4. **Delete Security Groups:**
   - Click **Actions** > **Delete Security Group**.
   - Confirm the deletion.

   ![Delete Security Groups](./images/Terminate%20Security%20group.png)

   ![Delete Security Groups 2](./images/Terminate%20Security%20group%202.png)

   *Figure 84: Deleting Security Groups*

### 8. Delete Key Pairs (Optional)

1. **Navigate to the EC2 Key Pairs Console:**
   - From the **Services** menu, select **EC2**.
   - In the EC2 dashboard, under **Network & Security**, select **Key Pairs**.

2. **Select the Key Pairs:**
   - Select the key pair(s) you no longer need.

3. **Delete Key Pairs:**
   - Click **Actions** > **Delete Key Pair**.
   - Confirm the deletion.

   ![Delete Key Pairs](./images/Terminate%20Key%20pair.png)

   ![Delete Key Pairs 2](./images/Terminate%20Key%20pair%202.png)

   ![Delete Key Pairs 3](./images/Terminate%20Key%20pair%203.png)

   *Figure 85: Deleting Key Pairs*

### 9. Review and Confirm

- **Double-Check All Services:**
  - Ensure all resources have been successfully terminated and deleted.
- **Verify No Lingering Resources:**
  - Check that there are no remaining resources that might incur costs.
- **Confirm No Active Instances:**
  - Ensure that no EC2 instances, RDS databases, or other services are running.

> **Note:** Always ensure you have backups or snapshots of any critical data before terminating resources to prevent data loss.

---

## Additional Best Practices

- **Implement IAM Best Practices:**
  - Use least privilege access by assigning minimal necessary permissions.
  - Regularly rotate access keys and credentials.
  - Use IAM roles for EC2 instances instead of storing credentials on instances.

- **Enable Multi-Factor Authentication (MFA):**
  - Protect your AWS account by enabling MFA, especially for privileged users.

- **Use AWS Systems Manager:**
  - For enhanced management and automation of your EC2 instances without relying solely on SSH.

- **Implement Web Application Firewall (WAF):**
  - Protect your WordPress site from common web exploits and bots by integrating AWS WAF with your ALB.

- **Regularly Review and Audit:**
  - Use AWS Config and AWS CloudTrail to monitor and audit resource configurations and API calls.

---

## Troubleshooting Tips

- **Instance Connectivity:**
  - Ensure that the security groups are correctly configured to allow necessary traffic.
  - Verify that the route tables are correctly routing traffic through the NAT Gateway for private subnets.

- **ALB Health Checks:**
  - If instances are marked as unhealthy, verify that Apache is running and accessible on port 80.
  - Check the WordPress installation and ensure the site is correctly configured.

- **Auto Scaling Issues:**
  - Ensure that the Launch Template is correctly configured with all necessary user data and security settings.
  - Verify that scaling policies are appropriate for your traffic patterns.

- **Database Connectivity:**
  - Confirm that the `wp-config.php` file has the correct RDS endpoint and credentials.
  - Ensure that the RDS security group allows inbound traffic from the WordPress EC2 security group on port 3306.

---

By following this guide, you will have a robust, scalable, and secure WordPress deployment on AWS, capable of handling varying traffic loads while maintaining high availability and security standards. This setup not only meets current requirements but also offers flexibility for future growth and

[key pair]: ./images/47.%20wordpress%20keypair.png
[def]: ./images/48.%20wordpress%20vpc.png
