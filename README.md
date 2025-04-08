# 🔍 End-to-End Logging with ELK & Filebeat using EC2 on AWS

In this guide, we'll walk through setting up a centralized logging system using the ELK stack (Elasticsearch, Logstash, and Kibana) on AWS EC2. We'll also deploy a Java application on a second EC2 instance, generate logs, and forward those logs to the ELK server using Filebeat.

By the end, you'll have:

* One EC2 instance running ELK stack
* Another EC2 instance running a Java app
* Logs from the app being shipped to the ELK stack in real-time

***

### 🧱 Prerequisites

* AWS account with EC2 access
* Two `t2.medium` EC2 instances with:
  * 20 GB EBS (General Purpose SSD)
  * Ubuntu Server 22.04 LTS
  * Same security group for both
* Basic knowledge of Linux, EC2, and Git

### 🛡 Step 1: Setup the Security Group

Create a **Security Group** called `elk-filebeat-sg` with the following rules:

| Type          | Protocol | Port Range | Source        |
| ------------- | -------- | ---------- | ------------- |
| SSH           | TCP      | 22         | Your IP       |
| HTTP          | TCP      | 80         | 0.0.0.0/0     |
| Custom TCP    | TCP      | 5044       | sg-\<same-sg> |
| Kibana        | TCP      | 5601       | 0.0.0.0/0     |
| Elasticsearch | TCP      | 9200       | sg-\<same-sg> |

_Replace `sg-<same-sg>` with the same security group ID. It allows communication between both EC2 instances._

***

### 🖥 Step 2: Launch EC2 Instances

Launch **two EC2 instances** with:

* Type: `t2.medium`
* Storage: 20 GB
* OS: Ubuntu Server 22.04 LTS
* Security Group: `elk-filebeat-sg`

Let’s name them:

* `elk-instance`
* `app-instance`

***

### ⚙️ Step 3: Install ELK Stack on `elk-instance`

SSH into `elk-instance`:

```bash
ssh -i "your-key.pem" ubuntu@<elk-instance-public-ip>
```

#### 3.1 Install Java

```bash
sudo apt update -y && sudo apt upgrade -y
sudo apt install -y openjdk-11-jdk
```

#### 3.2 Install Elasticsearch

```bash
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
sudo apt install apt-transport-https
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-7.x.list
sudo apt update -y && sudo apt install elasticsearch -y
```

Enable and start Elasticsearch:

```bash
sudo systemctl enable elasticsearch
sudo systemctl start elasticsearch
```

#### 3.3 Install Logstash

```bash
sudo apt install logstash -y
```

#### 3.4 Install Kibana

```bash
sudo apt install kibana -y
sudo systemctl enable kibana
sudo systemctl start kibana
```

#### 3.5 Configure Logstash to Receive Logs

Create a basic pipeline for Filebeat input:

```bash
sudo nano /etc/logstash/conf.d/filebeat.conf
```

Paste this:

```editorconfig
input {
  beats {
    port => 5044
  }
}

output {
  elasticsearch {
    hosts => ["http://localhost:9200"]
    index => "app-logs-%{+YYYY.MM.dd}"
  }
}
```

Now enable Logstash:

```bash
sudo systemctl enable logstash
sudo systemctl start logstash
```

***

### ☕️ Step 4: Setup the Java App on `app-instance`

SSH into your app server:

```bash
ssh -i "your-key.pem" ubuntu@<app-instance-public-ip>
```

#### 4.1 Install Java & Maven

```bash
sudo apt update -y && sudo apt upgrade -y
sudo apt install -y openjdk-11-jdk maven git
```

#### 4.2 Clone GitHub Repo

```bash
cd /home/ubuntu
git clone https://github.com/sarangsurve/Boardgame.git
cd Boardgame
```

#### 4.3 Build the Project

```bash
mvn clean package
```

> Output JAR file will be created in: `/home/ubuntu/Boardgame/target/`

#### 4.4 Run the App with nohup

```bash
cd target
nohup java -jar *.jar > app.log 2>&1 &
```

This generates logs in `/home/ubuntu/Boardgame/target/app.log`.

***

### 📦 Step 5: Install and Configure Filebeat on `app-instance`

```bash
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.17.0-amd64.deb
sudo dpkg -i filebeat-7.17.0-amd64.deb
```

#### 5.1 Configure Filebeat to Send Logs

```bash
sudo nano /etc/filebeat/filebeat.yml
```

Update the following sections:

```yaml
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /home/ubuntu/MyApp/target/app.log

output.logstash:
  hosts: ["<elk-instance-private-ip>:5044"]
```

Replace `<elk-instance-private-ip>` with the private IP of your ELK server.

#### 5.2 Start Filebeat

```bash
sudo filebeat modules enable system
sudo filebeat setup
sudo systemctl start filebeat
sudo systemctl enable filebeat
```

***

### 📊 Step 6: View Logs in Kibana

1. Visit `http://<elk-instance-public-ip>:5601`
2. Go to **Discover** in Kibana
3. Create a new index pattern: `app-logs-*`
4. Choose the time field (usually `@timestamp`)
5. Start exploring logs sent from your Java app!

***

### 🎉 Conclusion

You've just built a simple yet powerful **centralized logging solution** using:

* ELK Stack on one EC2 instance
* Java app on another EC2 instance
* Filebeat to ship logs

This setup can be easily scaled and secured for production by:

* Adding HTTPS with Nginx + Certbot
* Restricting Filebeat traffic to internal VPC
* Adding Logstash filters for better log parsing

***

If you found this helpful, give it a clap 👏 and follow me for more DevOps tips!
